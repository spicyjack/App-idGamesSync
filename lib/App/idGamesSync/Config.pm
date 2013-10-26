package App::idGamesSync::Config;
use strict;
use warnings;
use English qw( -no_match_vars );
use Mouse;
use Pod::Usage; # prints POD docs when --help is called

=head1 App::idGamesSync::Config

Configure/manage script options using L<Getopt::Long>.

=head2 Attributes

=over

=item optoions

An C<ArrayRef> to an array containing script options, in L<Getopt::Long> format.

=cut

has q(options) => (
    is      => q(rw),
    isa     => q(ArrayRef[Str]),
);

=back

=head2 Methods

=over

=item new() (aka BUILD)

Creates the L<App::idGamesSync::Config> object, parses options from the
command line via L<Getopt::Long>, and returns the object to the caller.
=cut

sub BUILD {
    my $self = shift;

    # can't continue without script options in Getopt::Long format
    die qq(Missing 'options' array to Config object)
        unless ( defined $self->options );

    # script arguments
    my %args;

    # parse the command line arguments (if any)
    my $parser = Getopt::Long::Parser->new();

    # pass in a reference to the args hash as the first argument
    $parser->getoptions( \%args, @{$self->options} );

    # assign the args hash to this object so it can be reused later on
    $self->{_args} = \%args;

    # set a flag if we're running on 'MSWin32'
    if ( $OSNAME eq q(MSWin32) ) {
        $self->set(is_mswin32 => 1);
    }

    # return this object to the caller
    return $self;
}

=item get($key)

Returns the scalar value of the key passed in as C<key>, or C<undef> if the
key does not exist in the L<App::idGamesSync::Config> object.

=cut

sub get {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) { return $args{$key}; }
    return undef;
}

=item set(key => $value)

Sets in the L<App::idGamesSync::Config> object the key/value pair passed in
as arguments.  Returns the old value if the key already existed in the
L<App::idGamesSync::Config> object, or C<undef> otherwise.

=cut

sub set {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    if ( exists $args{$key} ) {
        my $oldvalue   = $args{$key};
        $args{$key}    = $value;
        $self->{_args} = \%args;
        return $oldvalue;
    } else {
        $args{$key}    = $value;
        $self->{_args} = \%args;
    } # if ( exists $args{$key} )
    return undef;
}

=item get_args( )

Returns a hash containing the parsed script arguments.

=cut

sub get_args {
    my $self = shift;
    # hash-ify the return arguments
    return %{$self->{_args}};
}

=item defined($key)

Returns "true" (C<1>) if the value for the key passed in as C<key> is
C<defined>, and "false" (C<0>) if the value is undefined, or the key doesn't
exist.

=back

=cut

sub defined {
    my $self = shift;
    my $key = shift;
    # turn the args reference back into a hash with a copy
    my %args = %{$self->{_args}};

    # Can't use Log4perl here, since it hasn't been set up yet
    if ( exists $args{$key} ) {
        #warn qq(exists: $key\n);
        if ( defined $args{$key} ) {
            #warn qq(defined: $key; ) . $args{$key} . qq(\n);
            return 1;
        }
    }
    return 0;
}

1;

=head1 AUTHOR

Brian Manning, C<< <brian at xaoc dot org> >>

=head1 BUGS

Please report any bugs or feature requests to
L<https://github.com/spicyjack/App-idGamesSync/issues>.  I will be notified,
and then you'll automatically be notified of progress on your bug as I make
changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

perldoc idgames_sync.pl

You can also look for information at:

=over 4

=item * App::idGamesSync GitHub project page

L<https://github.com/spicyjack/App-idGamesSync>

=item * App::idGamesSync GitHub issues page

L<https://github.com/spicyjack/App-idGamesSync/issues>

=back

=head1 ACKNOWLEDGEMENTS

Perl, the Doom Wiki L<http://www.doomwiki.org> for lots of the documentation,
all of the various Doom source porters, and id Software for releasing the
source code for the rest of us to make merry mayhem with.

=head1 COPYRIGHT & LICENSE

Copyright (c) 2013 Brian Manning, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
