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
      tests => 16, two_accounts => 1, finish_count => 1
   );
my $C     = $cl->client;
my $disco = $cl->instance_ext ('Net::XMPP2::Ext::Disco');

my %muc;

my $muc_is_conference     = 0;
my $recv_presence_for_muc = 0;
my $muc_join_error        = '';
my $muc_joined_cb         = 0;
my $muc_joined_ev         = 0;
my $muc_left_once         = 0;
my $muc_joined_after_leave_cb = 0;
my $muc_status_check      = 0;

my $muc_got_delayed_message       = '';

my $muc_first_groupchat_msg       = '';
my $muc_first_groupchat_msg_echo  = '';
my $muc_second_groupchat_msg      = '';
my $muc_second_groupchat_msg_echo = '';
my $muc_first_private_message       = '';
my $muc_second_private_message      = '';

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
      $muc{$acc->bare_jid}->is_conference ($MUC, sub {
         my ($conf, $err) = @_;
         if ($conf) { $muc_is_conference = 1 }

         step_join_rooms ($C, \%muc, $jid1, $jid2);
      });
   },
   presence_xml => sub {
      my ($C, $acc, $node) = @_;
      if (prep_bare_jid ($node->attr ('from')) eq prep_bare_jid $ROOM) {
         $recv_presence_for_muc = 1
      }
   }
);

sub step_join_rooms {
   my ($C, $mucs, $jid1, $jid2) = @_;

   my @jobs;

   for (keys %$mucs) {
      my ($node) = split_jid $_;
      my $muc = $mucs->{$_};
      push @jobs, sub {
         $muc->reg_cb (
            enter_room => sub {
               my ($muc, $con, $room, $user) = @_;

               $muc_joined_ev++;

               $room->make_message (body => "made it (".$user->jid.")!")->send;

               if ($muc_joined_ev == 2) {
                 $mucs->{prep_bare_jid $jid1}
                    ->get_room ($ROOM)
                       ->send_part ("parting for tests");
               }
            },
            message_room => sub {
               my ($muc, $con, $room, $msg) = @_;

               if ($msg->is_delayed) {
                  $muc_got_delayed_message++;
                  $muc->unreg_me;
               }
            },
            leave_room => sub {
               my ($muc, $con, $room) = @_;

               if (prep_bare_jid ($room->jid) eq prep_bare_jid ($ROOM)) {
                  $muc_left_once++;
                  $muc->join_room ($ROOM, $node, sub {
                     unless ($_[2]) {
                        $muc_joined_after_leave_cb++;
                        step_check_status ($C, $mucs, $jid1, $jid2);
                     }
                  });
               }
            }
         );

         $muc->join_room ($ROOM, $node, sub {
            my ($room, $user, $error) = @_;
            if ($error) {
               $muc_join_error = $error->string;
            } else {
               $muc_joined_cb++;
               my $J = pop @jobs;
               $J->() if $J;
            }
         });
      };
   }

   (pop @jobs)->();
}

sub step_check_status {
   my ($C, $mucs, $jid1, $jid2) = @_;

   my $room1       = $mucs->{prep_bare_jid $jid1}->get_room ($ROOM);
   my $room2       = $mucs->{prep_bare_jid $jid2}->get_room ($ROOM);
   my $inr_jid_1   = $room1->nick_jid;
   my $inr_jid_2   = $room2->nick_jid;
   my @room1_users = $room1->users;
   my @room2_users = $room2->users;

   if ($room1->users >= 2) {
      $muc_status_check |= 1;
   }
   if ($room2->users >= 2) {
      $muc_status_check |= 2;
   }
   if (scalar (grep {
             cmp_jid ($_->in_room_jid, $inr_jid_1)
          || cmp_jid ($_->in_room_jid, $inr_jid_2)
       } @room1_users) == 2)
   {
      $muc_status_check |= 4;
   }
   if (scalar (grep {
             cmp_jid ($_->in_room_jid, $inr_jid_1)
          || cmp_jid ($_->in_room_jid, $inr_jid_2)
       } @room2_users) == 2)
   {
      $muc_status_check |= 8;
   }

   my $inr_user1 = $room1->get_me;
   my $inr_user2 = $room2->get_me;

   if ($inr_user1->affiliation ne '' && $inr_user1->role ne '') {
      $muc_status_check |= 16;
   }
   if ($inr_user2->affiliation ne '' && $inr_user2->role ne '') {
      $muc_status_check |= 32;
   }

   step_send_messages ($C, $mucs, $jid1, $jid2, $room1, $room2);
}

sub step_send_messages {
   my ($C, $mucs, $jid1, $jid2, $room1, $room2) = @_;

   $room2->reg_cb (message => sub {
      my ($room2, $msg, $is_echo) = @_;

      return if $msg->any_body =~ /^made/;

      if ($msg->type eq 'groupchat'
          && !$msg->is_delayed
          && cmp_jid ($msg->from, $room1->nick_jid)
          && !$is_echo)
      {
         $muc_first_groupchat_msg = $msg->any_body;
         my $repl = $msg->make_reply;
         $repl->add_body ('Hi there too!');
         $repl->send;

      } elsif ($msg->type eq 'groupchat'
               && !$msg->is_delayed
               && cmp_jid ($msg->from, $room2->nick_jid)
               && $is_echo)
      {
         $muc_second_groupchat_msg_echo = $msg->any_body;
         $room2->unreg_me;
      }
   });

   $room1->reg_cb (message => sub {
      my ($room1, $msg, $is_echo) = @_;

      return if $msg->any_body =~ /^made/;

      if ($msg->type eq 'groupchat'
          && !$msg->is_delayed
          && cmp_jid ($msg->from, $room1->nick_jid)
          && $is_echo)
      {
         $muc_first_groupchat_msg_echo = $msg->any_body;

      } elsif ($msg->type eq 'groupchat'
               && !$msg->is_delayed
               && cmp_jid ($msg->from, $room2->nick_jid)
               && !$is_echo)
      {
         $muc_second_groupchat_msg = $msg->any_body;
         $room1->unreg_me;
         step_private_messages ($C, $mucs, $jid1, $jid2, $room1, $room2);
      }
   });

   $room1->make_message (body => "Hi there, I'm a bot!")->send;
}

sub step_private_messages {
   my ($C, $mucs, $jid1, $jid2, $room1, $room2) = @_;

   $room1->reg_cb (message => sub {
      my ($room1, $msg) = @_;
      if ($msg->type eq 'chat'
          && cmp_jid ($msg->from, $room2->nick_jid)) {
         $muc_first_private_message = $msg->any_body;
         $msg->make_reply->add_body ("Hi, i got your msg!")->send;
      }
   });
   $room2->reg_cb (message => sub {
      my ($room2, $msg) = @_;
      if ($msg->type eq 'chat'
          && cmp_jid ($msg->from, $room1->nick_jid)) {
         $muc_second_private_message = $msg->any_body;
         $cl->finish;
      }
   });
   $room2->get_user_jid ($room1->nick_jid)->make_message (body => "Are you there?", type => 'chat')->send;
}

$cl->wait;

is ((scalar keys %muc),         2, "MUC extensions initialized");
ok ($muc_is_conference           , "detected a conference");
ok (!$recv_presence_for_muc      , "no presence for the room in the main handlers");
is ($muc_join_error,           '', "no join error");
is ($muc_joined_cb,             2, "joined MUC two times (callback)");
is ($muc_joined_ev,             3, "joined MUC two times (event)");
is ($muc_left_once,             1, "once left the room");
is ($muc_joined_after_leave_cb, 1, "once enterd the room (callback)");
is ($muc_status_check,  1|2|4|8|16|32,
                                   "muc room status checks");
ok ($muc_got_delayed_message,      "muc got delayed messages (and unreg cb)");

is ($muc_first_groupchat_msg       , 'Hi there, I\'m a bot!', "first muc message");
is ($muc_first_groupchat_msg_echo  , 'Hi there, I\'m a bot!', "first muc message echo");
is ($muc_second_groupchat_msg      , 'Hi there too!', "second muc message");
is ($muc_second_groupchat_msg_echo , 'Hi there too!', "second muc message echo");

is ($muc_first_private_message     , 'Are you there?', 'first private muc message');
is ($muc_second_private_message    , 'Hi, i got your msg!', 'second private muc message');
