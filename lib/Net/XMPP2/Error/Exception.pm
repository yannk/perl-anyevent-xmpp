package Net::XMPP2::Error::Exception;
use Net::XMPP2::Error;
use strict;
our @ISA = qw/Net::XMPP2::Error/;

=head1 NAME

Net::XMPP2::Error::Exception - Some exception was thrown somewhere

Subclass of L<Net::XMPP2::Error>

=head2 METHODS

=over 4

=item B<exception>

This returns the exception object that was thrown in C<$@>.

=cut

sub exception { $_[0]->{exception} }

=item B<context>

This returns a string which describes the context in which this exception
was thrown

=cut

sub context   { $_[0]->{context} }

sub string {
   my ($self) = @_;

   sprintf "exception in context '%s': %s",
      $self->context, $self->exception
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
