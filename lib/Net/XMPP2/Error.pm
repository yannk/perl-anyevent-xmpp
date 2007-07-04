package Net::XMPP2::Error;
use strict;
use Net::XMPP2::Util qw/stringprep_jid prep_bare_jid/;
use Net::XMPP2::Error;

=head1 NAME

Net::XMPP2::Error - An error class hierarchy for error reporting

=head1 SYNOPSIS

   die $error->string;

=head1 DESCRIPTION

This module is a helper class for abstracting any kind
of error that occurs in Net::XMPP2.

You receive instances of these objects by various events.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init { }

=head1 SUPER CLASS

Net::XMPP2::Error - The super class of all errors

=head2 METHODS

These methods are implemented by all subclasses.

=over 4

=item B<string ()>

Returns a humand readable string for this error.

=cut

sub string {
   my ($self) = @_;
   $self->{text}
}

=back

=cut

package Net::XMPP2::Error::Stanza;
our @ISA = qw/Net::XMPP2::Error/;

=head1 SUBCLASS

Net::XMPP2::Error::Stanza - Stanza errors

=cut

sub init {
   my ($self) = @_;
   my $node = $self->xml_node;

   unless (defined $node) {
      $self->{error_cond} = 'client-timeout';
      $self->{error_type} = 'cancel';
      return;
   }

   my @error;
   my ($err) = $node->find_all ([qw/client error/]);

   unless ($err) {
      warn "No error element found in error stanza!";
      $self->{text} = "Unknown Stanza error";
      return
   }

   $self->{error_type} = $err->attr ('type');
   $self->{error_code} = $err->attr ('code');

   if (my ($txt) = $err->find_all ([qw/stanzas text/])) {
      $self->{error_text} = $txt->text;
   }

   for my $er (
     qw/bad-request conflict feature-not-implemented forbidden
        gone internal-server-error item-not-found jid-malformed
        not-acceptable not-allowed not-authorized payment-required
        recipient-unavailable redirect registration-required
        remote-server-not-found remote-server-timeout resource-constraint
        service-unavailable subscription-required undefined-condition
        unexpected-request/)
   {
      if (my ($el) = $err->find_all ([stanzas => $er])) {
         $self->{error_cond}      = $er;
         $self->{error_cond_node} = $el;
         last;
      }
   }
}

=head2 METHODS

=over 4

=item B<xml_node ()>

Returns the L<Net::XMPP2::Node> object for this Stanza error.
This method returns undef if the Stanza timeouted.

In the case of a timeout the C<condition> method returns C<client-timeout>,
C<type> returns 'cancel' and C<code> undef.

=cut

sub xml_node {
   $_[0]->{node}
}

=item B<type ()>

This method returns one of:

   'cancel', 'continue', 'modify', 'auth' and 'wait'

=cut

sub type { $_[0]->{error_type} }

=item B<code ()>

This method returns the error code if one was found.

=cut

sub code { $_[0]->{error_code} }

=item B<condition ()>

Returns the error condition string if one was found when receiving the Stanza error.
It can be undef or one of:

   bad-request
   conflict
   feature-not-implemented
   forbidden
   gone
   internal-server-error
   item-not-found
   jid-malformed
   not-acceptable
   not-allowed
   not-authorized
   payment-required
   recipient-unavailable
   redirect
   registration-required
   remote-server-not-found
   remote-server-timeout
   resource-constraint
   service-unavailable
   subscription-required
   undefined-condition
   unexpected-request


=cut

sub condition { $_[0]->{error_cond} }

=item B<condition_node ()>

Returns the error condition node if one was found when receiving the Stanza error.
This is mostly for debugging purposes.

=cut

sub condition_node { $_[0]->{error_cond_node} }

=item B<text ()>

The humand readable error portion. Might be undef if none was received.

=cut

sub text { $_[0]->{error_text} }

sub string {
   my ($self) = @_;

   sprintf "stanza error: %s/%s (type %s): %s",
      $self->code || '',
      $self->condition || '',
      $self->type,
      $self->text
}

=back

=cut

package Net::XMPP2::Error::Presence;
our @ISA = qw/Net::XMPP2::Error::Stanza/;

=head1 SUBCLASS

Net::XMPP2::Error::Presence - Message errors

(Subclass of L<Net::XMPP2::Error::Stanza>)

=cut

sub string {
   my ($self) = @_;

   sprintf "presence error: %s/%s (type %s): %s",
      $self->code || '',
      $self->condition || '',
      $self->type,
      $self->text
}

package Net::XMPP2::Error::Message;
our @ISA = qw/Net::XMPP2::Error::Stanza/;

=head1 SUBCLASS

Net::XMPP2::Error::Message - Message errors

(Subclass of L<Net::XMPP2::Error::Stanza>)

=cut

sub string {
   my ($self) = @_;

   sprintf "message error: %s/%s (type %s): %s",
      $self->code || '',
      $self->condition || '',
      $self->type,
      $self->text
}

package Net::XMPP2::Error::IQ;
our @ISA = qw/Net::XMPP2::Error::Stanza/;

=head1 SUBCLASS

Net::XMPP2::Error::IQ - IQ errors

(Subclass of L<Net::XMPP2::Error::Stanza>)

=cut

sub init {
   my ($self) = @_;
   my $node = $self->xml_node;

   unless (defined $node) {
      $self->{error_cond} = 'client-timeout';
      $self->{error_type} = 'cancel';
      return;
   }

   $self->SUPER::init;
}

=head2 METHODS

=over 4

=item B<condition ()>

Same as L<Net::XMPP2::Error::Stanza> except that
in case of a IQ timeout it returns:

   'client-timeout'

=cut

sub string {
   my ($self) = @_;

   sprintf "iq error: %s/%s (type %s): %s",
      $self->code || '',
      $self->condition || '',
      $self->type,
      $self->text
}

=back

=cut

package Net::XMPP2::Error::Stream;
our @ISA = qw/Net::XMPP2::Error/;

=head1 SUBCLASS

Net::XMPP2::Error::Stream - XML Stream errors

=cut

sub init {
   my ($self) = @_;
   my $node = $self->xml_node;

   my @txt = $node->find_all ([qw/streams text/]);
   my $error;
   for my $er (
      qw/bad-format bad-namespace-prefix conflict connection-timeout host-gone
         host-unknown improper-addressing internal-server-error invalid-from
         invalid-id invalid-namespace invalid-xml not-authorized policy-violation
         remote-connection-failed resource-constraint restricted-xml
         see-other-host system-shutdown undefined-condition unsupported-stanza-type
         unsupported-version xml-not-well-formed/)
   {
      if (my (@n) = $node->find_all ([streams => $er])) {
         $error = $n[0]->name;
         last;
      }
   }

   unless ($error) {
      #d# warn "got undefined error stanza, trying to find any undefined error...";
      for my $n ($node->nodes) {
         if ($n->eq_ns ('streams')) {
            $error = $n->name;
         }
      }
   }

   $self->{error_name} = $error;
   $self->{error_text} = @txt ? $txt[0]->text : '';
}

=head2 METHODS

=over 4

=item B<xml_node ()>

Returns the L<Net::XMPP2::Node> object for this stream error.

=cut

sub xml_node {
   $_[0]->{node}
}

=item B<name ()>

Returns the name of the error. That might be undef, one of the following
strings or some other string that has been discovered by a heuristic
(because some servers send errors that are not in the RFC).

   bad-format
   bad-namespace-prefix
   conflict
   connection-timeout
   host-gone
   host-unknown
   improper-addressing
   internal-server-error
   invalid-from
   invalid-id
   invalid-namespace
   invalid-xml
   not-authorized
   policy-violation
   remote-connection-failed
   resource-constraint
   restricted-xml
   see-other-host
   system-shutdown
   undefined-condition
   unsupported-stanza-type
   unsupported-version
   xml-not-well-formed

=cut

sub name { $_[0]->{error_name} }

=item B<text ()>

The humand readable error portion. Might be undef if none was received.

=cut

sub text { $_[0]->{error_text} }

sub string {
   my ($self) = @_;

   sprintf ("stream error: %s: %s",
      $self->name,
      $self->text)
}

=back

=cut

package Net::XMPP2::Error::SASL;
our @ISA = qw/Net::XMPP2::Error/;

=head1 SUBCLASS

Net::XMPP2::Error::SASL - SASL authentication error

=cut

sub init {
   my ($self) = @_;
   my $node = $self->xml_node;

   my $error;
   for ($node->nodes) {
      $error = $_->name;
      last
   }

   $self->{error_cond} = $error;
}

=head2 METHODS

=over 4

=item B<xml_node ()>

Returns the L<Net::XMPP2::Node> object for this stream error.

=cut

sub xml_node {
   $_[0]->{node}
}

=item B<condition ()>

Returns the error condition, which might be one of:

   aborted
   incorrect-encoding
   invalid-authzid
   invalid-mechanism
   mechanism-too-weak
   not-authorized
   temporary-auth-failure

=cut

sub condition {
   $_[0]->{error_cond}
}

sub string {
   my ($self) = @_;

   sprintf "sasl error: %s",
      $self->condition
}

=back

=cut

package Net::XMPP2::Error::Register;
our @ISA = qw/Net::XMPP2::Error::IQ/;

=head1 SUBCLASS

Net::XMPP2::Error::Register - In band registration error

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
