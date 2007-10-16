#!perl

use strict;
no warnings;
use Test::More;
use Net::XMPP2::TestClient;
use Net::XMPP2::IM::Message;
use Net::XMPP2::Util qw/bare_jid prep_bare_jid split_jid cmp_jid/;
use Net::XMPP2::Ext::MUC;

my $MUC = $ENV{NET_XMPP2_TEST_MUC};

unless ($MUC) {
   plan skip_all => "environment var NET_XMPP2_TEST_MUC not set! Set it to a conference!";
   exit;
}

my $ROOM = "test@".$MUC;

my $cl =
   Net::XMPP2::TestClient->new_or_exit (
      tests => 26, two_accounts => 1, finish_count => 2
   );
my $C     = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');

my %muc;

$C->reg_cb (
   before_session_ready => sub {
      my ($C, $acc) = @_;
      my $con = $acc->connection;
      $con->add_extension (
         $muc{$acc->bare_jid} =
            Net::XMPP2::Ext::MUC->new (disco => $disco, connection => $con)
      );
   },
   two_accounts_ready => sub {
      my ($C, $acc, $jid1, $jid2) = @_;
      step_join_rooms ($C, \%muc, $jid1, $jid2);
   }
);

my $sjr_error   = '';
my $sjr_created = '';

sub step_join_rooms {
   my ($C, $mucs, $jid1, $jid2) = @_;

   my $muc1 = $mucs->{prep_bare_jid $jid1};
   $muc1->join_room ($ROOM, "test1owner", sub {
      my ($room, $user, $error) = @_;
      if ($error) {
         $sjr_error = $error->string;
      } else {
         if ($user->did_create_room) {
            $sjr_created = 1;
            step_rejoin ($C, $mucs, $jid1, $jid2, $room, $user);
         } else {
            $cl->finish;
         }
      }
   });
}

my $sr_error      = '';
my $sr_created    = 0;
my $sr_pass_field = 0;
my $sr_config_ok  = 0;

sub step_rejoin {
   my ($C, $mucs, $jid1, $jid2, $room1, $user1) = @_;

   $room1->send_part ("rejoin", sub {

      my $muc1 = $mucs->{prep_bare_jid $jid1};
      $muc1->join_room ($ROOM, "test1owner", sub {
         my ($room, $user, $error) = @_;

         if ($error) {
            $sjr_error = $error->string;

         } else {

            if ($user->did_create_room) {
               $sr_created = 1;

               $room->request_configuration (sub {
                  my ($form, $error) = @_;

                  if ($form) {

                     if ($form->get_field ('muc#roomconfig_passwordprotectedroom')
                         && $form->get_field ('muc#roomconfig_roomsecret')) {

                        $sr_pass_field = 1;

                        my $af = Net::XMPP2::Ext::DataForm->new;
                        $af->make_answer_form ($form);
                        $af->set_field_value ('muc#roomconfig_passwordprotectedroom', 1);
                        $af->set_field_value ('muc#roomconfig_roomsecret', "abc123");
                        $af->clear_empty_fields;

                        $room->send_configuration ($af, sub {
                           my ($ok, $error) = @_;
                           $sr_config_ok = 1 if $ok;
                           step_join_occupant ($C, $mucs, $jid1, $jid2, $room, $user);
                        });

                     } else {
                        $cl->finish;
                     }
                  }
               });

            } else {
               $cl->finish;
            }
         }
      }, create_instant => 0);
   });
}

my $sjo_join_error_type = '';

sub step_join_occupant {
   my ($C, $mucs, $jid1, $jid2, $room1, $user1) = @_;

   my $muc2 = $mucs->{prep_bare_jid $jid2};
   $muc2->join_room ($ROOM, "test2user", sub {
      my ($room, $user, $error) = @_;
      if ($error) {
         $sjo_join_error_type = $error->type;
         if ($sjo_join_error_type eq 'password_required') {
            step_join_occupant_password ($C, $mucs, $jid1, $jid2, $room1, $user1);
            return;
         }
      }
      $cl->finish;
   });
}

my $sjop_error = '';
my $sjop_join  = 0;

sub step_join_occupant_password {
   my ($C, $mucs, $jid1, $jid2, $room1, $user1) = @_;

   my $muc2 = $mucs->{prep_bare_jid $jid2};
   $muc2->join_room ($ROOM, "test2user", sub {
      my ($room, $user, $error) = @_;
      if ($error) {
         $sjop_error = $error->string;
         $cl->finish;
      } else {
         $sjop_join++;
         step_change_nick ($C, $mucs, $jid1, $jid2, $room1, $user1, $room, $user);
      }
   }, password => 'abc123');
}

my $nick_info = {};
my $second = 0;

sub step_change_nick {
   my ($C, $mucs, $jid1, $jid2, $room1, $user1, $room2, $user2) = @_;

   my $ni = $nick_info;
   if ($second == 1) {
      $ni = $nick_info->{second} = {};
   }

   my $cnt = 0;

   $room1->reg_cb (
      nick_change => sub {
         my ($room1, $user, $oldnick, $newnick) = @_;
         my (@other) = grep $_->jid ne $room1->get_me->jid, $room1->users;

         $ni->{user1}->{own}      = $user1->jid;
         $ni->{user1}->{other}    = $other[0]->jid;
         $ni->{user1}->{old_nick} = $oldnick;
         $ni->{user1}->{new_nick} = $newnick;
         $room1->unreg_me;
      }
   );
   $room1->reg_cb (
      after_nick_change => sub {
         my ($room1) = @_;

         if (not $second) {
            $cnt++;
            if ($cnt >= 2) {
               $second = 1;
               step_change_nick ($C, $mucs, $jid1, $jid2, $room1, $user1, $room2, $user2, 1);
            }
         } else {
            $cl->finish;
         }
      }
   ) if not $second;

   $room2->reg_cb (
      nick_change => sub {
         my ($room2, $user, $oldnick, $newnick) = @_;
         my (@other) = grep $_->jid ne $room2->get_me->jid, $room2->users;

         $ni->{user2}->{own}      = $user2->jid;
         $ni->{user2}->{other}    = $other[0]->jid;
         $ni->{user2}->{old_nick} = $oldnick;
         $ni->{user2}->{new_nick} = $newnick;
         $room2->unreg_me;
      }
   );

   $room2->reg_cb (
      after_nick_change => sub {
         my ($room2) = @_;

         if (not $second) {
            $cnt++;
            if ($cnt >= 2) {
               $second = 1;
               step_change_nick ($C, $mucs, $jid1, $jid2, $room1, $user1, $room2, $user2, 1);
            }
         } else {
            $cl->finish;
         }
      }
   ) if not $second;;

   if ($second == 1) {
      $room2->change_nick ("test2nd");
   } else {
      $room2->change_nick ("test2");
   }
}

$cl->wait;

is ((scalar keys %muc),         2, "MUC extensions initialized");
is ($sjr_error        ,        '', "creator joined without error");
ok ($sjr_created                 , "creator created room");
ok ($sr_created                  , "rejoin created room");
is ($sr_error         ,        '', "rejoin created without error");
ok ($sr_pass_field               , "configuration form has password fields");
ok ($sr_config_ok                , "configuration form was successfully sent");
is ($sjo_join_error_type, 'password_required', "occupant joined without error");
is ($sjop_error       ,        '', "rejoin with password no error");
is ($sjop_join        ,         1, "joined successfully with password");

is ($nick_info->{user1}->{own}     , "$ROOM/test1owner", 'observed own JID of user1');
is ($nick_info->{user1}->{other}   , "$ROOM/test2"     , 'observed other JID of user1');
is ($nick_info->{user1}->{old_nick}, "test2user"       , 'observed old nick of user1');
is ($nick_info->{user1}->{new_nick}, "test2"           , 'observed new nick of user1');
is ($nick_info->{user2}->{own}     , "$ROOM/test2"     , 'observed own JID of user2');
is ($nick_info->{user2}->{other}   , "$ROOM/test1owner", 'observed other JID of user2');
is ($nick_info->{user2}->{old_nick}, "test2user"       , 'observed old nick of user2');
is ($nick_info->{user2}->{new_nick}, "test2"           , 'observed new nick of user2');
$nick_info = $nick_info->{second};
is ($nick_info->{user1}->{own}     , "$ROOM/test1owner", '2nd observed own JID of user1');
is ($nick_info->{user1}->{other}   , "$ROOM/test2nd"   , '2nd observed other JID of user1');
is ($nick_info->{user1}->{old_nick}, "test2"           , '2nd observed old nick of user1');
is ($nick_info->{user1}->{new_nick}, "test2nd"         , '2nd observed new nick of user1');
is ($nick_info->{user2}->{own}     , "$ROOM/test2nd"   , '2nd observed own JID of user2');
is ($nick_info->{user2}->{other}   , "$ROOM/test1owner", '2nd observed other JID of user2');
is ($nick_info->{user2}->{old_nick}, "test2"           , '2nd observed old nick of user2');
is ($nick_info->{user2}->{new_nick}, "test2nd"         , '2nd observed new nick of user2');
