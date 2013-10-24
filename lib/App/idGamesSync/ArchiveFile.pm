#########################################
# package App::idGamesSync::ArchiveFile #
#########################################
package App::idGamesSync::ArchiveFile;

=head1 App::idGamesSync::ArchiveFile

A file synchronized/to be synchronized from the mirror.  This object inherits
from the L<App::idGamesSync::Role::FileDirAttribs> role.  See that role for a
complete list of inherited attributes and methods.

=cut

use Mouse;

with qw(App::idGamesSync::Role::FileDirAttribs);

1;
