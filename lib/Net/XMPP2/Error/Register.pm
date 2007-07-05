package Net::XMPP2::Error::Register;
use Net::XMPP2::Error;
our @ISA = qw/Net::XMPP2::Error::IQ/;

=head1 NAME

Net::XMPP2::Error::Register - In band registration error

Subclass of L<Net::XMPP2::Error>

=cut

=head2 METHODS

=over 4

=item B<register_state ()>

Returns the state of registration, one of:

   form-request
   form-submitted

=cut

sub register_state {
   my ($self) = @_;
   $self->{register_state}
}

sub string {
   my ($self) = @_;

   sprintf "ibb registration error (in %s): %s",
      $self->register_state,
      $self->SUPER::string
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
