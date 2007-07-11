package Net::XMPP2::Ext;
use warnings;
use strict;
use Net::XMPP2::Event;

our @ISA = qw/Net::XMPP2::Event/;

=head1 NAME

Net::XMPP2::Ext - Extension baseclass and documentation

=head1 DESCRIPTION

This module has documentation about the supported extensions
and also is a base class for all extensions that can be added
via the C<add_extension> method of the classes that derive from
L<Net::XMPP2::Extendable>. (That are: L<Net::XMPP2::Client>,
L<Net::XMPP2::Connection> and L<Net::XMPP2::IM::Connection>)

Basically C<add_extension> makes the extension an event receiver
for all events that the extended object receives.

=head1 Supportet extensions

This is the list of supported XMPP extensions:

=over 4

=item XEP-0004 - Data Forms

This extension handles data forms as described in XEP-0004.
L<Net::XMPP2::Ext::DataForm> allows you to construct, receive and
answer data forms. This is neccessary for all sorts of things in XMPP.
For example XEP-0055 (Jabber Search) or also In-band registration.

=item XEP-0086 - Error Condition Mappings

   "A mapping to enable legacy entities to correctly handle errors from XMPP-aware entities."

This extension will enable sending of the old error codes when generating a stanza
error with for example the C<write_error_tag> method of L<Net::XMPP2::Writer>.

=item XEP-0030 - Service Discovery

This extension allows you to send service discovery requests and
define a set of discoverable information. See also L<Net::XMPP2::Ext::Disco>.

=item XEP-0077 - In-Band Registration

This extension lets you register new accounts "in-band".
To use this look at the description of the C<register> option to the C<new>
method of L<Net::XMPP2::Connection>.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
