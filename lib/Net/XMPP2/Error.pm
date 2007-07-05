package Net::XMPP2::Error;
use strict;
use Net::XMPP2::Util qw/stringprep_jid prep_bare_jid/;
use Net::XMPP2::Error;
use Net::XMPP2::Error::SASL;
use Net::XMPP2::Error::IQ;
use Net::XMPP2::Error::Register;
use Net::XMPP2::Error::Stanza;
use Net::XMPP2::Error::Presence;
use Net::XMPP2::Error::Message;

=head1 NAME

Net::XMPP2::Error - An error class hierarchy for error reporting

=head1 SYNOPSIS

   die $error->string;

=head1 DESCRIPTION

This module is a helper class for abstracting any kind
of error that occurs in Net::XMPP2.

You receive instances of these objects by various events.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init { }

=head1 SUPER CLASS

Net::XMPP2::Error - The super class of all errors

=head2 METHODS

These methods are implemented by all subclasses.

=over 4

=item B<string ()>

Returns a humand readable string for this error.

=cut

sub string {
   my ($self) = @_;
   $self->{text}
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
