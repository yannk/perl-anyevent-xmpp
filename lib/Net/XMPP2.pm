package Net::XMPP2;
use warnings;
use strict;

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

or:

   use Net::XMPP2::Client;

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

L<Net::XMPP2::Client> is a multi account client class. It manages connections
to multiple XMPP accounts and tries to offer a nice highlevel interface
to XMPP communication.

For a list of L</Supportet extensions> see below.

There are also other modules in this distribution, for example:
L<Net::XMPP2::Util>, L<Net::XMPP2::Writer>, L<Net::XMPP2::Parser> and those I
forgot :-) Those modules might be helpful and/or required if you want to use
this framework for XMPP.

See also L<Net::XMPP2::Writer> for a discussion about the brokeness of XML in the XMPP
specification.

If you have any questions or seek for help look below under L</SUPPORT>.

=head1 REQUIREMENTS

One of the major drawbacks I see for Net::XMPP2 is the long list of required
modules to make it work.

=over 4

=item L<AnyEvent>

For the I/O events and timers.

=item L<XML::Writer>

For writing "XML".

=item L<XML::Parser::Expat>

For parsing partial "XML" stuff.

=item L<MIME::Base64>

For SASL authentication

=item L<Authen::SASL>

For SASL authentication

=item L<Net::LibIDN>

For stringprep profiles to handle JIDs.

=item L<Net::SSLeay>

For SSL connections.

=item L<Net::DNS>

For SRV RR lookups.

=back

And yes, all these are essential for XMPP communication. Even thought 'instant
messaging' and 'presence' is a quite simple problem XMPP somehow was successful
at complicating the task enough to keep me busy for a long time.  But all that
time wasn't only for the technology required to get it started, mostly it
was for all the quirks, hacks and badly applied "XML" in the protocol which
complicated the matter.

=head1 RELEASE NOTES

Here are some notes to the releases (release of this version is at top):

=head2 Version

=over 4

=item * 0.01

This release has beta status. The code is already used daily in my client
and I keep looking out for bugs. If you find undocumented, missing or faulty
code/methods please drop me a mail! See also L</BUGS> below.

Potential edges when using this module: sparely documented methods, missing
functionality and generally bugs bugs and bugs. Even thought this module is in
daily usage there are still lots of cases I might have missed.

For the next release I'm planning to provide more examples in the documentation
and/or samples/ directory, along with bugfixes and enhancements along with some
todo items killed from the TODO file.

=back

=head2 TODO

There are still lots of items on the TODO list (see also the TODO file
in the distribution of Net::XMPP2).

=head1 Why (yet) another XMPP module?

The main outstanding feature of this module in comparsion to the other XMPP
(aka Jabber) modules out there is the support for L<AnyEvent>. L<AnyEvent>
permits you to use this module together with other I/O event based programs and
libraries (ie. L<Gtk2> or L<Event>).

The other modules could often only be integrated in those applications or librarys
by using threads. I decided to write this module because I think CPAN lacks
an event based XMPP module. Threads are unfortunately not an alternative in Perl
at the moment due the limited threading functionality they provide and the global
speed hit. I also think that a simple event based I/O framework might be a bit easier
to handle than threads.

Another thing was that I didn't like the APIs of the other modules. In L<Net::XMPP2>
I try to provide low level modules for speaking XMPP as defined in RFC 3920 and RFC 3921
(see also L<Net::XMPP2::Connection> and L<Net::XMPP2::IM::Connection>). But I also
try to provide a high level API for easier usage for instant messaging tasks
and clients (eg. L<Net::XMPP2::Client>).

=head1 A note about TLS

This module also supports TLS, as the specification of XMPP requires an
implementation to support TLS.

There are maybe still some bugs in the handling of TLS in L<Net::XMPP2::Connection>.
So keep an eye on TLS with this module. If you encounter any problems it would be
very helpful if you could debug them or at least send me a detailed report on how
to reproduce the problem.

(As I use this module myself I don't expect TLS to be completly broken, but it
might break under different circumstances than I have here.  Those
circumstances might be a different load of data pumped through the TLS
connection.)

I mainly expect problems where aviable data isn't properly read from the socket
or written to it. You might want to take a look at the C<debug_send> and C<debug_recv>
events in L<Net::XMPP2::Connection>.

=head1 Supportet extensions

See L<Net::XMPP2::Ext> for a list.

=head1 EXAMPLES

See C<samples/test_client> for a first pointer. More examples will be included
in later releases, please feel free to ask the L</AUTHOR> if you have any questions
about the API. There is also an IRC channel, see L</SUPPORT>.

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 BUGS

Please note that I'm currently (July 2007) the only developer on this project
and I'm very busy with my studies in Computer Science in Summer 2007. If you
want to ease my workload or want timely releases please send me patches instead
only bug reports or feature requests. I won't forget the reports or requests if
you can't or didn't send patches but it can take a long time until I get enough
time to fix/implement them.

Also try to be as precise as possible with bugreports and best, if you can't
send a patch, would be if you find out which code doesn't work and tell me why.

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

=item * IRC: Net::XMPP2 IRC Channel

  IRC Network: http://freenode.net/
  Server     : chat.freenode.net
  Channel    : #net_xmpp2

  Feel free to join and ask questions!

=item * Net::XMPP2 Project Site

L<http://www.ta-sa.org/>

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

Thanks to the XSF for the development of an open instant messaging protocol (even thought it uses "XML").

And thanks to all people who had to listen to my desperate curses about the
brokeness/braindeadness of XMPP, without you I would've never brought this
module to a usable state.

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
