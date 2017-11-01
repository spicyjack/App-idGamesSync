############################################
# package App::idGamesSync::LocalDirectory #
############################################
package App::idGamesSync::LocalDirectory;

=head1 App::idGamesSync::LocalDirectory

A directory on the local filesystem.  This object inherits from the
L<App::idGamesSync::Role::DirAttribs>,
L<App::idGamesSync::Role::FileDirAttribs> and
L<App::idGamesSync::Role::LocalFileDir> roles.  See those roles for a complete
list of inherited attributes and methods.

=cut

use Moo;

with qw(
    App::idGamesSync::Role::DirAttribs
    App::idGamesSync::Role::FileDirAttribs
    App::idGamesSync::Role::LocalFileDir
);

=head2 Attributes

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

1;
