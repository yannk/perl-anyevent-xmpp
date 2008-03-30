package Net::XMPP2::Ext::VCard;
use Net::XMPP2::Ext;
use strict;

our @ISA = qw/Net::XMPP2::Ext/;

=head1 NAME

Net::XMPP2::Ext::VCard - VCards (XEP-0054 & XEP-0084)

=head1 SYNOPSIS

   use Net::XMPP2::Ext::VCard;

=head1 DESCRIPTION

This extension handles setting and retrieval of the VCard and the
VCard based avatars.

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

   $self->{cb_id} =
      $self->reg_cb (
         ext_before_vcard_retrieved => sub {
            my ($self, $jid, $vcard) = @_;
            $self->{cache}->{prep_bare_jid ($jid)} = $vcard;
         }
      );
}

sub store {
   my ($self, $con, $vcard_cb, $cb) = @_;

   $con->send_iq (
      set => sub {
         my ($w) = @_;
         $w->addPrefix (xmpp_ns ('vcard'), '');
         $w->startTag ([xmpp_ns ('vcard'), 'vCard']);
         $vcard_cb->($w);
         $w->endTag;
      }, sub {
         my ($xmlnode, $error) = @_;

         if ($error) {
            $cb->($error);
         } else {
            $cb->();
         }
      }
   );
}

sub retrieve {
   my ($self, $con, $dest, $cb) = @_;

   $con->send_iq (
      get => { defns => 'vcard', node => { ns => 'vcard', name => 'vCard' } },
      sub {
         my ($xmlnode, $error) = @_;

         if ($error) {
            $cb->(undef, $error);

         } else {
            my ($vcard) = $xmlnode->find_all ([qw/vcard vCard/]);
            $cb->($vcard, $error);
            $self->event (vcard => $dest, $vcard);
         }
      },
      (defined $dest ? (to => $dest) : ())
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
