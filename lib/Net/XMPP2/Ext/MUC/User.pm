package Net::XMPP2::Ext::MUC::User;
use strict;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Event;

our @ISA = qw/Net::XMPP2::Event/;

=head1 NAME

Net::XMPP2::Ext::MUC::User - User class

=head1 SYNOPSIS

=head1 DESCRIPTION

This module represents a user (occupant) handle for a MUC.

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
