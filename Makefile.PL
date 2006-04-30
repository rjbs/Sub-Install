use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Sub::Install',
    AUTHOR              => 'Ricardo Signes <rjbs@cpan.org>',
    VERSION_FROM        => 'lib/Sub/Install.pm',
    ABSTRACT_FROM       => 'lib/Sub/Install.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Scalar::Util' => 0,
        'Test::More'   => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Sub-Install-* cover_db' },
);
