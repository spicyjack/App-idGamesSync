#######################################
# package App::idGamesSync::LocalFile #
#######################################
package App::idGamesSync::LocalFile;

=head1 App::idGamesSync::LocalFile

A file on the local filesystem.  This object inherits from the
L<App::idGamesSync::Role::FileDirAttribs> and
L<App::idGamesSync::Role::LocalFileDir> roles.  See those roles for a complete
list of inherited attributes and methods.

=cut

use Mouse;

with qw(
    App::idGamesSync::Role::FileDirAttribs
    App::idGamesSync::Role::LocalFileDir
);

1;
