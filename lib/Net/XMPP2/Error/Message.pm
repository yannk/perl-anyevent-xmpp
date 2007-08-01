package Net::XMPP2::Error::Message;
use strict;
no warnings;
use Net::XMPP2::Error::Stanza;
our @ISA = qw/Net::XMPP2::Error::Stanza/;

=head1 NAME

Net::XMPP2::Error::Message - Message errors

Subclass of L<Net::XMPP2::Error::Stanza>

=cut

sub string {
   my ($self) = @_;

   sprintf "message error: %s/%s (type %s): %s",
      $self->code || '',
      $self->condition || '',
      $self->type,
      $self->text
}


=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
