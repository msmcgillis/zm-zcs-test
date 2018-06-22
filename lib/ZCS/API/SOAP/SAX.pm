package ZCS::API::SOAP::SAX;

use base qw(XML::SAX::Base);

=head1 NAME

ZCS::API::SOAP::SAX SAX parser module to generate json compatabile hash from SOAP.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 start_document

Set up internal structures to store hash representations of SOAP.

=cut

sub start_document {
    my ( $self, $doc ) = @_;
    $self->{prev} = [];
    $self->{cur} = $self->{tree} = {};
}

=head2 start_element

Save each element to hash. Set current element to new element, and store current element in previous array to restore from end_element.

=cut

sub start_element {
    my ( $self, $element ) = @_;
    my $name = $element->{Name};
    $name =~ s/.*://;
    my $tmp = {};
    if ( $element->{Attributes} ) {    # Might be undef
        foreach my $attr ( values %{ $element->{Attributes} } ) {
            my $key = $attr->{Name};
            $key = "_jsns" if ( $key eq "xmlns" );
            $tmp->{$key} = $attr->{Value};
        }
    }
    push( @{ $self->{prev} }, $self->{cur} );
    if ( exists( $self->{cur}{$name} ) ) {
        if ( ref( $self->{cur}{$name} ) eq HASH ) {
            my $hold = $self->{cur}{$name};
            $self->{cur}{$name} = [ $hold, $tmp ];
            $self->{cur} = $tmp;
        }
        else {
            push( @{ $self->{cur}{$name} }, $tmp );
            $self->{cur} = $tmp;
        }
    }
    else {
        $self->{cur}{$name} = $tmp;
        $self->{cur} = $self->{cur}{$name};
    }
}

=head2 characters

Save each elements text to hash.

=cut

sub characters {
    my $self  = shift;
    my $chars = shift;
    $self->{cur}{_content} .= $chars->{Data};
}

=head2 end_element

Restore previous element stored from start_element.

=cut

sub end_element {
    my $self = shift;
    $self->{cur} = pop @{ $self->{prev} };
}

=head2 end_document

Return the hash of all data and remove all internal storage values.

=cut

sub end_document {
    my $self = shift;
    delete( $self->{cur} );
    delete( $self->{prev} );
    my $tree = $self->{tree};
    delete( $self->{tree} );
    return $tree->{Envelope};
}

1;
