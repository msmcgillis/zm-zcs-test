package ZCS::API::JSON;

use strict;
use warnings;

use JSON::PP;

our $DEBUG = 0;
our $ERROR = '';

=head1 NAME

ZCS::API::JSON - perl module for accessing Zimbra SOAP API through JSON

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;
    return $self;
}

=head2 debug

=cut

sub debug {
    $DEBUG = $_[1] if ( @_ > 1 );
    return $DEBUG;
}

=head2 error

=cut

sub error {
    $ERROR = $_[1] if ( @_ > 1 );
    return $ERROR;
}

=head2 json

=cut

sub json {
    my $self = shift;
    unless ( exists( $self->{_json} ) ) {
        $self->{_json} = JSON::PP->new();
    }
    return $self->{_json};
}

=head2 mime

=cut

sub mime {
    my $self = shift;
    $self->{_mime} = shift if ( defined( $_[0] ) );
    unless ( exists( $self->{_mime} ) ) {
        $self->{_mime} = "application/soap+json;charset=UTF-8";
    }
    return $self->{_mime};
}

=head2 tohash

Converts JSON to a hash value.

=cut

sub tohash {
    my $self = shift;
    my $json = shift;
    return $self->json->decode($json);
}

=head2 fromhash

Converts a hash value to JSON.

=cut

sub fromhash {
    my $self = shift;
    my $hash = shift;
    return $self->json->encode($hash);
}

1;
