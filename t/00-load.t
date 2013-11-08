#!perl -T

use Test::More tests => 11;

BEGIN {
use_ok( q(App::idGamesSync::ArchiveDirectory) );
use_ok( q(App::idGamesSync::ArchiveFile) );
use_ok( q(App::idGamesSync::Config) );
use_ok( q(App::idGamesSync::LocalDirectory) );
use_ok( q(App::idGamesSync::LocalFile) );
use_ok( q(App::idGamesSync::LWPWrapper) );
use_ok( q(App::idGamesSync::Reporter) );
use_ok( q(App::idGamesSync::RuntimeStats) );
use_ok( q(App::idGamesSync::Role::DirAttribs) );
use_ok( q(App::idGamesSync::Role::FileDirAttribs) );
use_ok( q(App::idGamesSync::Role::LocalFileDir) );
}


diag( "Testing, Perl $], $^X" );
