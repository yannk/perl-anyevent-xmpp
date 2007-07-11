package DevCL::Main;
use strict;
use Gtk2;
use Net::XMPP2::Util qw/dump_twig_xml/;
use POSIX qw/strftime/;
use DevCL::Browser;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class
}

sub start {
   my ($self) = @_;

   my $w = Gtk2::Window->new ('toplevel');
   $w->add (my $vb = Gtk2::VBox->new);
   $w->set_default_size (500, 600);

   $vb->pack_start (my $menu = Gtk2::MenuBar->new, 0, 1, 0);
      $self->_populate_menu ($menu);
   $vb->pack_start (my $vp = Gtk2::VPaned->new, 1, 1, 0);
      $vp->add1 (my $sw = $self->{log_send_sb} = Gtk2::ScrolledWindow->new);
         $sw->set_policy ('automatic', 'automatic');
         $sw->add (my $log = $self->{log_send} = Gtk2::TextView->new);
            $log->set_wrap_mode ('word');
      $vp->add2 (my $sw2 = $self->{log_recv_sb} = Gtk2::ScrolledWindow->new);
         $sw2->set_policy ('automatic', 'automatic');
         $sw2->add (my $log2 = $self->{log_recv} = Gtk2::TextView->new);
            $log2->set_wrap_mode ('word');
   $vb->pack_start (my $sb = $self->{sb} = Gtk2::Statusbar->new, 0, 1, 0);

   _prep_text_view ($log);
   _prep_text_view ($log2);

   $w->signal_connect (destroy => sub { ::end () });

   $self->attach;
   $w->show_all;
}

sub _populate_menu {
   my ($self, $menu) = @_;
   $menu->append (my $browser = Gtk2::MenuItem->new ('Browser'));
      $browser->signal_connect (activate => sub {
         $self->start_browser;
      });
}

sub _ts {
   strftime ("%T %F %z", localtime (time))
}
sub _append_text_view {
   my ($tv, $txt) = @_;
   my $buf = $tv->get_buffer;
   $buf->insert ($buf->get_end_iter, $txt);
}

sub _prep_text_view {
   my ($tv) = @_;
   my $b = $tv->get_buffer ();
   my $em = $b->create_mark ('end', $b->get_end_iter, 0);
   $b->signal_connect (insert_text => sub {
      $tv->scroll_to_mark ($em, 0, 1, 0, 1);
   });
}

sub attach {
   my ($self) = @_;

   $::CLIENT->reg_cb (
      debug_recv => sub {
         my ($cl, $acc, $data) = @_;
         _append_text_view ($self->{log_recv}, _ts . " recv:\n");
         _append_text_view ($self->{log_recv}, dump_twig_xml ($data));
         1
      },
      debug_send => sub {
         my ($cl, $acc, $data) = @_;
         _append_text_view ($self->{log_send}, _ts . " send:\n");
         _append_text_view ($self->{log_send}, dump_twig_xml ($data));
         1
      },
   );
}

sub start_browser {
   my ($self) = @_;
   return if $self->{browser};

   $self->{browser} = DevCL::Browser->new (
      on_destroy => sub { delete $self->{browser} },
   );

   $self->{browser}->start;
}

1
