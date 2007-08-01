package Net::XMPP2::Ext::MUC::Room;
use strict;
no warnings;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Util qw/
   bare_jid prep_bare_jid cmp_jid split_jid join_jid is_bare_jid
   prep_res_jid prep_join_jid
/;
use Net::XMPP2::Event;
use Net::XMPP2::Ext::MUC::User;
use Net::XMPP2::Error::MUC;

use constant {
   JOIN_SENT => 1,
   JOINED    => 2,
   LEFT      => 3,
};

our @ISA = qw/Net::XMPP2::Event/;

=head1 NAME

Net::XMPP2::Ext::MUC::Room - Room class

=head1 SYNOPSIS

=head1 DESCRIPTION

This module represents a room handle for a MUC.

=head1 METHODS

=over 4

=item B<new (%args)>

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { status => LEFT, @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;
   $self->{jid} = bare_jid ($self->{jid});

   my $proxy = sub {
      my ($self, $error) = @_;
      $self->event (error => $error);
   };

   $self->reg_cb (
      join_error => $proxy,
   );
}

sub handle_message {
   my ($self, $node) = @_;
   my $msg = Net::XMPP2::Ext::MUC::Message->new (room => $self);
   $msg->from_node ($node);
   my $is_echo = cmp_jid ($msg->from, $self->nick_jid);
   $self->event (message => $msg, $is_echo);
}

sub handle_presence {
   my ($self, $node) = @_;

   my $s = $self->{status};

   my $from    = $node->attr ('from');
   my $type    = $node->attr ('type');

   my $error;
   if ($node->attr ('type') eq 'error') {
      $error = Net::XMPP2::Error::Presence->new (node => $node);
   }

   if ($s == JOIN_SENT) {
      if ($error) {
         my $muce = Net::XMPP2::Error::MUC->new (
            presence_error => $error,
            type           => 'presence_error'
         );
         $self->event (join_error => $muce);

      } else {

         if (cmp_jid ($from, $self->nick_jid)) {
            my $user = $self->add_user_xml ($node);
            $self->{status} = JOINED;
            $self->{me} = $user;
            $self->event (enter => $user);

         } else {
            $self->add_user_xml ($node);
         }
      }
   } elsif ($s == JOINED) { # nick changes?

      if ($error) {
         my $muce = Net::XMPP2::Error::MUC->new (
            presence_error => $error,
            type           => 'presence_error'
         );
         $self->event (error      => $muce);

      } elsif ($type eq 'unavailable') {

         if (cmp_jid ($from, $self->nick_jid)) {
            $self->event ('leave');
            $self->we_left_room ();

         } else {
            my $nick = prep_res_jid ($from);

            my $user = delete $self->{users}->{$nick};
            if ($user) {
               $user->update ($node);
               $self->event (part => $user);
            } else {
               warn "User with '$nick' not found in room $self->{jid}!\n";
            }
         }
      } else {
         my $nick = prep_res_jid $from;
         my $pre  = $self->{users}->{$nick};
         my $user = $self->add_user_xml ($node);
         if ($pre) {
            $self->event (presence => $user);
         } else {
            $self->event (join     => $user);
         }
      }
   }
}

sub we_left_room {
   my ($self) = @_;
   $self->{users}  = {};
   $self->{status} = LEFT;
   delete $self->{me};
}

=item B<get_user ($nick)>

This method returns the user with the C<$nick> in the room.

=cut

sub get_user {
   my ($self, $nick) = @_;
   $self->{users}->{$nick}
}

=item B<get_me>

This method returns the L<Net::XMPP2::Ext::MUC::User> object of yourself
in the room. If will return undef if we are not in the room anymore.

=cut

sub get_me {
   my ($self) = @_;
   $self->{me}
}

=item B<get_user_jid ($jid)>

This method looks whether a user with the JID C<$jid> exists
in the room. That means whether the node and domain part of the
JID match the rooms node and domain part, and the resource part of the
JID matches a joined nick.

=cut

sub get_user_jid {
   my ($self, $jid) = @_;
   my ($room, $srv, $nick) = split_jid ($jid);
   return unless prep_join_jid ($room, $srv) eq prep_bare_jid $self->jid;
   $self->{users}->{$nick}
}

sub add_user_xml {
   my ($self, $node) = @_;
   my $from = $node->attr ('from');
   my $nick = prep_res_jid ($from);

   my $user = $self->{users}->{$nick};
   unless ($user) {
      $user = $self->{users}->{$nick} =
         Net::XMPP2::Ext::MUC::User->new (room => $self, jid => $from);
   }

   $user->update ($node);

   $user
}

sub _join_jid_nick {
   my ($jid, $nick) = @_;
   my ($node, $host) = split_jid $jid;
   join_jid ($node, $host, $nick);
}

sub check_online {
   my ($self) = @_;
   unless ($self->is_connected) {
      warn "room $self not connected anymore!";
      return 0;
   }
   1
}

sub send_join {
   my ($self, $nick) = @_;
   $self->check_online or return;

   $self->{nick_jid} = _join_jid_nick ($self->{jid}, $nick);
   $self->{status}   = JOIN_SENT;

   my $con = $self->{muc}->{connection};
   $con->send_presence (undef, {
      defns => 'muc', node => { ns => 'muc', name => 'x' }
   }, to => $self->{nick_jid});
}

sub message_class { 'Net::XMPP2::Ext::MUC::Message' }

=item B<make_message (%args)>

This method constructs a L<Net::XMPP2::Ext::MUC::Message> with
a connection to this room.

C<%args> are further arguments for the constructor of L<Net::XMPP2::Ext::MUC::Message>.
The default C<to> argument for the message is the room and the
C<type> will be 'groupchat'.

=cut

sub make_message {
   my ($self, %args) = @_;
   $self->message_class ()->new (
      room       => $self,
      to         => $self->jid,
      type       => 'groupchat',
      %args
   )
}

=item B<send_part ($msg)>

This lets you part the room, C<$msg> is an optional part message
and can be undef if no custom message should be generated.

=cut

sub send_part {
   my ($self, $msg) = @_;
   $self->check_online or return;
   my $con = $self->{muc}->{connection};
   $con->send_presence (
      'unavailable', undef,
      (defined $msg ? (status => $msg) : ()),
      to => $self->{nick_jid});
}

=item B<users>

Returns a list of L<Net::XMPP2::Ext::MUC::User> objects
which are in this room.

=cut

sub users {
   my ($self) = @_;
   values %{$self->{users}}
}

=item B<jid>

Returns the bare JID of this room.

=cut

sub jid      { $_[0]->{jid} }

=item B<nick_jid>

Returns the full JID of yourself in the room.

=cut

sub nick_jid { $_[0]->{nick_jid} }

=item B<is_connected>

Returns true if this room is still connected (but maybe not joined (yet)).

=cut

sub is_connected {
   my ($self) = @_;
   $self->{muc}
   && $self->{muc}->is_connected
}

=item B<is_joined>

Returns true if this room is still joined (and connected).

=cut

sub is_joined {
   my ($self) = @_;
   $self->is_connected
   && $self->{status} == JOINED
}

=back

=head1 EVENTS

These events can be registered on with C<reg_cb>:

=over 4

=item message => $msg, $is_echo

This event is emitted when a message was received from the room.
C<$msg> is a L<Net::XMPP2::Ext::MUC::Message> object and C<$is_echo>
is true if the message is an echo.

=item error => $error

This event is emitted when any error occured.
C<$error> is a L<Net::XMPP2::Error::MUC> object.

=item join_error => $error

This event is emitted when a error occured when joining a room.
C<$error> is a L<Net::XMPP2::Error::MUC> object.

=item enter => $user

This event is emitted when we successfully joined the room.
C<$user> is a L<Net::XMPP2::Ext::MUC::User> object which is
the user handle for ourself.

=item join => $user

This event is emitted when a new user joins the room.
C<$user> is the L<Net::XMPP2::Ext::MUC::User> of that user.

=item presence => $user

This event is emitted when a user changes it's presence status
(eg. affiliation or role, or away status).
C<$user> is the L<Net::XMPP2::Ext::MUC::User> of that user.

=item part => $user

This event is emitted when a user leaves the channel.  C<$user> is the
L<Net::XMPP2::Ext::MUC::User> of that user, but please note that you shouldn't
send any messages to this user anymore.

=item leave

This event is emitted when we leave the room.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;