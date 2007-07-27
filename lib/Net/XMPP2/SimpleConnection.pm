package Net::XMPP2::SimpleConnection;
use strict;
no warnings;

use IO::Socket::INET;
use Errno;
use Fcntl;
use Encode;
use Net::SSLeay;
use IO::Handle;

BEGIN {
   Net::SSLeay::load_error_strings ();
   Net::SSLeay::SSLeay_add_ssl_algorithms ();
   Net::SSLeay::randomize ();
}

=head1 NAME

Net::XMPP2::SimpleConnection - Low level TCP/TLS connection

=head1 SYNOPSIS

   package foo;
   use Net::XMPP2::SimpleConnection;

   our @ISA = qw/Net::XMPP2::SimpleConnection/;

=head1 DESCRIPTION

This module only implements the basic low level socket and SSL handling stuff.
It is used by L<Net::XMPP2::Connection> and you shouldn't mess with it :-)

(NOTE: This is the part of Net::XMPP2 which I feel least confident about :-)

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = {
      disconnect_cb => sub {},
      max_write_length => 4096,
      @_
   };
   bless $self, $class;
   return $self;
}

sub set_block {
   my ($self) = @_;
   my $flags = 0;
   fcntl($self->{socket}, F_GETFL, $flags)
       or die "Couldn't get flags for HANDLE : $!\n";
   $flags &= ~O_NONBLOCK;
   fcntl($self->{socket}, F_SETFL, $flags)
       or die "Couldn't set flags for HANDLE: $!\n";
}

sub set_noblock {
   my ($self) = @_;
   my $flags = 0;
   fcntl($self->{socket}, F_GETFL, $flags)
       or die "Couldn't get flags for HANDLE : $!\n";
   $flags |= O_NONBLOCK;
   fcntl($self->{socket}, F_SETFL, $flags)
       or die "Couldn't set flags for HANDLE: $!\n";
}

sub connect {
   my ($self, $host, $port) = @_;

   $self->{socket}
      and return 1;

   my $sock = IO::Socket::INET->new (
      PeerAddr => $host,
      PeerPort => $port,
      Proto    => 'tcp',
      Blocking => 1
   );
   return undef unless $sock;;

   $self->{socket} = $sock;
   $self->{host}   = $host;
   $self->{port}   = $port;

   $self->set_noblock;

   binmode $sock, ":raw";

   $self->{r} =
      AnyEvent->io (poll => 'r', fh => $sock, cb => sub {
         my $l = sysread $sock, my $data, 1024;

         if ($l) {
            $self->{read_buffer} .= decode_utf8 $data;
            $self->handle_data (\$self->{read_buffer});

         } else {
            return if $! == Errno::EAGAIN;
            if (defined $l) {
               $self->disconnect ("EOF from server '$self->{host}:$self->{port}'");
               return;

            } else {
               $self->disconnect ("Error while reading from server '$self->{host}:$port': $!");
               return;
            }
         }
      });
   return 1;
}

sub end_sockets {
   my ($self) = @_;
   delete $self->{r};
   delete $self->{w};
   if (delete $self->{ssl_enabled}) {
      Net::SSLeay::free ($self->{ssl});
      delete $self->{ssl};
      Net::SSLeay::CTX_free ($self->{ctx});
      delete $self->{ctx};
   }
   close ($self->{socket});
   delete $self->{socket};
}

sub try_ssl_write {
   my ($self) = @_;

   my $data = substr $self->{write_buffer}, 0, $self->{max_write_length};
   my $l = Net::SSLeay::write ($self->{ssl}, $data);

   if ($l <= 0) {
      if ($l == 0) {
         $self->disconnect ("unexpected EOF from server (ssl) '$self->{host}:$self->{port}'");
         return;

      } else {
         my $err2 = Net::SSLeay::get_error $self->{ssl}, $l;
         if ($err2 == 2 || $err2 == 3) {
            delete $self->{w};
            $self->make_ssl_write_watcher ($err2 == 2 ? 'r' : 'w');
            return;
         }

         if ($! != Errno::EAGAIN
             or my $err = Net::SSLeay::ERR_get_error) {

            $self->disconnect (
               sprintf (
                  "Error while writing from server '$self->{host}:$self->{port}': (%d|%s|%s)",
               $err2, (Net::SSLeay::ERR_error_string $err), "$!")
            );
            return;
         }
      }
   } else {
      $self->debug_wrote_data (substr $self->{write_buffer}, 0, $l);
      $self->{write_buffer} = substr $self->{write_buffer}, $l;
      if (length ($self->{write_buffer}) <= 0) {
         delete $self->{w};
      }
   }
}

sub try_ssl_read {
   my ($self) = @_;
   my $r = Net::SSLeay::read ($self->{ssl});

   if (defined $r) {
      if ($r eq '') {
         if (my $err = Net::SSLeay::ERR_get_error) {
            $self->disconnect (
               sprintf (
                  "Error while reading from server '$self->{host}:$self->{port}':"
                  ."(%s|%s)",
                  (Net::SSLeay::ERR_error_string $err), "$!")
            );
            return;
         }
         # is this right? $r = '' => EOF? sucky Net::SSLeay... arg...
         $self->disconnect ("EOF from server '$self->{host}:$self->{port}'.");
         return;
      }

      $self->{read_buffer} .= decode_utf8 ($r);
      $self->handle_data (\$self->{read_buffer});
   } else {
      my $err2 = Net::SSLeay::get_error $self->{ssl}, $r;
      if ($err2 == 2 || $err2 == 3) {
         #d# warn "READ RETRY $err2\n";
         delete $self->{r};
         $self->make_ssl_read_watcher ($err2 == 2 ? 'r' : 'w');
         return;
      }

      if ($! != Errno::EAGAIN
          or my $err = Net::SSLeay::ERR_get_error) {

         $self->disconnect (
            sprintf (
               "Error while reading from server '$self->{host}:$self->{port}':"
               ."(%d|%s|%s)",
               $err2, (Net::SSLeay::ERR_error_string $err), "$!")
         );
         return;
      }
   }
}

sub write_data {
   my ($self, $data) = @_;
   #return unless $self->{r};

   my $cl = $self->{socket};
   $self->{write_buffer} .= encode_utf8 ($data);

   unless ($self->{w}) {
      $self->{w} =
         AnyEvent->io (poll => 'w', fh => $cl, cb => sub {
            if (not $self->{ssl_enabled}) {
               if (my $data = $self->{write_buffer}) {
                  $data = substr $data, 0, $self->{max_write_length};
                  my $len = syswrite $cl, $data;
                  unless ($len) {
                     return if $! == Errno::EAGAIN;
                     if (not defined $len) {
                        warn "error when writing data on $self->{host}:$self->{port}: $!";
                        return;
                     } else {
                        delete $self->{w};
                     }
                  }

                  if ($len == length $self->{write_buffer}) {
                     delete $self->{w};
                  }

                  $self->debug_wrote_data (substr $self->{write_buffer}, 0, $len);
                  $self->{write_buffer} = substr $self->{write_buffer}, $len;
               }
            } else {
               $self->try_ssl_write;
            }
         });
   }
}

sub make_ssl_read_watcher {
   my ($self, $poll) = @_;
   return if $self->{r};

   $poll ||= 'r';
   $self->{r} =
      AnyEvent->io (poll => $poll, fh => $self->{socket}, cb => sub {
         $self->try_ssl_read;
      });
}

sub make_ssl_write_watcher {
   my ($self, $poll) = @_;
   return if $self->{w};

   $poll ||= 'w';
   $self->{w} =
      AnyEvent->io (poll => $poll, fh => $self->{socket}, cb => sub {
         $self->try_ssl_write;
      });
}

sub enable_ssl {
   my ($self) = @_;

   $Net::SSLeay::ssl_version = 10; # Insist on TLSv1

   $self->{ssl_enabled} = 1;

   #d# warn "START TLS!\n";

   $self->{r} = undef;
   $self->{w} = undef;

   $self->{ctx} = Net::SSLeay::CTX_new ();

   # enable SSL_MODE_ENABLE_PARTIAL_WRITE and SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER
   Net::SSLeay::CTX_set_mode($self->{ctx}, 1 | 2);

   $self->{ssl} = Net::SSLeay::new ($self->{ctx});

   Net::SSLeay::set_fd ($self->{ssl}, fileno $self->{socket});
   #d# warn "CONNECT\n";
   Net::SSLeay::connect $self->{ssl};
   #d# warn "CONNECT END\n";
   binmode $self->{socket}, ":bytes";

   $self->{ssl_read_data} = "";
   $self->make_ssl_read_watcher;
}

sub disconnect {
   my ($self, $msg) = @_;
   $self->end_sockets;
   $self->{disconnect_cb}->($self->{host}, $self->{port}, $msg);
}

1;
