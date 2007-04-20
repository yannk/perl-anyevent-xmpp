package Net::XMPP2::IM::Contact;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::IM::Presence;
use Net::XMPP2::IM::Message;

=head1 NAME

Net::XMPP2::IM::Contact - A instant messaging roster contact

=head1 SYNOPSIS

   my $con = Net::XMPP2::IM::Connection->new (...);
   ...
   my $ro  = $con->roster;
   if (my $c = $ro->get_contact ('test@example.com')) {
      $c->make_message ()->add_body ("Hello there!")->send;
   }

=head1 DESCRIPTION

This module represents a class for contact objects which populate
a roster (L<Net::XMPP2::IM::Roster>.

You can get an instance of this class only by calling the C<get_contact>
function on a roster object.

=cut


sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   bless { @_ }, $class;
}

sub _set {
   my ($self, %data) = @_;
   $self->{$_} = $data{$_} for keys %data;
   $self
}

sub remove_presence {
   my ($self, $jid) = @_;
   my $sjid = Net::XMPP2::Util::stringprep_jid ($jid);
   delete $self->{presences}->{$sjid}
}

sub touch_presence {
   my ($self, $jid) = @_;
   my $sjid = Net::XMPP2::Util::stringprep_jid ($jid);

   unless (exists $self->{presences}->{$sjid}) {
      $self->{presences}->{$sjid} =
         Net::XMPP2::IM::Presence->new (connection => $self->{connection}, jid => $jid);
   }
   $self->{presences}->{$sjid}
}

=head2 get_presence ($jid)

This method returns a presence of this contact if
it is available. The return value is an instance of L<Net::XMPP2::IM::Presence>
or undef if no such presence exists.

=cut

sub get_presence {
   my ($self, $jid) = @_;
   my $sjid = Net::XMPP2::Util::stringprep_jid ($jid);
   $self->{presences}->{$sjid}
}

=head2 get_presences

Returns all presences of this contact in form of
L<Net::XMPP2::IM::Presence> objects.

=cut

sub get_presences { values %{$_[0]->{presences}} }

sub set_presence {
   my ($self, $jid, %data) = @_;
   my $old;
   if ($data{type} eq 'unavailable') {
      $old = $self->remove_presence ($jid);
   } else {
      my $p = $self->touch_presence ($jid);
      $old = $p->clone;
      $p->_set (%data);
   }
   $old
}

=head2 groups

Returns the list of groups (strings) this contact is in.

=cut

sub groups {
   @{$_[0]->{groups} || []}
}

=head2 jid

Returns the bare JID of this contact.

=cut

sub jid {
   $_[0]->{jid}
}

=head2 name

Returns the (nick)name of this contact.

=cut

sub name {
   $_[0]->{name}
}

=head2 is_on_roster ()

Returns 1 if this is a contact that is officially on the
roster and not just a contact we've received presence information
for.

=cut

sub is_on_roster {
   my ($self) = @_;
   $self->{subscription} && $self->{subscription} ne ''
}

=head2 subscription

Returns the subscription state of this contact, which
can be one of:

   'none', 'to', 'from', 'both'

=cut

sub subscription {
   $_[0]->{subscription}
}

sub make_message {
   my ($self) = @_;
   Net::XMPP2::IM::Message->new (
      connection => $self->{connection},
      to         => $self->jid
   );
}

sub debug_dump {
   my ($self) = @_;
   printf "- %-30s    [%-20s] (%s)\n",
      $self->jid,
      $self->name || '',
      $self->subscription;

   for ($self->get_presences) {
      $_->debug_dump;
   }
}

1;
