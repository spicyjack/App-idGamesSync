##############################################
# package App::idGamesSync::Role::DirAttribs #
##############################################
package App::idGamesSync::Role::DirAttribs;

=head1 App::idGamesSync::Role::DirAttribs

A role that contains attributes for a local or remote directory.
Currently, this is only the total blocks used by this directory.

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

=item total_blocks

The total blocks used by this directory and the contents of this directory on
disk or in the archive file.

=back

=cut

has total_blocks    => (
    is      => q(rw),
    isa     => $INTEGER,
);

1;
