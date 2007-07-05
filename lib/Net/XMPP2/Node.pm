package Net::XMPP2::Node;
use warnings;
use strict;
use Net::XMPP2::Namespaces qw/xmpp_ns/;

use constant {
   NS     => 0,
   NAME   => 1,
   ATTRS  => 2,
   TEXT   => 3,
   NODES  => 4,
   PARSER => 5,
};

=head1 NAME

Net::XMPP2::Node - XML node tree helper for the parser.

=head1 SYNOPSIS

   use Net::XMPP2::Node;
   ...

=head1 DESCRIPTION

This class represens a XML node. L<Net::XMPP2> should usually not
require messing with the parse tree, but sometimes it is neccessary.

If you experience any need for messing with these and feel L<Net::XMPP2> should
rather take care of it drop me a mail, feature request or most preferably a patch!

Every L<Net::XMPP2::Node> has a namespace, attributes, text and child nodes.

You can access these with the following methods:

=head1 METHODS

=over 4

=item B<new ($ns, $el, $attrs, $parser)>

Creates a new Net::XMPP2::Node object with the node tag name C<$el> in the
namespace URI C<$ns> and the attributes C<$attrs>. The C<$parser> must be
the instance of C<Net::XMPP2::Parser> which generated this node.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = [];
   $self->[0] = $_[0];
   $self->[1] = $_[1];
   $self->[2] = $_[2];
   $self->[5] = $_[3];
   bless $self, $class;
   return $self
}

=item B<name>

The tag name of this node.

=cut

sub name {
   $_[0]->[NAME]
}

=item B<namespace>

Returns the namespace URI of this node.

=cut

sub namespace {
   $_[0]->[NS]
}

=item B<eq ($namespace_or_alias, $name) or eq ($node)>

Returns true whether the current element matches the tag name C<$name>
in the namespaces pointed at by C<$namespace_or_alias>.

You can either pass an alias that was defined in L<Net::XMPP2::Namespaces>
or pass an namespace URI in C<$namespace_or_alias>. If no alias with the name
C<$namespace_or_alias> was found in L<Net::XMPP2::Namespaces> it will be
interpreted as namespace URI.

The first argument to eq can also be another L<Net::XMPP2::Node> instance.

=cut

sub eq {
   my ($self, $n, $name) = @_;
   if (ref $n) {
      return $self->[PARSER]->nseq ($n->namespace, $n->name, $self->name);
   } else {
      my $ns = xmpp_ns ($n);
      return $self->[PARSER]->nseq (($ns ? $ns : $n), $name, $self->name);
   }
}

=item B<eq_ns ($namespace_or_alias) or eq_ns ($node)>

This method return true if the namespace of this instance of L<Net::XMPP2::Node>
matches the namespace described by C<$namespace_or_alias> or the
namespace of the C<$node> which has to be another L<Net::XMPP2::Node> instance.

See C<eq> for the meaning of C<$namespace_or_alias>.

=cut

sub eq_ns {
   my ($self, $n) = @_;
   if (ref $n) {
      return ($n->namespace eq $self->namespace);
   } else {
      my $ns = xmpp_ns ($n);
      $ns ||= $n;
      return ($ns eq $self->namespace);
   }
}

=item B<attr ($name)>

Returns the contents of the C<$name> attribute.

=cut

sub attr {
   $_[0]->[ATTRS]->{$_[1]};
}

=item B<add_node ($node)>

Adds a sub-node to the current node.

=cut

sub add_node {
   my ($self, $node) = @_;
   push @{$self->[NODES]}, $node;
}

=item B<nodes>

Returns a list of sub nodes.

=cut

sub nodes {
   @{$_[0]->[NODES] || []};
}

=item B<add_text ($string)>

Adds character data to the current node.

=cut

sub add_text {
   my ($self, $text) = @_;
   $self->[TEXT] .= $text;
}

=item B<text>

Returns the text for this node.

=cut

sub text {
   $_[0]->[TEXT];
}

=item B<find_all (@path)>

This method does a recursive descent through the sub-nodes and
fetches all nodes that match the last element of C<@path>.

The elements of C<@path> consist of a array reference to an array with
two elements: the namespace key known by the C<$parser> and the tagname
we search for.

=cut

sub find_all {
   my ($self, @path) = @_;
   my $cur = shift @path;
   my @ret;
   for my $n ($self->nodes) {
      if ($n->eq (@$cur)) {
         if (@path) {
            push @ret, $n->find_all (@path);
         } else {
            push @ret, $n;
         }
      }
   }
   @ret
}

=item B<write_on ($writer)>

This writes the current node out to the L<Net::XMPP2::Writer> object in C<$writer>.

=cut

sub write_on {
   my ($self, $w) = @_;

   my ($ns, $tag) = ($self->namespace, $self->name);
   $w->addPrefix ($ns => ''); # omg, xmpp is soo broken...
   if ($self->nodes) {
      $w->startTag ([$ns, $tag], %{$self->[ATTRS]});
      $_->write_on ($w) for $self->nodes;
      $w->endTag;
   } else {
      $w->emptyTag ([$ns, $tag], %{$self->[ATTRS]});
   }
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
