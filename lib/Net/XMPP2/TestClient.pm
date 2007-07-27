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
      timeout => 10,
      finish_count => 1,
      @_
   };

   if ($ENV{NET_XMPP2_TEST_DEBUG}) {
      $self->{debug} = 1;
   }

   if ($ENV{NET_XMPP2_TEST}) {
      plan tests => $self->{tests} + 1;
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
   $cl->add_account ($jid, $password);

   if ($self->{two_accounts}) {
      $cl->add_account ("2nd_".$jid, $password);
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
