package ZCS::Config;

use strict;
use warnings;

use IO::File ();
use JSON::PP ();

our $ERROR;

sub new {
    my ( $class, %arg ) = ( shift, @_ );
    my $self = bless( {}, ref($class) || $class );

    if ( defined $arg{file} ) {
        return undef unless $self->file( $arg{file} );
    }

    return $self;
}

sub file {
    my ( $self, $file ) = @_;

    if ( defined $file ) {
        $self->{_file} = $file;
        unless ( $self->load ) {
            delete( $self->{_file} );
            return undef;
        }
    }

    return $self->{_file};
}

sub get {
    my $self = shift;

    $ERROR = "";
    my $result = $self->_find( $self->{_config}, @_ );

    return $result if ( defined $result );

    if ( $ERROR ne "" ) {
        $ERROR = "Config does not contain: " . $ERROR;
    }

    return undef;
}

sub _find {
    my ( $self, $src, $value ) = ( shift, shift, shift );

    if ( exists $src->{$value} ) {
        if (@_) {
            return $self->_find( $src->{$value}, @_ );
        }
        else {
            if ( ref $src->{$value} ) {
                return $src->{$value};    # should clone the object and return
                                          # but no Clone module around
            }
            else {
                return $src->{$value};
            }
        }
    }

    $ERROR = $value;
    return undef;
}

sub hash {
    return $_[0]->{_config};
}

sub load {
    my $self = shift;
    my $file = $self->file;
    if ( -f $file ) {
        local $/;
        if ( my $fh = IO::File->new( "< " . $file ) ) {
            my $json = <$fh>;
            local $@;
            $self->{_config} = eval { JSON::PP->new->utf8->decode($json) };
            if ($@) {
                my $tmp = $@;
                $tmp =~ s/[\s\n]*$//;
                $self->error($tmp);
                return undef;
            }
            else {
                $fh->close;
            }
        }
        else {
            $self->error("could not open $file to read");
            return undef;
        }
    }
    else {
        $self->error( $file . " does not exist" );
        return undef;
    }
    return 1;
}

sub error {
    $ERROR = $_[1] if ( $#_ == 1 );
    return $ERROR;
}

1;
