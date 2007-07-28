package Net::XMPP2::Ext::MUC;
use strict;
use Net::XMPP2::Util;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Ext;

our @ISA = qw/Net::XMPP2::Ext/;

=head1 NAME

Net::XMPP2::Ext::MUC - Implements XEP-0045: Multi-User Chat

=head1 SYNOPSIS

   my $con = Net::XMPP2::Connection->new (...);
   $con->add_extension (my $disco = Net::XMPP2::Ext::Disco->new);
   $con->add_extension (my $muc = Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con));
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
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub is_conference {
   my ($self, $jid) = @_;
}

sub is_room {
   my ($self, $con, $jid) = @_;
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
