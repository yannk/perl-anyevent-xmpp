use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Net::XMPP2',
    AUTHOR              => 'Robin Redeker <elmex@ta-sa.org>',
    LICENSE             => 'perl',
    VERSION_FROM        => 'lib/Net/XMPP2.pm',
    ABSTRACT_FROM       => 'lib/Net/XMPP2.pm',
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
       PREOP => 'pod2text lib/Net/XMPP2.pm | tee README >$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;',
    },
    clean               => { FILES => 'Net-XMPP2-*' },
);
