package Net::XMPP2::Util;
use strict;
use Encode;
use Net::LibIDN qw/idn_prep_name idn_prep_resource idn_prep_node/;
use Net::XMPP2::Namespaces qw/xmpp_ns_maybe/;
require Exporter;
our @EXPORT_OK = qw/resourceprep nodeprep prep_join_jid join_jid
                    split_jid stringprep_jid prep_bare_jid bare_jid
                    is_bare_jid simxml dump_twig_xml/;
our @ISA = qw/Exporter/;

=head1 NAME

Net::XMPP2::Util - Utility functions for Net::XMPP2

=head1 SYNOPSIS

   use Net::XMPP2::Util qw/split_jid/;
   ...

=head1 FUNCTIONS

These functions can be exported if you want:

=over 4

=item B<resourceprep ($string)>

This function applies the stringprep profile for resources to C<$string>
and returns the result.

=cut

sub resourceprep {
   my ($str) = @_;
   decode_utf8 (idn_prep_resource (encode_utf8 ($str), 'UTF-8'))
}

=item B<nodeprep ($string)>

This function applies the stringprep profile for nodes to C<$string>
and returns the result.

=cut

sub nodeprep {
   my ($str) = @_;
   decode_utf8 (idn_prep_node (encode_utf8 ($str), 'UTF-8'))
}

=item B<prep_join_jid ($node, $domain, $resource)>

This function joins the parts C<$node>, C<$domain> and C<$resource>
to a full jid and applies stringprep profiles. If the profiles couldn't
be applied undef will be returned.

=cut

sub prep_join_jid {
   my ($node, $domain, $resource) = @_;
   my $jid = "";

   if ($node ne '') {
      $node = nodeprep ($node);
      return undef unless defined $node;
      $jid .= "$node\@";
   }

   $domain = $domain; # TODO: apply IDNA!
   $jid .= $domain;

   if ($resource ne '') {
      $resource = resourceprep ($resource);
      return undef unless defined $resource;
      $jid .= "/$resource";
   }

   $jid
}

=item B<join_jid ($user, $domain, $resource)>

This is a plain concatenation of C<$user>, C<$domain> and C<$resource>
without stringprep.

See also L<prep_join_jid>

=cut

sub join_jid {
   my ($node, $domain, $resource) = @_;
   my $jid = "";
   $jid .= "$node\@" if $node ne '';
   $jid .= $domain;
   $jid .= "/$resource" if $resource ne '';
   $jid
}

=item B<split_jid ($jid)>

This function splits up the C<$jid> into user/node, domain and resource
part and will return them as list.

   my ($user, $host, $res) = split_jid ($jid);

=cut

sub split_jid {
   my ($jid) = @_;
   if ($jid =~ /^([^@]*)@?([^\/]+)\/?(.*)$/) {
      return ($1, $2, $3);
   } else {
      return (undef, undef, undef);
   }
}

=item B<stringprep_jid ($jid)>

This applies stringprep to all parts of the jid according to the RFC 3920.
Use this if you want to compare two jids like this:

   stringprep_jid ($jid_a) eq stringprep_jid ($jid_b)

This function returns undef if the C<$jid> couldn't successfully be parsed
and the preparations done.

=cut

sub stringprep_jid {
   my ($jid) = @_;
   my ($user, $host, $res) = split_jid ($jid);
   return undef unless defined ($user) || defined ($host) || defined ($res);
   return prep_join_jid ($user, $host, $res);
}

=item B<prep_bare_jid ($jid)>

This function makes the jid C<$jid> a bare jid, meaning:
it will strip off the resource part. With stringprep.

=cut

sub prep_bare_jid {
   my ($jid) = @_;
   my ($user, $host, $res) = split_jid ($jid);
   prep_join_jid ($user, $host)
}

=item B<bare_jid ($jid)>

This function makes the jid C<$jid> a bare jid, meaning:
it will strip off the resource part. But without stringprep.

=cut

sub bare_jid {
   my ($jid) = @_;
   my ($user, $host, $res) = split_jid ($jid);
   join_jid ($user, $host)
}

=item B<is_bare_jid ($jid)>

This method returns a boolean which indicates whether C<$jid> is a 
bare JID.

=cut

sub is_bare_jid {
   my ($jid) = @_;
   my ($user, $host, $res) = split_jid ($jid);
   defined $res
}

=item B<simxml ($w, %xmlstruct)>

This method takes a L<XML::Writer> as first argument (C<$w>) and the
rest key value pairs:

   simxml ($w,
      defns => '<xmlnamespace>',
      node => <node>,
      prefixes => { prefix => namespace, ... },
      fb_ns => '<fallbackxmlnamespace for all elementes without ns or dns field>',
   );

Where node is:

   <node> := {
                ns => '<xmlnamespace>',
                name => 'tagname',
                attrs => [ ['name', 'value'], ... ],
                childs => [ <node>, ... ]
             }
           | {
                dns => '<xmlnamespace>',  # dns will set that namespace to the default namespace before using it.
                name => 'tagname',
                attrs => [ ['name', 'value'], ... ],
                childs => [ <node>, ... ]
             }
           | "textnode"

Please note: C<childs> stands for C<child sequence> :-)

=back

=cut

sub simxml {
   my ($w, %desc) = @_;

   if (my $n = $desc{defns}) {
      $w->addPrefix (xmpp_ns_maybe ($n), '');
   }

   if (my $p = $desc{prefixes}) {
      for (keys %{$p || {}}) {
         $w->addPrefix (xmpp_ns_maybe ($_), $p->{$_});
      }
   }

   my $node = $desc{node};

   if (not defined $node) {
      return;

   } elsif (ref ($node)) {
      my $ns = $node->{dns} ? $node->{dns} : $node->{ns};
      $ns = $ns ? $ns : $desc{fb_ns};
      $ns = xmpp_ns_maybe ($ns);
      my $tag = $ns ? [$ns, $node->{name}] : $node->{name};

      if (@{$node->{childs} || []}) {

         $w->startTag ($tag, @{$node->{attrs} || []});

            my (@args);
            if ($node->{defns}) { @args = (defns => $node->{defns}) }

            for (@{$node->{childs}}) {
               if (ref ($_) && $_->{dns}) { push @args, (defns => $_->{dns}) }
               if (ref ($_) && $_->{ns})  {
                  push @args, (fb_ns => $_->{ns})
               } else {
                  push @args, (fb_ns => $desc{fb_ns})
               }
               simxml ($w, node => $_, @args)
            }

         $w->endTag;

      } else {
         $w->emptyTag ($tag, @{$node->{attrs} || []});
      }
   } else {
      $w->characters ($node);
   }
}


sub dump_twig_xml {
   my $data = shift;
   require XML::Twig;
   my $t = XML::Twig->new;
   if ($t->safe_parse ("<deb>$data</deb>")) {
      $t->set_pretty_print ('indented');
      return ($t->sprint . "\n");
   } else {
      return "$data\n";
   }
}

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
