package Net::XMPP2::Client;
use strict;
use AnyEvent;
use IO::Socket::INET;
use Net::XMPP2::Parser;
use Net::XMPP2::Writer;
use Net::XMPP2::Util;
use Net::XMPP2::Event;
use Net::XMPP2::SimpleConnection;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::DNS;

our @ISA = qw/Net::XMPP2::Event/;

=head1 NAME

Net::XMPP2::Client - A XMPP Client abstraction

=head1 SYNOPSIS

   use Net::XMPP2::Client;
   use AnyEvent;

   my $j = AnyEvent->condvar;

   my $cl = Net::XMPP2::Client->new;
   $cl->start;

   $j->wait;

=head1 DESCRIPTION

This module tries to implement a straight forward and easy to
use API to communicate with XMPP entities. L<Net::XMPP2::Client>
handles connections and timeouts and all such stuff for you.

For more flexibility please have a look at L<Net::XMPP2::Connection>
and L<Net::XMPP2::IM::Connection>, they allow you to control what
and how something is being sent more precisely.

=head1 METHODS

=head2 new (%args)

Following arguments can be passed in C<%args>:

=over 4

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class;

   return $self;
}

=head1 EVENTS

These events can be registered on with C<reg_cb>:

=over 4

=item iq_get_request_xml => $node, $handled_ref

These events are sent when an iq request stanza of type 'get' or 'set' is received.
C<$type> will either be 'get' or 'set' and C<$node> will be the L<Net::XMPP2::Node>
object of the iq tag.

If C<$$handled_ref> is true an event handler should not handle this message anymore.

If one of the event handlers handled this message the scalar pointed at by
the reference in C<$handled_ref> should be set to 1 true value. If C<$$handled_ref>
is still false after all event handlers were executed an error iq will be generated.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::Client
