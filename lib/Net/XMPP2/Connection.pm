package Net::XMPP2::Connection;
use strict;
use AnyEvent;
use IO::Socket::INET;
use Net::XMPP2::Parser;
use Net::XMPP2::Writer;
use Net::XMPP2::Util qw/split_jid/;
use Net::XMPP2::Event;
use Net::XMPP2::SimpleConnection;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Extendable;
use Net::XMPP2::Error;
use Net::DNS;

our @ISA = qw/Net::XMPP2::SimpleConnection Net::XMPP2::Event Net::XMPP2::Extendable/;

=head1 NAME

Net::XMPP2::Connection - XML stream that implements the XMPP RFC 3920.

=head1 SYNOPSIS

   use Net::XMPP2::Connection;

   my $con =
      Net::XMPP2::Connection->new (
         username => "abc",
         domain => "jabber.org",
         resource => "Net::XMPP2"
      );

   $con->connect or die "Couldn't connect to jabber.org: $!";
   $con->init;
   $con->reg_cb (stream_ready => sub { print "XMPP stream ready!\n" });

=head1 DESCRIPTION

This module represents a XMPP stream as described in RFC 3920. You can issue the basic
XMPP XML stanzas with methods like C<send_iq>, C<send_message> and C<send_presence>.

And receive events with the C<reg_cb> event framework from the connection.

If you need instant messaging stuff please take a look at C<Net::XMPP2::IM::Connection>.

=head1 METHODS

=over 4

=item B<new (%args)>

Following arguments can be passed in C<%args>:

=over 4

=item language => $tag

This should be the language of the human readable contents that
will be transmitted over the stream. The default will be 'en'.

Please look in RFC 3066 how C<$tag> should look like.

=item jid => $jid

This can be used to set the settings C<username>, C<domain>
(and optionally C<resource>) from a C<$jid>.

=item resource => $resource

If this argument is given C<$resource> will be passed as desired
resource on resource binding.

Note: You have to take care that the stringprep profile for
resources can be applied at: C<$resource>. Otherwise the server
might signal an error. See L<Net::XMPP2::Util> for utility functions
to check this.

=item domain => $domain

This is the destination host we are going to connect to.
As the connection won't be automatically connected use C<connect>
to initiate the connect.

Note: A SRV RR lookup will be performed to discover the real hostname
and port to connect to. See also C<connect>.

=item override_host => $host
=item override_port => $port

This will be used as override to connect to.

=item port => $port

This is optional, the default port is 5222.

Note: A SRV RR lookup will be performed to discover the real hostname
and port to connect to. See also C<connect>.

=item username => $username

This is your C<$username> (the userpart in the JID);

Note: You have to take care that the stringprep profile for
nodes can be applied at: C<$username>. Otherwise the server
might signal an error. See L<Net::XMPP2::Util> for utility functions
to check this.

=item password => $password

This is the password for the C<username> above.

=item disable_ssl => $bool

If C<$bool> is true no SSL will be used.

=back

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self =
      $class->SUPER::new (
         language         => 'en',
         stream_namespace => 'client',
         @_
      );

   $self->{parser} = new Net::XMPP2::Parser;
   $self->{writer} = Net::XMPP2::Writer->new (
      write_cb     => sub { $self->write_data ($_[0]) },
      send_iq_cb   => sub { $self->event (send_iq_hook => @_) },
      send_msg_cb  => sub { $self->event (send_message_hook => @_) },
      send_pres_cb => sub { $self->event (send_presence_hook => @_) },
   );

   $self->{parser}->set_stanza_cb (sub {
      $self->handle_stanza (@_);
   });
   $self->{parser}->set_error_cb (sub {
      my ($ex, $data, $type) = @_;
      if ($type eq 'xml') {
         my $pe = Net::XMPP2::Error::Parser->new (exception => $_[0], data => $_[1]);
         $self->event (xml_parser_error => $pe);
         $self->disconnect ("xml error: $_[0], $_[1]");
      } else {
         my $pe = Net::XMPP2::Error->new (
            text => "uncaught exception in stanza handling: $ex"
         );
         $self->event (uncaught_exception_error => $pe);
         $self->disconnect ($pe->string);
      }
   });

   $self->{iq_id}              = 1;
   $self->{default_iq_timeout} = 60;

   $self->{disconnect_cb} = sub {
      my ($host, $port, $message) = @_;
      delete $self->{authenticated};
      delete $self->{ssl_enabled};
      $self->event (disconnect => $host, $port, $message);
   };

   if ($self->{jid}) {
      my ($user, $host, $res) = split_jid ($self->{jid});
      $self->{username} = $user;
      $self->{domain}   = $host;
      $self->{resource} = $res if defined $res;
   }

   my $proxy_cb = sub {
      my ($self, $er) = @_;
      $self->event (error => $er);
   };

   $self->reg_cb (
      xml_parser_error => $proxy_cb,
      sasl_error       => $proxy_cb,
      stream_error     => $proxy_cb,
      bind_error       => $proxy_cb,
      iq_result_cb_exception => sub {
         my ($self, $ex) = @_;
         $self->event (error =>
            Net::XMPP2::Error::Exception->new (
               exception => $ex, context => 'iq result callback execution'
            )
         );
      },
      tls_error => sub {
         my ($self) = @_;
         $self->event (error =>
            Net::XMPP2::Error->new (text => 'tls_error: tls negotiation failed')
         );
      },
   );

   return $self;
}

=item B<connect ($no_srv_rr)>

Try to connect to the domain and port passed in C<new>.

A SRV RR lookup will be performed on the domain to discover
the host and port to use. If you don't want this set C<$no_srv_rr>
to a true value. C<$no_srv_rr> is false by default.

As the SRV RR lookup might return multiple host and you fail to
connect to one you might just call this function again to try a
different host.

If C<connect> was successful and we connected a true value is returned.
If the connect was unsuccessful undef is returned and C<$!> will be set
to the error that occured while connecting.

If you want to know whether further connection attempts might be more
successful (as SRV RR lookup may return multiple hosts) call C<may_try_connect>
(see also C<may_try_connect>).

Note that an internal list will be kept of tried hosts.  Use
C<reset_connect_tries> to reset the internal list of tried hosts.

=cut

sub connect {
   my ($self, $no_srv_rr) = @_;

   my ($host, $port) = ($self->{domain}, $self->{port} || 5222);
   if ($self->{override_host}) {
      $host = $self->{override_host};
      $port = $self->{override_port} if defined $self->{override_port};

   } else {
      unless ($no_srv_rr) {
         my $res = Net::DNS::Resolver->new;
         my $p   = $res->query ('_xmpp-client._tcp.'.$host, 'SRV');
         if ($p) {
            my @srvs = grep { $_->type eq 'SRV' } $p->answer;
            if (@srvs) {
               @srvs = sort { $a->priority <=> $b->priority } @srvs;
               @srvs = sort { $b->weight <=> $a->weight } @srvs; # TODO
               $port = $srvs[0]->port;
               $host = $srvs[0]->target;
            }
         }
      }
   }

   if ($self->SUPER::connect ($host, $port)) {
      $self->event (connect => $host, $port);
      return 1;
   } else {
      return undef;
   }
}

=item B<may_try_connect>

Returns the number of left alternatives of hosts to connect to for the
domain passed to C<new>.

An internal list of tried hosts will be managed by C<connect> and those
hosts will be ignored by a SRV RR lookup (which will be done if you
call this function).

Use C<reset_connect_tries> to reset the internal list of tried hosts.

=cut

sub may_try_connect {
   # TODO
}

=item B<reset_connect_tries>

This function resets the internal list of tried hosts for C<connect>.
See also C<connect>.

=cut

sub reset_connect_tries {
   # TODO
}

sub handle_data {
   my ($self, $buf) = @_;
   $self->event (debug_recv => $$buf);
   $self->{parser}->feed (substr $$buf, 0, (length $$buf), '');
}

sub debug_wrote_data {
   my ($self, $data) = @_;
   $self->event (debug_send => $data);
}

sub write_data {
   my ($self, $data) = @_;
   $self->event (send_stanza_data => $data);
   $self->SUPER::write_data ($data);
}

sub handle_stanza {
   my ($self, $p, $node) = @_;

   if (not defined $node) { # got stream end
      $self->disconnect ("end of 'XML' stream encountered");
      return;
   }

   $self->event (recv_stanza_xml => $node);

   if ($node->eq (stream => 'features')) {
      $self->event (stream_features => $node);
      $self->{features} = $node;
      $self->handle_stream_features ($node);

   } elsif ($node->eq (tls => 'proceed')) {
      $self->enable_ssl;
      $self->{parser}->init;
      $self->{writer}->init;
      $self->{writer}->send_init_stream (
         $self->{language}, $self->{domain}, $self->{stream_namespace}
      );

   } elsif ($node->eq (tls => 'failure')) {
      $self->event ('tls_error');
      $self->disconnect ('TLS failure on TLS negotiation.');

   } elsif ($node->eq (sasl => 'challenge')) {
      $self->handle_sasl_challenge ($node);

   } elsif ($node->eq (sasl => 'success')) {
      $self->handle_sasl_success ($node);

   } elsif ($node->eq (sasl => 'failure')) {
      my $error = Net::XMPP2::Error::SASL->new (node => $node);
      $self->event (sasl_error => $error);
      $self->disconnect ('SASL authentication failure: ' . $error->string);

   } elsif ($node->eq (client => 'iq')) {
      $self->event (iq_xml => $node);
      $self->handle_iq ($node);

   } elsif ($node->eq (client => 'message')) {
      $self->event (message_xml => $node);

   } elsif ($node->eq (client => 'presence')) {
      $self->event (presence_xml => $node);

   } elsif ($node->eq (stream => 'error')) {
      $self->handle_error ($node);
   }
}

=item B<init ()>

Initiate the XML stream.

=cut

sub init {
   my ($self) = @_;
   $self->{writer}->send_init_stream ($self->{language}, $self->{domain}, $self->{stream_namespace});
}

=item B<is_connected ()>

Returns true if the connection is still connected and stanzas can be
sent.

=cut

sub is_connected {
   my ($self) = @_;
   $self->{authenticated}
}

=item B<set_default_iq_timeout ($seconds)>

This sets the default timeout for IQ requests. If the timeout runs out
the request will be aborted and the callback called with a L<Net::XMPP2::Error::IQ> object
where the C<condition> method returns a special value (see also C<condition> method of L<Net::XMPP2::Error::IQ>).

The default timeout for IQ is 60 seconds.

=cut

sub set_default_iq_timeout {
   my ($self, $sec) = @_;
   $self->{default_iq_timeout} = $sec;
}

=item B<send_iq ($type, $create_cb, $result_cb, %attrs)>

This method sends an IQ XMPP request.

Please take a look at the documentation for C<send_iq> in Net::XMPP2::Writer
about the meaning of C<$type>, C<$create_cb> and C<%attrs> (with the exception
of the 'timeout' key of C<%attrs>, see below).

C<$result_cb> will be called when a result was received or the timeout reached.
The first argument to C<$result_cb> will be a Net::XMPP2::Node instance
containing the IQ result stanza contents.

If the IQ resulted in a stanza error the second argument to C<$result_cb> will
be C<undef> (if the error type was not 'continue') and the third argument will
be a L<Net::XMPP2::Error::IQ> object.

The timeout can be set by C<set_default_iq_timeout> or passed seperatly
in the C<%attrs> array as the value for the key C<timeout> (timeout in seconds btw.).

This method returns the newly generated id for this iq request.

=cut

sub send_iq {
   my ($self, $type, $create_cb, $result_cb, %attrs) = @_;
   my $id = $self->{iq_id}++;
   $self->{iqs}->{$id} = $result_cb;

   my $timeout = delete $attrs{timeout} || $self->{default_iq_timeout};
   if ($timeout) {
      $self->{iq_timers}->{$id} =
         AnyEvent->timer (after => $timeout, cb => sub {
            delete $self->{iq_timers}->{$id};
            my $cb = delete $self->{iqs}->{$id};
            $cb->(undef, Net::XMPP2::Error::IQ->new)
         });
   }

   $self->{writer}->send_iq ($id, $type, $create_cb, %attrs);
   $id
}

=item B<reply_iq_result ($req_iq_node, $create_cb, %attrs)>

This method will generate a result reply to the iq request C<Net::XMPP2::Node>
in C<$req_iq_node>.

Please take a look at the documentation for C<send_iq> in Net::XMPP2::Writer
about the meaning C<$create_cb> and C<%attrs>.

Use C<$create_cb> to create the XML for the result.

The type for this iq reply is 'result'.

=cut

sub reply_iq_result {
   my ($self, $iqnode, $create_cb, %attrs) = @_;
   $self->{writer}->send_iq ($iqnode->attr ('id'), 'result', $create_cb, %attrs);
}

=item B<reply_iq_error ($req_iq_node, $error_type, $error, %attrs)>

This method will generate an error reply to the iq request C<Net::XMPP2::Node>
in C<$req_iq_node>.

C<$error_type> is one of 'cancel', 'continue', 'modify', 'auth' and 'wait'.
C<$error> is one of the defined error conditions described in
C<write_error_tag> method of L<Net::XMPP2::Writer>.

Please take a look at the documentation for C<send_iq> in Net::XMPP2::Writer
about the meaning of C<%attrs>.

The type for this iq reply is 'error'.

=cut

sub reply_iq_error {
   my ($self, $iqnode, $errtype, $error, %attrs) = @_;

   $self->{writer}->send_iq (
      $iqnode->attr ('id'), 'error',
      sub { $self->{writer}->write_error_tag ($iqnode, $errtype, $error) },
      %attrs
   );
}

sub handle_iq {
   my ($self, $node) = @_;

   my $type = $node->attr ('type');

   my $id = $node->attr ('id');
   delete $self->{iq_timers}->{$id} if defined $id;

   if ($type eq 'result') {
      if (my $cb = delete $self->{iqs}->{$id}) {
         eval {
            $cb->($node);
         };
         if ($@) { $self->event (iq_result_cb_exception => $@) }
      }

   } elsif ($type eq 'error') {
      if (my $cb = delete $self->{iqs}->{$id}) {

         my $error = Net::XMPP2::Error::IQ->new (node => $node);
         $cb->(($error->type eq 'continue' ? $node : undef), $error);
      }

   } else {
      my (@r) = $self->event ("iq_${type}_request_xml" => $node);
      @r = grep { $_ } @r;

      my @from;
      push @from, (to => $node->attr ('from')) if $node->attr ('from');

      unless (@r) {
         $self->reply_iq_error ($node, undef, 'service-unavailable', @from);
      }
   }
}

sub send_sasl_auth {
   my ($self, @mechs) = @_;

   for (qw/username password domain/) {
      die "No '$_' argument given to new, but '$_' is required\n"
         unless $self->{$_};
   }

   $self->{writer}->send_sasl_auth (
      (join ' ', map { $_->text } @mechs),
      $self->{username}, $self->{domain}, $self->{password}
   );
}

sub handle_stream_features {
   my ($self, $node) = @_;
   my @bind  = $node->find_all ([qw/bind bind/]);
   my @tls   = $node->find_all ([qw/tls starttls/]);

   # and yet another weird thingie: in XEP-0077 it's said that
   # the register feature MAY be advertised by the server. That means:
   # it MAY not be advertised even if it is available... so we don't
   # care about it...
   # my @reg   = $node->find_all ([qw/register register/]);

   if (not ($self->{disable_ssl}) && not ($self->{ssl_enabled}) && @tls) {
      $self->{writer}->send_starttls;

   } elsif (not $self->{authenticated}) {
      my $continue = 1;
      my (@ret) = $self->event (stream_pre_authentication => \$continue);
      $continue = pop @ret if @ret;
      if ($continue) {
         $self->authenticate;
      }

   } elsif (@bind) {
      $self->do_rebind ($self->{resource});
   }
}

=item B<authenticate>

This method should be called after the C<stream_pre_authentication> event
was emitted to continue authentication of the stream.

Usually this method only has to be called when you want to register before
you authenticate. See also the documentation of the C<stream_pre_authentication>
event below.

=cut

sub authenticate {
   my ($self) = @_;
   my $node = $self->{features};
   my @mechs = $node->find_all ([qw/sasl mechanisms/], [qw/sasl mechanism/]);
   my @iqa   = $node->find_all ([qw/iqauth auth/]);

   if (@mechs) {
      $self->send_sasl_auth (@mechs)
   } elsif (@iqa) {
      $self->do_iq_auth;
   }
}

sub handle_sasl_challenge {
   my ($self, $node) = @_;
   $self->{writer}->send_sasl_response ($node->text);
}

sub handle_sasl_success {
   my ($self, $node) = @_;
   $self->{authenticated} = 1;
   $self->{parser}->init;
   $self->{writer}->init;
   $self->{writer}->send_init_stream ($self->{language}, $self->{domain}, $self->{stream_namespace});
}

sub handle_error {
   my ($self, $node) = @_;
   my $error = Net::XMPP2::Error::Stream->new (node => $node);

   $self->event (stream_error => $error);
   $self->{writer}->send_end_of_stream;
}

sub do_iq_auth {
   my ($self) = @_;
   # TODO
}

=item B<send_presence ($type, $create_cb, %attrs)>

This method sends a presence stanza, for the meanings
of C<$type>, C<$create_cb> and C<%attrs> please take a look
at the documentation for C<send_presence> method of L<Net::XMPP2::Writer>.

This methods does attach an id attribute to the message stanza and
will return the id that was used (so you can react on possible replies).

=cut

sub send_presence {
   my ($self, $type, $create_cb, %attrs) = @_;
   my $id = $self->{iq_id}++;
   $self->{writer}->send_presence ($id, $type, $create_cb, %attrs);
   $id
}

=item B<send_message ($to, $type, $create_cb, %attrs)>

This method sends a presence stanza, for the meanings
of C<$to>, C<$type>, C<$create_cb> and C<%attrs> please take a look
at the documentation for C<send_message> method of L<Net::XMPP2::Writer>.

This methods does attach an id attribute to the message stanza and
will return the id that was used (so you can react on possible replies).

=cut

sub send_message {
   my ($self, $to, $type, $create_cb, %attrs) = @_;
   my $id = $self->{iq_id}++;
   $self->{writer}->send_message ($id, $to, $type, $create_cb, %attrs);
   $id
}

=item B<do_rebind ($resource)>

In case you got a C<bind_error> event and want to retry
binding you can call this function to set a new C<$resource>
and retry binding.

If it fails again you can call this again. Becareful not to
end up in a loop!

If binding was successful the C<stream_ready> event will be generated.

=cut

sub do_rebind {
   my ($self, $resource) = @_;
   $self->{resource} = $resource;
   $self->send_iq (
      set =>
         sub {
            my ($w) = @_;
            if ($self->{resource}) {
               $w->startTag ([xmpp_ns ('bind'), 'bind']);
                  $w->startTag ([xmpp_ns ('bind'), 'resource']);
                  $w->characters ($self->{resource});
                  $w->endTag;
               $w->endTag;
            } else {
               $w->emptyTag ([xmpp_ns ('bind'), 'bind'])
            }
         },
         sub {
            my ($ret_iq, $error) = @_;

            if ($error) {
               # TODO: make bind error into a seperate error class?
               if ($error->xml_node ()) {
                  my ($res) = $error->xml_node ()->find_all ([qw/bind bind/], [qw/bind resource/]);
                  $self->event (bind_error => $error, ($res ? $res : $self->{resource}));
               } else {
                  $self->event (bind_error => $error);
               }

            } else {
               my @jid = $ret_iq->find_all ([qw/bind bind/], [qw/bind jid/]);
               my $jid = $jid[0]->text;
               unless ($jid) { die "Got empty JID tag from server!\n" }
               $self->{jid} = $jid;

               $self->event (stream_ready => $jid);
            }
         }
   );
}


=item B<jid>

After the stream has been bound to a resource the JID can be retrieved via this
method.

=cut

sub jid { $_[0]->{jid} }

=item B<features>

Returns the last received <features> tag in form of an L<Net::XMPP2::Node> object.

=cut

sub features { $_[0]->{features} }

=back

=head1 EVENTS

These events can be registered on with C<reg_cb>:

=over 4

=item stream_features => $node

This event is sent when a stream feature (<features>) tag is received. C<$node> is the
L<Net::XMPP2::Node> object that represents the <features> tag.

=item stream_pre_authentication

This event is emitted after TLS/SSL was initiated (if enabled) and before any
authentication happened.

The return value of the first event callback that is called decides what happens next.
If it is true value the authentication continues. If it is undef or a false value
authentication is stopped and you need to call C<authentication> later.
value

This event is usually used when you want to do in-band registration,
see also L<Net::XMPP2::Ext::Registration>.

=item stream_ready => $jid

This event is sent if the XML stream has been established (and
resources have been bound) and is ready for transmitting regular stanzas.

C<$jid> is the bound jabber id.

=item error => $error

This event is generated whenever some error occured.
C<$error> is an instance of L<Net::XMPP2::Error>.
Trivial error reporting may look like this:

   $con->reg_cb (error => sub { warn "xmpp error: " . $_[1]->string . "\n" });

Basically this event is a collect event for all other error events.

=item stream_error => $error

This event is sent if a XML stream error occured. C<$error>
is a L<Net::XMPP2::Error::Stream> object.

=item xml_parser_error => $error

This event is generated whenever the parser trips over XML that it can't
read. C<$error> is a L<Net::XMPP2::Error::Parser> object.

=item tls_error

This event is emitted when a TLS error occured on TLS negotiation.
After this the connection will be disconnected.

=item sasl_error => $error

This event is emitted on SASL authentication error.

=item bind_error => $error, $resource

This event is generated when the stream was unable to bind to
any or the in C<new> specified resource. C<$error> is a L<Net::XMPP2::Error::IQ>
object. C<$resource> is the errornous resource string or undef if none
was received.

The C<condition> of the C<$error> might be one of: 'bad-request',
'not-allowed' or 'conflict'.

Node: this is untested, I couldn't get the server to send a bind error
to test this.

=item connect => $host, $port

This event is generated when a successful connect was performed to
the domain passed to C<new>.

Note: C<$host> and C<$port> might be different from the domain you passed to
C<new> if C<connect> performed a SRV RR lookup.

If this connection is lost a C<disconnect> will be generated with the same
C<$host> and C<$port>.

=item disconnect => $host, $port, $message

This event is generated when the connection was lost or another error
occured while writing or reading from it.

C<$message> is a humand readable error message for the failure.
C<$host> and C<$port> were the host and port we were connected to.

Note: C<$host> and C<$port> might be different from the domain you passed to
C<new> if C<connect> performed a SRV RR lookup.

=item recv_stanza_xml => $node

This event is generated before any processing of a "XML" stanza happens.
C<$node> is the node of the stanza that is being processed, it's of
type L<Net::XMPP2::Node>.

This method might not be as handy for debuggin purposes as C<debug_recv>.

=item send_stanza_data => $data

This event is generated shortly before data is sent to the socket.
C<$data> contains a complete "XML" stanza or the end of stream closing
tag. This method is useful for debugging purposes and I recommend
using XML::Twig or something like that to display it nicely.

See also the event C<debug_send>.

=item debug_send => $data

This method is invoked whenever data is written out. This event
is mostly the same as C<send_stanza_data>.

=item debug_recv => $data

This method is incoked whenever a chunk of data was received.

It works to filter C<$data> through L<XML::Twig> for debugging
display purposes sometimes, but as C<$data> is some arbitrary chunk
of bytes you might get a XML parse error (did I already mention that XMPP's
application of "XML" sucks?).

So you might want to use C<recv_stanza_xml> to detect
complete stanzas. Unfortunately C<recv_stanza_xml> doesn't have the
bytes anymore and just a datastructure (L<Net::XMPP2::Node>).

=item presence_xml => $node

This event is sent when a presence stanza is received. C<$node> is the
L<Net::XMPP2::Node> object that represents the <presence> tag.

=item message_xml => $node

This event is sent when a message stanza is received. C<$node> is the
L<Net::XMPP2::Node> object that represents the <message> tag.

=item iq_xml => $node

This event is emitted when a iq stanza arrives. C<$node> is the
L<Net::XMPP2::Node> object that represents the <iq> tag.

=item iq_set_request_xml => $node

=item iq_get_request_xml => $node

These events are sent when an iq request stanza of type 'get' or 'set' is received.
C<$type> will either be 'get' or 'set' and C<$node> will be the L<Net::XMPP2::Node>
object of the iq tag.

If one of the event callbacks returns a true value the IQ request will be
considered as handled.
If no callback returned a true value or no value at all an error iq will be generated.

=item iq_result_cb_exception => $exception

If the C<$result_cb> of a C<send_iq> operation somehow threw a exception
or failed this event will be generated.

=item send_iq_hook => $id, $type, $attrs

This event lets you add any desired number of additional create callbacks
to a IQ stanza that is about to be sent.

C<$id>, C<$type> are described in the documentation of C<send_iq> of
L<Net::XMPP2::Writer>. C<$attrs> is the hashref to the C<%attrs> hash that can
be passed to C<send_iq> and also has the exact same semantics as described in
the documentation of C<send_iq>.

The return values of the event callbacks are interpreted as C<$create_cb> value as
documented for C<send_iq>. (That means you can for example return a callback
that fills the IQ).

Example:

   # this appends a <test/> element to all outgoing IQs
   # and also a <test2/> element to all outgoing IQs
   $con->reg_cb (send_iq_hook => sub {
      my ($id, $type, $attrs) = @_;
      (sub {
         my $w = shift; # $w is a XML::Writer instance
         $w->emptyTag ('test');
      }, {
         node => { name => "test2" } # see also simxml() defined in Net::XMPP2::Util
      })
   });

=item send_message_hook => $id, $to, $type, $attrs

This event lets you add any desired number of additional create callbacks
to a message stanza that is about to be sent.

C<$id>, C<$to>, C<$type> and the hashref C<$attrs> are described in the documentation
for C<send_message> of L<Net::XMPP2::Writer> (C<$attrs> is C<%attrs> there).

To actually append something you need to return something, what you need to return
is described in the C<send_iq_hook> event above.

=item send_presence_hook => $id, $type, $attrs

This event lets you add any desired number of additional create callbacks
to a presence stanza that is about to be sent.

C<$id>, C<$type> and the hashref C<$attrs> are described in the documentation
for C<send_presence> of L<Net::XMPP2::Writer> (C<$attrs> is C<%attrs> there).

To actually append something you need to return something, what you need to return
is described in the C<send_iq_hook> event above.

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
