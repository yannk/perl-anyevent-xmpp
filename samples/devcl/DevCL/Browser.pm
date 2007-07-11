package DevCL::Browser;
use strict;
use Gtk2;
use POSIX qw/strftime/;
use Gtk2::SimpleList;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class
}

sub start {
   my ($self) = @_;

   my $w = Gtk2::Window->new ('toplevel');
   $w->set_default_size (300, 400);
   $w->signal_connect (destroy => $self->{on_destroy});

   $w->add (my $hb = Gtk2::HPaned->new);
   $hb->add1 (my $lsw = Gtk2::ScrolledWindow->new);
      $lsw->add (my $ll = $self->{log} = Gtk2::SimpleList->new (ID => 'int', request => 'text'));
      $lsw->set_policy (automatic => 'automatic');
      $ll->signal_connect (row_activated => sub {
         my ($ll, $path, $column) = @_;
         my $row_ref = $ll->get_row_data_from_path ($path);
         $self->select_page ($row_ref->[0]);
      });
   $hb->add2 (my $vb = Gtk2::VBox->new);
      $vb->pack_start (my $e = Gtk2::Entry->new, 0, 1, 0);
         $e->signal_connect (activate => sub {
            $self->do_browse ($e->get_text);
         });
      $vb->pack_start ($self->{view_title} = Gtk2::Label->new, 0, 1, 0);
      $vb->pack_start (my $sw = $self->{view} = Gtk2::ScrolledWindow->new, 1, 1, 0);
         $sw->set_policy ('automatic', 'automatic');
         $sw->add ($self->{viewp} = Gtk2::Viewport->new);
   $w->show_all;
}

sub do_browse {
   my ($self, $txt, $node) = @_;
   $::DISCO->request_items (::get_con (), $txt, $node, sub {
      my ($disco, $i, $e) = @_;
      if ($e) {
         $self->add_page (
            "items <error> [$txt]" . ($node ? " ($node)" : ""),
            Gtk2::Label->new ($e->string)
         );
      } else {
         my $sl = Gtk2::SimpleList->new ('JID' => 'text', 'Name' => 'text', Node => 'text');
         @{$sl->{data}} =
            map {
               [ $_->{jid}, $_->{name}, $_->{node} ]
            } $i->items;

         $sl->signal_connect (row_activated => sub {
            my ($sl, $path, $column) = @_;
            my $row_ref = $sl->get_row_data_from_path ($path);
            $self->do_browse ($row_ref->[0], $row_ref->[2] ne '' ? $row_ref->[2] : undef);
         });
         my $id = $self->add_page ("items [".$i->jid."]" . ($i->node ? " (".$i->node.")" : ""), $sl);
         $self->select_page ($id);
      }
   });
   $::DISCO->request_info (::get_con (), $txt, undef, sub {
      my ($disco, $i, $e) = @_;
      if ($e) {
         $self->add_page (
            "info <error> [$txt]" . ($node ? " ($node)" : ""),
            Gtk2::Label->new ($e->string)
         );
      } else {
         my $vb = Gtk2::VBox->new;
         $vb->pack_start (
            my $sl1 = Gtk2::SimpleList->new (
               Category => 'text', Type => 'text', Name => 'text'
            ),
            0, 1, 0
         );
         @{$sl1->{data}} =
            map {
               [ $_->{category}, $_->{type}, $_->{name} ]
            } sort { $a->{category} cmp $b->{category} } $i->identities;
         $vb->pack_start (
            my $sl2 = Gtk2::SimpleList->new (Feature => 'text'),
            0, 1, 0
         );
         @{$sl2->{data}} = sort keys %{$i->features || {}};
         $self->add_page ("info [".$i->jid."]" . ($i->node ? " (".$i->node.")" : ""), $vb);
      }
   });
}

sub select_page {
   my ($self, $id) = @_;
   my $p = $self->{page}->{$id} or return;
   for ($self->{viewp}->get_children) {
      $_->hide_all;
      $self->{viewp}->remove ($_);
   }
   $self->{view_title}->set_text ($p->[0]);
   $self->{viewp}->add ($p->[1]);
   $p->[1]->show_all;
}

sub add_page {
   my ($self, $title, $chld) = @_;
   my $id = 1 * $self->{page_id}++;
   $self->{page}->{$id} = [$title, $chld];
   push @{$self->{log}->{data}}, [$id, $title];
   $id
}
1
