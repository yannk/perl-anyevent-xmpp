package Net::XMPP2::Error::MUC;
use Net::XMPP2::Error;
our @ISA = qw/Net::XMPP2::Error/;

=head1 NAME

Net::XMPP2::Error::MUC - MUC error

Subclass of L<Net::XMPP2::Error>

=head2 METHODS

=over 4

=item B<type>

This method returns either:

C<join_timeout>

C<presence_error>

=cut

sub type { $_[0]->{type} }

sub text { $_[0]->{text} }

sub presence_error { $_[0]->{presence_error} }

sub string {
   my ($self) = @_;

   sprintf "muc error: '%s' %s",
      $self->type,
      (
         $self->type eq 'presence_error'
            ? $self->presence_error ()->string
            : $self->text
      )
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
