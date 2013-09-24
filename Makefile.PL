use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'App::idGamesЅync',
    AUTHOR              => 'Brian Manning <brian at xaoc dot org>',
    VERSION_FROM        => 'bin/idgames_sync.pl',
    ABSTRACT            => 'Synchronize a copy of the C<idgames> archive.',
    #ABSTRACT_FROM       => 'bin/idgames_sync.pl',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    BUILD_REQUIRES => {
        'Test::More'            => 0,
    },
    PREREQ_PM => {
        'Date::Format'          => 0,
        'Digest::MD5'           => 0,
        'File::Copy'            => 0,
        'File::stat'            => 0,
        'File::Stat::Ls'        => 0,
        'File::Temp'            => 0,
        'Getopt::Long'          => 0,
        'IO::File'              => 0,
        'Log::Log4perl'         => 0,
        'LWP::UserAgent'        => 0,
        'Mouse'                 => 0,
        'Number::Format'        => 0,
        'Pod::Usage'            => 0,
        'Test::More'            => 0,
        'Time::HiRes'           => 0,
        'constant'              => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'App-idGamesЅync' },
);
