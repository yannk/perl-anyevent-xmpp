package DevCL::Browser;
use strict;
use Gtk2;
use POSIX qw/strftime/;
use Gtk2::SimpleList;
use DevCL::TreeView;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class
}

sub start {
   my ($self) = @_;

   $self->{t} = {};

   my $w = Gtk2::Window->new ('toplevel');
   $w->set_default_size (300, 400);
   $w->signal_connect (destroy => $self->{on_destroy});

   my $t = $self->{tree} = DevCL::TreeView->new;
   my $tv = $t->init ("JID/Node");

   $t->set_activate_cb (sub {
      my ($title, $id, $us) = @_;
      my ($jid, $node, $wid) = @$us;
      if ($wid) {
         $self->select_page ($wid);
      } else {
         $self->do_browse ($jid, $node);
      }
   });

   $w->add (my $hb = Gtk2::HPaned->new);
   $hb->add1 (my $lsw = Gtk2::ScrolledWindow->new);
      $lsw->add ($tv);
      $lsw->set_policy (automatic => 'automatic');
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
        $self->add_entry (
           $txt, $node, "item_error",
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
         $self->add_entry ($i->jid, $i->node, 'items', $sl);
         $self->select_page ($sl);
      }
   });
   $::DISCO->request_info (::get_con (), $txt, undef, sub {
      my ($disco, $i, $e) = @_;
      if ($e) {
        $self->add_entry (
           $txt, $node, "info_error",
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
         $self->add_entry ($i->jid, $i->node, 'info', $vb);
      }
   });
}

sub select_page {
   my ($self, $chld) = @_;
   for ($self->{viewp}->get_children) {
      $_->hide_all;
      $self->{viewp}->remove ($_);
   }
   $self->{view_title}->set_text ("...");
   $self->{viewp}->add ($chld);
   $chld->show_all;
}

sub add_entry {
   my ($self, $jid, $node, $type, $chld) = @_;

   my $usr = [$jid, $node];

   $node = "/$node";

   my $t = $self->{tree};
   my ($jid_id, $jid_sub)   = $t->walk_step ($self->{t}, undef, $jid,    $usr);
   my ($node_id, $node_sub) = $t->walk_step ($jid_sub, $jid_id, $node,   $usr);
   my ($type_id, $type_sub) = $t->walk_step ($node_sub, $node_id, $type, $usr);

   $t->add_rec_path ($type_id, time, [@$usr, $chld]);
}
1
