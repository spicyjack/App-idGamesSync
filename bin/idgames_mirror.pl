#!/usr/bin/env perl

# Copyright (c) 2011,2013 by Brian Manning <brian at xaoc dot org>

# For support with this file, please file an issue on the GitHub issue
# tracker: https://github.com/spicyjack/App-idGamesMirror/issues

=head1 NAME

idgames_mirror.pl - Create/update a mirror of the idgames repository.

=head1 VERSION

Version v0.0.3

=cut

use version; our $VERSION = qv('0.0.3');

# shortcut to get the name of the file this script lives in
use File::Basename;
our $our_name = basename $0;

=head1 SYNOPSIS

Create or update a mirror of the C<idgames> archive on the local host.

=cut

# ! = script defaults
#
# script reports:
# ! files in the tarball but missing on disk
# ! files that have different sizes between the tarball and disk
# ! files that have the same size in both places
# - files on disk but not listed in the tarball; note that this mode would
# require scanning the filesystem at some point in order to compare what's
# on disk and not in the tarball
# - all of the above reports
#
# output types:
# - simple - one file per line, with status flags in the left hand side
# - full - one line per file/directory attribute
# ! more - filename, date/time, size on one line, file attributes on the next
# line
#
# Objects
# - Role::Dir::Attribs - local/archive directory attributes
# - Role::FileDir::Attribs - local/archive file/directory attributes
# - Role::LocalFileDir - methods and attributes for interacting with local
# files; exists, local_path
# - Archive::File - a file in the archive
# - Archive::Directory - a directory in the archive, can contain one or more
# file and/or directory objects
# - Local::File - a file on the filesystem
# - Local::Directory - a directory on the filesystem, can contain one or more
# file and/or directory objects
# - Reporter - writes reports based on the type of report specified by the
# user

our @options = (
    # help/verbosity options
    q(help|h),
    q(debug|D|d),
    q(verbose|v),
    q(examples|x),
    q(morehelp|m),
    # script options
    q(dry-run|n), # don't mirror, just show steps that would be performed
    q(exclude|e=s@), # URLs to exclude when pulling from mirrors
    q(format|f=s), # reporting format
    q(path|p=s), # output path
    q(type|t=s@), # what type of information to report
    q(url|u=s), # URL to use for mirroring
    # logging options
    q(colorize), # always colorize logs, no matter if a pipe is present or not
    q(loglevel|log|level|ll=s),
    # misc options
    q(show-mirrors), # show the mirrors array and exit
    q(incoming), # show files in the /incoming directory
    q(dotfiles), # don't show dotfiles in reports - .filename
    q(headers), # show directory headers and blocks used
    q(tempdir=s), # temporary directory to use for tempfiles
    q(update-ls-lar), # update the ls-laR.gz file, then exit
    # combination options
    q(size-local|local-size|sl), # show size mismatches, missing local files
    q(size-same|ss), # show size mismatches and missing local files
);

=head1 OPTIONS

 perl idgames_mirror.pl [options]

 Help/verbosity options:
 -h|--help          Displays script options and usage
 -d|--debug         Sets logging level to DEBUG, tons of output
 -v|--verbose       Sets logging level to INFO, verbose output
 -x|--examples      Show examples of script execution
 -m|--morehelp      Show extended help info (format/type specifiers)

 Script options:
 -n|--dry-run       Don't mirror content, explain script actions instead
 -e|--exclude       Don't use these mirror URL(s) for syncing
 -p|--path          Path to mirror the idgames archive to
 -t|--type          Report type(s) to use for reporting (see --morehelp)
 -f|--format        Output format, [full|more|simple] (see --morehelp)
 -u|--url           Use a specific URL instead of a random mirror

 Logging options:
 --colorize         Always colorize log output (for piping log output)

 Misc. options:
 --show-mirrors     Show the current set of mirrors then exit
 --dotfiles         Show "hidden" files, Example: .message/.listing
 --headers          Show directory headers and blocks used in output
 --incoming         Show files located in the /incoming directory
 --tempdir          Temporary directory to use when downloading files
 --update-ls-lar    Update the local 'ls-laR.gz' file, then exit

=head1 DESCRIPTION

Using a current C<ls-lR.gz> listing file downloaded from an C<idgames> mirror
site, updates an existing copy of the C<idgames> mirror on the local host, or
create a new copy of the mirror on the local host if a copy does not exist.

Script normally exits with a 0 status code, or a non-zero status code if any
errors were encountered.

=head1 OBJECTS

=head2 idGames::Mirror::Config

Configure/manage script options using L<Getopt::Long>.

=head3 Methods

=over

=cut

package idGames::Mirror::Config;

use strict;
use warnings;
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
    if ( $self->get(q(help)) ) { pod2usage(-exitstatus => 1); }

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

print <<"EXAMPLES";

 Basic Usage Examples:

 $our_name --path /path/to/your/idgames/dir

 # use a different format
 $our_name --path /path/to/your/idgames/dir --format simple

 # use the "show what needs to be updated" shortcut (--size-local)
 $our_name --path /path/to/your/idgames/dir --format simple \
   --size-local --dry-run

 More Complex Usage Examples:

 # use a specific mirror, the 'more' output format
 $our_name --url http://example.com --format more \
    --path /path/to/your/idgames/dir

 # specific mirror, 'simple' output format, show missing local files
 # and files that are different sizes between local and the mirror
 $our_name --path /path/to/your/idgames/dir \
    --url http://example.com --format simple --type size --type local

 # same as above, with shortcut options
 $our_name --path /path/to/your/idgames/dir \
    --url http://example.com --format simple --size-local

 # use random mirrors, exclude a specific mirror
 $our_name --path /path/to/your/idgames/dir \
    --exclude http://some-mirror-server.example.com \
    --size-local --format more

 # use random mirrors, exclude a specific mirror,
 # specify temporary directory
 $our_name --path /path/to/your/idgames/dir \
    --exclude http://some-mirror-server.example.com \
    --size-local --format more --tempdir /path/to/temp/dir

EXAMPLES

}

=item show_morehelp

Show more help information on how to use the script and how the script
functions.

=cut

sub show_morehelp {

print <<MOREHELP;

 By default, the script will query a random mirror for each file that needs to
 be downloaded unless the --url switch is used to specify a specific mirror.

 Files located in the /incoming directory will not be mirrored by default
 unless --incoming is used.  Most FTP sites won't let you download/retrieve
 files from /incoming due to file/directory permissions on the FTP server;
 it's basically useless to try to download files from that directory, it will
 only generate errors.

 Report Types (for use with the --type switch):
 - headers - print directory headers and directory block sizes
 - local - files in the archive that are missing on local disk
 - archive - files on the local disk not listed in the archive
 - size - size differences between the local file and archive file
 - same - same size file exists on disk and in the archive
 - all - print all of the above information
 The default report type is: _all of the above_.

 Combined report types:
 --size-local   (size + local) Show file size mismatches, and files missing on
                local system
 --size-same    (size + same) Show all files, both valid files and size
                mismatched files

 Output formats (for use with the --format switch):
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

    if ( exists $args{$key} ) {
        if ( defined $args{$key} ) {
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

=item parent

The parent directory of this file/directory.

=back

=cut

has parent      => (
    is      => q(rw),
    isa     => q(Str),
);

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

use constant {
    IS_DIR      => q(D),
    IS_FILE     => q(F),
    IS_UNKNOWN  => q(?),
    IS_MISSING  => q(!),
    DIFF_SIZE   => q(S),
    LOGNAME     => __PACKAGE__,
};

my @_dotfiles = qw( .message .DS_Store .mirror_log .listing );

=head3 Attributes

=over

=item opts_path

The path to the local C</idgames> archive passed in by the user.

=cut

has opts_path => (
    is      => q(rw),
    isa     => q(Str),
);

=item absolute_path

The absolute path to this file or directory, from the filesystem root.

=cut

has absolute_path => (
    is      => q(rw),
    isa     => q(Str),
);

=item archive_obj

The Archive object that his object is based off of.

=cut

has archive_obj => (
    is      => q(rw),
    isa     => q(Object),
);

=item short_path

The short path to the file, made up of the filename, and any parent
directories above the file's directory.


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

=item long_status

A longer description than C<short_type> above.

=cut

has long_status => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
);

=item short_status

A single character that shows the file's status in relation to what's listed
in the archive.

=cut

has short_status => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
);

=item long_status

A longer description than C<short_status> above.

=cut

has long_status => (
    is      => q(rw),
    isa     => q(Str),
    default => q(),
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

=item new (BUILD)

Creates the object, and runs C<stat()> on the file/directory to see if it
exists on the filesystem.  Sets some extra attributes (below) based on whether
or not the file exists.

Required arguments:

=over

=item opts_path

The path on the local filesystem to the C<idgames> archive directory.

=item current_dir

The current directory in the archive.  As the archive file is parsed, a
directory will be listed, then all of the files in that directory will be
listed.  The script needs this directory so it knows where underneath the
C<opts_path> to look for the file that this object is trying to describe.

=item name

The name of the file or directory from the archive to look for on the local
filesystem.

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
    my $parent_dir = $archive->parent;
    # trim leading slash, it will be added back later
    $parent_dir =~ s/^\///;
    $self->parent($parent_dir);
    if ( length($self->parent) > 0 ) {
        $self->short_path($self->parent . q(/) . $self->name);
    } else {
        $self->short_path($self->name);
    }

    $self->absolute_path($self->opts_path . $self->short_path);
    $log->debug(qq(Creating stat object using local file/dir; ));
    $log->debug(q(Local file/dir: ) . $self->absolute_path);
    my $stat = stat( $self->absolute_path );

    unless ( defined $stat ) {
        # file doesn't exist
        $log->debug($archive->name . q( is not on the local system!));
        $self->short_type(IS_MISSING);
        $self->short_status(IS_MISSING);
        $self->long_status(q(Missing locally));
    } else {
        my $lsperms = File::Stat::Ls->new();
        $self->perms($lsperms->format_mode($stat->mode) );
        $self->hardlinks($stat->nlink);
        my $file_owner = getpwuid($stat->uid);
        my $file_group = getgrgid($stat->gid);
        $self->owner( $file_owner );
        $self->group( $file_group );
        $self->size($stat->size);
        my $mtime = time2str(q(%b %e %Y), $stat->mtime);
        # get rid of extra spaces in the output of time2str
        $mtime =~ s/\s{2,}/ /;
        $self->mod_time($mtime);

        # file does exist; what kind of file is it?
        if ( -f $stat ) {
            $self->short_type(IS_FILE);
            $self->short_status(IS_FILE);
            $log->debug($archive->name . q( is a file!));
            # check the size listed in the tarball versus the file size
            if ( $stat->size != $archive->size ) {
                $self->short_status(DIFF_SIZE);
                $self->long_status(q(Size mismatch));
                # for full dumps
                $self->append_notes(qq(Size mismatch; )
                    . q(archive size: ) . $archive->size . q( )
                    . q(local size: ) . $self->size . qq(\n));
            }
        } elsif ( -d $stat ) {
            $self->short_type(IS_DIR);
            $self->short_status(IS_DIR);
            $log->debug($self->name . q( is a directory!));
            $self->long_status(q(Directory));
        } else {
            $self->short_type(IS_UNKNOWN);
            $self->short_status(IS_UNKNOWN);
            $log->debug($self->name . q( is an unknown file!));
        }
    }
}

=item needs_sync

Tests to see if this file/directory object needs to be synchronized with the
mirror.  Returns C<1> for true if the file/directory needs to be synchronized,
and C<0> for false.

=cut

sub needs_sync {
    my $self = shift;

    my $log = Log::Log4perl->get_logger();

    if ( $self->short_status eq IS_MISSING ) {
        $log->debug(q(File is missing from local system:));
        $log->debug(q(-> ) . $self->absolute_path);
        return 1;
    } elsif ( $self->short_status eq DIFF_SIZE ) {
        $log->debug(q(Local file different size than archive:));
        $log->debug(q(-> ) . $self->absolute_path);
        return 1;
    } else {
        $log->debug(q(File/dir does not need to be sync'ed));
        $log->debug(q(-> ) . $self->absolute_path);
        return 0;
    }
}

=item sync

Syncs a remote file or directory to the local system.  Local directories are
created, local files are downloaded from the remote system.

=cut

sub sync {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();
    $log->logdie(qq(missing 'lwp' argument))
        unless ( defined $args{lwp} );
    $log->logdie(qq(missing 'sync_dotfiles' argument))
        unless ( defined $args{sync_dotfiles} );

    # exit if we're not printing dotfiles
    if ( $self->is_dotfile() ) {
        if ( $args{sync_dotfiles} == 0 ) {
            $log->debug(qq(Skipping sync of a dotfile));
            return 0;
        }
    }
    my $lwp = $args{lwp};
    if ( $log->is_debug() ) {
        $log->debug(qq(Simulated download of a file;));
        $log->debug(qq(Archive: ) . $lwp->get_base_url() . $self->short_path);
        $log->debug(qq(Local:   ) . $self->absolute_path );
        return 1;
    } else {
        if ( ref($self) eq q(Local::File) ) {
            my $temp_file = $lwp->fetch( filename => $self->short_path );
            if ( defined $temp_file ) {
                print qq(- Writing file: ) . $self->absolute_path . qq(\n);
                move($temp_file, $self->absolute_path );
            }
            return 1;
        } elsif ( ref($self) eq q(Local::Directory) ) {
            if ( -e $self->absolute_path ) {
                $log->debug(qq(Directory ) . $self->absolute_path
                    . qq( already exists));
            } else {
                if ( ! mkdir($self->absolute_path, q(0755)) ) {
                    $log->warn(q(Failed to create directory )
                        . $self->absolute_path);
                    $log->logdie(q(Error message: ) . $!);
                }
                return 1;
            }
        } else {
            $log->logdie(qq(Can't sync unknown object: ) . ref($self));
        }
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

=item is_dotfile

Tests to see if the current file/directory is a "dotfile", or a file that is
usually hidden on *NIX systems.  You usually don't care about these files,
unless you are building an exact replica of the mirror server.  Returns C<0>
false if the current object is not a dotfile, or C<1> true if the current
object I<is> a dotfile.

=cut

sub is_dotfile {
    my $self = shift;

    my $checkname = $self->name;
    # return the number of matches, 0 or 1
    return scalar(grep(/$checkname/, @_dotfiles));
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

A file downloaded/to be downloaded from the mirror.  This object inherits from
the L<Role::FileDir::Attribs> role.  See that role for a complete list of
inherited attributes and methods.

=cut

#########################
# package Archive::File #
#########################
package Archive::File;

use Mouse;

with qw(Role::FileDir::Attribs);

=head2 Archive::Directory

A directory downloaded/to be downloaded from the mirror.  This object inherits
from the L<Role::FileDir::Attribs> and L<Role::Dir::Attribs> roles.  See those
roles for a complete list of inherited attributes and methods.

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
    LOGNAME     => __PACKAGE__,
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
    LOGNAME     => __PACKAGE__,
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
    my $write_flag;

    # return unless...
    # - file is missing on local and 'local' is set
    # - file is missing in archive and 'archive' is set
    # - file is different sizes between local and archive, and 'size' is set
    # - file is the same size between local and archive, and 'same' is set
    # - 'all' is set
    # report types: headers:local:archive:size:same
    # missing files
    my $checkname = $a->name;
    my $grepcheck = scalar(grep(/$checkname/, @_dotfiles));
    if ( $l->short_status eq IS_MISSING ) {
        if ( $self->report_types =~ /local/ ) { $write_flag = 1; }
    }
    # different size files
    if ( $l->short_status eq DIFF_SIZE ) {
        if ( $self->report_types =~ /size/ ) { $write_flag = 1; }
    }
    # is a file/directory on the local filesystem
    if ( $l->short_status eq IS_FILE || $l->short_status eq IS_DIR ) {
        if ( $self->report_types =~ /same/ ) { $write_flag = 1; }
    }
    # is an unknown file on the local filesystem
    if ( $l->short_status eq IS_UNKNOWN ) {
        $write_flag = 1;
    }
    # skip dotfiles?
    if ( $l->is_dotfile == 1 && ! $self->show_dotfiles ) {
        $write_flag = 0;
    }
    return undef unless ( $write_flag );

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
    if ( $a->parent !~ /\./ ) {
        $filepath = $a->parent . q(/) . $a->name;
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
$a->parent . q(/) . $a->name
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
- @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$a->parent . q(/) . $a->name
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
use Mouse;
use Number::Format;

use constant {
    LOGNAME     => __PACKAGE__,
};

my @usable_mirrors;
# used for /newstuff

my @idgames_mirrors = qw(
    ftp://ftp.fu-berlin.de/pc/games/idgames
    ftp://ftp.ntua.gr/pub/vendors/idgames
    http://youfailit.net/pub/idgames
    http://www.gamers.org/pub/idgames
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
                $log->debug(LOGNAME
                    . qq(: Checking $exclude_test against $mirror_test));
                if ( $mirror_test =~ /$exclude_test/ ) {
                    $log->debug(LOGNAME . qq(: Excluding mirror $mirror_test));
                } else {
                    $log->debug(LOGNAME
                        . qq(: Adding $mirror_test to usable mirrors));
                    push(@usable_mirrors, $mirror_test);
                }
            }
        }
    } else {
        @usable_mirrors = @idgames_mirrors;
    }
    if ( $log->is_debug () ) {
        foreach my $um ( @usable_mirrors ) {
            $log->debug(LOGNAME . qq(: Usable mirror: $um));
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

    $log->debug(LOGNAME . qq(: get_base_url; returning: $base_url));
    return $base_url;
}

=item fetch

Required arguments:

=over

=item filename

The name of the file to download.

=back

Optional arguments:

=over

=item base_url

The base URL to use for downloading files.  Allows for recursive calls using
different URLs.

=back

The C<fetch()> method fetches files from the remote mirror.  Note that the
C<filename> argument should be fully qualified from the server's "document
root", i.e.  given a URL of C<http://example.com>, your C<$filename> should be
something like C<path/to/file>, so that the full URL would become
C<http://example.com/path/to/file>.

The downloaded file is saved with a temporary name in the directory that was
passed in as C<tempdir> when the object was created (or the default
L<File::Temp> directory if no C<tempdir> was used), and this temporary name is
returned if the download was successful (HTTP 200).  If any errors were
encountered, then the method returns C<undef>.

=cut

sub fetch {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    $log->logdie(qq(missing 'filename' argument))
        unless ( exists $args{filename} );

    my $filename = $args{filename};
    my $base_url = $args{base_url};
    # set a base URL if one was not set by the caller
    if ( ! defined $base_url ) {
        $base_url = $self->get_base_url;
    }

    # if the user didn't pass in a URL, pick one at random

    # remove leading slash
    if ( $filename !~ /^\// ) {
        $filename = q(/) . $filename;
    }

    # arguments for creating temp files
    my %temp_args = (
        UNLINK      => 0,
        TEMPLATE    => q(idgm.XXXXXXXX),
        SUFFIX      => q(.tmp),
    );

    # add a temporary directory?
    if ( defined $self->tempdir ) {
        $temp_args{DIR} = $self->tempdir;
    }

    # create a tempfile for the download
    my $fh = File::Temp->new( %temp_args );
    $log->debug(LOGNAME . qq(: Created temp file ) . $fh->filename );

    # for formatting downloaded file sizes
    my $nf = Number::Format->new();

    # grab the file
    $log->debug(LOGNAME . qq(: Fetching file: )
        . $base_url . $filename . qq(\n));
    print qq(- Fetching file: ) . $base_url . $filename . qq(\n);
    my $ua = $self->user_agent();
    my $response = $ua->get(
        $base_url . $filename,
        q(:content_file) => $fh->filename,
    );
    if ( $response->is_error() ) {
        $log->warn(qq(Error downloading '$filename'; ));
        $log->warn(q(Response status: ) . $response->status_line() );
        my $master_mirror = $self->master_mirror;
        if ( $response->code() == 404 && $base_url !~ /$master_mirror/ ) {
            $log->warn(qq(Retrying download of: $filename ));
            $log->warn(qq(from ) . $self->master_mirror );
            # recursive call here, make another try with the master mirror
            return $self->fetch(
                filename => $filename,
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
        print q(- Download successful; downloaded )
            . $nf->format_bytes($size)
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
    $log->logdie(qq(missing 'synced_files' argument))
        unless ( exists $args{synced_files} );
    $log->logdie(qq(missing 'total_archive_files' argument))
        unless ( exists $args{total_archive_files} );
    $log->logdie(qq(missing 'total_archive_size' argument))
        unless ( exists $args{total_archive_size} );

    my $total_synced_bytes = 0;
    my @synced_files = @{$args{synced_files}};
    print qq(Calculating runtime statistics...\n);
    foreach my $synced ( @synced_files ) {
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
    $output .= scalar(@synced_files) . qq(\n);
    if ( $self->dry_run ) {
        $output .= qq(- Total bytes to be synced from archive: );
    } else {
        $output .= qq(- Total bytes synced from archive: );
    }
    $output .= $nf->format_bytes($total_synced_bytes) . qq(\n);
    $output .= qq(- Total script execution time: )
        . tv_interval ( $start_time, $stop_time ) . qq( seconds\n);
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
use Digest::MD5; # comparing the ls-laR.gz files
use File::Copy;
use Getopt::Long;
use IO::File;
use IO::Uncompress::Gunzip qw($GunzipError);
use Log::Log4perl qw(get_logger :no_extra_logdie_message);
use LWP::UserAgent;
use Mouse; # sets strict and warnings


use constant {
    DEBUG_LOOPS => 100,
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
my $report_types = q(headers:local:archive:size:same);
my $report_format = q(more);


=head1 DESCRIPTION

Script normally exits with a 0 status code, or a non-zero status code if any
errors were encountered.

=cut

    # force writes in output to STDOUT
    $| = 1;
    my $cfg = idGames::Mirror::Config->new();

    if ( defined $cfg->get(q(help)) ) {
        pod2usage( { -verbose => 1, -exitval => 0, -input => __FILE__ } );
    }

    if ( defined $cfg->get(q(examples)) ) {
        show_examples();
        exit 0;
    }

    # parent directory
    my $parent = q();
    # flag set whenever we're parsing files in/beneath the /incoming directory
    my $incoming_dir_flag = 0;
    #if ( defined $cfg->get(q(incoming)} ) {
    #    $incoming_dir_flag = 1;
    #} else {
    #    $incoming_dir_flag = 0;
    #}


    # default log level
    my $log4perl_conf = qq(log4perl.rootLogger = WARN, Screen\n);
    if ( $cfg->defined(q(verbose)) && $cfg->defined(q(debug)) ) {
        die(q(Script called with --debug and --verbose; choose one!));
    } elsif ( $cfg->defined(q(debug)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = DEBUG, Screen\n);
    } elsif ( $cfg->defined(q(verbose)) ) {
        $log4perl_conf = qq(log4perl.rootLogger = INFO, Screen\n);
    }

    # color log output
    if ( -t STDOUT || $cfg->defined(q(colorize))) {
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
        . qq|= [%6r] %p{1} %L (%M{1}) %m%n\n|;

    Log::Log4perl->init(\$log4perl_conf);
    my $log = Log::Log4perl->get_logger();
    $log->debug(__FILE__ . qq(: script start; ) . time2str(q(%C), time));

    my @exclude_urls;
    if ( $cfg->defined(q(exclude)) ) {
        @exclude_urls = @{$cfg->get(q(exclude))};
    }

    # set a temporary directory; this directory is used when downloading
    # files, LWP::Wrapper downloads to the file directly instead of
    # downloading to an object in memory
    if ( ! $cfg->defined(q(tempdir)) ) {
        if ( defined $ENV{TEMP} ) {
            # FIXME need to set taint mode, and untaint the environment
            # variables used below
            $cfg->set(q(tempdir)) = $ENV{TEMP};
            $log->debug(__FILE__ . q(: setting tempdir to )
                . $cfg->get(q(tempdir)));
        } elsif ( defined $ENV{TMP} ) {
            $cfg->set(q(tempdir), $ENV{TMP});
        } elsif ( defined $ENV{TMPDIR} ) {
            $cfg->set(q(tempdir), $ENV{TMPDIR})
        } else {
            $cfg->set(q(tempdir), q(/tmp));
        }
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

    $log->logdie(q(Must specify path directory with --path))
        unless ( $cfg->defined(q(path)) );
    # append a forward slash on to the URL so other paths don't need the
    # forward slash later on
    if ( $cfg->get(q(path)) !~ /\/$/ ) {
        $cfg->set(q(path), $cfg->get(q(path)) . q(/));
    }

    ### REPORT TYPES
    if ( $cfg->defined(q(type)) ) {
        my @reports = @{$cfg->get(q(type))};
        my @requested_types;
        foreach my $type ( @reports ) {
            if ( $report_types =~ /$type/ ) {
                $log->logdie(qq(Report type '$type' is not a valid report));
            } else {
                push(@requested_types, $type);
            }
        }
        $report_types = join(q(:), @requested_types);
    }
    if ( $cfg->defined(q(size-local)) ) {
        if ( $cfg->defined(q(type)) ) {
            $log->warn(qq(--size-local overrides any --type options used));
        }
        $report_types = q(size:local);
    }
    if ( $cfg->defined(q(size-same)) ) {
        if ( $cfg->defined(q(type)) ) {
            $log->warn(qq(--size-same overrides any --type options used));
        }
        $report_types = q(size:same);
    }

    ### REPORT FORMATS
    if ( $cfg->defined(q(format)) ) {
        $report_format = $cfg->get(q(format));
    }

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
    my $total_archive_files = 0;
    my $total_archive_size = 0;
    my $dl_file;
    my $lslar_file = $cfg->get(q(path)) . q(ls-laR.gz);
    $log->debug(qq(Set lslar_file to $lslar_file));
    if ( ! -r $lslar_file ) {
        $log->logdie(qq(Can't read file $lslar_file));
    }

    ### UPDATE LS-LAR.GZ
    if ( ! $cfg->defined(q(dry-run)) ) {
        $log->debug(qq(Fetching 'ls-laR.gz' file listing));
        # if a custom URL was specified, use that here instead
        my $lslar_url = $lwp->master_mirror;
        if ( $cfg->defined(q(url)) ) {
            $lslar_url = $cfg->get(q(url));
        }
        # returns undef if there was a problem fetching the file
        $dl_file = $lwp->fetch(
            filename => q(ls-laR.gz),
            base_url => $lslar_url,
        );
        if ( ! defined $dl_file ) {
            $log->logdie(qq(Could not download ls-laR.gz file));
        }

        my $in_fh = IO::File->new(qq(< $lslar_file));
        my $file_digest;
        # create the digest object outside of any nested blocks
        my $md5 = Digest::MD5->new();
        # get the digest for the local file, if the local file exists
        if ( defined $in_fh ) {
            $md5->addfile($in_fh);
            # note this resets the digest contained in $md5
            $file_digest = $md5->hexdigest();
        } else {
            # if there's no previous copy of the archive on disk, just use
            # a bogus string for the checksum
            $file_digest = q(bogus file digest);
        }
        # close the local file filehandle
        $in_fh->close();
        # get the digest for the downloaded file
        my $dl_fh = IO::File->new(qq(< $dl_file));
        # $md5 has already been reset with the call to hexdigest() above
        $md5->addfile($dl_fh);
        my $content_digest = $md5->hexdigest();
        # close the filehandle
        $dl_fh->close();
        # check to see if the downloaded ls-laR.gz file is the same file
        # on disk by comparing MD5 checksums for the buffer and file
        if ( $file_digest ne $content_digest ) {
            #my $out_fh = IO::File->new(qq(> $lslar_file));
            print qq(- ls-laR.gz Checksum mismatch...\n);
            print qq(- Local copy: $file_digest\n);
            print qq(- Archive copy: $content_digest\n);
            print qq(- Replacing file: $lslar_file\n);
            print qq(- With file: $dl_file\n);
            move($dl_file, $lslar_file);
        } else {
            print qq(- $lslar_file and mirror copy match!\n);
            $log->debug(qq(Unlinking $dl_file));
            unlink $dl_file;
        }
        # exit here if --update-ls-lar was used
        if ( $cfg->defined(q(update-ls-lar)) ) {
            print qq(- ls-laR.gz downloaded, exiting program\n);
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

    # parse the ls-laR.gz file
    my $counter = 0;
    my $current_dir;
    BUFFER: foreach my $line ( split(/\n/, $buffer) ) {
        # skip blank lines
        next if ( $line =~ /^$/ );
        $log->debug(qq(line: $line));
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
            $log->debug(qq(Reassembled filename: '$name_field'));
        }
        if ( $fields[PERMS] =~ /^-.*/ ) {
            $total_archive_files++;
            # skip this file if it's inside the /incoming directory
            next if ( $incoming_dir_flag && ! $cfg->defined(q(incoming)) );
            my $archive_file = Archive::File->new(
                parent          => $current_dir,
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
            my $local_file = Local::File->new(
                opts_path       => $cfg->get(q(path)),
                archive_obj    => $archive_file,
            );
            $report->write_record(
                archive_obj    => $archive_file,
                local_obj      => $local_file,
            );
            if ( $local_file->needs_sync() ) {
                if ( $cfg->defined(q(dry-run)) ) {
                    $log->debug(q(dry-run is set; parsing next line...));
                    push(@synced_files, $archive_file);
                } else {
                    my $sync_status = $local_file->sync(
                            lwp             => $lwp,
                            sync_dotfiles   => $cfg->get(q(dotfiles))
                    );
                    if ( $sync_status ) {
                        # add the file to the list of synced files
                        # used later on in reporting
                        push(@synced_files, $archive_file);
                    }
                }
            }
        # the directory bit is set in the listing output
        } elsif ( $fields[PERMS] =~ /^d.*/ ) {
            # skip this directory if it's inside the /incoming directory
            next if ( $incoming_dir_flag && ! $cfg->defined(q(incoming)) );
            my $archive_dir = Archive::Directory->new(
                parent          => $current_dir,
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
            my $local_dir = Local::Directory->new(
                opts_path       => $cfg->get(q(path)),
                archive_obj    => $archive_dir,
            );
            $report->write_record(
                archive_obj    => $archive_dir,
                local_obj      => $local_dir,
            );
            if ( $local_dir->needs_sync() ) {
                if ( ! $cfg->defined(q(dry-run)) ) {
                    $local_dir->sync(
                        lwp             => $lwp,
                        sync_dotfiles   => $cfg->get(q(dotfiles)),
                    );
                }
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
        $counter++;
        if ( $log->is_debug() ) {
            if ( $counter == DEBUG_LOOPS ) {
                last BUFFER;
            }
        }
    } # foreach my $line ( split(/\n/, $buffer) )
    $stats->stop_timer();
    $stats->write_stats(
        synced_files            => \@synced_files,
        total_archive_files     => $total_archive_files,
        total_archive_size      => $total_archive_size,
    );
    exit 0;

=head1 AUTHOR

Brian Manning, C<< <brian at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-idGamesMirror/issues>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I make
changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc idgames_mirror.pl

You can also look for information at:

=over 4

=item * App::idGamesMirror GitHub project page

L<https://github.com/spicyjack/App-idGamesMirror>

=item * App::idGamesMirror GitHub issues page

L<https://github.com/spicyjack/App-idGamesMirror/issues>

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
