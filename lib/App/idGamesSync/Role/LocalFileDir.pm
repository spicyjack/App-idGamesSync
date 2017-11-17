################################################
# package App::idGamesSync::Role::LocalFileDir #
################################################
package App::idGamesSync::Role::LocalFileDir;

=head1 App::idGamesSync::Role::LocalFileDir

Methods and attributes used for interacting with a file or directory on the
local filesystem.

=cut

use Moo::Role;
use Date::Format;
use File::Copy;
use File::stat; # OO wrapper around stat()
use Scalar::Util qw(blessed);
use Stat::lsMode; # conversion tools for the file/dir modes

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

=head2 Attributes

=over

=item opts_path

The path to the local C</idGames> archive passed in by the user.

=cut

has opts_path => (
    is      => q(rw),
    isa     => sub { defined($_) },
);

=item archive_obj

The Archive object that this object is based off of.

=cut

has archive_obj => (
    is      => q(rw),
    # checks to see if the object being set is "blessed" in Perl
    isa     => sub { blessed($_) },
);

=item absolute_path

The absolute path to this file or directory, from the drive/filesystem root.

=cut

has absolute_path => (
    is      => q(rw),
    isa     => sub { defined($_) },
);


=item short_path

The short path to the file, made up of the filename, and any parent
directories above the file's directory.  Note that the path separatator will
change depending on what platform this script is run on (C</> for *NIX, C<\>
for Windows).

=cut

has short_path => (
    is      => q(rw),
    isa     => sub { defined($_) },
);

=item short_type

A single character that denotes what this object is; a file, a directory,
missing from the filesystem, or 'unknown'.

=cut

has short_type => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(),
);

=item short_status

A single character that shows the file's status on the local system, whether
the file is present or not, or if the size of the file on the local system
does not match the size of the file in the archive.

=cut

has short_status => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(),
);

=item long_status

A short summary of the file's status, used in more verbose reports.

=cut

has long_status => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(),
);

=item url_path

The path that can be used to build a valid URL to the resource on any
C<idGames> mirror server.  This path always has forward slashes, as opposed to
C<short_path>, which has slashes based on what platform the script is
currently running on.

=cut

has url_path => (
    is      => q(rw),
    isa     => sub { defined($_) },
);

=item needs_sync

A flag that is set when this file or directory needs to be synchronized.

=cut

has needs_sync => (
    is      => q(rw),
    isa     => sub { defined $_ && $_ =~ /0|1|y|n|t|f/i },
    default => q(0),
);

=item notes

A string that contains extra information about the file/directory.

=back

=cut

has notes => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(),
);

=head2 Methods

=over

=item BUILD() (aka 'new')

Creates an object that has consumed the
L<App::idGamesSync::Role::LocalFileDir> role.  This object would be used to
keep track of attributes of a local file or directory.  Sets up different
"shortcuts", or file/directory attributes that would be commonly used when
interacting with this object (aboslute path, parent path, short name, etc.)

Required arguments:

=over

=item opts_path

The path on the local filesystem to the C<idGames> archive directory.

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
        # translate output from 'stat()' into something human readable
        $self->perms(format_mode($stat->mode) );
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
        #if ( -f $stat )
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
    $log->debug(q(Short type/status: )
        . $self->short_type . q(/) . $self->short_status);
}

=item sync()

Syncs a remote file or directory to the local system.  Local directories are
created, local files are synchronized from the remote system.  Returns C<1> if
the file was synchronized (downloaded to the local system as a tempfile and
renamed with the same name and location in the archive as the copy on the
mirror), or in the case of directories, the directory was created
successfully, returns a C<0> otherwise.

=cut

sub sync {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();
    $log->logdie(qq(missing 'lwp' argument))
        unless ( defined $args{lwp} );

    my $lwp = $args{lwp};
    $log->debug(q(Syncing file/dir ') . $self->name . q('));
    if ( ref($self) eq q(App::idGamesSync::LocalFile) ) {
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
    } elsif ( ref($self) eq q(App::idGamesSync::LocalDirectory) ) {
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

=item exists()

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
        return;
    }
}

=item append_notes()

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

=item is_mswin32()

Boolean flag that is set when running under Windows platforms.

=cut

has is_mswin32 => (
    is      => q(rw),
    isa     => sub { defined $_ && $_ =~ /0|1|y|n|t|f/i },
);

=item is_newstuff()

Boolean flag that is set when the current file is located in the C</newstuff>
directory.

=back

=cut

has is_newstuff => (
    is      => q(rw),
    isa     => sub { defined $_ && $_ =~ /0|1|y|n|t|f/i },
    default => q(0),
);

1;
