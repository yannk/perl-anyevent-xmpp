package Net::XMPP2::IM::Connection;
use strict;
use Net::XMPP2::Connection;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::IM::Roster;
use Net::XMPP2::IM::Message;
our @ISA = qw/Net::XMPP2::Connection/;

=head1 NAME

Net::XMPP2::IM::Connection - A XML stream that implements the XMPP RFC 3921.

=head1 SYNOPSIS

   use Net::XMPP2::Connection;

   my $con = Net::XMPP2::Connection->new;

=head1 DESCRIPTION

This module represents a XMPP instant messaging connection and implements
RFC 3921.

This module is a subclass of C<Net::XMPP2::Connection> and inherits all methods.
For example C<reg_cb> and the stanza sending routines.

For additional events that can be registered to look below in the EVENTS section.

=head1 METHODS

=cut

=head2 new (%args)

This is the constructor. It takes the same arguments as
the constructor of L<Net::XMPP2::Connection> along with a
few others:

=over 4

=item dont_retrieve_roster => $bool

Set this to a true value if no roster should be requested on connection
establishment. You can retrieve the roster later if you want to
with the C<retrieve_roster> method.

The internal roster will be set even if this option is active, and
even presences will be stored in there, except that the C<get_contacts>
method on the roster object won't return anything as there are
no roster items.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = $class->SUPER::new (@_);

   $self->{ext} = {}; # reserved for extensions
   $self->{roster} = Net::XMPP2::IM::Roster->new (connection => $self);

   $self->reg_cb (message_xml =>
      sub { shift @_; $self->handle_message (@_);    1 });
   $self->reg_cb (presence_xml =>
      sub { shift @_; $self->handle_presence (@_);   1 });
   $self->reg_cb (iq_set_request_xml =>
      sub { shift @_; $self->handle_iq_set (@_);     1 });
   $self->reg_cb (disconnect =>
      sub { shift @_; $self->handle_disconnect (@_); 1 });

   $self->reg_cb (stream_ready => sub {
      my ($jid) = @_;
      if ($self->features ()->find_all ([qw/session session/])) {
         $self->send_session_iq;
      } else {
         $self->init_connection;
      }
   });
   $self
}

sub send_session_iq {
   my ($self) = @_;

   $self->send_iq (set => sub {
      my ($w) = @_;
      $w->addPrefix (xmpp_ns ('session'), '');
      $w->emptyTag ([xmpp_ns ('session'), 'session']);

   }, sub {
      my ($node, $errnode, $errar) = @_;
      if ($node) {
         $self->init_connection;
      } else {
         $self->event (session_error => $errnode, $errar); # TODO: make error obj
      }
   });
}

sub init_connection {
   my ($self) = @_;
   $self->{session_active} = 1;
   if ($self->{dont_retrieve_roster}) {
      $self->send_presence;
   } else {
      $self->retrieve_roster (1);
   }
   $self->event ('session_ready');
}

sub retrieve_roster {
   my ($self, $init) = @_;

   $self->send_iq (get => sub {
      my ($w) = @_;
      $w->addPrefix (xmpp_ns ('roster'), '');
      $w->emptyTag ([xmpp_ns ('roster'), 'query']);

   }, sub {
      my ($node, $errnode, $errar) = @_;
      if ($node) {
         $self->store_roster ($node);
      } else {
         $self->event (roster_error => $errnode, $errar); # TODO: make error obj
      }

      $self->send_presence if $init;
   });
}

sub store_roster {
   my ($self, $node) = @_;

   my ($query) = $node->find_all ([qw/roster query/]);
   return unless $query;

   my @upd;

   for my $item ($query->find_all ([qw/roster item/])) {
      my ($jid, $name, $subscription) =
         ($item->attr ('jid'), $item->attr ('name'), $item->attr ('subscription'));
      my @groups;
      push @groups, $_->text for $item->find_all ([qw/roster group/]);

      push @upd,
         $self->{roster}->set_contact ($jid,
            name         => $name,
            subscription => $subscription,
            groups       => [ @groups ]
         );
   }

   $self->event (roster_update => $self->{roster}, \@upd);
}

sub get_roster {
   my ($self) = @_;
   $self->{roster}
}

sub handle_iq_set {
   my ($self, $node, $rhandled) = @_;

   if ($node->find_all ([qw/roster query/])) {
      $self->store_roster ($node);
      $self->reply_iq_result ($node, sub {});
   }
}

sub handle_presence {
   my ($self, $node) = @_;

   my $type       = $node->attr ('type');
   my ($show)     = $node->find_all ([qw/client show/]);
   my ($priority) = $node->find_all ([qw/client priority/]);

   my $jid = $node->attr ('from');

   my %stati;
   $stati{$_->attr ('lang') || ''} = $_->text
      for $node->find_all ([qw/client status/]);

   my $old =
      $self->{roster}->set_presence ($jid,
         show     => $show     ? $show->text     : undef,
         priority => $priority ? $priority->text : undef,
         type     => $type,
         status   => \%stati,
      );

   my $new = $self->{roster}->get_contact ($jid)->get_presence ($jid);

   $self->event (presence_update => $self->{roster}, $self->{roster}->get_contact ($jid), $old, $new)
}

sub handle_message {
   my ($self, $node) = @_;

   my $from     = $node->attr ('from');
   my $to       = $node->attr ('to');
   my $type     = $node->attr ('type');
   my ($thread) = $node->find_all ([qw/client thread/]);

   my %bodies;
   my %subjects;

   $bodies{$_->attr ('lang') || ''} = $_->text
      for $node->find_all ([qw/client body/]);
   $subjects{$_->attr ('lang') || ''} = $_->text
      for $node->find_all ([qw/client subject/]);

   my $msg =
      Net::XMPP2::IM::Message->new (
         connection => $self,
         from       => $from,
         to         => $to,
         type       => $type,
         bodies     => \%bodies,
         subjects   => \%subjects,
         thread     => $thread
      );

   $self->event (message => $msg);
}

sub handle_disconnect {
   my ($self) = @_;
   delete $self->{roster};
}

=head1 EVENTS

These additional events can be registered on with C<reg_cb>:

=over 4

=item session_ready

This event is generated when the session has been fully established and
can be used to send around messages and other stuff.

=item session_error => $erriq, $errarr

If an error happened during establishment of the session this
event will be generated. C<$erriq> is the L<Net::XMPP2::Node> object
of the error iq tag and C<$errar> is an error array as described in
L<Net::XMPP2::Connection::send_iq> for error responses for iq requests.

=item roster_update => $roster, $contacts

This event is emitted when a roster update has been received.
C<$roster> is the L<Net::XMPP2::IM::Roster> object you get by
calling C<get_roster>.
C<$contacts> is an array reference of L<Net::XMPP2::IM::Contact> objects
which have changed.

=item presence_update => $roster, $contact, $old_presence, $new_presence

This event is emitted when the presence of a contact has changed.
C<$roster> is the L<Net::XMPP2::IM::Roster> object you get by
calling C<get_roster>.
C<$contact> is the L<Net::XMPP2::IM::Contact> object which presence status
has changed.
C<$old_presence> is a L<Net::XMPP2::IM::Presence> object which represents the
presence prior to the change.
C<$new_presence> is a L<Net::XMPP2::IM::Presence> object which represents the
presence after to the change.

=item message => $msg

This event is emitted when a message was received.
C<$msg> is a L<Net::XMPP2::IM::Message> object.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
