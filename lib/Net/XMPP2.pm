package Net::XMPP2;
use warnings;
use strict;

=head1 NAME

Net::XMPP2 - An implementation of the XMPP Protocol

=head1 VERSION

Version 0.13

=cut

our $VERSION = '0.13';

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
for clients, which handles TCP connect up to the resource binding. And provides
low level access to the XML nodes on the XML stream along with some high
level methods to send the predefined XML stanzas.

L<Net::XMPP2::IM::Connection> is a more high level module, which is derived
from L<Net::XMPP2::Connection>. It handles all the instant messaging client
functionality described in RFC 3921.

L<Net::XMPP2::Client> is a multi account client class. It manages connections
to multiple XMPP accounts and tries to offer a nice high level interface
to XMPP communication.

For a list of L</Supported extensions> see below.

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

=item L<Object::Event>

The former L<Net::XMPP2::Event> module has been outsourced to the L<Object::Event>
module to provide a more generic way for more other modules to register and call
event callbacks.

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

=item L<Digest::SHA1>

For component authentication and old-style authentication.

=back

And yes, all these are essential for XMPP communication. Even though 'instant
messaging' and 'presence' is a quite simple problem XMPP somehow was successful
at making the task complicated enough to keep me busy for a long time.  But all
of that time wasn't only for the technology required to get it started, mostly
it was for all the quirks, hacks and badly applied "XML" in the protocol which
complicated the matter.

=head1 RELEASE NOTES

Here are some notes to the last releases (release of this version is at top):

=head2 Version

=over 4

=item * 0.12

B<API CHANGE:> The connects are now non-blocking, you should revisit the
places you use the C<connect> method of Net::XMPP2::Connection/::IM::Connection
directly!

Implemented XEP-0054 and XEP-0153 (see L<Net::XMPP2::Ext::VCard>),
on top of that a serious bug in C<split_jid> in L<Net::XMPP2::Util> was fixed
and a C<connect_timeout> argument can be set now for L<Net::XMPP2::Connection>.

Aside from that a few changes here and there, but nothing serious,
see the C<Changes> file.

=item * 0.11

Mainly a maintenance release. The C<init> method for the connection classes
have been made implicit on connect. So you should not call it yourself anymore.

Aside from that there were some documentation fixes in L<Net::XMPP2::Client>.

Other additions were the xmpp_datetime_as_timestamp in L<Net::XMPP2::Util> and
the nick collision callback in L<Net::XMPP2::Ext::MUC>, to change the nick when the
nick has already been taken when joining a room.

The tests have been tweaked a bit and a L<Pod::Coverage> test has been added.

=item * 0.10

Fixed some bugs and implemented an old/ancient authentication method
used by some very old (jabberd 1.4.2) servers. Also implemented a chat session
tracking mechanism to help the users of L<Net::XMPP2::Client> to get their
message to the right resource. (See also the method C<send_tracked_message>
of L<Net::XMPP2::IM::Account>).

=item * 0.09

Just a bugfix release. Last change before the last release introduced a bug
with namespace handling in resource binding.

=item * 0.08

Lots of bugfixes and minor changes you might want to read about in the C<Changes>
file. Added some examples which might be useful.

Introduced a character filter on the low XML writer level which will filter out
not allowed XML characters to prevent unexpected disconnects. Arguably this is the
programmers fault but I hope noone is confuses if this module tries everything to
be as reliable as possible.

=item * 0.07

Many small changes in L<Net::XMPP2::Event>. Implemented XEP-0199 (XMPP Ping)
and also whitespace pings in L<Net::XMPP2::Connection>.

Also fixed some bugs.

For further details look in the C<Changes> file.

=item * 0.06

The event API has been changed a bit, it's possible to intercept events
now, see L<Net::XMPP2::Event>.

Implemented the old legacy XEP-0078 (IQ authentication), see also
L<Net::XMPP2::Ext> for some notes about it.

Some bugs with JID preps have been fixed and some functions for JID handling
have been added to L<Net::XMPP2::Util>.

Reworked the subscription system a bit, you now have to reply with 'subscribed'
yourself, etc. (See also L<Net::XMPP2::IM::Connection> about subscriptions).

Implemented following new XEPs:

   - XEP-0082 - XMPP Date and Time Profiles
   - XEP-0091 - Delayed Delivery (legacy)
   - XEP-0092 - Software Version
   - XEP-0203 - Delayed Delivery (new)

For further information about them see L<Net::XMPP2::Ext>.

I also started an implementation of XEP-0045 (Multi User Chats), please consult
the test t/z_05_muc.t and the API at L<Net::XMPP2::Ext::MUC> for the already
working features.  (Very basic MUCing should work, but there are lots of edges
still with error reporting and all the other nice features).

Also enhanced the message API a bit see L<Net::XMPP2::IM::Message> and the methods
of other classes that generate messages (eg. like C<make_message>).

There has been a considerable efford in test writing.  Added instructions about
the test suite below in section L<TEST SUITE>.

And another API change: C<reply_iq_result> and C<reply_iq_error> now attach a
from attribute themselves (see L<Net::XMPP2::Connection>).

=item * 0.05

I added some unit tests and fixed a lot of bugs. The unit tests
are mostly for me (the L<AUTHOR>) to not accidentally release a buggy
version with too ugly show stopper bugs.

The tests require network access to a jabber server and won't run unless you
set the right environment variable.  If you want to run these tests yourself
you might want to take a look at L<Net::XMPP2::TestClient>.

=item * 0.04

After realizing that in band registration in L<Net::XMPP2::Ext> was already
in in version 0.03 I finally had to implement it.

While implementing in band registration I implemented XEP-0066: Out of Band Data.
You can now receive and send URLs from and to others. See also L<Net::XMPP2::Ext::OOB>.

I also fixed some bugs in L<Net::XMPP2::Ext::Disco>.

=item * older

For older release notes please have a look at the Changes file or CPAN.

=back

=head2 TODO

There are still lots of items on the TODO list (see also the TODO file
in the distribution of Net::XMPP2).

=head1 TEST SUITE

If you are a developer and want to test either a server or maybe just whether
this module passes some basic tests you might want to run the developer test
suite.

This test suite is not enabled by default because it requires some human
interaction to set it up, please see L<Net::XMPP2::TestClient> for hints about
the setup procedure for the test suite.

I wrote the test suite mostly because I wanted to make sure I didn't break
something essential before a release. The tests don't cover everything and I
don't plan to write a test for every single function in the API, that would
slow down development considerably for me. But I hope that some grave show
stopper bugs in releases are prevented with this test suite.

The tests are also useful if you want to test a server implementation. But
there are maybe of course conformance issues with L<Net::XMPP2> itself, so if
you find something where L<Net::XMPP2> doesn't conform to the XMPP RFCs or XEPs
consult the L<BUGS> section below.

If you find a server that doesn't handle something correctly but you need to
interact with it you are free to implement workarounds and send me a patch, or
even ask me whether I might want to look into the issue (I can't gurantee
anything here, but I want this module to be as interoperable as possible. But
if the implementation of a workaround for some non-conformant software will
complicate the code too much I'm probably not going to implement it.).

Of course, if you find a bug in some server implementation don't forget to file
a bugreport to them, one hack less in L<Net::XMPP2> means more time for bug
fixing and improvements and new features.

=head1 Why (yet) another XMPP module?

The main outstanding feature of this module in comparison to the other XMPP
(aka Jabber) modules out there is the support for L<AnyEvent>. L<AnyEvent>
permits you to use this module together with other I/O event based programs and
libraries (ie. L<Gtk2> or L<Event>).

The other modules could often only be integrated in those applications or
libraries by using threads. I decided to write this module because I think CPAN
lacks an event based XMPP module. Threads are unfortunately not an alternative
in Perl at the moment due the limited threading functionality they provide and
the global speed hit. I also think that a simple event based I/O framework
might be a bit easier to handle than threads.

Another thing was that I didn't like the APIs of the other modules. In
L<Net::XMPP2> I try to provide low level modules for speaking XMPP as defined
in RFC 3920 and RFC 3921 (see also L<Net::XMPP2::Connection> and
L<Net::XMPP2::IM::Connection>). But I also try to provide a high level API for
easier usage for instant messaging tasks and clients (eg. L<Net::XMPP2::Client>).

=head1 A note about TLS

This module also supports TLS, as the specification of XMPP requires an
implementation to support TLS.

Maybe there are still some bugs in the handling of TLS in L<Net::XMPP2::Connection>.
So keep an eye on TLS with this module. If you encounter any problems it would be
very helpful if you could debug them or at least send me a detailed report on how
to reproduce the problem.

(As I use this module myself I don't expect TLS to be completly broken, but it
might break under different circumstances than I have here.  Those
circumstances might be a different load of data pumped through the TLS
connection.)

I mainly expect problems where available data isn't properly read from the socket
or written to it. You might want to take a look at the C<debug_send> and C<debug_recv>
events in L<Net::XMPP2::Connection>.

=head1 Supported extensions

See L<Net::XMPP2::Ext> for a list.

=head1 EXAMPLES

Following examples are included in this distribution:

=over 4

=item B<samples/simple_example_1>

This example script just connects to a server and sends a message and
also displays incoming messages on stdout.

=item B<samples/devcl/devcl>

This is a more advanced 'example'. It requires you to have L<Gtk2>
installed. It's mostly used by the author to implement proof-of-concepts.
Currently you start the client like this:

   ../Net-XMPP2/samples/devcl/# perl ./devcl <jid> <password>

The client's main window displays a protocol dump and there is currently
a service discovery browser implemented.

This might be a valuable source if you look for more real-world
applications of L<Net::XMPP2>.

=item B<samples/conference_lister>

See below.

=item B<samples/room_lister>

See below.

=item B<samples/room_lister_stat>

These three scripts implements a global room scan.  C<conference_lister> takes
a list of servers (the file is called C<servers.xml> which has the same format as
the xml file at L<http://www.jabber.org/servers.xml>). It then scans all
servers for chat room services and lists them into a file C<conferences.stor>,
which is a L<Storable> dump.

C<room_lister> then reads that file and queries all services for rooms, and then
all rooms for their occupants. The output file is C<room_data.stor>, also a L<Storable>
dump, which in turn can be read with C<room_lister_stat>, which transform
the data structures into something human readable.

These scripts are a bit hacky and quite complicated, but maybe it's of any
value for someone. You might note L<samples/EVQ.pm> which is a module that
handles request-throttling (You don't want to flood the server and risk
getting the admins attention :).

=item B<samples/simple_component>

This is a (basic) skeleton for a jabber component.

=item B<samples/simple_oob_retriever>

This is a simple out of band file transfer receiver bot.  It uses C<curl> to
fetch the files and also has the sample functionality of sending a file url for
someone who sends the bot a 'send <filename>' message.

=item B<samples/simple_register_example>

This is a example script which allows you to register, unregister and change
your password for accounts. Execute it without arguments for more details.

=item B<samples/disco_info>

This is a small example tool that allows you to fetch the software version,
disco info and disco items information about a JID.

=item B<samples/talkbot>

This is a simple bot that will read lines from a file and recite them
when you send it a message. It will also automatically allow you to subscribe
to it. Start it without commandline arguments to be informed about the usage.

=item B<samples/retrieve_roster>

This is a simple example script that will retrieve the roster
for an account and print it to stdout. You start it like this:

   samples/# ./retrieve_roster <jid> <password>

=item B<samples/display_avatar>

This is just a small example which should display the avatar
of the account you connect to. It can be used like this:

   samples/# ./display_avatar <jid> <password>

=back

For others, which the author might forgot or didn't want to
list here see the C<samples/> directory.

More examples will be included in later releases, please feel free to ask the
L</AUTHOR> if you have any questions about the API. There is also an IRC
channel, see L</SUPPORT>.

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 BUGS

Please note that I'm currently (July 2007) the only developer on this project
and I'm very busy with my studies in Computer Science in Summer 2007. If you
want to ease my workload or want timely releases, please send me patches instead
of bug reports or feature requests. I won't forget the reports or requests if
you can't or didn't send patches, but I can't gurantee immediate response.
But I will of course try to fix/implement them as soon as possible!

Also try to be as precise as possible with bug reports, if you can't send a
patch, it would be best if you find out which code doesn't work and tell me
why.

Please report any bugs or feature requests to
C<bug-net-xmpp2 at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Net-XMPP2>.
I will be notified and then you'll automatically be notified of progress on
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

L<http://www.ta-sa.org/net_xmpp2>

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

Thanks to the XSF for the development of an open instant messaging protocol (even though it uses "XML").

And thanks to all people who had to listen to my desperate curses about the
brokenness/braindeadness of XMPP. Without you I would've never brought this
module to a usable state.

Thanks to:

=over 4

=item * J. Cameijo Cerdeira

For pointing out a serious bug in C<split_jid> in L<Net::XMPP2::Util>
and suggesting to add a timeout argument to the C<connect> method of
L<Net::XMPP2::SimpleConnection>.

=item * Carlo von Loesch (aka lynX) L<http://www.psyced.org/>

For pointing out some typos.

=back

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
