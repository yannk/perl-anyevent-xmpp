package Net::XMPP2;
use warnings;
use strict;

our %EXTENSION_ENABLED;

=head1 NAME

Net::XMPP2 - An implementation of the XMPP Protocol

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

   use Net::XMPP2::Connection;

or:

   use Net::XMPP2::IM::Connection;

=head1 DESCRIPTION

This is the head module of the L<Net::XMPP2> XMPP client protocol (as described in
RFC 3920 and RFC 3921) framework.

L<Net::XMPP2::Connection> is a RFC 3920 conformant "XML" stream implementation
for clients, which handles tcp connect up to the resource binding. And provides
low-level access to the XML nodes on the XML stream along with some high
level methods to send the predefined XML stanzas.

L<Net::XMPP2::IM::Connection> is a more highlevel module, which is derived
from L<Net::XMPP2::Connection>. It handles all the instant messaging client
functionality described in RFC 3921.

Some extensions for XMPP are also implemented and can be activated as described
below in L<Supportet extensions>.

There are also other modules in this distribution, for example:
L<Net::XMPP2::Util>, L<Net::XMPP2::Writer>, L<Net::XMPP2::Parser> and those i
forgot :-) Those modules might be helpful and/or required if you want to use
this framework for XMPP.

See also L<Net::XMPP2::Writer> for a discussion about the brokeness of XML in the XMPP
specification.

=head1 Why (yet) another XMPP module?

The main outstanding feature of this module in comparsion to the other XMPP
(aka Jabber) modules out there is the support for L<AnyEvent>. L<AnyEvent>
permits you to use this module together with other I/O event based programs and
libraries (ie. L<Gtk2> or L<Event>).

The other modules could often only be integrated in those applications or librarys
by using threads. I decided to write this module because i think CPAN lacks
an event based XMPP module. Threads are unfortunately not an alternative in Perl
at the moment due the limited threading functionality they provide and the global
speed hit. I also think that a simple event based I/O framework might be a bit easier
to handle than threads.

Another thing was that I didn't like the APIs of the other modules. In L<Net::XMPP2>
i try to provide low level modules for speaking XMPP as defined in RFC 3920 and RFC 3921
(see also L<Net::XMPP2::Connection> and L<Net::XMPP2::IM::Connection>). But i also
try to provide a high level API.

I also try to have all additional features and functionality as optional as possible
to give the client writers enough freedom.

=head1 A note about TLS

This module also supports TLS, as the specification of XMPP requires an
implementation to support TLS. This module also needs a very recent version of
L<Net::SSLeay> which has the functions L<Net::SSLeay::write_nb> and
L<Net::SSLeay::read_nb>. Those functions are required for non-blocking I/O with TLS.

Unfortunately the implementation of TLS with non-blocking sockets was not as easy as i
expected. I needed to extend L<Net::SSLeay> to provide read and write functions
which supported retries and i also needed some more complicated approach in handling
ready states of the sockets.

There are maybe still some bugs in the handling of TLS in L<Net::XMPP2::Connection>.
So keep an eye on TLS with this module and please inform with a detailed bug report
if you run into any problems. As i use this module myself i don't expect TLS to be
completly broken, but it might break under different circumstances than i have here.
Those circumstances might be a different load of data pumped through the TLS
connection.

I mainly expect problems where aviable data isn't properly read from the socket
or written to it. You might want to take a look at the C<debug_send> and C<debug_recv>
events in L<Net::XMPP2::Connection>.

=head1 Supportet extensions

You can extend the functionality of this modules either by giving C<use Net::XMPP2>
an argument like this:

   use Net::XMPP2 qw/xep-0086/;

This is the list of supported XMPP extensions:

=over 4

=item XEP-0086 - Error Condition Mappings

   "A mapping to enable legacy entities to correctly handle errors from XMPP-aware entities."

This extension will enable sending of the old error codes when generating a stanza
error with for example: L<Net::XMPP2::Writer::write_error_tag>

=back

=cut

sub import {
   my ($mod, @exts) = @_;
   for (@exts) {
      if (/^xep-(\d+)$/i) {
         $EXTENSION_ENABLED{''. (1*$1)} = 1;
      }
   }
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-net-xmpp2 at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-XMPP2>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Net::XMPP2

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Net-XMPP2>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Net-XMPP2>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Net-XMPP2>

=item * Search CPAN

L<http://search.cpan.org/dist/Net-XMPP2>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
