##################################################
# package App::idGamesSync::Role::FileDirAttribs #
##################################################
package App::idGamesSync::Role::FileDirAttribs;

=head1 App::idGamesSync::Role::FileDirAttribs

A role that contains attributes for a local or remote file or directory.
Things like filename, full path, owner/group, permissions, size, etc.

=cut

use Moo::Role;
use Type::Tiny;

my $INTEGER = "Type::Tiny"->new(
   name       => q(Integer),
   constraint => sub { $_ =~ /\d+/ },
   message    => sub { qq($_ ain't an Integer) },
);


=head2 Attributes

=over

=item perms

Permissions of the file/directory.

=cut

has perms       => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(----------),
);

=item hardlinks

Number of hard links back to this file/directory.

=cut

has hardlinks   => (
    is      => q(rw),
    isa     => $INTEGER,
    default => 0,
);

=item owner

Name of the owner of the file/directory.

=cut

has owner       => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(!!!),
);

=item group

Name of the group of the file/directory.

=cut

has group       => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(!!!),
);


=item size

Size of the file/directory.

=cut

has size        => (
    is      => q(rw),
    isa     => $INTEGER,
    default => 0,
);


=item mod_time

Modification date of the file/directory.

=cut

has mod_time    => (
    is      => q(rw),
    isa     => sub { defined($_) },
    default => q(!!!),
);

=item name

Name of the file/directory.

=cut

has name        => (
    is      => q(rw),
    isa     => sub { defined($_) },
);

=item parent_path

The parent_path directory of this file/directory.

=cut

has parent_path      => (
    is      => q(rw),
    isa     => sub { defined($_) },
);

=item dotfiles

A regular expression reference of filenames that match "dotfiles" or files
that are meant to be hidden on *NIX platforms.  These files are usually used
to store text messages that are displayed in FTP/HTTP directory listings.

=cut

has dotfiles      => (
    is      => q(ro),
    default => sub {qr/\.message|\.DS_Store|\.mirror_log|\.listing/;}
);

=item metafiles

A regular expression that describes a set of files ("metadata files") that
should usually be downloaded from the master mirror, unless C<--url>
is used, in which case, these files will be downloaded from the mirror server
specified with C<--url>.

=cut

has metafiles => (
    is      => q(ro),
    default => sub {
        qr/ls-laR\.gz|LAST\.\d+\w+|fullsort\.gz|REJECTS|README\.*/;},
);

=item wad_dirs

A regular expression that describes directories where C<WAD> files are stored
inside of the C<idGames> Mirror.

=cut

has not_wad_dirs => (
    is      => q(ro),
    default => sub {
        # regex that covers all "non-WAD" directories
        my $levels = q(^docs|^graphics|^history|^idstuff|^levels/reviews);
        $levels .= q(|^lmps|^misc|^music|^prefabs|^roguestuff|^skins);
        $levels .= q(|^sounds|^source|^themes/terrywads|^utils);
        # regex that covers all levels directories
        #my $levels = q(^combos|^deathmatch);
        #$levels .= q(|^levels/[doom|doom2|hacx|heretic|hexen|strife]);
        # going to implement this as an attribute/boolean flag; this will let
        # it be reused later on when capturing the contents of the /newstuff
        # directory, in order to get a list of files to delete
        #$levels .= q(|^newstuff);
        return qr/$levels/;
    },
);

=back

=head2 Methods

=over

=item is_dotfile()

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

=item is_metafile()

Tests to see if the current file/directory is a "metafile", or a
meta-information file.  The current list of "meta" files includes the
following (with Perl-style regular expressions showing what search text is
used to match meta filenames):

=over

=item ls-laR.gz

=item LAST.\d+\w+

=item fullsort.gz

=item REJECTS

=item README

=back

Returns C<0> false if the current object is not a
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

=item is_wad_dir()

Tests to see if the current directory is in a "WAD directory", or a directory
known to have C<WAD> files inside of it.  Returns C<0> false if the directory
is not a C<WAD> directory, or C<1> true if the directory does have C<WAD>
files inside of it.

=back

=cut

sub is_wad_dir {
    my $self = shift;
    my $not_wad_dirs_regex = $self->not_wad_dirs;

    #my $log = Log::Log4perl->get_logger();
    #$log->debug(qq(Checking: ) . $self->short_path);
    #$log->debug(qq(With regex: $wad_dirs_regex));

    if ( $self->short_path =~ /$not_wad_dirs_regex/ ) {
        #$log->debug($self->short_path . qq( is *NOT* a WAD dir));
        return 0;
    } else {
        #$log->debug($self->short_path . qq( is a WAD dir));
        return 1;
    }
}

1;
