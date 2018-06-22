package ZCS::API::SOAP;

use strict;
use warnings;

our $DEBUG = 0;
our $ERROR = '';

use XML::SAX;
use ZCS::API::SOAP::SAX;

=head1 NAME

ZCS::API::SOAP - perl module for accessing Zimbra SOAP API through SOAP

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

=head2 mime

=cut

sub mime {
    my $self = shift;
    $self->{_mime} = shift if ( defined( $_[0] ) );
    unless ( exists( $self->{_mime} ) ) {
        $self->{_mime} = "application/soap+xml;charset=UTF-8";
    }
    return $self->{_mime};
}

=head2 sax 

=cut

sub sax {
    my $self = shift;
    unless ( exists( $self->{_sax} ) ) {
        $self->{_sax} =
          XML::SAX::ParserFactory->parser(
            Handler => ZCS::API::SOAP::SAX->new );
    }
    return $self->{_sax};
}

=head2 escape_text

=cut

sub escape_text {
    my $self = shift;
    my $text = shift;
    $text =~ s{\&}{\&amp;}gm;
    $text =~ s{<}{\&lt;}gm;
    $text =~ s{>}{\&gt;}gm;
    return $text;
}

=head2 tohash

Converts SOAP to a hash value.

=cut

sub tohash {
    my $self = shift;
    my $soap = shift;
    return $self->sax->parse_string($soap);
}

=head2 fromhash

Converts a hash value to SOAP.

=cut

sub fromhash {
    my $self = shift;
    my $hash = shift;

    my $namespace = "soap";

    my $mesg = "<"
      . $namespace
      . ":Envelope xmlns:soap=\"http://www.w3.org/2003/05/soap-envelope\">";
    foreach my $key ( keys %$hash ) {
        $mesg .= $self->_hash( $namespace . ":" . $key, $hash->{$key} );
    }
    $mesg .= "</" . $namespace . ":Envelope>";
    return $mesg;
}

sub _hash {
    my $self  = shift;
    my $name  = shift;
    my $value = shift;
    my $mesg  = "";
    if ( ref($value) eq "ARRAY" ) {
        foreach my $item (@$value) {
            $mesg .= $self->_hash( $name, $item );
        }
    }
    elsif ( ref($value) eq "HASH" ) {
        my $content = 0;
        $mesg .= "<" . $name;

        # add all parameters
        foreach my $key ( keys %$value ) {
            next if ( $key eq "_content" );
            if ( ref( $value->{$key} ) eq "" ) {
                my $prop = $key;
                if ( $key eq "_jsns" ) {
                    $prop = "xmlns";
                }
                $mesg .= " " . $prop . "=\"" . $value->{$key} . "\"";
            }
            else {
                $content = 1;
            }
        }

        # process content
        if ( exists( $value->{_content} ) ) {
            $mesg .= ">";
            $mesg .= $self->escape_text( $value->{_content} );
            $mesg .= "</" . $name . ">";
        }
        elsif ($content) {
            $mesg .= ">";
            foreach my $key ( keys %$value ) {
                unless ( ref( $value->{$key} ) eq "" ) {
                    $mesg .= $self->_hash( $key, $value->{$key} );
                }
            }
            $mesg .= "</" . $name . ">";
        }
        else {
            $mesg .= "/>";
        }
    }
    else {
        print STDERR "This should not happen investigate why\n";
    }
    return $mesg;
}

1;
