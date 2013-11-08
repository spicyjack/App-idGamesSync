######################################
# package App::idGamesSync::Reporter #
######################################
package App::idGamesSync::Reporter;

=head1 App::idGamesSync::Reporter

A tool that outputs file/directory information based on the methods used by
the caller, i.e.  if there is files missing on the local system, then the
L</"missing_local"> method would be called and the
L<App::idGamesSync::Reporter> object will display the information about the
missing file.  This object consumes the L<Role::Reports> role.

=cut

use Mouse;
use constant {
    IS_DIR      => q(D),
    IS_FILE     => q(F),
    IS_UNKNOWN  => q(?),
    IS_MISSING  => q(!),
    DIFF_SIZE   => q(S),
};

=head2 Attributes

=over

=item report_types

A reference to an array containing the types of reports the reporter should
print.  Defaults to the contents of C<default_report_types> attribute.

=cut

has report_types => (
    is      => q(rw),
    isa     => q(ArrayRef[Str]),
    default => sub{ [qw(size local)] },
);

=item report_format

The report format to use when writing reports. Defaults to the C<more> format.

=cut

has report_format => (
    is      => q(rw),
    isa     => q(Str),
    default => q(more),
);

=item default_report_types

A reference to an array containing the default report types, currently
C<size:local>.

=cut

has default_report_types => (
    is      => q(ro),
    isa     => q(ArrayRef[Str]),
    default => sub{ [qw(size local)] },
);

=item valid_report_types

A reference to an array of B<valid> report types.  Specifying a report type
not on this list will cause the script to exit with an error.

=cut

has valid_report_types => (
    is      => q(ro),
    isa     => q(ArrayRef[Str]),
    default => sub{ [qw(headers local archive size same)] },
);

=item default_report_format

The default report format, currently C<more>.

=cut

has default_report_format => (
    is      => q(ro),
    isa     => q(Str),
    default => q(more),
);

=item valid_report_formats

A reference to an array of B<valid> report formats.  Specifying a report type
not on this list will cause the script to exit with an error.

=cut

has q(valid_report_formats) => (
    is      => q(rw),
    isa     => q(ArrayRef[Str]),
    default => sub{ [qw(full more simple)] },
);

=item show_dotfiles

Show dotfiles in the output listings.  C<0> means don't show dotfiles, and
C<1> means show dotfiles.  Default is C<0>, don't show dotfiles.

=cut

has show_dotfiles => (
    is      => q(ro),
    isa     => q(Bool),
    default => 0,
);

=back

=head2 Methods

=over

=item BUILD() (aka 'new')

Creates the L<App::idGamesSync::Reporter> object, which is used to write the
information about local/archived files and directories to C<STDOUT>.

Optional arguments:

=over

=item show_dotfiles

Boolean flag that indicates whether or not to show dotfiles in script output.
Defaults to C<0>, false.

=back

=cut

sub BUILD {
    my $self = shift;
    my $log = Log::Log4perl->get_logger();
}

=item write_record()

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
        if ( scalar(grep(/local/, @{$self->report_types})) > 0 ) {
            $log->debug(qq($checkname: missing locally));
            $write_report_flag = 1;
        }
    }

    # different size files
    if ( $l->short_status eq DIFF_SIZE ) {
        if ( scalar(grep(/size/, @{$self->report_types})) > 0
            && ! $l->is_metafile ) {
            $log->debug(qq($checkname: different sizes between archive/local));
            $write_report_flag = 1;
        }
    }

    # is a file/directory on the local filesystem
    if ( $l->short_status eq IS_FILE || $l->short_status eq IS_DIR ) {
        if ( scalar(grep(/same/, @{$self->report_types})) > 0 ) {
            $log->debug(qq($checkname: same size between archive/local));
            $write_report_flag = 1;
        }
    }

    # is an unknown file on the local filesystem
    if ( $l->short_status eq IS_UNKNOWN ) {
        $write_report_flag = 1;
        $log->debug(qq($checkname: is unknown));
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

=item format_simple()

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

    my ($month, $date, $year_time) = $self->split_mod_time(file_obj => $a);

format SIMPLE =
@@ @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @<< @> @<<<< @#########
$l->short_type, $l->short_status, $filepath, $month, $date, $year_time, $a->size
.
    # set the current $FORMAT_NAME to the SIMPLE format
    $~ = q(SIMPLE);
    write();
}

=item format_more()

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

    my $notes = q();
        if ( length($l->long_status) > 0 ) {
        $notes = q(Notes:);
    }

    my ($a_month, $a_date, $a_year_time) =
        $self->split_mod_time(file_obj => $a);
    my ($l_month, $l_date, $l_year_time) =
        $self->split_mod_time(file_obj => $l);

### BEGIN FORMAT
format MORE =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$a->parent_path . q(/) . $a->name
  archive: @>>>>>>>>> @>>>>>>> @>>>>>>> @>> @> @<<<< @######## @<<<<<<<<<<<<<<
$a->perms, $a->owner, $a->group, $a_month, $a_date, $a_year_time, $a->size, $notes
  local:   @>>>>>>>>> @>>>>>>> @>>>>>>> @>> @> @<<<< @######## @<<<<<<<<<<<<<<
$l->perms, $l->owner, $l->group, $l_month, $l_date, $l_year_time, $l->size, $l->long_status
.
### END FORMAT

    # set the current $FORMAT_NAME to the MORE format
    $~ = q(MORE);
    write();
}

=item format_full()

Reports on the difference between the archive file and the file on the local
system, in a very verbose three line format; the first line is the name of the
archive file, each subsequent line displays one attribute of both the archive
file and the local file, if the local file exists.

=cut

sub format_full {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    my $l = $args{local_obj};
    my $a = $args{archive_obj};

    my ($a_month, $a_date, $a_year_time) =
        $self->split_mod_time(file_obj => $a);
    my ($l_month, $l_date, $l_year_time) =
        $self->split_mod_time(file_obj => $l);

### BEGIN FORMAT
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
  mtime:       @>>> @> @>>>>    mtime:       @>>> @> @>>>>
  $a_month, $a_date, $a_year_time, $l_month, $l_date, $l_year_time
  size:        @############    size:        @############
  $a->size, $l->size
  Notes: @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
  $l->notes
.
### END FORMAT

    # set the current $FORMAT_NAME to the FULL format and write report
    $~ = q(FULL);
    write();

}

=item split_mod_time()

Splits a file's C<mod_time> attribute into separate month, date, and year or
time elements, and returns those elements as a list.  Splitting the fields
like this makes it so the fields can be aligned in the output reports.

=back

=cut

sub split_mod_time {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    my $file = $args{file_obj};
    my $file_time = $file->mod_time;
    my ($month, $date, $year_time);
    if ( $file->mod_time ne q(!!!) ) {
        ($month, $date, $year_time) =  split(/ /, $file->mod_time);
    } else {
        ($month, $date, $year_time) =  qw(!!! !! !!!!!);
    }
    return ($month, $date, $year_time);
}

1;
