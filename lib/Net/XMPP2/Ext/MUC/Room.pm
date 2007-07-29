package Net::XMPP2::Ext::MUC::Room;
use strict;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Util qw/bare_jid prep_bare_jid cmp_jid split_jid join_jid is_bare_jid/;
use Net::XMPP2::Event;
use Net::XMPP2::Ext::MUC::User;

use constant {
   JOIN_SENT => 1,
   JOINED    => 2,
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
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;
   $self->{jid} = bare_jid ($self->{jid});
}

sub handle_presence {
   my ($self, $node) = @_;

   my $s = $self->{status};

   my $to   = $node->attr ('to');
   my $from = $node->attr ('from');
   my ($xuser) = $node->find_all ([qw/muc_user x/]);

   my $error;
   if ($node->attr ('type') eq 'error') {
      $error = Net::XMPP2::Error::Presence->new (node => $node);
   }

   if ($s == JOIN_SENT) {
   warn "PRESENCE\b";
      if (is_bare_jid ($from) && $error) {
         my $muce = Net::XMPP2::Error::MUC->new (
            presence_error => $error, type => 'presence_error'
         );
         $self->event (join_error => $muce);
         $self->event (error      => $muce);

      } else {
      warn "CMP $from :" .$self->nick_jid ."\n";
         if (cmp_jid ($from, $self->nick_jid)) {
            $self->add_user_xml ($node, $xuser);
            $self->{status} = JOINED;
            $self->event ('enter');
         } else {
            $self->add_user_xml ($node, $xuser);
         }
      }
   } else { # nick changes?

   }
}

sub add_user_xml {
   my ($self, $node, $xuser) = @_;
   my $from = $node->attr ('from');
   my ($node, $srv, $nick) = split_jid ($from);

   my ($aff, $role, $stati);
   $stati = {};

   if (my ($item) = $xuser->find_all ([qw/muc_user item/])) {
      $aff  = $item->attr ('affiliation');
      $role = $item->attr ('role');
   }

   $self->add_user ($from, $nick, $aff, $role);
}

sub add_user {
   my ($self, $jid, $nick, $affiliation, $role, @info) = @_;
   $self->{users}->{$nick} =
      Net::XMPP2::Ext::MUC::User->new (
         room => $self,
         jid => $jid, nick => $nick, affiliation => $affiliation,
         role => $role
      )
}

sub _join_jid_nick {
   my ($jid, $nick) = @_;
   my ($node, $host) = split_jid $jid;
   join_jid ($node, $host, $nick);
}

sub send_join {
   my ($self, $nick) = @_;

   unless ($self->is_connected) {
      warn "room $self not connected anymore!";
      return;
   }

   $self->{nick_jid} = _join_jid_nick ($self->{jid}, $nick);
   $self->{status}   = JOIN_SENT;

   my $con = $self->{muc}->{connection};
   $con->send_presence (undef, {
      defns => 'muc', node => { ns => 'muc', name => 'x' }
   }, to => $self->{nick_jid});
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

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
