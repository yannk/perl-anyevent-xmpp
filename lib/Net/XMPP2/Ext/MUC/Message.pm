package Net::XMPP2::Ext::MUC::Message;
use strict;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::IM::Message;

our @ISA = qw/Net::XMPP2::IM::Message/;

=head1 NAME

Net::XMPP2::Ext::MUC::Message - A room message

=head1 SYNOPSIS

=head1 DESCRIPTION

This message represents a message from a MUC room. It is
derived from L<Net::XMPP2::IM::Message>. (You can use the
methods from that class to access it for example).

=head1 METHODS

=over 4

=item B<new (%args)>

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = $class->SUPER::new (@_);
   $self->{connection} = $self->{room}->{muc}->{connection};
   $self
}

sub from_node {
   my ($self, $node) = @_;
   $self->SUPER::from_node ($node);
}

=item B<room>

Returns the chatroom in which' context this message
was sent.

=cut

sub room { $_[0]->{room} }

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
