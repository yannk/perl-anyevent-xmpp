package AnyEvent::XMPP::Ext::Skel;
use AnyEvent::XMPP::Ext;
use strict;

our @ISA = qw/AnyEvent::XMPP::Ext/;

=head1 NAME

AnyEvent::XMPP::Ext::Skel - Extension skeleton

=head1 SYNOPSIS

   use AnyEvent::XMPP::Ext::Skel;

=head1 DESCRIPTION

This is just a skeleton extension.

=head1 METHODS

=over 4

=item B<new (%args)>

Creates a new extension handle.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;

   $self->{cb_id} = $self->reg_cb (
   );
}

sub DESTROY {
   my ($self) = @_;
   $self->unreg_cb ($self->{cb_id})
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
