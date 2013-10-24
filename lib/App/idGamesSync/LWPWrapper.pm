########################################
# package App::idGamesSync::LWPWrapper #
########################################
package App::idGamesSync::LWPWrapper;

=head1 App::idGamesSync::LWPWrapper

A wrapper around LWP::UserAgent, which handles fetching files via HTTP/FTP and
then handling response codes from servers, if any.

=cut

use File::Temp;
use LWP::UserAgent;
use URI::Escape;
use Mouse;
use Number::Format;

my @usable_mirrors;
my @idgames_mirrors = qw(
    ftp://ftp.fu-berlin.de/pc/games/idgames
    ftp://ftp.ntua.gr/pub/vendors/idgames
    ftp://ftp.mancubus.net/pub/idgames/
    http://youfailit.net/pub/idgames
);

=head2 Attributes

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

URLs to exclude from the built in list of C<idGames> mirror servers.  Use this
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

=item url_regex

Regex to get different bits of the URL back, to be used in script/debug output.

=cut

has q(url_regex) => (
    is      => q(ro),
    isa     => q(RegexpRef),
    # $1 = scheme, $2 = host, $3 is path
    default => sub {qr!^(ftp|http|https){1}://([\w.-]+)/??(.*)*$!;}
);

=item tempdir

Temporary directory to use for downloading files.  Defaults to C<undef>, which
will cause L<File::Temp> to use it's built-in default.

=back

=cut

has q(tempdir) => (
    is      => q(rw),
    isa     => q(Str),
);

=head2 Methods

=over

=item new() (aka BUILD)

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
                $log->debug(qq(: Checking $exclude_test against $mirror_test));
                if ( $mirror_test =~ /$exclude_test/ ) {
                    $log->debug(qq(: Excluding mirror $mirror_test));
                } else {
                    $log->debug(qq(: Adding $mirror_test to usable mirrors));
                    push(@usable_mirrors, $mirror_test);
                }
            }
        }
    } else {
        @usable_mirrors = @idgames_mirrors;
    }
    if ( $log->is_debug () ) {
        foreach my $um ( @usable_mirrors ) {
            $log->debug(qq(Usable mirror: $um));
        }
    }
}

=item get_random_mirror()

Returns a random mirror server from a list of "valid" mirror servers, i.e. the
built-in list of mirror servers minus servers excluded via the C<--exclude>
command line switch.

=cut

sub get_random_mirror {
    my $self = shift;
    my $url_index = rand(@usable_mirrors);
    return $usable_mirrors[$url_index];
}

=item get_base_url()

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

    # $1 = scheme, $2 = host, $3 is path
    $base_url =~ $self->url_regex;
    $log->debug(qq(Returning base URL host: '$2'));
    return $base_url;
}

=item fetch()

Required arguments:

=over

=item filepath

The "relative path" of the file to download, which is combined with the "base
path" in order to determine the full URL.

=back

Optional arguments:

=over

=item base_url

The base URL to use for downloading files.  This allows for recursive fetching
using different base URLs.

=back

The C<fetch()> method fetches files from the remote mirror.  Note that the
C<filepath> argument should be fully qualified from the server's "document
root", i.e.  given a URL of C<http://example.com>, your C<$filepath> should be
something like C<path/to/file>, so that the full URL would become
C<http://example.com/path/to/file>.

The synchronized file is saved with a temporary name in the directory that was
passed in as C<tempdir> when the object was created (or the default
L<File::Temp> directory if no C<tempdir> was used), and this temporary name is
returned if the download was successful (HTTP 200).  If any errors were
encountered, then the method returns C<undef>.

=cut

sub fetch {
    my $self = shift;
    my %args = @_;

    my $log = Log::Log4perl->get_logger();

    $log->logdie(qq(missing 'filepath' argument))
        unless ( exists $args{filepath} );

    my $filepath = $args{filepath};
    my $base_url = $args{base_url};

    # set a base URL if one was not set by the caller
    # if $self->base_url is undefined, a random mirror will be chosen
    if ( ! defined $base_url ) {
        $base_url = $self->get_base_url;
    }

    # remove leading slash
    if ( $filepath !~ /^\// ) {
        $filepath = q(/) . $filepath;
    }

    my $filename = (split(/\//, $filepath))[-1];
    # create a tempfile for the download
    my $fh = File::Temp->new(
        # don't unlink files by default; this should be done by the caller
        UNLINK      => 0,
        DIR         => $self->tempdir,
        TEMPLATE    => qq(idgs.$filename.XXXXXXXX),
        SUFFIX      => q(.tmp),
    );
    $log->debug(qq(Created temp file ) . $fh->filename );

    # grab the file
    # $1 = scheme, $2 = host, $3 is path
    $base_url =~ $self->url_regex;
    print qq(- Fetching file '$filepath' from '$2'\n);
    my $ua = $self->user_agent();
    my $encoded_url = $base_url
        . uri_escape_utf8($filepath, qq(^A-Za-z0-9\-\._~\/));
    $log->debug(qq(Encoded URL: $encoded_url));
    my $response = $ua->get(
        $encoded_url,
        q(:content_file) => $fh->filename,
    );
    if ( $response->is_error() ) {
        $log->warn(qq(Error downloading '$filepath'; ));
        $log->warn(q(Response status: ) . $response->status_line() );
        $log->debug(q(Deleting tempfile ) . $fh->filename );
        unlink $fh->filename;
        undef $fh;
        my $master_mirror = $self->master_mirror;
        if ( $base_url !~ /$master_mirror/ ) {
            $log->warn(qq(Retrying download of: $filepath ));
            # $1 = scheme, $2 = host, $3 is path
            $self->master_mirror =~ $self->url_regex;
            $log->warn(qq(from $2));
            # recursive call here, make another try with the master mirror
            return $self->fetch(
                filepath => $filepath,
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
        # for formatting synchronized file sizes
        my $nf = Number::Format->new();
        print q(- Download successful, downloaded ) . $nf->format_bytes($size)
            . qq| byte(s)\n|;
        return $fh->filename;
    }
}

=item get_mirror_list()

Returns a list of C<idGames> mirror servers.

=back

=cut

sub get_mirror_list {
    return @idgames_mirrors;
}

1;
