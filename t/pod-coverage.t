use strict;
use warnings;
use Test::More;

# Ensure a recent version of Test::Pod::Coverage
my $min_tpc = 1.08;
eval "use Test::Pod::Coverage $min_tpc";
plan skip_all => "Test::Pod::Coverage $min_tpc required for testing POD coverage"
    if $@;

# Test::Pod::Coverage doesn't require a minimum Pod::Coverage version,
# but older versions don't recognize some common documentation styles
my $min_pc = 0.18;
eval "use Pod::Coverage $min_pc";
plan skip_all => "Pod::Coverage $min_pc required for testing POD coverage"
    if $@;

my %SPEC = (
   'AnyEvent::XMPP::Ext::VCard'         => [qw/DESTROY _publish_avatar _retrieve _store decode_vcard encode_vcard init/],
   'AnyEvent::XMPP::Ext::Disco::Items'  => [qw/init new/],
   'AnyEvent::XMPP::Ext::Disco::Info'   => [qw/init new/],
   'AnyEvent::XMPP::Ext::MUC::Message'  => [qw/from_node/],
   'AnyEvent::XMPP::Ext::MUC::Room'     => [qw/
      _join_jid_nick add_user_xml check_online we_left_room
      send_join message_class handle_message handle_presence
      init
   /],
   'AnyEvent::XMPP::Ext::MUC::RoomInfo' => [qw/init/],
   'AnyEvent::XMPP::Ext::MUC::User' => [qw/
      init is_in_nick_change message_class nick_change_old_nick update
   /],
   'AnyEvent::XMPP::Error::Message' => [qw/string/],
   'AnyEvent::XMPP::Error::IQAuth' => [qw/string iq_error/],
   'AnyEvent::XMPP::Error::Presence' => [qw/string/],
   'AnyEvent::XMPP::Error::Parser' => [qw/string init/],
   'AnyEvent::XMPP::Error::Stream' => [qw/string init/],
   'AnyEvent::XMPP::Error::Stanza' => [qw/string init/],
   'AnyEvent::XMPP::Error::Exception' => [qw/string init/],
   'AnyEvent::XMPP::Error::Register' => [qw/string init/],
   'AnyEvent::XMPP::Error::MUC' => [qw/string init/],
   'AnyEvent::XMPP::Error::IQ' => [qw/string init/],
   'AnyEvent::XMPP::Error::SASL' => [qw/string init/],
   'AnyEvent::XMPP::Ext::RegisterForm' => [qw/_get_legacy_form init_from_node init_new_form/],
   'AnyEvent::XMPP::Ext::Disco' => [qw/DESTROY handle_disco_query init write_feature write_identity/],
   'AnyEvent::XMPP::Ext::Registration' => [qw/_error_or_form_cb init/],
   'AnyEvent::XMPP::Ext::Skel' => [qw/DESTROY init/],
   'AnyEvent::XMPP::Ext::Pubsub' => [qw/init/],
   'AnyEvent::XMPP::Ext::Ping' => [qw/DESTROY _start_cust_timeout disable_timeout disco_feature
                              handle_ping init/],
   'AnyEvent::XMPP::Ext::OOB' => [qw/disco_feature init/],
   'AnyEvent::XMPP::Ext::MUC' => [qw/cleanup init install_room uninstall_room/],
   'AnyEvent::XMPP::Ext::DataForm' => [qw/init _field_to_simxml _extract_field/],
   'AnyEvent::XMPP::Ext::Version' => [qw/DESTROY _version_from_node handle_query init version_result/],
   'AnyEvent::XMPP::IM::Message' => [qw/from_node to_string/],
   'AnyEvent::XMPP::IM::Account' => [qw/new remove_connection spawn_connection/],
   'AnyEvent::XMPP::IM::Presence' => [qw/clone debug_dump message_class new update/],
   'AnyEvent::XMPP::IM::Connection' => [qw/handle_disconnect handle_iq_set handle_message
      handle_presence init_connection send_session_iq store_roster
   /],
   'AnyEvent::XMPP::IM::Roster' => [qw/new remove_contact set_retrieved
                              touch_jid update update_presence/],
   'AnyEvent::XMPP::IM::Contact' => [qw/debug_dump message_class new remove_presence touch_presence /],
   'AnyEvent::XMPP::Node' => [qw/_to_sax_events/],
   'AnyEvent::XMPP::Error' => [qw/init new/],
   'AnyEvent::XMPP::Connection' => [qw/_start_whitespace_ping _stop_whitespace_ping
      debug_wrote_data do_iq_auth do_iq_auth_send handle_data handle_error
      handle_iq handle_sasl_challenge handle_sasl_success handle_stanza
      handle_stream_features init send_sasl_auth start_old_style_authentication
      write_data connected
   /],
   'AnyEvent::XMPP::Parser' => [qw/cb_char_data cb_end_tag cb_start_tag cb_default/],
   'AnyEvent::XMPP::Component' => [qw/authenticate/],
   'AnyEvent::XMPP::Writer' => [qw/_fetch_cb_additions _generate_key_xml
                           _generate_key_xmls _trans_create_cb/],
   'AnyEvent::XMPP::SimpleConnection' => [qw/ connect disconnect enable_ssl end_sockets
      make_ssl_read_watcher make_ssl_write_watcher new set_block set_noblock try_ssl_read
      try_ssl_write write_data drain send_buffer_empty
   /],
   'AnyEvent::XMPP::Client' => [qw/add_extension/],
   'AnyEvent::XMPP::TestClient' => [qr/./],
   'AnyEvent::XMPP::Util' => [qw/dump_twig_xml install_default_debug_dump/],
);

my $cnt = scalar all_modules ();
plan tests => $cnt;

for my $mod (all_modules ()) {
   pod_coverage_ok ($mod, { private => $SPEC{$mod} || [] });
}
