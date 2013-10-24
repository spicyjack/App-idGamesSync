##############################################
# package App::idGamesSync::ArchiveDirectory #
##############################################
package App::idGamesSync::ArchiveDirectory;

=head1 App::idGamesSync::ArchiveDirectory

A directory synchronized/to be synchronized from the mirror.  This object
inherits from the L<App::idGamesSync::Role::FileDirAttribs> and
L<App::idGamesSync::Role::DirAttribs> roles.  See those roles for a complete
list of inherited attributes and methods.

=cut

use Mouse;

with qw(
    App::idGamesSync::Role::FileDirAttribs
    App::idGamesSync::Role::DirAttribs
);

1;
