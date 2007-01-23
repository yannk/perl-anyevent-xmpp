package Net::XMPP2::Writer;
use warnings;
use strict;
use XML::Writer;
use Authen::SASL;
use MIME::Base64;
use Net::XMPP2::Namespaces qw/xmpp_ns/;

=head1 NAME

Net::XMPP2::Writer - A XML writer for XMPP

=head1 SYNOPSIS

   use Net::XMPP2::Writer;
   ...

=head1 METHODS

=head2 new (%args)

This methods takes following arguments:

=over 4

=item write_cb

The callback that is called when a XML stanza was completly written
and is ready for transfer. The first argument of the callback
will be the character data to send to the socket.

And calls C<init>.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { write_cb => sub {}, @_ };
   bless $self, $class;
   $self->init;
   return $self;
}

=head2 init

(Re)initializes the writer.

=cut

sub init {
   my ($self) = @_;
   $self->{write_buf} = "";
   $self->{writer} = XML::Writer->new (OUTPUT => \$self->{write_buf}, NAMESPACES => 1);
}

=head2 flush ()

This method flushes the internal write buffer and will invoke the C<write_cb>
callback. (see also C<new ()> above)

=cut

sub flush {
   my ($self) = @_;
   $self->{write_cb}->(substr $self->{write_buf}, 0, (length $self->{write_buf}), '');
}

=head2 send_init_stream ($domain)

This method will generate a XMPP stream header. C<$domain> has to be the
domain of the server (or endpoint) we want to connect to.

=cut

sub send_init_stream {
   my ($self, $language, $domain) = @_;

   my $w = $self->{writer};
   $w->xmlDecl ('UTF-8');
   $w->addPrefix (xmpp_ns ('stream'), 'stream');
   $w->addPrefix (xmpp_ns ('client'), '');
   $w->forceNSDecl ('jabber:client');
   $w->startTag (
      [xmpp_ns ('stream'), 'stream'],
      to => $domain,
      version => '1.0',
      [xmpp_ns ('xml'), 'lang'] => $language
   );
   $self->flush;
}

=head2 send_end_of_stream

Sends end of the stream.

=cut

sub send_end_of_stream {
   my ($self) = @_;
   my $w = $self->{writer};
   $w->endTag ([xmpp_ns ('stream'), 'stream']);
   $self->flush;
}

=head2 send_sasl_auth ($mechanisms)

This methods sends the start of a SASL authentication. C<$mechanisms> is
a string with space seperated mechanisms that are supported by the other
end.

=cut

sub send_sasl_auth {
   my ($self, $mechanisms, $user, $domain, $pass) = @_;

   my $sasl = Authen::SASL->new (
      mechanism => $mechanisms,
      callback => {
         authname => $user,
         user => $user,
         pass => $pass,
      }
   );

   $self->{sasl} = $sasl->client_new ('xmpp', $domain);

   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('sasl'),   '');
   $w->startTag ([xmpp_ns ('sasl'), 'auth'], mechanism => $self->{sasl}->mechanism);
   $w->characters (MIME::Base64::encode_base64 ($self->{sasl}->client_start, ''));
   $w->endTag;
   $self->flush;
}

=head2 send_sasl_response ($challenge)

This method generated the SASL authentication response to a C<$challenge>.
You must not call this method without calling C<send_sasl_auth ()> before.

=cut

sub send_sasl_response {
   my ($self, $challenge) = @_;
   $challenge = MIME::Base64::decode_base64 ($challenge);
   my $ret = '';
   unless ($challenge =~ /rspauth=/) { # rspauth basically means: we are done
      $ret = $self->{sasl}->client_step ($challenge);
      unless ($ret) {
         die "Error in SASL authentication in client step with challenge: '$challenge'\n";
      }
   }
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('sasl'),   '');
   $w->startTag ([xmpp_ns ('sasl'), 'response']);
   $w->characters (MIME::Base64::encode_base64 ($ret, ''));
   $w->endTag;
   $self->flush;
}

=head2 send_starttls

Sends the starttls command to the server.

=cut

sub send_starttls {
   my ($self) = @_;
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('tls'),   '');
   $w->emptyTag ([xmpp_ns ('tls'), 'starttls']);
   $self->flush;
}

=head2 send_iq ($id, $type, $create_cb, %attrs)

This method sends an IQ stanza of type C<$type>. C<$create_cb>
will be called with an XML::Writer instance as first argument.
C<$create_cb> should be used to fill the IQ xml stanza.

C<%attrs> should have further attributes for the IQ stanza tag.
For example 'to' or 'from'. If the C<%attrs> contain a 'lang' attribute
it will be put into the 'xml' namespace.

C<$id> is the id to give this IQ stanza.

=cut

sub send_iq {
   my ($self, $id, $type, $create_cb, %attrs) = @_;
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('bind'), '');
   my (@from) = ($self->{jid} ? (from => $self->{jid}) : ());
   if ($attrs{lang}) {
      push @from, ([ xmpp_ns ('xml'), 'lang' ] => delete $attrs{leng})
   }
   $w->startTag ('iq', id => $id, type => $type, @from, %attrs);
   $create_cb->($w);
   $w->endTag;
   $self->flush;
}

sub send_initial_presence {
   my ($self) = @_;
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('client'), '');
   $w->emptyTag ('presence', from => $self->{jid});
   $self->flush;
}

# XXX
sub send_presence {
   my ($self, $to) = @_;
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('client'), '');
   $w->emptyTag ('presence', from => $self->{jid}, to => $to);
   $self->flush;
}

# XXX
sub send_message {
   my ($self, $to, $type, $cb) = @_;
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('client'), '');
   $w->startTag ('message', to => $to, from => $self->{jid}, type => $type);
   $cb->($w);
   $w->endTag;
   $self->flush;
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
