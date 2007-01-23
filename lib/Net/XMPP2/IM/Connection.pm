package Net::XMPP2::IM::Connection;
use warnings;
use strict;
use Net::XMPP2::Connection;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
our @ISA = qw/Net::XMPP2::Connection/;

=head1 NAME

Net::XMPP2::Connection - A XML stream that implements the XMPP RFC 3920.

=head1 SYNOPSIS

   use Net::XMPP2::Connection;

   my $con = Net::XMPP2::Connection->new;

=head1 DESCRIPTION

This module represents a XMPP instant messaging connection and implements
RFC 3921.

This module is a subclass of C<Net::XMPP2::Connection> and inherits all methods.
For example C<reg_cb> and the stanza sending routines.

For additional events that can be registered to look below in the EVENTS section.

=head1 METHODS

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = $class->SUPER::new (@_);
   $self->reg_cb (stream_ready => sub {
      my ($jid) = @_;
      $self->send_iq (set => sub {
         my ($w) = @_;
         $w->addPrefix (xmpp_ns ('session'), '');
         $w->emptyTag ([xmpp_ns ('session'), 'session']);
      }, sub {
         $self->event ('session_ready');
      });
   });
   $self
}

=head1 EVENTS

These additional events can be registered on with C<reg_cb>:

=over 4

=item session_ready

This event is sent if the session has been completly established and you can
send messages and such over the stream.

=back

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
