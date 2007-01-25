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

=head1 DESCRIPTION

This module contains some helper functions for writing XMPP XML,
which is not real XML at all ;-( I use L<XML::Writer> and tune it
until it creates XML that is accepted by most servers propably
(all of the XMPP servers i tested yet work (jabberd14, jabberd2, ejabberd).

I hope the semantics of L<XML::Writer> don't change much over the future,
but if they do and you run into problems, please report them!

The whole XML concept of XMPP is fundamentally broken anyway. It's supposed
to be an subset of XML. But a subset of XML productions is not XML. Strictly
speaking you need a special XMPP XML parser and writer to be 100% conformant.

But i try to be as XML XMPP conformant as possible (it should be around 99-100%).
But it's hard to say what XML is conformant, as the specifications of XMPP XML and XML
are contradicting. For example XMPP also says you only have to generated and accept
utf-8 encodings of XML, but the XML recommendation says that each parser has
to accept utf-8 E<and> utf-16. So, what do you do? Do you use a XML conformant parser
or do you write your own?

I'm using XML::Parser::Expat as expat does support parsing of broken (aka 'partial')
XML documents, as XMPP requires. Another argument is that if you capture a XMPP
conversation to the end, and even if a '</stream:stream>' tag was captured, you
wont have a valid XML document. The problem is that you have to resent a <stream> tag
after TLS and SASL authentication each!

But well... Net::XMPP2 does it's best with expat to cope with the fundamental brokeness
of XML in XMPP.

Back to the issue with XML generation: I've discoverd that many XMPP servers (eg.
jabberd14 and ejabberd) have problems with XML namespaces. Thats the reason why
i'm assigning the namespace prefixes manually: The servers just don't accept validly
namespaced XML. The draft 3921bis does even state that a client SHOULD generate a 'stream'
prefix for the <stream> tag.

I advice you to explictly set the namespaces too if you generate XML for XMPP yourself,
at least until all or most of the XMPP servers have been fixed. Which might take some
years :-) And maybe will happen never.

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

This method sends an IQ stanza of type C<$type> (to be compliant
only use: 'get', 'set', 'result' and 'error'). C<$create_cb>
will be called with an XML::Writer instance as first argument.
C<$create_cb> should be used to fill the IQ xml stanza.
If C<$create_cb> is undefined an empty tag will be generated.

C<%attrs> should have further attributes for the IQ stanza tag.
For example 'to' or 'from'. If the C<%attrs> contain a 'lang' attribute
it will be put into the 'xml' namespace.

C<$id> is the id to give this IQ stanza and is mandatory in this API.

=cut

sub send_iq {
   my ($self, $id, $type, $create_cb, %attrs) = @_;
   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('bind'), '');
   my (@from) = ($self->{jid} ? (from => $self->{jid}) : ());
   if ($attrs{lang}) {
      push @from, ([ xmpp_ns ('xml'), 'lang' ] => delete $attrs{leng})
   }
   if (defined $create_cb) {
      $w->startTag ('iq', id => $id, type => $type, @from, %attrs);
      $create_cb->($w);
      $w->endTag;
   } else {
      $w->emptyTag ('iq', id => $id, type => $type, @from, %attrs);
   }
   $self->flush;
}

=head2 send_presence ($id, $type, $create_cb, %attrs)

Sends a presence stanza.

C<$create_cb> has the same meaning as for C<send_iq>.
C<%attrs> will let you pass further optional arguments like 'to'.

C<$type> is the type of the presence, which may be one of:

   unavailable, subscribe, subscribed, unsubscribe, unsubscribed, probe, error

Or something completly different if you don't like the RFC 3921 :-)

C<%attrs> contains further attributes for the presence tag or may contain one of the
following exceptional keys:

If C<%attrs> contains a 'show' key: a child xml tag with that name will be geenerated
with the value as the content, which should be one of 'away', 'chat', 'dnd' and 'xa'.

If C<%attrs> contains a 'status' key: a child xml tag with that name will be generated
with the value as content. If the value of the 'status' key is an hash reference
the keys will be interpreted as language identifiers for the xml:lang attribute
of each status element. If one of these keys is the empty string '' no xml:lang attribute
will be generated for it. The values will be the character content of the status tags.

If C<%attrs> contains a 'priority' key: a child xml tag with that name will be generated
with the value as content, which must be a number between -128 and +127.

Note: If C<$create_cb> is undefined and one of the above attributes (show,
status or priority) were given, the generates presence tag won't be empty.

=cut

sub _generate_key_xml {
   my ($w, $key, $value) = @_;
   $w->startTag ($key);
   $w->characters ($value);
   $w->endTag;
}

sub _generate_key_xmls {
   my ($w, $key, $value) = @_;
   if (ref ($value) eq 'HASH') {
      for (keys %$value) {
         $w->startTag ($key, [xmpp_ns ('xml'), 'lang'] => $_);
         $w->characters ($value->{$_});
         $w->endTag;
      }
   } else {
      $w->startTag ($key);
      $w->characters ($value);
      $w->endTag;
   }
}

sub send_presence {
   my ($self, $type, $create_cb, %attrs) = @_;

   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('client'), '');

   my @add;
   push @add, (type => $type) if defined $typ;

   if (defined $create_cb) {
      $w->startTag ('presence', @add, %attrs);
      _generate_key_xml (show => $attrs{show})         if defined $attrs{show};
      _generate_key_xml (priority => $attrs{priority}) if defined $attrs{priority};
      _generate_key_xmls (status => $attrs{status})    if defined $attrs{status};
      $create_cb->($w);
      $w->endTag;
   } else {
      if (exists $attrs{show} or $attrs{priority} or $attrs{status}) {
         $w->startTag ('presence', @add, %attrs);
         _generate_key_xml (show => $attrs{show})         if defined $attrs{show};
         _generate_key_xml (priority => $attrs{priority}) if defined $attrs{priority};
         _generate_key_xmls (status => $attrs{status})    if defined $attrs{status};
         $w->endTag;
      } else {
         $w->emptyTag ('presence', @add, %attrs);
      }
   }

   $self->flush;
}

=head2 send_message ($id, $to, $type, $create_cb, %attrs)

Sends a message stanza.

C<$to> is the destination JID of the message. C<$type> is
the type of the message, and if it is undefined it will default to 'chat'.
C<$type> must be one of the following: 'chat', 'error', 'groupchat', 'headline'
or 'normal'.

C<$create_cb> has the same meaning as in C<send_iq>.

C<%attrs> contains further attributes for the message tag or may contain one of the
following exceptional keys:

If C<%attrs> contains a 'body' key: a child xml tag with that name will be generated
with the value as content. If the value of the 'body' key is an hash reference
the keys will be interpreted as language identifiers for the xml:lang attribute
of each body element. If one of these keys is the empty string '' no xml:lang attribute
will be generated for it. The values will be the character content of the body tags.

If C<%attrs> contains a 'subject' key: a child xml tag with that name will be generated
with the value as content. If the value of the 'subject' key is an hash reference
the keys will be interpreted as language identifiers for the xml:lang attribute
of each subject element. If one of these keys is the empty string '' no xml:lang attribute
will be generated for it. The values will be the character content of the subject tags.

If C<%attrs> contains a 'thread' key: a child xml tag with that name will be generated
and the value will be the character content.

=cut

sub send_message {
   my ($self, $to, $type, $create_cb, %attrs) = @_;

   my $w = $self->{writer};
   $w->addPrefix (xmpp_ns ('client'), '');

   $type ||= 'chat';

   if (defined $create_cb) {
      $w->startTag ('message', to => $to, type => $type, %attrs);
      _generate_key_xmls (subject => $attrs{subject})    if defined $attrs{subject};
      _generate_key_xmls (body => $attrs{body})          if defined $attrs{body};
      _generate_key_xml (thread => $attrs{thread})       if defined $attrs{thread};
      $create_cb->($w);
      $w->endTag;
   } else {
      if (exists $attrs{subject} or $attrs{body} or $attrs{thread}) {
         $w->startTag ('message', to => $to, type => $type, %attrs);
         _generate_key_xmls (subject => $attrs{subject})    if defined $attrs{subject};
         _generate_key_xmls (body => $attrs{body})          if defined $attrs{body};
         _generate_key_xml (thread => $attrs{thread})       if defined $attrs{thread};
         $w->endTag;
      } else {
         $w->emptyTag ('message', to => $to, type => $type, %attrs);
      }
   }

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
