package Net::XMPP2::Ext::Pubsub;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;

=head1 NAME

Net::XMPP2::Ext::Pubsub - Implements XEP-0060: Publish-Subscribe

=head1 SYNOPSIS

   my $con = Net::XMPP2::Connection->new (...);
   $con->add_extension (my $ps = Net::XMPP2::Ext::Pubsub->new);
   ...

=head1 DESCRIPTION

This module implements all tasks of handling the publish subscribe
mechanism. (NOT IMPLEMENTED YET!)

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

1; # End of Net::XMPP2::Ext::Pubsub
