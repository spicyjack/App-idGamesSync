##########################################
# package App::idGamesSync::RuntimeStats #
##########################################
package App::idGamesSync::RuntimeStats;

=head1 App::idGamesSync::RuntimeStats

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

use Moo;
use Number::Format; # pretty output of bytes
use Time::HiRes qw( gettimeofday tv_interval );

my ($start_time, $stop_time);

=head2 Attributes

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

=head2 Methods

=over

=item start_timer()

Starts the internal timer, used to measure total script execution time.

=cut

sub start_timer {
    $start_time = [gettimeofday];
}

=item stop_timer()

Stops the internal timer, used to measure total script execution time.

=cut

sub stop_timer {
    $stop_time = [gettimeofday];
}

=item write_stats()

Output the runtime stats from the script.

=back

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
        unless ( exists $args{newstuff_deleted_count} );

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
    $output .= qq(- Total files currently in /newstuff directory: );
    $output .= $args{newstuff_file_count} . qq(\n);
    $output .= qq(- Total old files deleted from /newstuff directory: );
    $output .= $args{newstuff_deleted_count} . qq(\n);
    # if non_wad_file_count is not passed in, don't try to display it
    if ( exists $args{non_wad_file_count} ) {
        $output .= q(- Total non-WAD files that could be sync'ed)
            . q( from idGames Archive: );
        $output .= $args{non_wad_file_count} . qq(\n);
    }
    $output .= qq(- Total script execution time: )
        . sprintf('%0.2f', tv_interval ( $start_time, $stop_time ) )
        . qq( seconds\n);
    print $output;
}

1;
