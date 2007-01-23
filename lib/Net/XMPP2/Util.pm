package Net::XMPP2::Util;
use warnings;
use strict;
use Encode;
use Net::LibIDN qw/idn_prep_name idn_prep_resource idn_prep_node/;

=head1 NAME

Net::XMPP2::Util - Utility functions for Net::XMPP2

=head1 SYNOPSIS

   use Net::XMPP2::Util;
   ...

=head1 FUNCTIONS

=head2 resourceprep ($string)

This function applies the stringprep profile for resources to C<$string>
and returns the result.

=cut

sub resourceprep {
   my ($str) = @_;
   decode_utf8 (idn_prep_resource (encode_utf8 ($str), 'UTF-8'))
}

=head2 nodeprep ($string)

This function applies the stringprep profile for nodes to C<$string>
and returns the result.

=cut

sub nodeprep {
   my ($str) = @_;
   decode_utf8 (idn_prep_node (encode_utf8 ($str), 'UTF-8'))
}

=head2 join_jid ($node, $domain, $resource)

This function joins the parts C<$node>, C<$domain> and C<$resource>
to a full jid and applies stringprep profiles. If the profiles couldn't
be applied undef will be returned.

=cut

sub join_jid {
   my ($node, $domain, $resource) = @_;
   my $jid = "";

   if (defined $node) {
      $node = nodeprep ($node);
      return undef unless defined $node;
      $jid .= "$node\@";
   }

   $domain = $domain; # TODO: apply IDNA!
   $jid .= $domain;

   if (defined $resource) {
      $resource = resourceprep ($resource);
      return undef unless defined $resource;
      $jid .= "/$resource";
   }

   $jid
}

=head2 stringprep_jid ($jid)

This applies stringprep to all parts of the jid according to the RFC 3920.
Use this if you want to compare two jids like this:

   stringprep_jid ($jid_a) eq stringprep_jid ($jid_b)

This function returns undef if the C<$jid> couldn't successfully be parsed
and the preparations done.

=cut

sub stringprep_jid {
   my ($jid) = @_;
   if ($jid =~ /^([^@]*)@?([^\/]+)\/(.*)$/) {
      return join_jid ($1, $2, $3);
   } else {
      return undef;
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
