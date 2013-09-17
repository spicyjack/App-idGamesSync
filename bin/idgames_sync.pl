#!/usr/bin/env perl

use strict;
use warnings;
our $copyright = q|Copyright (c) 2011,2013 by Brian Manning |
    . q|<brian at xaoc dot org>|;
# For support with this file, please file an issue on the GitHub issue
# tracker: https://github.com/spicyjack/App-idGamesSync/issues

=head1 NAME

idgames_sync.pl - Synchronize a copy of the C<idgames> archive.

=head1 VERSION

Version v0.0.5

=cut

use version; our $VERSION = qv('0.0.5');

# shortcut to get the name of the file this script lives in
use File::Basename;
our $our_name = basename $0;

=head1 SYNOPSIS

Create or update a copy of the C<idgames> archive on the local host.

=cut

our @options = (
    # help/verbosity options
    q(help|h),
    q(debug|D|d),
    q(debug-files=i), # how many lines to parse/compare from ls-laR.gz
    q(debug-noexit), # don't exit when debugging
    q(verbose|v),
    q(version),
    q(examples|x),
    q(morehelp|m),
    # script options
    q(dry-run|n), # don't sync, just show steps that would be performed
    q(exclude|e=s@), # URLs to exclude when pulling from mirrors
    q(format|f=s), # reporting format
    q(path|p=s), # output path
    q(type|t=s@), # what type of information to report
    q(url|u=s), # URL to use for mirroring
    # logging options
    q(colorize!), # always colorize logs, no matter if a pipe is present or not
    q(loglevel|log|level|ll=s),
    # misc options
    q(prune-all), # prune files from the mirror, not just /newstuff
    q(sync-all), # sync everything, not just WADs
    q(show-mirrors), # show the mirrors array and exit
    q(create-mirror), # create a new mirror if ls-laR.gz not found at --path
    q(incoming), # show files in the /incoming directory
    q(dotfiles), # don't show dotfiles in reports - .filename
    q(headers), # show directory headers and blocks used
    q(tempdir=s), # temporary directory to use for tempfiles
    q(skip-ls-lar|skip-lslar), # update the ls-laR.gz file, then exit
    q(update-ls-lar|update-lslar), # update the ls-laR.gz file, then exit
    # combination options
    q(size-local|local-size|sl), # show size mismatches, missing local files
    q(size-same|ss), # show size mismatches and missing local files
);

=head1 OPTIONS

 perl idgames_sync.pl [options]

 Script options:
 -h|--help          Displays script options and usage
 -v|--verbose       Sets logging level to INFO, more verbose output
 --version          Shows script version, then exits
 -n|--dry-run       Don't sync content, explain script actions instead

 -p|--path          Path to the local copy of the idgames archive
 -t|--type          Report type(s) to use for reporting (see --morehelp)
 -f|--format        Output format, [full|more|simple] (see --morehelp)
 -u|--url           Use a specific URL instead of a random mirror
 --create-mirror    Authorize script to create a new copy of the mirror
 --sync-all         Synchronize everything, not just WAD directories
 --skip-ls-lar      Don't fetch 'ls-laR.gz' (after using '--update-ls-lar')
 --update-ls-lar    Update the local 'ls-laR.gz' file, then exit

 Run with '--examples' switch to see examples of script usage

 Run with '--morehelp' for more script options, and descriptions of the
 '--format' and '--type' options

=head1 DESCRIPTION

Using a current C<ls-lR.gz> listing file synchronized from an C<idgames> archive
mirror site, synchronizes an existing copy of the C<idgames> mirror on the
local host, or creates a new copy of the mirror on the local host if a copy of
the mirror does not already exist.

Script normally exits with a 0 status code, or a non-zero status code if any
errors were encountered.

=head1 OBJECTS

=head2 idGames::Sync::Config

Configure/manage script options using L<Getopt::Long>.

=head3 Methods

=over

=cut

package idGames::Sync::Config;

use strict;
use warnings;
use English qw( -no_match_vars );
use Pod::Usage; # prints POD docs when --help is called

sub new {
    my $class = shift;

    my $self = bless ({}, $class);

    # script arguments
    my %args;

    # parse the command line arguments (if any)
    my $parser = Getopt::Long::Parser->new();

    # pass in a reference to the args hash as the first argument
    $parser->getoptions( \%args, @options );

    # assign the args hash to this object so it can be reused later on
    $self->{_args} = \%args;

    # dump and bail if we get called with --help
    if ( $self->get(q(help)) ) { pod2usage(-exitstatus => 0); }

    # dump and bail if we get called with --help
    if ( $self->get(q(version)) ) {
        print __FILE__
            . qq(: synchronize files from 'idgames' mirrors to local host\n);
        print qq(version: $VERSION\n);
        print qq(copyright: $copyright\n);
        print qq|license: Same terms as Perl (Perl Artistic/GPLv1 or later)\n|;
        exit 0;
    }

    # set a flag if we're running on 'MSWin32'
    # this needs to be set before possibly showing examples because examples
    # will show differently on Windows than it does on *NIX (different paths
    # and prefixes)
    if ( $OSNAME eq q(MSWin32) ) {
        $self->set(q(is_mswin32), 1);
    }

    # dump and bail if we get called with --examples
    if ( $self->get(q(examples)) ) {
        $self->show_examples();
        exit 0;
    }

    # dump and bail if we get called with --morehelp
    if ( $self->get(q(morehelp)) ) {
        $self->show_morehelp();
        exit 0;
    }


    # return this object to the caller
    return $self;
}

=item show_examples

Show examples of script usage.

=cut

sub show_examples {
    my $self = shift;


    ### WINDOWS EXAMPLES ###
    if ( $self->defined(q(is_mswin32)) ) {

        print <<"WIN_EXAMPLES";

 =-=-= $our_name - $VERSION - USAGE EXAMPLES =-=-=

 Create a mirror:
 ----------------
 $our_name --path C:\\path\\to\\idgames\\dir --create-mirror

 # Use the 'simple' output format
 $our_name --path C:\\path\\to\\idgames\\dir --create-mirror \\
   --format=simple

 # Use the 'simple' output format, synchronize everything
 $our_name --path C:\\path\\to\\idgames\\dir --create-mirror \\
   --format=simple --sync-all

 Synchronize existing mirror:
 ----------------------------
 $our_name --path C:\\path\\to\\idgames\\dir

 # Use 'simple' output format; default format is 'more'
 $our_name --path C:\\path\\to\\idgames\\dir --format simple

 # Use 'simple' output format, synchronize everything
 $our_name --path C:\\path\\to\\idgames\\dir --format simple --sync-all

 "Dry-Run", or test what would be downloaded/synchronized
 --------------------------------------------------------
 # Update the 'ls-laR.gz' archive listing
 $our_name --path C:\\path\\to\\idgames\\dir --update-lslar

 # Then use '--dry-run' to see what will be updated; use 'simple' output
 # format
 $our_name --path C:\\path\\to\\idgames\\dir --format simple --dry-run

 # Same thing, but synchronize everything instead of just WADs
 $our_name --path C:\\path\\to\\idgames\\dir --format simple \\
   --dry-run --sync-all

 More Complex Usage Examples:
 ----------------------------
 # specific mirror, 'simple' output format, show all files being mirrored
 $our_name --path C:\\path\\to\\idgames\\dir \\
    --url http://example.com --format simple --type all

 # use random mirrors, exclude a specific mirror, 'simple' output format
 $our_name --path C:\\path\\to\\idgames\\dir --format simple \\
    --exclude http://some-mirror-server.example.com

 # use random mirrors, exclude a specific mirror,
 # specify temporary directory, 'full' output format
 $our_name --path C:\\path\\to\\idgames\\dir \\
    --exclude http://some-mirror-server.example.com \\
    --format full --tempdir C:\\path\\to\\temp\\dir

 # 'simple' output format, try to synchronize the '/incoming' directory
 # NOTE: this will cause download failures, please see '--morehelp' for a
 # longer explanation
 $our_name --path C:\\path\\to\\idgames\\dir --incoming

 # Show the list of mirror servers embedded into this script, then exit
 $our_name --show-mirrors

WIN_EXAMPLES

    } else {
        print <<"NIX_EXAMPLES";

 =-=-= $our_name - $VERSION - USAGE EXAMPLES =-=-=

 Create a mirror:
 ----------------
 $our_name --path /path/to/your/idgames/dir --create-mirror

 # Use the 'simple' output format
 $our_name --path /path/to/your/idgames/dir --create-mirror \\
   --format=simple

 # Use the 'simple' output format, synchronize everything
 $our_name --path /path/to/your/idgames/dir --create-mirror \\
   --format=simple --sync-all

 Synchronize existing mirror:
 ----------------------------
 $our_name --path /path/to/your/idgames/dir

 # Use 'simple' output format; default format is 'more'
 $our_name --path /path/to/your/idgames/dir --format simple

 # Use 'simple' output format, synchronize everything
 $our_name --path /path/to/your/idgames/dir --format simple --sync-all

 "Dry-Run", or test what would be downloaded/synchronized
 --------------------------------------------------------
 # Update the 'ls-laR.gz' archive listing
 $our_name --path /path/to/your/idgames/dir --update-lslar

 # Then use '--dry-run' to see what will be updated;
 # use 'simple' output format
 $our_name --path /path/to/your/idgames/dir --format simple --dry-run

 # Same thing, but synchronize everything instead of just WADs
 $our_name --path /path/to/your/idgames/dir --format simple \\
   --dry-run --sync-all

 More Complex Usage Examples:
 ----------------------------
 # specific mirror, 'simple' output format, show all files being mirrored
 $our_name --path /path/to/your/idgames/dir \\
    --url http://example.com --format simple --size-same

 # use random mirrors, exclude a specific mirror, 'simple' output format
 $our_name --path /path/to/your/idgames/dir \\
    --exclude http://some-mirror-server.example.com --format simple

 # use random mirrors, exclude a specific mirror,
 # specify temporary directory, 'full' output format
 $our_name --path /path/to/your/idgames/dir \\
    --exclude http://some-mirror-server.example.com \\
    --format full --tempdir /path/to/temp/dir

 # 'simple' output format, try to synchronize the '/incoming' directory
 # NOTE: this will cause download failures, please see '--morehelp' for a
 # longer explanation
 $our_name --path /path/to/your/idgames/dir --incoming

 # Show the list of mirror servers embedded into this script, then exit
 $our_name --show-mirrors

NIX_EXAMPLES

    }
}

=item show_morehelp

Show more help information on how to use the script and how the script
functions.

=cut

sub show_morehelp {

print <<MOREHELP;

 =-=-= $our_name - $VERSION - More Help Screen =-=-=

 Misc. script options:
 ---------------------
 -x|--examples      Show examples of script execution
 -m|--morehelp      Show extended help info (format/type specifiers)
 -e|--exclude       Don't use these mirror URL(s) for syncing
 --dotfiles         Show "hidden" files, Example: .message/.listing
 --headers          Show directory headers and blocks used in output
 --incoming         Show files located in the /incoming directory
 --show-mirrors     Show the current set of mirrors then exit
 --size-local       Combination of '--type size --type local' (default)
 --size-same        Combination of '--type size --type same'
 --tempdir          Temporary directory to use when downloading files

 Script debugging options:
 -------------------------
 -d|--debug         Sets logging level to DEBUG, tons of output
 --debug-noexit     Don't exit if --debug is set (ignores --debug-files)
 --debug-files      Sync this many files before exiting (default: 50)
                    Requires '--debug'
 --colorize         Always colorize log output (when piping log output)

 Notes about script behaivor:
 ----------------------------
 By default, the script will query a random mirror for each file that needs to
 be synchronized unless the --url switch is used to specify a specific mirror.

 Files located in the /incoming directory will not be synchronized by default
 unless --incoming is used.  Most FTP sites won't let you download/retrieve
 files from /incoming due to file/directory permissions on the FTP server;
 it's basically useless to try to download files from that directory, it will
 only generate errors.

 Report Types (for use with the --type switch):
 ----------------------------------------------
 Use these report types with the '--type' flag; note '--type' can be specified
 multiple times.
 - headers  - Print directory headers and directory block sizes
 - local    - Files in the archive that are missing on local disk
 - archive  - Files on the local disk not listed in the archive
 - size     - Size differences between the local file and archive file
 - same     - Same size file exists on disk and in the archive

 The default report type is "size + local" (same as '--size-local' below).

 Combined report types:
 ----------------------
 Use these combined report types instead of specifying '--type' multiple
 times.
 --size-local   (size + local) Show file size mismatches, and files missing on
                local system; this is the default report type
 --size-same    (size + same) Show all files listed in the archive, both with
                valid local files and with size mismatched local files

 Output formats (for use with the --format switch):
 --------------------------------------------------
 - full     One line per file/directory attribute
 - more     Shows filename, date/time, size on one line, file attributes on
            the next line
 - simple   One file per line, with status flags to the left of the filename
            Status flags:
            - FF = This object is a file
            - DD = This object is a directory
            - FS = This object is a file, file size mismatch
            - !! = File/directory is missing file on local system

 The default output format is "more".

MOREHELP
}

=item get($key)

Returns the scalar value of the key passed in as C<key>, or C<undef> if the
key does not exist in the L<JenkBuilder::Config> object.

=cut

sub get {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) { return $args{$key}; }
    return undef;
}

=item set( key => $value )

Sets in the L<JenkBuilder::Config> object the key/value pair passed in
as arguments.  Returns the old value if the key already existed in the
L<JenkBuilder::Config> object, or C<undef> otherwise.

=cut

sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) {
        my $oldvalue   = $args{$key};
        $args{$key}    = $value;
        $self->{_args} = \%args;
        return $oldvalue;
    } else {
        $args{$key}    = $value;
        $self->{_args} = \%args;
    } # if ( exists $args{$key} )
    return undef;
}

=item get_args( )

Returns a hash containing the parsed script arguments.

=cut

sub get_args {
    my $self = shift;
    # hash-ify the return arguments
    return %{$self->{_args}};
}

=item defined($key)

Returns "true" (C<1>) if the value for the key passed in as C<key> is
C<defined>, and "false" (C<0>) if the value is undefined, or the key doesn't
exist.

=cut

sub defined {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    # Can't use Log4perl here, since it hasn't been set up yet
    if ( exists $args{$key} ) {
        #warn qq(exists: $key\n);
        if ( defined $args{$key} ) {
            #warn qq(defined: $key; ) . $args{$key} . qq(\n);
            return 1;
        }
    }
    return 0;
}

=back

=head2 Role::Dir::Attribs

A role that contains attributes for a local or remote directory.
Currently, this is only the total blocks used by this directory.

=cut

##############################
# package Role::Dir::Attribs #
##############################
package Role::Dir::Attribs;

use Mouse::Role;

=head3 Attributes

=over

=item total_blocks

The total blocks used by this directory and the contents of this directory on
disk or in the archive file.

=back

=cut

has total_blocks    => (
    is      => q(rw),
    isa     => q(Int),
);

=head2 Role::FileDir::Attribs

A role that contains attributes for a local or remote file or directory.
Things like filename, full path, owner/group, permissions, size, etc.

=cut

##################################
# package Role::FileDir::Attribs #
##################################
package Role::FileDir::Attribs;

use Mouse::Role;

=head3 Attributes

=over

=item perms

Permissions of the file/directory.

=cut

has perms       => (
    is      => q(rw),
    isa     => q(Str),
    default => q(----------),
);

=item hardlinks

Number of hard links back to this file/directory.

=cut

has hardlinks   => (
    is      => q(rw),
    isa     => q(Int),
    default => 0,
);

=item owner

Name of the owner of the file/directory.

=cut

has owner       => (
    is      => q(rw),
    isa     => q(Str),
    default => q(!!!),
);

=item group

Name of the group of the file/directory.

=cut

has group       => (
    is      => q(rw),
    isa     => q(Str),
    default => q(!!!),
);


=item size

Size of the file/directory.

=cut

has size        => (
    is      => q(rw),
    isa     => q(Int),
    default => 0,
);


=item mod_time

Modification date of the file/directory.

=cut

has mod_time    => (
    is      => q(rw),
    isa     => q(Str),
    default => q(!!!),
);

=item name

Name of the file/directory.

=cut

has name        => (
    is      => q(rw),
    isa     => q(Str),
);

=item parent_path

The parent_path directory of this file/directory.

=back

=cut

has parent_path      => (
    is      => q(rw),
    isa     => q(Str),
);

=item dotfiles

A regular expression reference of filenames that match "dotfiles" or files
that are meant to be hidden on *NIX platforms.  These files are usually used
to store text messages that are displayed in FTP/HTTP directory listings.

=back

=cut

has dotfiles      => (
    is      => q(ro),
    isa     => q(RegexpRef),
    default => sub {qr/\.message|\.DS_Store|\.mirror_log|\.listing/;}
);

=item is_dotfile

Tests to see if the current file/directory is a "dotfile", or a file that is
usually hidden on *NIX systems.  You usually don't care about these files,
unless you are building an exact replica of the mirror server.  Returns C<0>
false if the current object is not a dotfile, or C<1> true if the current
object I<is> a dotfile.

=cut

sub is_dotfile {
    my $self = shift;
    my $dotfiles_regex = $self->dotfiles;

    #my $log = Log::Log4perl->get_logger();
    #$log->debug(qq(Checking: ) . $self->name);
    #$log->debug(qq(With regex: $dotfiles_regex));

    if ( $self->name =~ /$dotfiles_regex/ ) {
        #$log->debug($self->name . qq( is a dotfile));
        return 1;
    } else {
        #$log->debug($self->name . qq( is *NOT* a dotfile));
        return 0;
    }
}

=item metafiles

A regular expression that describes a set of files ("metadata files") that
should usually be downloaded from the master mirror, unless C<--url>
is used, in which case, these files will be downloaded from the mirror server
specified with C<--url>.

=back

=cut

has metafiles     => (
    is      => q(ro),
    isa     => q(RegexpRef),
    default => sub {
        qr/ls-laR\.gz|LAST\.\d+\w+|fullsort\.gz|REJECTS|README\.*/;},
);

=item is_metafile

Tests to see if the current file/directory is a "metafile", or a
meta-information file.  Returns C<0> false if the current object is not a
dotfile, or C<1> true if the current object I<is> a dotfile.

=cut

sub is_metafile {
    my $self = shift;
    my $metafiles_regex = $self->metafiles;

    #my $log = Log::Log4perl->get_logger();
    #$log->debug(qq(Checking: ) . $self->name);
    #$log->debug(qq(With regex: $metafiles_regex));

    if ( $self->name =~ /$metafiles_regex/ ) {
        #$log->debug($self->name . qq( is a metafile));
        return 1;
    } else {
        #$log->debug($self->name . qq( is *NOT* a metafile));
        return 0;
    }
}

=item wad_dirs

A regular expression that describes directories where C<WAD> files are stored
inside of the C<idgames> Mirror.

=back

=cut

has wad_dirs      => (
    is      => q(ro),
    isa     => q(RegexpRef),
    default => sub {
        # regex that covers all "non-WAD" directories
        #my $levels = q(/docs|/graphics|/history|/idstuff|/lmps|/misc|/music);
        #$levels .= q(|/prefabs|/roguestuff|/skins|/sounds|/source);
        #$levels .= q(|/themes|/utils);
        # regex that covers all levels directories
        my $levels = q(^combos|^deathmatch);
        $levels .= q(|^levels/[doom|doom2|hacx|heretic|hexen|strife]);
        # going to implement this as an attribute/boolean flag; this will let
        # it be reused later on when capturing the contents of the /newstuff
        # directory, in order to get a list of files to delete
        #$levels .= q(|^newstuff);
        return qr/$levels/;
    },
);

=item is_wad_dir

Tests to see if the current directory is in a "WAD directory", or a directory
known to have C<WAD> files inside of it.  Returns C<0> false if the directory
is not a C<WAD> directory, or C<1> true if the directory does have C<WAD>
files inside of it.

=cut

sub is_wad_dir {
    my $self = shift;
    my $wad_dirs_regex = $self->wad_dirs;

    #my $log = Log::Log4perl->get_logger();
    #$log->debug(qq(Checking: ) . $self->short_path);
    #$log->debug(qq(With regex: $wad_dirs_regex));

    if ( $self->short_path =~ /$wad_dirs_regex/ ) {
        #$log->debug($self->short_path . qq( is a WAD dir));
        return 1;
    } else {
        #$log->debug($self->short_path . qq( is *NOT* a WAD dir));
        return 0;
    }
}

=head2 Role::LocalFileDir

Methods and attributes used for interacting with a file or directory on the
local filesystem.

=cut

##############################
# package Role::LocalFileDir #
##############################
package Role::LocalFileDir;

use Mouse::Role;
use Date::Format;
use File::Copy;
use File::stat; # OO wrapper around stat()
use File::Stat::Ls; # conversion tools for the file/dir modes

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

use constant {
    IS_DIR      => q(D),
    IS_FILE     => q(F),
    IS_UNKNOWN  => q(?),
    IS_MISSING  => q(!),
    DIFF_SIZE   => q(S),
};


=head3 Attributes

=over

=item opts_path

The path to the local C</idgames> archive passed in by the user.

=cut

has opts_path => (
    is      => q(rw),
    isa     => q(Str),
);

=item archive_obj

The Archive object that this object is based off of.

=cut

has archive_obj => (
    is      => q(rw),
    isa     => q(Object),
);

=item absolute_path

The absolute path to this file or directory, from the drive/filesystem root.

=cut

has absolute_path => (
    is      => q(rw),
    isa     => q(Str),
);

=item is_mswin32

Boolean flag that is set when running under Windows platforms.

=cut

has is_mswin32 => (
    is      => q(rw),
    isa     => q(Bool),
);

=item is_newstuff

Boolean flag that is set when the current file is located in the C</newstuff>
directory.

=cut

has is_newstuff => (
    is      => q(rw),
    isa     => q(Bool),
    default => q(0),
);

=item short_path

The short path to the file, made up of the filename, and any parent
directories above the file's directory.  Note that the path separatator will
change depending on what platform this script is run on (C</> for *NIX, C<\>
for Windows).

=cut

has short_path => (
    is      => q(rw),
    isa     => q(Str),
);

=item short_type

A single character that denotes what this object is; a file, a directory,
missing from the filesystem, or 'unknown'.

=cut

has short_type => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
);

=item short_status

A single character that shows the file's status on the local system, whether
the file is present or not, or if the size of the file on the local system
does not match the size of the file in the archive.

=cut

has short_status => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
);

=item long_status

A short summary of the file's status, used in more verbose reports.

=cut

has long_status => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
);

=item url_path

The path that can be used to build a valid URL to the resource on any
C<idgames> mirror server.  This path always has forward slashes, as opposed to
C<short_path>, which has slashes based on what platform the script is
currently running on.

=cut

has url_path => (
    is      => q(rw),
    isa     => q(Str),
);

=item needs_sync

A flag that is set when this file or directory needs to be synchronized.

=cut

has needs_sync => (
    is      => q(rw),
    isa     => q(Bool),
    default => q(0),
);

=item notes

A string that contains extra information about the file/directory.

=back

=cut

has notes => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
);

=head3 Methods

=over

=item new() (BUILD)

Creates an object that has consumed the L<Role::LocalFileDir> role.  This
object would be used to keep track of attributes of a local file or directory.
Sets up different "shortcuts", or file/directory attributes that would be
commonly used when interacting with this object (aboslute path, parent path,
short name, etc.)

Required arguments:

=over

=item opts_path

The path on the local filesystem to the C<idgames> archive directory.

=item archive_obj

The C<archive> object, which is used to map paths in the archive to local
system paths.

=item is_mswin32

Boolean flag that should be set when running this script on top of a Microsoft
Windows platform.  This changes how a file's userid is determined.

=back

=cut

sub BUILD {
    my $self = shift;
    my $log = Log::Log4perl->get_logger();

    $log->logdie(qq(missing 'opts_path' argument))
        unless ( defined $self->opts_path );
    $log->logdie(qq(missing 'archive_obj' argument))
        unless ( defined $self->archive_obj );

    # the archive file object
    my $archive = $self->archive_obj;

    # set up parent dir and short path
    $self->name($archive->name);
    my $parent_dir = $archive->parent_path;
    # trim leading slash, it will be added back later
    $parent_dir =~ s/^\///;
    $self->parent_path($parent_dir);
    if ( $self->parent_path =~ /^newstuff/ ) {
        # set the newstuff flag
        $self->is_newstuff(1);
    }
    #$log->debug(qq(Parent path is: ) . $self->parent_path);
    if ( length($self->parent_path) > 0 ) {
        $self->url_path($self->parent_path . q(/) . $self->name);
        if ( $self->is_mswin32 ) {
            $self->short_path($self->parent_path . q(\\) . $self->name);
        } else {
            $self->short_path($self->url_path);
        }
    } else {
        $self->short_path($self->name);
        $self->url_path($self->name);
    }
    #$log->debug(qq(Short path is: ) . $self->short_path);

    $self->absolute_path($self->opts_path . $self->short_path);
    $log->debug(qq(Absolute path is: ) . $self->absolute_path);
}

=item stat_local()

Runs C<stat()> on the file/directory to see if it exists on the filesystem.
Sets some extra attributes (below) based on whether or not the file exists.

=cut

sub stat_local {
    my $self = shift;
    my $log = Log::Log4perl->get_logger();

    $log->debug(q(stat'ing file/dir: ) . $self->absolute_path);
    my $stat = stat( $self->absolute_path );
    my $archive = $self->archive_obj;

    unless ( defined $stat ) {
        # file doesn't exist
        $log->debug($archive->name . q( is not on the local system));
        $self->short_type(IS_MISSING);
        $self->short_status(IS_MISSING);
        $self->long_status(q(Missing locally));
        $self->append_notes(qq(Missing on local system));
        $self->needs_sync(1);
    } else {
        my $lsperms = File::Stat::Ls->new();
        $self->perms($lsperms->format_mode($stat->mode) );
        $self->hardlinks($stat->nlink);
        my ($file_owner, $file_group);
        if ( $self->is_mswin32 ) {
            # Microsoft Windows; use Win32 modules
            $file_owner = Win32::LoginName() || q(unknown);
            $file_group = $file_owner;
        } else {
            # *NIX platforms
            $file_owner = getpwuid($stat->uid) || q(unknown);
            $file_group = getgrgid($stat->gid) || q(unknown);
        }
        $self->owner( $file_owner );
        $self->group( $file_group );
        $self->size($stat->size);
        my $mtime = time2str(q(%b %e %Y), $stat->mtime);
        # get rid of extra spaces in the output of time2str
        $mtime =~ s/\s{2,}/ /;
        $self->mod_time($mtime);

        # this only works in File::stat in Perl 5.12.1 or newer
        #if ( -f $stat ) {
        # file does exist; what kind of file is it?
        if ( -f $self->absolute_path ) {
            $self->short_type(IS_FILE);
            $self->short_status(IS_FILE);
            $log->debug($archive->name . q( is a file));
            # check the size listed in the tarball versus the file size
            if ( $stat->size != $archive->size ) {
                $self->short_status(DIFF_SIZE);
                $self->long_status(q(Size mismatch));
                # for full dumps
                $self->append_notes(qq(Size mismatch; )
                    . q(archive size: ) . $archive->size . q( )
                    . q(local size: ) . $self->size . qq(\n));
                $self->needs_sync(1);
            }
        # this only works in 5.12.1 or newer
        #} elsif ( -d $stat ) {
        } elsif ( -d $self->absolute_path ) {
            $self->short_type(IS_DIR);
            $self->short_status(IS_DIR);
            $log->debug($self->name . q( is a directory));
            $self->long_status(q(Directory));
        } else {
            $self->short_type(IS_UNKNOWN);
            $self->short_status(IS_UNKNOWN);
            $log->debug($self->name . q( is an unknown file!));
        }
    }
}

=item sync

Syncs a remote file or directory to the local system.  Local directories are
created, local files are synchronized from the remote system.  Returns C<1> if
the file was synchronized (downloaded to the local system as a tempfile and
renamed with the same name and location in the archive as the copy on the
mirror), or in the case of directories, the directory was created successfully,
returns a C<0> otherwise.

=cut

sub sync {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();
    $log->logdie(qq(missing 'lwp' argument))
        unless ( defined $args{lwp} );

    my $lwp = $args{lwp};
    $log->debug(q(Syncing file/dir ') . $self->name . q('));
    if ( ref($self) eq q(Local::File) ) {
        # check to see if this is one of the metadata files, or a file in the
        # /newstuff directory; if so, sync it from the master mirror, as the
        # other mirrors may not have the file sync'ed yet
        my $temp_file;
        if ( $self->is_metafile || $self->is_newstuff ) {
            $log->debug(q(Syncing [meta|newstuff] file from master mirror));
            $temp_file = $lwp->fetch(
                base_url => $lwp->master_mirror,
                filepath => $self->url_path
            );
        } else {
            # use a random mirror
            $temp_file = $lwp->fetch( filepath => $self->url_path );
        }
        if ( defined $temp_file ) {
            print qq(- Writing file: ) . $self->absolute_path . qq(\n);
            $log->debug(qq(Moving $temp_file...));
            $log->debug(q(to ) . $self->absolute_path);
            $log->logdie(qq(Could not write file! $!))
                unless (move($temp_file, $self->absolute_path ));
        }
        return 1;
    } elsif ( ref($self) eq q(Local::Directory) ) {
        if ( -e $self->absolute_path ) {
            $log->debug(qq(Directory ) . $self->absolute_path
                . qq( already exists));
        } else {
            print qq(- Creating directory ) . $self->absolute_path . qq(\n);
            $log->logdie(qq(Failed to create directory: $!))
                unless ( mkdir($self->absolute_path) );
            print qq(- Directory created successfully\n);
            return 1;
        }
    } else {
        $log->logdie(qq(Can't sync unknown object: ) . ref($self));
    }
    return 0;
}

=item exists

Tests to see if the file or directory specified by the arguments exist on the
local filesystem.

=cut

sub exists {
    my $self = shift;
    my $check_path = shift;

    my $log = Log::Log4perl->get_logger();

    $log->debug(qq(Checking for local file $check_path));
    my $stat = stat($check_path);
    if ( defined $stat ) {
        return $stat;
    } else {
        return undef;
    }
}

=item append_notes

Add more notes to the C<notes> attribute of this object.

=cut

sub append_notes {
    my $self = shift;
    my $new_notes = shift;

    my $notes = $self->notes;
    if ( defined $notes ) {
        $self->notes($notes . $new_notes);
    }
}

=back

=head2 Archive::File

A file synchronized/to be synchronized from the mirror.  This object inherits
from the L<Role::FileDir::Attribs> role.  See that role for a complete list of
inherited attributes and methods.

=cut

#########################
# package Archive::File #
#########################
package Archive::File;

use Mouse;

with qw(Role::FileDir::Attribs);

=head2 Archive::Directory

A directory synchronized/to be synchronized from the mirror.  This object
inherits from the L<Role::FileDir::Attribs> and L<Role::Dir::Attribs> roles.
See those roles for a complete list of inherited attributes and methods.

=cut

##############################
# package Archive::Directory #
##############################
package Archive::Directory;

use Mouse;

with qw(
    Role::FileDir::Attribs
    Role::Dir::Attribs
);

=head2 Local::File

A file on the local filesystem.  This object inherits from the
L<Role::FileDir::Attribs> and L<Role::LocalFileDir> roles.  See those
roles for a complete list of inherited attributes and methods.

=cut

#######################
# package Local::File #
#######################
package Local::File;

use Mouse;

with qw(
    Role::FileDir::Attribs
    Role::LocalFileDir
);

=head2 Local::Directory

A directory on the local filesystem.  This object inherits from the
L<Role::Dir::Attribs>, L<Role::FileDir::Attribs> and
L<Role::LocalFileDir> roles.  See those roles for a complete list of
inherited attributes and methods.

=cut

############################
# package Local::Directory #
############################
package Local::Directory;

use Mouse;

with qw(
    Role::Dir::Attribs
    Role::FileDir::Attribs
    Role::LocalFileDir
);

=head3 Attributes

=over

=item total_blocks

The total blocks used by this directory and the contents of this directory on
disk or in the archive file.

=back

=cut

has total_blocks    => (
    is      => q(rw),
    isa     => q(Int),
);

=head2 Role::Reports

A role that is consumed by different modules that generate reports to be
output by the user.

=cut

#########################
# package Role::Reports #
#########################
package Role::Reports;

use Mouse::Role;

use constant {
    IS_DIR      => q(D),
    IS_FILE     => q(F),
    IS_UNKNOWN  => q(?),
    IS_MISSING  => q(!),
    DIFF_SIZE   => q(S),
};

=head3 Attributes

=over

=item report_format

The format of the report output, i.e. full, simple, more information,
script-friendly.

=cut

has report_format => (
    is      => q(ro),
    isa     => q(Str),
);

=back

=head2 Reporter

A tool that outputs file/directory information based on the methods used by
the caller, i.e.  if there is files missing on the local system, then the
L</"missing_local"> method would be called and the L<Reporter> object will
display the information about the missing file.  This object consumes the
L<Role::Reports> role.

=cut

####################
# package Reporter #
####################
package Reporter;

use Mouse;
use constant {
    IS_DIR      => q(D),
    IS_FILE     => q(F),
    IS_UNKNOWN  => q(?),
    IS_MISSING  => q(!),
    DIFF_SIZE   => q(S),
};

with qw(Role::Reports);

=head3 Attributes

=over

=item report_types

The types of reports to print.

=cut

has report_types => (
    is      => q(ro),
    isa     => q(Str)
);

=item show_dotfiles

Show dotfiles in the output listings.  C<0> means don't show dotfiles, and
C<1> means show dotfiles.  Default is C<0>, don't show dotfiles.

=cut

has show_dotfiles => (
    is      => q(ro),
    isa     => q(Int),
    default => 0,
);

=back

=head3 Methods

=over

=item new (BUILD)

Creates the L<Reporter> object, which is used to write the information about
local/archived files and directories to C<STDOUT>.

Required arguments:

=over

=item report_types

An array reference, containing the types of reports to print, i.e. what
information you want to display in the report output.

=item report_format

The format of the report.  From least information to most information, the
arguments can be one of I<simple>, I<more>, I<full>.

=back

=cut

sub BUILD {
    my $self = shift;

    my $log = Log::Log4perl->get_logger();

    my @valid_report_formats = qw(full more simple);

    # do some validation on the report type here
    my $rf = $self->report_format;
    if ( scalar(grep(/$rf/, @valid_report_formats)) == 0 ) {
        $log->logdie(qq(Can't create reports using the '$rf' format style));
    }
}

=item write_record

Writes the of file/directory attributes of the file in the archive and on the
local filesystem, if present.  The output format of the record is determined
by the C<--format> command line switch.  See the C<--help> output for a list
of valid formats.

=cut

sub write_record {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    $log->logdie(qq(missing 'archive_obj' object))
        unless ( exists $args{archive_obj} );
    $log->logdie(qq(missing 'local_obj' object))
        unless ( exists $args{local_obj} );

    my $a = $args{archive_obj};
    my $l = $args{local_obj};

    # whether or not to report on the file
    my $write_report_flag;

    # return unless...
    # - file is missing on local and 'local' is set
    # - file is missing in archive and 'archive' is set
    # - file is different sizes between local and archive, and 'size' is set
    # - file is the same size between local and archive, and 'same' is set
    # - 'all' is set
    # report types: headers:local:archive:size:same
    # missing files
    my $checkname = $a->name;
    if ( $l->short_status eq IS_MISSING ) {
        if ( $self->report_types =~ /local/ ) { $write_report_flag = 1; }
    }
    # different size files
    if ( $l->short_status eq DIFF_SIZE ) {
        if ( $self->report_types =~ /size/ && ! $l->is_metafile ) {
            $write_report_flag = 1;
        }
    }
    # is a file/directory on the local filesystem
    if ( $l->short_status eq IS_FILE || $l->short_status eq IS_DIR ) {
        if ( $self->report_types =~ /same/ ) { $write_report_flag = 1; }
    }
    # is an unknown file on the local filesystem
    if ( $l->short_status eq IS_UNKNOWN ) {
        $write_report_flag = 1;
    }
    # skip dotfiles?
    if ( $l->is_dotfile == 1 && ! $self->show_dotfiles ) {
        $log->debug(q(Found dotfile, but --dotfiles not set, not displaying));
        $write_report_flag = 0;
    }
    return undef unless ( $write_report_flag );

    if ( $self->report_format eq q(full) ) {
        $self->format_full(
            archive_obj    => $a,
            local_obj      => $l,
        );
    } elsif ( $self->report_format eq q(more) ) {
        $self->format_more(
            archive_obj    => $a,
            local_obj      => $l,
        );
    } elsif ( $self->report_format eq q(simple) ) {
        $self->format_simple(
            archive_obj    => $a,
            local_obj      => $l,
        );
    }
}

=item format_simple

Reports on the difference between the archive file and the file on the local
system, in a simple, one-line format.

=cut

sub format_simple {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    my $a = $args{archive_obj};
    my $l = $args{local_obj};

    my $filepath;
    if ( $a->parent_path !~ /\./ ) {
        $filepath = $a->parent_path . q(/) . $a->name;
    } else {
        $filepath = $a->name;
    }

format SIMPLE =
@@ @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<<<<<<<<<<<<< @#########
$l->short_type, $l->short_status, $filepath, $a->mod_time, $a->size
.
    # set the current $FORMAT_NAME to the SIMPLE format
    $~ = q(SIMPLE);
    write();
}

=item format_more

Reports on the difference between the archive file and the file on the local
system, in a more verbose three line format; the first line is the name of the
archive file, second line is the archive file attributes, third line is the
attributes of the file on the local system, if the file exists.


=cut

sub format_more {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    my $l = $args{local_obj};
    my $a = $args{archive_obj};

### BEGIN FORMAT

my $notes = q();
if ( length($l->long_status) > 0 ) {
    $notes = q(Notes:);
}

format MORE =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$a->parent_path . q(/) . $a->name
  archive: @>>>>>>>>> @>>>>>>> @>>>>>>> @||||||||||| @######## @<<<<<<<
$a->perms, $a->owner, $a->group, $a->mod_time, $a->size, $notes
  local:   @>>>>>>>>> @>>>>>>> @>>>>>>> @||||||||||| @######## @<<<<<<<<<<<<<<
$l->perms, $l->owner, $l->group, $l->mod_time, $l->size, $l->long_status
.
### END FORMAT
    # set the current $FORMAT_NAME to the MORE format
    $~ = q(MORE);
    write();
}

=item format_full

Reports on the difference between the archive file and the file on the local
system, in a very verbose three line format; the first line is the name of the
archive file, each subsequent line displays one attribute of both the archive
file and the local file, if the local file exists.

=back

=cut

sub format_full {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    my $l = $args{local_obj};
    my $a = $args{archive_obj};

format FULL =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$a->parent_path . q(/) . $a->name
  Archive:                      Local:
  permissions: @>>>>>>>>>>>>    permissions: @>>>>>>>>>>>>
  $a->perms, $l->perms
  owner:       @>>>>>>>>>>>>    owner:       @>>>>>>>>>>>>
  $a->owner, $l->owner
  group:       @>>>>>>>>>>>>    group:       @>>>>>>>>>>>>
  $a->group, $l->group
  mtime:       @<<<<<<<<<<<<    mtime:       @<<<<<<<<<<<<
  $a->mod_time, $l->mod_time
  size:        @############    size:        @############
  $a->size, $l->size
  Notes: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  $l->notes
.
### END FORMAT

    # write out the report
    $~ = q(FULL);
    write();

}


=head2 LWP::Wrapper

A wrapper around LWP::UserAgent, which handles fetching files via HTTP/FTP and
then handling response codes from servers, if any.

=cut

########################
# package LWP::Wrapper #
########################
package LWP::Wrapper;

use File::Temp;
use LWP::UserAgent;
use URI::Escape;
use Mouse;
use Number::Format;

my @usable_mirrors;
my @idgames_mirrors = qw(
    ftp://ftp.fu-berlin.de/pc/games/idgames
    ftp://ftp.ntua.gr/pub/vendors/idgames
    ftp://ftp.mancubus.net/pub/idgames/
    http://youfailit.net/pub/idgames
);

=head3 Attributes

=over

=item base_url

The base URL that is used to come up with a fully qualified path in order to
pull files from the mirror server.

=cut

has q(base_url) => (
    is      => q(rw),
    isa     => q(Any),
);

=item user_agent

The L<LWP::UserAgent> object that's created in the L<new()> method.

=cut

has q(user_agent) => (
    is      => q(rw),
    isa     => q(Object),
);

=item exclude_urls

URLs to exclude from the built in list of C<idgames> mirror servers.  Use this
option to skip mirror servers that are not functioning.

=cut

has q(exclude_urls) => (
    is      => q(rw),
    isa     => q(ArrayRef[Str]),
);

=item master_mirror

The main mirror site, currently L<ftp://ftp.fu-berlin.de/pc/games/idgames>.

=cut

has q(master_mirror) => (
    is      => q(ro),
    isa     => q(Str),
    default => q(ftp://ftp.fu-berlin.de/pc/games/idgames),
);

=item url_regex

Regex to get different bits of the URL back, to be used in script/debug output.

=cut

has q(url_regex) => (
    is      => q(ro),
    isa     => q(RegexpRef),
    # $1 = scheme, $2 = host, $3 is path
    default => sub {qr!^(ftp|http|https){1}://([\w.-]+)/??(.*)*$!;}
);

=item tempdir

Temporary directory to use for downloading files.  Defaults to C<undef>, which
will cause L<File::Temp> to use it's built-in default.

=cut

has q(tempdir) => (
    is      => q(rw),
    isa     => q(Str),
);

=back

=head3 Methods

=over

=item new (BUILD)

Creates the L<LWP::UserAgent> wrapper object.

=cut

sub BUILD {
    my $self = shift;

    my $log = Log::Log4perl->get_logger();

    $self->user_agent(LWP::UserAgent->new());
    my @exclude_mirrors = @{$self->exclude_urls};
    if ( scalar(@exclude_mirrors) > 0 ) {
        # create a list of mirrors from the built in list minus the excluded
        # mirrors
        foreach my $mirror_test ( @idgames_mirrors ) {
            foreach my $exclude_test ( @exclude_mirrors ) {
                $log->debug(qq(: Checking $exclude_test against $mirror_test));
                if ( $mirror_test =~ /$exclude_test/ ) {
                    $log->debug(qq(: Excluding mirror $mirror_test));
                } else {
                    $log->debug(qq(: Adding $mirror_test to usable mirrors));
                    push(@usable_mirrors, $mirror_test);
                }
            }
        }
    } else {
        @usable_mirrors = @idgames_mirrors;
    }
    if ( $log->is_debug () ) {
        foreach my $um ( @usable_mirrors ) {
            $log->debug(qq(Usable mirror: $um));
        }
    }
}

=item get_random_mirror

Returns a random mirror server from a list of "valid" mirror servers, i.e. the
built-in list of mirror servers minus servers excluded via the C<--exclude>
command line switch.

=cut

sub get_random_mirror {
    my $self = shift;
    my $url_index = rand(@usable_mirrors);
    return $usable_mirrors[$url_index];
}

=item get_base_url

Returns the base URL as set by the user, or a random mirror if the user did
not specify a base URL.

=cut

sub get_base_url {
    my $self = shift;
    my $log = Log::Log4perl->get_logger();

    my $base_url;
    if ( ! defined $self->base_url ) {
        $base_url = $self->get_random_mirror();
    } else {
        $base_url = $self->base_url;
    }

    # $1 = scheme, $2 = host, $3 is path
    $base_url =~ $self->url_regex;
    $log->debug(qq(Returning base URL host: '$2'));
    return $base_url;
}

=item fetch

Required arguments:

=over

=item filepath

The "relative path" of the file to download, which is combined with the "base
path" in order to determine the full URL.

=back

Optional arguments:

=over

=item base_url

The base URL to use for downloading files.  This allows for recursive fetching
using different base URLs.

=back

The C<fetch()> method fetches files from the remote mirror.  Note that the
C<filepath> argument should be fully qualified from the server's "document
root", i.e.  given a URL of C<http://example.com>, your C<$filepath> should be
something like C<path/to/file>, so that the full URL would become
C<http://example.com/path/to/file>.

The synchronized file is saved with a temporary name in the directory that was
passed in as C<tempdir> when the object was created (or the default
L<File::Temp> directory if no C<tempdir> was used), and this temporary name is
returned if the download was successful (HTTP 200).  If any errors were
encountered, then the method returns C<undef>.

=cut

sub fetch {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    $log->logdie(qq(missing 'filepath' argument))
        unless ( exists $args{filepath} );

    my $filepath = $args{filepath};
    my $base_url = $args{base_url};

    # set a base URL if one was not set by the caller
    # if $self->base_url is undefined, a random mirror will be chosen
    if ( ! defined $base_url ) {
        $base_url = $self->get_base_url;
    }

    # remove leading slash
    if ( $filepath !~ /^\// ) {
        $filepath = q(/) . $filepath;
    }

    my $filename = (split(/\//, $filepath))[-1];
    # create a tempfile for the download
    my $fh = File::Temp->new(
        # don't unlink files by default; this should be done by the caller
        UNLINK      => 0,
        DIR         => $self->tempdir,
        TEMPLATE    => qq(idgs.$filename.XXXXXXXX),
        SUFFIX      => q(.tmp),
    );
    $log->debug(qq(Created temp file ) . $fh->filename );

    # grab the file
    # $1 = scheme, $2 = host, $3 is path
    $base_url =~ $self->url_regex;
    print qq(- Fetching file '$filepath' from '$2'\n);
    my $ua = $self->user_agent();
    my $encoded_url = $base_url
        . uri_escape_utf8($filepath, qq(^A-Za-z0-9\-\._~\/));
    $log->debug(qq(Encoded URL: $encoded_url));
    my $response = $ua->get(
        $encoded_url,
        q(:content_file) => $fh->filename,
    );
    if ( $response->is_error() ) {
        $log->warn(qq(Error downloading '$filepath'; ));
        $log->warn(q(Response status: ) . $response->status_line() );
        $log->debug(q(Deleting tempfile ) . $fh->filename );
        unlink $fh->filename;
        undef $fh;
        my $master_mirror = $self->master_mirror;
        if ( $base_url !~ /$master_mirror/ ) {
            $log->warn(qq(Retrying download of: $filepath ));
            # $1 = scheme, $2 = host, $3 is path
            $self->master_mirror =~ $self->url_regex;
            $log->warn(qq(from $2));
            # recursive call here, make another try with the master mirror
            return $self->fetch(
                filepath => $filepath,
                base_url => $self->master_mirror,
            );
        } else {
            # we couldn't grab it from the master mirror either
            return undef;
        }
    } elsif ( $response->is_redirect() ) {
        $log->warn(qq(Server returned 3XX redirect code;));
        $log->warn(q(Response status: ) . $response->status_line );
        return undef;
    } else {
        #my $content = $response->content;
        my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
               $atime,$mtime,$ctime,$blksize,$blocks)
                   = stat($fh);
        # for formatting synchronized file sizes
        my $nf = Number::Format->new();
        print q(- Download successful, downloaded ) . $nf->format_bytes($size)
            . qq| byte(s)\n|;
        return $fh->filename;
    }
}

=item get_mirror_list

Returns a list of C<idgames> mirror servers.

=cut

sub get_mirror_list {
    return @idgames_mirrors;
}

=back

=head2 Runtime::Stats

An object that keeps different types of statistics about script execution.
Among other things, this object will help keep track of:

=over

=item Total script execution time

=item Total files found in archive

=item Total size of files listed in archive

=item Total files (to be) retrieved/synchronized from archive

=item Total bytes (to be) retrieved/synchronized from archive

=back

=cut

##########################
# package Runtime::Stats #
##########################
package Runtime::Stats;
use Mouse;
use Number::Format; # pretty output of bytes
use Time::HiRes qw( gettimeofday tv_interval );

my ($start_time, $stop_time);

=head3 Attributes

=over

=item dry_run

Whether C<--dry-run> was specified on the command line.  This will
change the status blurb that is output at the completion of the script
to say "Total [files|bytes] to be synced..." instead of
"Total [files|bytes] synced...".

=cut

has q(dry_run) => (
    is      => q(rw),
    isa     => q(Bool),
);

=over

=item total_synced_bytes

The amount of data in bytes synced from the mirror server.

=cut

has q(total_synced_bytes) => (
    is      => q(rw),
    isa     => q(Int),
);

=item total_synced_files

The number of files pulled from the mirrors.

=cut

has q(total_synced_files) => (
    is      => q(rw),
    isa     => q(Int),
);

=item total_archive_files

The number of files on a mirror.

=cut

has q(total_archive_files) => (
    is      => q(rw),
    isa     => q(Int),
);

=item total_archive_size

The amount of data stored on each mirror server.

=cut

has q(total_archive_size) => (
    is      => q(rw),
    isa     => q(Int),
);

=back

=head3 Methods

=over

=item start_timer

Starts the internal timer, used to measure total script execution time.

=cut

sub start_timer {
    $start_time = [gettimeofday];
}

=item stop_timer

Stops the internal timer, used to measure total script execution time.

=cut

sub stop_timer {
    $stop_time = [gettimeofday];
}

=item write_stats

Output the runtime stats from the script.

=cut

sub write_stats {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();
    $log->logdie(qq(missing 'total_synced_files' argument))
        unless ( exists $args{total_synced_files} );
    $log->logdie(qq(missing 'total_archive_files' argument))
        unless ( exists $args{total_archive_files} );
    $log->logdie(qq(missing 'total_archive_size' argument))
        unless ( exists $args{total_archive_size} );
    $log->logdie(qq(missing 'newstuff_file_count' argument))
        unless ( exists $args{newstuff_file_count} );
    $log->logdie(qq(missing 'deleted_file_count' argument))
        unless ( exists $args{deleted_file_count} );

    my $total_synced_bytes = 0;
    my @total_synced_files = @{$args{total_synced_files}};
    print qq(Calculating runtime statistics...\n);
    foreach my $synced ( @total_synced_files ) {
        $total_synced_bytes += $synced->size;
    }
    my $nf = Number::Format->new();
    my $output;
    $output = qq(- Total files found in archive: )
        . $args{total_archive_files} . qq(\n);
    $output .= qq(- Total size of files in archive: )
        . $nf->format_bytes($args{total_archive_size}) . qq(\n);
    if ( $self->dry_run ) {
        $output .= qq(- Total files to be synced from archive: );
    } else {
        $output .= qq(- Total files synced from archive: );
    }
    $output .= scalar(@total_synced_files) . qq(\n);
    if ( $self->dry_run ) {
        $output .= qq(- Total bytes to be synced from archive: );
    } else {
        $output .= qq(- Total bytes synced from archive: );
    }
    $output .= $nf->format_bytes($total_synced_bytes) . qq(\n);
    $output .= qq(- Total files in /newstuff directory: );
    $output .= $args{newstuff_file_count} . qq(\n);
    $output .= qq(- Total old files deleted from /newstuff directory: );
    $output .= $args{deleted_file_count} . qq(\n);

    $output .= qq(- Total script execution time: )
        . sprintf('%0.2f', tv_interval ( $start_time, $stop_time ) )
        . qq( seconds\n);
    print $output;
}

=back

=cut

################
# package main #
################
package main;

### external packages
use Date::Format; # strftime
use Devel::Size; # for profiling filelist hashes (/newstuff, archive)
use Digest::MD5; # comparing the ls-laR.gz files
use English;
use File::Copy;
use File::Find::Rule;
use File::stat;
use Getopt::Long;
use IO::File;
use IO::Uncompress::Gunzip qw($GunzipError);
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use LWP::UserAgent;
use Mouse; # sets strict and warnings

use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Terse = 1;

use constant {
    DEBUG_LOOPS => 50,
    PERMS       => 0,
    HARDLINKS   => 1,
    OWNER       => 2,
    GROUP       => 3,
    SIZE        => 4,
    MONTH       => 5,
    DATE        => 6,
    YEAR_TIME   => 7,
    NAME        => 8,
    TOTAL_FIELDS=> 9,
};

### script variables
# FIXME GitHub issue #58 filed, default and allowed report types and formats
# should live in the Reporter object
my $allowed_report_types = q(headers:local:archive:size:same);
my $default_report_types = q(local:size);
my $default_report_format = q(more);

=head1 DESCRIPTION

Script normally exits with a 0 status code, or a non-zero status code if any
errors were encountered.

=cut

    # force writes in output to STDOUT
    $| = 1;

    # creating a Config object will check for things like '--help',
    # '--examples', and '--morehelp'
    my $cfg = idGames::Sync::Config->new();

    # parent directory
    my $parent = q();
    # flag set whenever we're parsing files in/beneath the /incoming directory
    my $incoming_dir_flag = 0;

    # default log level
    my $log4perl_conf = qq(log4perl.rootLogger = WARN, Screen\n);
    if ( $cfg->defined(q(verbose)) && $cfg->defined(q(debug)) ) {
        die(q(Script called with --debug and --verbose; choose one!));
    } elsif ( $cfg->defined(q(debug)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = DEBUG, Screen\n);
    } elsif ( $cfg->defined(q(verbose)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = INFO, Screen\n);
    }

    # if 'colorize' is undefined, set a default (needed for Log4perl check
    # below)
    if ( ! $cfg->defined(q(colorize)) ) {
        # colorize if STDOUT is connected to a terminal
        if ( -t STDOUT ) {
            $cfg->set(q(colorize), 1);
        } else {
            $cfg->set(q(colorize), 0);
        }
        # Unless we're running on Windows, in which case, don't colorize
        # unless --colorize is explicitly used, which would cause this whole
        # block to get skipped
        if ( $cfg->defined(q(is_mswin32)) ) {
            $cfg->set(q(colorize), 0);
        }
    }

    # color log output
    if ( $cfg->get(q(colorize)) ) {
        $log4perl_conf .= q(log4perl.appender.Screen )
            . qq(= Log::Log4perl::Appender::ScreenColoredLevels\n);
    } else {
        $log4perl_conf .= q(log4perl.appender.Screen )
            . qq(= Log::Log4perl::Appender::Screen\n);
    }

    # the rest of the log4perl setup
    $log4perl_conf .= qq(log4perl.appender.Screen.stderr = 1\n)
        . qq(log4perl.appender.Screen.layout = PatternLayout\n)
        . q(log4perl.appender.Screen.layout.ConversionPattern )
        . qq|= [%8r] %p{1} %4L (%M{1}) %m%n\n|;

    Log::Log4perl->init(\$log4perl_conf);
    my $log = Log::Log4perl->get_logger();
    $log->debug(q(##### ) . __FILE__ . qq( - $VERSION #####));
    $log->debug(qq(script start; ) . time2str(q(%C), time));

    my @exclude_urls;
    if ( $cfg->defined(q(exclude)) ) {
        @exclude_urls = @{$cfg->get(q(exclude))};
    }

    # set a temporary directory; this directory is used when downloading
    # files, LWP::Wrapper downloads to the file directly instead of
    # downloading to an object in memory
    if ( ! $cfg->defined(q(tempdir)) ) {
        if ( defined $ENV{TEMP} ) {
            # Windows usually sets %TEMP% as well
            $cfg->set(q(tempdir), $ENV{TEMP});
            $log->debug(q(Using ENV{TEMP} for tempdir));
        } elsif ( defined $ENV{TMP} ) {
            $cfg->set(q(tempdir), $ENV{TMP});
            $log->debug(q(Using ENV{TMP} for tempdir));
        } elsif ( defined $ENV{TMPDIR} ) {
            $cfg->set(q(tempdir), $ENV{TMPDIR});
            $log->debug(q(Using ENV{TMPDIR} for tempdir));
        } else {
            $cfg->set(q(tempdir), q(/tmp));
            $log->debug(q(Using '/tmp' for tempdir));
        }
        $log->debug(q(Using ) . $cfg->get(q(tempdir)) . q( for tempdir));
    }
    my $lwp = LWP::Wrapper->new(
        base_url        => $cfg->get(q(url)),
        exclude_urls    => \@exclude_urls,
        tempdir         => $cfg->get(q(tempdir)),
    );

    if ( $cfg->defined(q(show-mirrors)) ) {
        print qq(Current mirror URLs:\n);
        foreach my $mirror ( $lwp->get_mirror_list() ) {
            print qq(- $mirror\n);
        }
        exit 0;
    }

    if ( $log->is_debug ) {
        $log->debug(q(Dumping %args hash:));
        my %args = $cfg->get_args();
        warn(Dumper {%args});
    }

    $log->logdie(q(Must specify path directory with --path))
        unless ( $cfg->defined(q(path)) );

    if ( ! $cfg->defined(q(is_mswin32)) ) {
        # For *NIX, append a forward slash on to the directory name so other
        # paths don't need the forward slash later on
        if ( $cfg->get(q(path)) !~ /\/$/ ) {
            $cfg->set(q(path), $cfg->get(q(path)) . q(/));
        }
    } else {
        # same for Windows, but append a backslash
        if ( $cfg->get(q(path)) !~ /\\$/ ) {
            $cfg->set(q(path), $cfg->get(q(path)) . q(\\));
        }
    }

    ### REPORT TYPES
    # the default report type is now size-local
    # FIXME GitHub issue #58 filed, default report types should live in the
    # Reporter object
    my $report_types = $default_report_types;
    if ( $cfg->defined(q(size-same)) ) {
        $report_types = q(size:same);
    }

    if ( $cfg->defined(q(type)) ) {
        my @reports = @{$cfg->get(q(type))};
        my @requested_types;
        foreach my $type ( @reports ) {
            if ( $allowed_report_types !~ /$type/i ) {
                $log->logdie(qq(Report type '$type' is not a valid report));
            } else {
                push(@requested_types, $type);
            }
        }
        $report_types = join(q(:), @requested_types);
    }


    ### REPORT FORMATS
    # FIXME GitHub issue #58 filed, default report format should live in the
    # Reporter object
    my $report_format = $default_report_format;
    if ( $cfg->defined(q(format)) ) {
        $report_format = $cfg->get(q(format));
    }

    # skip syncing of dotfiles by default
    if ( ! $cfg->defined(q(dotfiles)) ) {
        $cfg->set(q(dotfiles), 0);
    }

    my $stats = Runtime::Stats->new(
        dry_run       => $cfg->defined(q(dry-run)),
        report_format => $report_format
    );
    $stats->start_timer();

    my $report = Reporter->new(
        report_format   => $report_format,
        report_types    => $report_types,
        show_dotfiles   => $cfg->get(q(dotfiles)),
    );

    # a list of files/directories were sync'ed with a mirror, either because
    # they're missing from the local system, or for files, the file is the
    # wrong size
    my @synced_files;
    my $total_archive_size = 0;
    my $dl_lslar_file;
    my $lslar_file = $cfg->get(q(path)) . q(ls-laR.gz);
    my $lslar_stat = stat($lslar_file);
    $log->debug(qq(Set lslar_file to $lslar_file));
    if ( ! -r $lslar_file && ! $cfg->defined(q(create-mirror)) ) {
        $log->fatal(qq(Can't read/find the 'ls-laR.gz' file!));
        $log->fatal(qq|(Checked: $lslar_file)|);
        $log->fatal(qq(If you are creating a new mirror, please use the));
        $log->fatal(qq('--create-mirror' switch; otherwise, check that));
        $log->fatal(qq(the '--path' switch is pointing to the directory));
        $log->fatal(qq(where the local copy of 'idgames' is located.));
        $log->logdie(qq(Exiting script...));
    }

    ### UPDATE ls-laR.gz ###
    if ( ! $cfg->defined(q(dry-run)) && ! $cfg->defined(q(skip-ls-lar)) ) {
        $log->debug(qq(Fetching 'ls-laR.gz' file listing));
        # if a custom URL was specified, use that here instead
        my $lslar_url = $lwp->master_mirror;
        if ( $cfg->defined(q(url)) ) {
            $lslar_url = $cfg->get(q(url));
        }
        # returns undef if there was a problem fetching the file
        $dl_lslar_file = $lwp->fetch(
            filepath => q(ls-laR.gz),
            base_url => $lslar_url,
        );
        if ( ! defined $dl_lslar_file ) {
            $log->logdie(qq(Error downloading ls-laR.gz file));
        }
        $log->debug(qq(Received tempfile $dl_lslar_file from fetch method));
        my $dl_lslar_stat = stat($dl_lslar_file);

        my $in_fh = IO::File->new(qq(< $lslar_file));
        # create the digest object outside of any nested blocks
        my $md5 = Digest::MD5->new();
        # get the digest for the local file, if the local file exists
        if ( defined $in_fh ) {
            $md5->addfile($in_fh);
            # close the local file filehandle
            $in_fh->close();
        } else {
            # if there's no previous copy of the archive on disk, just use
            # a bogus file for the stat object, and bogus string for the
            # checksum;
            # no need to close the filehandle, it will already be 'undef'
            if ( $cfg->defined(q(is_mswin32)) ) {
                $lslar_stat = stat(q(C:));
            } else {
                $lslar_stat = stat(q(/dev/null));
            }
            $md5->add(q(bogus file digest));
        }
        my $local_digest = $md5->hexdigest();

        # get the digest for the synchronized file
        my $dl_fh = IO::File->new(qq(< $dl_lslar_file));
        # $md5 has already been reset with the call to hexdigest() above
        $md5->addfile($dl_fh);
        my $archive_digest = $md5->hexdigest();
        # close the filehandle
        $dl_fh->close();
        # check to see if the synchronized ls-laR.gz file is the same file
        # on disk by comparing MD5 checksums for the buffer and file
        print q(- Local file size:   ) . $lslar_stat->size
            . qq(;  checksum: $local_digest\n);
        print q(- Archive file size: ) . $dl_lslar_stat->size
            . qq(;  checksum: $archive_digest\n);
        if ( $local_digest ne $archive_digest ) {
            #my $out_fh = IO::File->new(qq(> $lslar_file));
            print qq(- ls-laR.gz Checksum mismatch...\n);
            print qq(- Replacing file: $lslar_file\n);
            print qq(- With file: $dl_lslar_file\n);
            move($dl_lslar_file, $lslar_file);
        } else {
            print qq(- $lslar_file and archive copy match!\n);
            $log->debug(qq(Unlinking $dl_lslar_file));
            unlink $dl_lslar_file;
        }
        # exit here if --update-ls-lar was used
        if ( $cfg->defined(q(update-ls-lar)) ) {
            print qq(- ls-laR.gz synchronized, exiting program\n);
            exit 0;
        }
    }

    my $gunzip = IO::Uncompress::Gunzip->new($lslar_file, Append => 1);
    $log->logdie(q(Could not create IO::Uncompress::Gunzip object; ) .
        $GunzipError) unless (defined $gunzip);
    my ($buffer, $uncompressed_bytes);
    # keep reading into $buffer until we reach EOF
    until ( $gunzip->eof() ) {
        $uncompressed_bytes = $gunzip->read($buffer);
    }
    $log->info(qq(ls-laR.gz uncompressed size: ) . length($buffer));

    ### PARSE ls-laR.gz FILE ###
    my %idgames_filelist;
    my $current_dir;
    my %newstuff_dir;
    IDGAMES_LINE: foreach my $line ( split(/\n/, $buffer) ) {
        # skip blank lines
        next if ( $line =~ /^$/ );
        $log->debug(qq(line: >>>$line<<<));
        my @fields = split(/\s+/, $line);
        my $name_field;
        # we're not expecting any more than TOTAL_FIELDS fields returned
        # from the above split() call
        if ( scalar(@fields) > TOTAL_FIELDS ) {
            $log->debug(q(HEY! got ) . scalar(@fields) . qq( fields!));
            my @name_fields = splice(@fields, NAME, scalar(@fields));
            $log->debug(qq(name field had spaces; joined name is: )
                . join(q( ), @name_fields));
            $name_field = join(q( ), @name_fields);
        } else {
            $name_field = $fields[NAME];
        }
        # a file, the directory bit will not be set in the listing output
        if ( defined $name_field ) {
            $log->debug(qq(Reassembled file/dir name: '$name_field'));
        }
        if ( $fields[PERMS] =~ /^-.*/ ) {
            # skip this file if it's inside the /incoming directory
            # this can't be combined with the --dotfiles check below because
            # that requires a local file object, whereas the incoming dir
            # check works off of the archive directory
            if ( $incoming_dir_flag && ! $cfg->defined(q(incoming)) ) {
                $log->debug(q(file in /incoming, but --incoming not used));
                next IDGAMES_LINE;
            }

            $log->debug(qq(Creating archive file object '$name_field'));
            my $archive_file = Archive::File->new(
                parent_path     => $current_dir,
                perms           => $fields[PERMS],
                hardlinks       => $fields[HARDLINKS],
                owner           => $fields[OWNER],
                group           => $fields[GROUP],
                size            => $fields[SIZE],
                mod_time        => $fields[MONTH] . q( )
                    . $fields[DATE] . q( ) . $fields[YEAR_TIME],
                name            => $name_field,
            );
            $total_archive_size += $archive_file->size;
            $log->debug(qq(Creating local file object '$name_field'));
            my $local_file = Local::File->new(
                opts_path   => $cfg->get(q(path)),
                archive_obj => $archive_file,
                is_mswin32  => $cfg->defined(q(is_mswin32)),
            );
            # stat the file to see if it exists on the local system, and to
            # populate file attribs if it does exist
            $local_file->stat_local();

            # add the file to the filelist
            $idgames_filelist{$local_file->absolute_path}++;

            $report->write_record(
                archive_obj    => $archive_file,
                local_obj      => $local_file,
            );
            if ( $local_file->is_newstuff ) {
                    # add this file to the list of files that should be in
                    # /newstuff
                    $newstuff_dir{$local_file->absolute_path}++;
                    $log->debug(q(Added file to /newstuff list));
            }
            if ( $local_file->needs_sync ) {
                # skip syncing dotfiles unless --dotfiles was used
                if ($local_file->is_dotfile && ! $cfg->get(q(dotfiles))) {
                    $log->debug(q(dotfile needs sync, missing --dotfiles));
                    next IDGAMES_LINE;
                }
                # skip syncing non-WAD files/metafiles unless --sync-all was
                # used
                if (! ($local_file->is_wad_dir
                    || $local_file->is_metafile
                    || $local_file->is_newstuff)
                    && ! $cfg->defined(q(sync-all))){
                    $log->debug(q(Non-WAD file needs sync, missing --sync-all));
                    next IDGAMES_LINE;
                }
                if ( $cfg->defined(q(dry-run)) ) {
                    $log->debug(q(Needs sync, dry-run set; parsing next line));
                    push(@synced_files, $archive_file);
                    next IDGAMES_LINE;
                } else {
                    my $sync_status = $local_file->sync( lwp => $lwp );
                    if ( $sync_status ) {
                        # add the file to the list of synced files
                        # used later on in reporting
                        push(@synced_files, $archive_file);
                    }
                }
                $local_file->stat_local();
                # check here that the downloaded file matches the size
                # shown in ls-laR.gz; make another call to stat_local; make
                # another call to stat_local
                if ( ($local_file->size != $archive_file->size)
                    && ! $local_file->is_metafile ) {
                    $log->warn(q(Downloaded size: ) . $local_file->size
                        . q( doesn't match archive file size: )
                        . $archive_file->size);
                }
            } else {
                $log->debug(q(File exists on local system, no need to sync));
            }
        # the directory bit is set in the listing output
        } elsif ( $fields[PERMS] =~ /^d.*/ ) {
            # skip this directory if it's inside the /incoming directory
            if ( $incoming_dir_flag && ! $cfg->defined(q(incoming)) ) {
                $log->debug(q(dir in /incoming, but --incoming not used));
                next IDGAMES_LINE;
            }
            $log->debug(qq(Creating archive dir object '$name_field'));
            my $archive_dir = Archive::Directory->new(
                parent_path     => $current_dir,
                perms           => $fields[PERMS],
                hardlinks       => $fields[HARDLINKS],
                owner           => $fields[OWNER],
                group           => $fields[GROUP],
                size            => $fields[SIZE],
                mod_time        => $fields[MONTH] . q( )
                    . $fields[DATE] . q( ) . $fields[YEAR_TIME],
                name            => $name_field,
                total_blocks    => 0,
            );
            $log->debug(qq(Creating local dir object '$name_field'));
            my $local_dir = Local::Directory->new(
                opts_path       => $cfg->get(q(path)),
                archive_obj    => $archive_dir,
            );
            $local_dir->stat_local();
            $report->write_record(
                archive_obj    => $archive_dir,
                local_obj      => $local_dir,
            );
            if ( $local_dir->needs_sync ) {
                if ( ! $cfg->defined(q(dry-run)) ) {
                    $local_dir->sync( lwp => $lwp );
                }
            } else {
                $log->debug(qq(Directories do not need to be synchronized));
            }
        # A new directory entry
        } elsif ( $fields[PERMS] =~ /^\.[\/\w\-_\.]*:$/ ) {
            print qq(=== Entering directory: )
                . $fields[PERMS] . qq( ===\n)
                if ( $cfg->defined(q(headers)) );
            # scrape out the directory name sans trailing colon
            $current_dir = $fields[PERMS];
            $current_dir =~ s/:$//;
            $current_dir =~ s/^\.//;
            if ( $current_dir =~ /^\/incoming.*/ ) {
                $log->debug(qq(Parsing subdirectory: $current_dir));
                $log->debug(q(/incoming directory; setting flag));
                $incoming_dir_flag = 1;
            } else {
                if ($current_dir =~ /^$/ ) {
                    $log->debug(qq(Setting current directory to: <root>));
                } else {
                    $log->debug(qq(Setting current directory to: $current_dir));
                }
                $log->debug(q(Clearing /incoming directory flag));
                $incoming_dir_flag = 0;
            }
        } elsif ( $line =~ /^total (\d+)$/ ) {
            # $1 got populated in the regex above
            my $dir_blocks = $1;
            print qq(- total blocks taken by this directory: $dir_blocks\n)
                if ( $cfg->defined(q(headers)) );
        } elsif ( $line =~ /^lrwxrwxrwx.*/ ) {
            print qq(- found a symlink: $current_dir\n)
                if ( $log->is_info() );
        } else {
            $log->warn(qq(Unknown line found in input data; >$line<));
        }
        if ( $log->is_debug() ) {
            # don't worry about counters or constants if --debug-noexit was
            # used
            next IDGAMES_LINE if ( $cfg->defined(q(debug-noexit)) );
            # check to see if --debug-files was used
            if ( $cfg->defined(q(debug-files)) ) {
                if ( scalar(keys(%idgames_filelist))
                        > $cfg->get(q(debug-files)) ) {
                    $log->debug(q|reached | . $cfg->get(q(debug-files))
                        . q( files));
                    $log->debug(q(Exiting script early due to --debug flag));
                    last IDGAMES_LINE;
                }
            } else {
                # go with the constant 'DEBUG_LOOPS'
                if ( scalar(keys(%idgames_filelist)) == DEBUG_LOOPS ) {
                    $log->debug(q|DEBUG_LOOPS (| . DEBUG_LOOPS
                        . q|) reached...|);
                    $log->debug(q(Exiting script early due to --debug flag));
                    last IDGAMES_LINE;
                }
            }
        }
    } # foreach my $line ( split(/\n/, $buffer) )

    # check the contents of /newstuff, make sure that files have been deleted
    # if they don't belong there anymore
    # FIXME redo this so it finds all files in $cfg->get(q(path)), and greps
    # out the files in /newstuff, unless the user asks to check for extra
    # files to be deleted in the whole mirror
    my $deleted_file_count = 0;

    # all of the files in the local mirror
    my @local_idgames_files = File::Find::Rule
        ->file
        ->in($cfg->get(q(path)));

    # are we only deleting from newstuff?
    my @local_file_check;
    if ( $cfg->defined(q(prune-all)) ) {
        $log->debug(q(Checking local archive for files to delete));
        $log->debug(q(There are currently ) . scalar(keys(%idgames_filelist))
            . q( files on the 'idgames' Archive mirrors));
        $log->debug(q(There are currently ) . scalar(@local_idgames_files)
            . q( files in the local copy of 'idgames' archive));
        @local_file_check = @local_idgames_files;
    } else {
        $log->debug(q(Checking /newstuff for files to delete));
        $log->debug(q(/newstuff currently should have )
            . scalar(keys(%newstuff_dir)) . q( files));
        my $newstuff_path = $cfg->get(q(path)) . q(newstuff);
        @local_file_check = grep(/$newstuff_path/, @local_idgames_files);
    }

    foreach my $local_file ( sort(@local_file_check) ) {
        my $check_file;
        my $delete_location;
        # see if the $check_file exists in the archive (and in /newstuff)
        if ( $cfg->defined(q(prune-all)) ) {
            $check_file = $idgames_filelist{$local_file};
            $delete_location = "non-archive";
        } else {
            $check_file = $idgames_filelist{$local_file};
            $delete_location = "/newstuff";
        }
        # if the file does not exist in the archive/in /newstuff
        if ( ! defined $check_file ) {
            if ( $cfg->defined(q(dry-run)) ) {
                print qq(* Would delete $delete_location file: $local_file\n);
            } else {
                print qq(* Deleting $delete_location file: $local_file\n);
                if ( unlink $local_file ) {
                    $deleted_file_count++;
                } else {
                    $log->error(qq(Can't unlink $local_file: $!));
                }
            }
        }
    }

    # stop the timer prior to calculating stats
    $stats->stop_timer();

    # calc stats and write them out
    $stats->write_stats(
        total_synced_files      => \@synced_files,
        total_archive_files     => scalar(keys(%idgames_filelist)),
        total_archive_size      => $total_archive_size,
        newstuff_file_count     => scalar(keys(%newstuff_dir)),
        deleted_file_count      => $deleted_file_count,
    );
    exit 0;

=head1 AUTHOR

Brian Manning, C<< <brian at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-idGamesSync/issues>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I make
changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc idgames_sync.pl

You can also look for information at:

=over 4

=item * App::idGamesSync GitHub project page

L<https://github.com/spicyjack/App-idGamesSync>

=item * App::idGamesSync GitHub issues page

L<https://github.com/spicyjack/App-idGamesSync/issues>

=back

=head1 ACKNOWLEDGEMENTS

Perl, the Doom Wiki L<http://www.doomwiki.org> for lots of the documentation,
all of the various Doom source porters, and id Software for releasing the
source code for the rest of us to make merry mayhem with.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2011, 2013 Brian Manning, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
