package Net::XMPP2::IM::Account;
use strict;
use Net::XMPP2::Util qw/stringprep_jid prep_bare_jid split_jid/;
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

=head1 METHODS

=over 4

=item B<connection ()>

Returns the L<Net::XMPP2::IM::Connection> object if this account already
has one (undef otherwise).

=cut

sub connection { $_[0]->{con} }

=item B<is_connected ()>

Returns true if this accunt is connected.

=cut

sub is_connected {
   my ($self) = @_;
   $self->{con} && $self->{con}->is_connected
}

=item B<jid ()>

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

=item B<bare_jid ()>

Returns always the bare jid of this account.

=cut

sub bare_jid {
   my ($self) = @_;
   prep_bare_jid $self->jid
}

=item B<nickname ()>

Your nickname for this account.

=cut

sub nickname {
   my ($self) = @_;
   # FIXME: fetch real nickname from server somehow? Does that exist?
   # eg. from the roster?
   my ($user, $host, $res) = split_jid ($self->bare_jid);
   $user
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
