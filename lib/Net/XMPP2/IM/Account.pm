package Net::XMPP2::IM::Account;
use strict;
use Net::XMPP2::Util qw/stringprep_jid prep_bare_jid/;
use Net::XMPP2::IM::Connection;

=head1 NAME

Net::XMPP2::IM::Account - An instant messaging account

=head1 SYNOPSIS

   my $cl = Net::XMPP2::IM::Client->new;
   ...
   my $acc = $cl->get_account ($jid);

=head1 DESCRIPTION

This module represents a class for IM accounts. It is used
by L<Net::XMPP2::Client>.

You can get an instance of this class only by calling the C<get_account>
method on a L<Net::XMPP2::Client> object.

=cut


sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->{jid} = stringprep_jid $self->{jid};
   $self
}

sub remove_connection {
   my ($self) = @_;
   delete $self->{con}
}

sub spawn_connection {
   my ($self) = @_;

   $self->{con} = Net::XMPP2::IM::Connection->new (
      jid      => $self->jid,
      password => $self->{password},
      ($self->{host} ? (override_host => $self->{host}) : ()),
      ($self->{port} ? (override_port => $self->{port}) : ()),
   )
}

=head2 connection ()

Returns the L<Net::XMPP2::IM::Connection> object if this account already
has one (undef otherwise).

=cut

sub connection { $_[0]->{con} }

=head2 is_connected ()

Returns true if this accunt is connected.

=cut

sub is_connected {
   my ($self) = @_;
   $self->{con} && $self->{con}->is_connected
}

=head2 jid ()

Returns either the full JID if the account is
connected or returns the bare jid if not.

=cut

sub jid {
   my ($self) = @_;
   if ($self->is_connected) {
      return $self->{con}->jid;
   }
   $_[0]->{jid}
}

=head2 bare_jid ()

Returns always the bare jid of this account.

=cut

sub bare_jid {
   my ($self) = @_;
   prep_bare_jid $self->jid
}

1;
