package Net::XMPP2::IM::Connection;
use strict;
use Net::XMPP2::Connection;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::IM::Roster;
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
         $self->{session_active} = 1;
         $self->send_presence ();
         $self->event ('session_ready');
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
         $self->{session_active} = 1;
         $self->send_presence;
         $self->retrieve_roster;
         $self->event ('session_ready');
      } else {
         $self->event (session_error => $errnode, $errar); # TODO: make error obj
      }
   });
}

sub retrieve_roster {
   my ($self) = @_;

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
   });
}

sub store_roster {
   my ($self, $node) = @_;

   my ($query) = $node->find_all ([qw/roster query/]);
   return unless $query;

   for my $item ($query->find_all ([qw/roster item/])) {
      my ($jid, $name, $subscription) =
         ($item->attr ('jid'), $item->attr ('name'), $item->attr ('subscription'));
      my @groups;
      push @groups, $_->text for $item->find_all ([qw/roster group/]);

      $self->{roster}->set_contact ($jid,
         name         => $name,
         subscription => $subscription,
         groups       => [ @groups ]
      );
   }

   $self->event (roster_update => $self->{roster});
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

   my @stati;
   push @stati, [$_->attr ('lang'), $_->text]
      for $node->find_all ([qw/client status/]);

   $self->{roster}->set_presence ($jid,
      show     => $show     ? $show->text     : undef,
      priority => $priority ? $priority->text : undef,
      type     => $type,
      status   => \@stati,
   );

   $self->event (presence_update => $self->{roster}, $self->{roster}->get_contact ($jid))
}

sub handle_message {
   my ($self) = @_;
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

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-xmpp2 at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-XMPP2>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::XMPP2

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-XMPP2>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-XMPP2>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-XMPP2>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-XMPP2>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut



1; # End of Net::XMPP2
