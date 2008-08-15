use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'AnyEvent::XMPP',
    AUTHOR              => 'Robin Redeker <elmex@ta-sa.org>',
    LICENSE             => 'perl',
    VERSION_FROM        => 'lib/AnyEvent/XMPP.pm',
    ABSTRACT_FROM       => 'lib/AnyEvent/XMPP.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'AnyEvent'           => 0,
        'Scalar::Util'       => 0,
        'XML::Writer'        => 0,
        'XML::Parser::Expat' => 0,
        'MIME::Base64'       => 0,
        'Net::LibIDN'        => 0,
        'Authen::SASL'       => 0,
        'Net::SSLeay'        => 0,
        'Net::DNS'           => 0,
        'Digest::SHA1'       => 0,
        'Object::Event'      => 0,
    },
    dist                => {
       COMPRESS => 'gzip -9f',
       SUFFIX => 'gz',
       PREOP => 'pod2text lib/AnyEvent/XMPP.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
    },
    clean               => { FILES => 'AnyEvent-XMPP-*' },
);
