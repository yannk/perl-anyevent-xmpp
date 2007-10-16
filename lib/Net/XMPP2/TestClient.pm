package Net::XMPP2::TestClient;
use strict;
no warnings;
use AnyEvent;
use Net::XMPP2::Client;
use Net::XMPP2::Util qw/stringprep_jid prep_bare_jid dump_twig_xml/;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Test::More;

=head1 NAME

Net::XMPP2::TestClient - XMPP Test Client for tests

=head1 SYNOPSIS

=head1 DESCRIPTION

This module is a helper module to ease the task of testing.
If you want to run the developer test suite you have to set the environment
variable C<NET_XMPP2_TEST> to something like this:

   NET_XMPP2_TEST="test_me@your_xmpp_server.tld:secret_password"

Most tests will try to connect two accounts, so please take a server
that allows two connections from the same IP.

If you also want to run the MUC tests (see L<Net::XMPP2::Ext::MUC>)
you also need to setup the environment variable C<NET_XMPP2_TEST_MUC>
to contain the domain of a MUC service:

   NET_XMPP2_TEST_MUC="conference.your_xmpp_server.tld"

If you see some tests fail and want to know more about the protocol flow
you can enable the protocol debugging output by setting C<NET_XMPP2_TEST_DEBUG>
to '1':

   NET_XMPP2_TEST_DEBUG=1

(NOTE: You will only see the output of this by running a single test)

If one of the tests takes longer than the preconfigured 20 seconds default
timeout in your setup you can set C<NET_XMPP2_TEST_TIMEOUT>:

   NET_XMPP2_TEST_TIMEOUT=60  # for a 1 minute timeout

=head1 CLEANING UP

If the tests went wrong somewhere or you interrupted the tests you might
want to delete the accounts from the server manually, then run:

   perl t/z_*_unregister.t

=head1 MANUAL TESTING

If you just want to run a single test yourself, just execute the register
test before doing so:

   perl t/z_00_register.t

And then you could eg. run:

   perl t/z_03_iq_auth.t

=head1 METHODS

=head2 new (%args)

Following arguments can be passed in C<%args>:

=over 4

=back

=cut

sub new_or_exit {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = {
      timeout      => 20,
      finish_count =>  1,
      @_
   };

   if ($ENV{NET_XMPP2_TEST_DEBUG}) {
      $self->{debug} = 1;
   }

   if ($ENV{NET_XMPP2_TEST_TIMEOUT}) {
      $self->{timeout} = $ENV{NET_XMPP2_TEST_TIMEOUT};
   }

   $self->{tests};

   if ($self->{muc_test} && not $ENV{NET_XMPP2_TEST_MUC}) {
      plan skip_all => "environment var NET_XMPP2_TEST_MUC not set! Set it to a conference!";
      exit;
   }

   if ($ENV{NET_XMPP2_TEST}) {
      plan tests => $self->{tests} + 1
   } else {
      plan skip_all => "environment var NET_XMPP2_TEST not set! (see also Net::XMPP2::TestClient)!";
      exit;
   }

   bless $self, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;
   $self->{condvar} = AnyEvent->condvar;
   $self->{timeout} =
      AnyEvent->timer (
         after => $self->{timeout}, cb => sub {
            $self->{error} .= "Error: Test Timeout\n";
            $self->{condvar}->broadcast;
         }
      );

   my $cl = $self->{client} = Net::XMPP2::Client->new (debug => $self->{debug} || 0);
   my ($jid, $password) = split /:/, $ENV{NET_XMPP2_TEST}, 2;

   $self->{jid} = $jid;
   $self->{password} = $password;
   $cl->add_account ($jid, $password, undef, undef, $self->{connection_args});

   if ($self->{two_accounts}) {
      $self->{connected_accounts} = {};

      $cl->reg_cb (session_ready => sub {
         my ($cl, $acc) = @_;
         $self->{connected_accounts}->{$acc->bare_jid} = $acc->jid;
         my (@jids) = values %{$self->{connected_accounts}};
         my $cnt = scalar @jids;
         if ($cnt > 1) {
            $cl->event (two_accounts_ready => $acc, @jids);
         }
      });

      $cl->add_account ("2nd_".$jid, $password, undef, undef, $self->{connection_args});
   }


   if ($self->{muc_test} && $ENV{NET_XMPP2_TEST_MUC}) {
      $self->{muc_room} = "test@" . $ENV{NET_XMPP2_TEST_MUC};

      my $disco = $self->instance_ext ('Net::XMPP2::Ext::Disco');
      $self->{disco} = $disco;

      $cl->reg_cb (
         before_session_ready => sub {
            my ($cl, $acc) = @_;
            my $con = $acc->connection;
            $con->add_extension (
               $self->{mucs}->{$acc->bare_jid}
                  = Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con)
            );
         },
         two_accounts_ready => sub {
            my ($cl, $acc, $jid1, $jid2) = @_;
            my $cnt = 0;
            my ($room1, $room2);
            my $muc = $self->{muc1} = $self->{mucs}->{prep_bare_jid $jid1};

            $muc->join_room ($self->{muc_room}, "test1", sub {
               my ($room, $user, $error) = @_;
               $room1 = $room;
               if ($error) {
                  $self->{error} .= "Error: Couldn't join $self->{muc_room} as 'test1'\n";
                  $self->{condvar}->broadcast;
               } else {
                  my $muc = $self->{muc2} = $self->{mucs}->{prep_bare_jid $jid2};
                  $muc->join_room ($self->{muc_room}, "test2", sub {
                     my ($room, $user, $error) = @_;
                     my $room2 = $room;
                     if ($error) {
                        $self->{error} .= "Error: Couldn't join $self->{muc_room} as 'test2'\n";
                        $self->{condvar}->broadcast;
                     } else {
                        $cl->event (two_rooms_joined => $acc, $jid1, $jid2, $room1, $room2)
                     }
                  });
               }
            });


         }
      );
   }


   $cl->reg_cb (error => sub {
      my ($cl, $acc, $error) = @_;
      $self->{error} .= "Error: " . $error->string . "\n";
      $self->finish unless $self->{continue_on_error};
   });

   $cl->start;
}

sub main_account { ($_[0]->{jid}, $_[0]->{password}) }

sub client { $_[0]->{client} }

sub tests { $_[0]->{tests} }

sub instance_ext {
   my ($self, $ext, @args) = @_;
   eval "require $ext; 1";
   if ($@) { die "Couldn't load '$ext': $@" }
   my $eo = $ext->new (@args);
   $self->{client}->add_extension ($eo);
   $eo
}

sub finish {
   my ($self) = @_;
   $self->{_cur_finish_cnt}++;
   if ($self->{finish_count} <= $self->{_cur_finish_cnt}) {
      $self->{condvar}->broadcast;
   }
}

sub wait {
   my ($self) = @_;
   $self->{condvar}->wait;

   if ($self->error) {
      fail ("error free");
      diag ($self->error);
   } else {
      pass ("error free");
   }
}

sub error { $_[0]->{error} }

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::TestClient
