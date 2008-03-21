package Net::XMPP2::Ext::MUC;
use strict;
use Net::XMPP2::Util qw/prep_bare_jid bare_jid/;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Ext;
use Net::XMPP2::Ext::MUC::Room;
use Net::XMPP2::Ext::MUC::RoomInfo;

our @ISA = qw/Net::XMPP2::Ext/;

=head1 NAME

Net::XMPP2::Ext::MUC - Implements XEP-0045: Multi-User Chat

=head1 SYNOPSIS

   my $con = Net::XMPP2::Connection->new (...);
   $con->add_extension (my $disco = Net::XMPP2::Ext::Disco->new);
   $con->add_extension (
      my $muc = Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con)
   );
   ...

=head1 DESCRIPTION

This module handles multi user chats and provides new events to catch
multi user chat messages. It intercepts messages from the connection
so they don't interfere with your other callbacks on the connection.

This extension requires the L<Net::XMPP2::Ext::Disco> extension for service
discovery.

=cut

=head1 METHODS

=over 4

=item B<new>

This is the constructor for a pubsub object.
It takes no further arguments.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { join_timeout => 60, @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;

   $self->reg_cb (
      ext_before_presence_xml => sub {
         my ($self, $con, $node) = @_;
         my $from_jid = $node->attr ('from');

         if (exists $self->{room_evs}->{prep_bare_jid $from_jid}) {
            $self->stop_event;
            $self->{room_evs}->{prep_bare_jid $from_jid}->handle_presence ($node);
         }
      },
      ext_before_message_xml => sub {
         my ($self, $con, $node) = @_;
         my $from_jid = $node->attr ('from');

         if (exists $self->{room_evs}->{prep_bare_jid $from_jid}) {
            $self->stop_event;
            $self->{room_evs}->{prep_bare_jid $from_jid}->handle_message ($node);
         }
      },
      disconnect => sub {
         my ($self) = @_;
         $self->cleanup
      }
   );
}

sub cleanup {
   my ($self) = @_;
   $self->{room_evs} = {};
}

=item B<is_conference ($jid, $cb)>

TODO

=cut

sub is_conference {
   my ($self, $jid, $cb) = @_;

   $self->{disco}->request_info ($self->{connection}, $jid, undef, sub {
      my ($disco, $info, $error) = @_;
      if ($error || !$info->features ()->{xmpp_ns ('muc')}) {
         $cb->(undef, $error);
      } else {
         $cb->($info, undef);
      }
   });
}

=item B<is_room ($jid, $cb)>

This method sends a information discovery to the C<$jid>.
C<$cb> is called when the information arrives or with an error
after the usual IQ timeout.

When the C<$jid> was a room C<$cb> is called with the first argument
being a L<Net::XMPP2::Ext::MUC::RoomInfo> object. If the destination
wasn't reachable, the room doesn't exist or some other error happened
the first argument will be undefined and the second a L<Net::XMPP2::Error::IQ>
object.

=cut

sub is_room {
   my ($self, $jid, $cb) = @_;

   $self->{disco}->request_info ($self->{connection}, $jid, undef, sub {
      my ($disco, $info, $error) = @_;

      if ($error || !$info->features ()->{xmpp_ns ('muc')}) {
         $cb->(undef, $error);
      } else {
         my $rinfo = Net::XMPP2::Ext::MUC::RoomInfo->new (disco_info => $info);
         $cb->($rinfo, undef);
      }
   });
}

=item B<join_room ($jid, $nick, $cb, %args)>

This method joins a room.

C<$jid> should be the bare jid of the room.
C<$nick> should be your desired nickname in the room.

C<$cb> is called upon successful entering the room or
if an error occured. If no error occured the first
argument is a L<Net::XMPP2::Ext::MUC::Room> object (the
one of the joined room) and the second is a L<Net::XMPP2::Ext::MUC::User>
object, the one of yourself. And the third argument is undef.

If an error occured and we couldn't join the room, the first two arguments are
undef and the third is a L<Net::XMPP2::Error::MUC> object signalling the error.

C<%args> hash can contain one of the following keys:

=over 4

=item timeout => $timeout_in_secs

This is the timeout for joining the room.
The default timeout is 60 seconds if the timeout is not specified.

=item create_instant => $bool

If you set C<$bool> to a true value we try to establish an instant room
on joining if it doesn't already exist.

The default for this flag is true! So if you want to creat an reserved room
with custom creation in the beginning you have to pass a false value as C<$bool>.

B<PLEASE NOTE:> If you set C<$bool> to a B<false> value you have to check the
C<did_create_room> statusflag on your own instance of
L<Net::XMPP2::Ext::MUC::User> (provided as the second argument to the callback)
to see whether you need to finish room creation! If you don't do this the room
B<may stay LOCKED for ever>.

See also the C<make_instant> and C<request_configuration> methods of L<Net::XMPP2::Ext::MUC>.

=item password => $password

The password for the room.

=item nickcollision_cb => $cb

If the join to the room results in a nickname collision the C<$cb>
will be called with the nickname that collided and the return value will
be used as alternate nickname and the join is retried.

This function is called I<everytime> the nickname collides on join, so you
should take care of possible endless retries.

=back

=cut

sub join_room {
   my ($self, $jid, $nick, $cb, %args) = @_;

   unless (exists $args{create_instant}) {
      $args{create_instant} = 1;
   }
   my $timeout = $args{timeout} || $self->{join_timeout};

   my $room = $self->install_room ($jid);

   my $pbj = prep_bare_jid $jid;

   $self->{room_join_timer}->{$pbj} =
      AnyEvent->timer (after => $timeout, cb => sub{
         $self->uninstall_room ($room);
         my $muce = Net::XMPP2::Error::MUC->new (
            type => 'join_timeout',
            text => "Couldn't join room in time, timeout after $timeout\n"
         );
         delete $self->{room_join_timer}->{$pbj};
         $cb->(undef, undef, $muce);
      });

   my $rcb_id;
   $rcb_id = $room->reg_cb (
      join_error => sub {
         my ($room, $error) = @_;

         if ($error->type eq 'nickname_in_use'
             && exists $args{nickcollision_cb}) {
            $nick = $args{nickcollision_cb}->($nick);
            $room->send_join ($nick, $args{password});
            return;
         }

         delete $self->{room_join_timer}->{$pbj};
         $self->uninstall_room ($room);
         $room->unreg_cb ($rcb_id);
         $cb->(undef, undef, $error);
      },
      enter => sub {
         my ($room, $user) = @_;

         delete $self->{room_join_timer}->{$pbj};
         $room->unreg_cb ($rcb_id);

         if ($user->did_create_room && $args{create_instant}) {
            $room->make_instant (sub {
               my ($room, $error) = @_;
               if ($error) {
                  $cb->(undef, undef, $error);
               } else {
                  $cb->($room, $user, undef);
               }
            });

         } else {
            $cb->($room, $user, undef);
         }
      }
   );

   $room->send_join ($nick, $args{password});
}

sub install_room {
   my ($self, $room_jid) = @_;
   my $room
      = $self->{room_evs}->{prep_bare_jid $room_jid}
         = Net::XMPP2::Ext::MUC::Room->new (muc => $self, jid => $room_jid);

   $room->add_forward ($self, sub {
      my ($room, $self, $ev, @args) = @_;
      $self->_event ($ev . '_room', $self->{connection}, $room, @args);
   });

   $room->reg_cb (
      ext_after_leave => sub {
         my ($room) = @_;
         $room->remove_forward ($self);
      }
   );

   $room
}

sub uninstall_room {
   my ($self, $room) = @_;
   my $jid = $room->{jid};
   delete $self->{room_evs}->{prep_bare_jid $jid};
   delete $room->{muc};
}

=item B<get_room ($jid)>

This returns the L<Net::XMPP2::Ext::MUC::Room> object
for the bare part of the C<$jid> if we are joining or have
joined such a room.

If we are not joined undef is returned.

=cut

sub get_room {
   my ($self, $jid) = @_;
   $self->{room_evs}->{prep_bare_jid $jid}
}

=item B<is_connected>

This returns whether we are still connected and can send messages.

=cut

sub is_connected {
   my ($self) = @_;
   $self->{connection}->is_connected
}

=back

=head1 EVENTS

All events from L<Net::XMPP2::Ext::MUC::Room> instances that were
joined with this MUC are forwarded to this object. The events
from the room are prefixed with 'room_' and the first argument
is always the L<Net::XMPP2::Connection> the MUC operates on, the
second is always the L<Net::XMPP2::Ext::MUC::Room> object and
the rest of the argument corresponds to the arguments of the event of
the room. See the event description for L<Net::XMPP2::Ext::MUC::Room>
for details which events are generated. Generally, if you want for example
to get the joined event:

   $muc->reg_cb (room_enter => sub {
      my ($muc, $con, $room) = @_;
      # ...
   });

These additional events can be registered on with C<reg_cb>:

=over 4

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::Ext::Pubsub
