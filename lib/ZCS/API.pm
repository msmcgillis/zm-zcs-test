package ZCS::API;

use strict;
use warnings;

our $VERSION = '0.01';
our $DEBUG    = 0;
our $WARN     = 0;
our $RETRY    = 0;
our $ERROR    = '';
our $AUTOLOAD = '';

use Data::Dumper;
use LWP::UserAgent;
use ZCS::API::JSON;
use ZCS::API::SOAP;
use ZCS::API::Zimbra;

BEGIN {

    # avoid self signed SSL certificate rejection
    $ENV{"PERL_LWP_SSL_VERIFY_HOSTNAME"} = 0;

    # avoid default SSL_verify_mode SSL_VERIFY_NONE deprecated warning
    use LWP::Protocol::http ();
    @LWP::Protocol::http::EXTRA_SOCK_OPTS = ( SSL_verify_mode => 0 );
}

my $UUIDRE = '^[\da-f]{8}-[\da-f]{4}-[\da-f]{4}-[\da-f]{4}-[\da-f]{12}$';

=head1 NAME

ZCS::API - perl module for accessing Zimbra SOAP API

=head1 SYNOPSIS

  use ZCS::API;

  my $zapi = ZCS::API->new();
  ...

=head1 DESCRIPTION

Open Issues to think about/work.
1) Config Object (pull out from ZCS API other than a access path to a standard config object see ZCS::Config as possible replacement)
2) Group ZCS::API::Zimbra Methods by (Admin, User)
3) Consider better processing around when delegate auth is used (test and evaluate functionality of a simple user using this versus a admin user and how best to support)
4) remove the call method in ZCS::API
5) make the retry code in submit configurable

=head1 METHODS

=head2 new

Created new ZCS::API object.

=cut

sub new {
    my $class = shift;
    my $self = bless( {}, ref($class) || $class );

    if ( @_ % 2 ) {
        $self->error("new: invalid arguments");
        return undef;
    }
    my @args = @_;
    my ( $err, $key, $val );
    for ( my $i = 0 ; $i < $#args ; $i += 2 ) {
        ( $key, $val ) = ( $args[$i], $args[ $i + 1 ] );
        local ($@);
        eval {
            my $func = "arg_$key";
            warn( ref($self), "->new calling $func($val)\n" )
              if $DEBUG;
            $self->$func($val);
        };
        $err = $@;
        last if $err;
    }
    if ($err) {
        chomp($err);
        $self->error("new: $key($val) failed: $err");
        return undef;
    }

    # attempt to populate conf via ENV if necessary
    return undef unless ( $self->conf );

    # make sure we can initialize zimbra
    $self->zimbra;

    return $self;
}

=head2 arg_conf

support setting conf from new with a conf parameter.

=cut

sub arg_conf { shift->conf(@_); }

=head2 arg_debug

support setting debug from new.

=cut

sub arg_debug { shift->debug(@_); }

=head2 debug

Enables debug output.

  $za->debug(1);  # enabled
  $za->debug(0);  # disabled

=cut

sub debug {
    $DEBUG = $_[1] if ( @_ > 1 );
    return $DEBUG;
}

=head2 warn

Enables warning output.

Will generate warning messages for retry and reauth attentemts.

  $za->warn(1);  # enabled
  $za->warn(0);  # disabled

=cut

sub warn {
    $WARN = $_[1] if ( @_ > 1 );
    return $WARN;
}

=head2 retry

Sets number of times to automaticly retry requests.

  $za->retry(3);  # retry 3 additional times
  $za->retry(0);  # no retry on failure

=cut

sub retry {
    $RETRY = $_[1] if ( @_ > 1 );
    return $RETRY;
}

=head2 error

Returns last error message encountered.

  print $za->error."\n";
  print ZCS::API->error."\n";

=cut

sub error {
    $ERROR = $_[1] if ( @_ > 1 );
    return $ERROR;
}

=head2 conf_envprefix

Returns the prefix for looking up configuration values from a users environment.

This is currently set to Z so if you have ZSOAPURI defined in your environment then that value would get used if no other value was found.

=cut

# prefix "keys" with "Z" to use as environment variables
sub conf_envprefix { return "Z" }

=head2 conf_keys

Returns the required configuration values for this module.

=over

=item SOAPURI

=item SOAPUser

=item SOAPPass

=back

=cut

sub conf_keys { return qw(SOAPURI SOAPUser SOAPPass); }

=head2 conf

Attempts to initialize the required config values.

=cut

sub conf {
    my ( $self, $conf ) = @_;
    if ( !exists( $self->{_conf} ) ) {
        if ( @_ > 1 ) {
            unless ( ref($conf) eq "HASH" ) {
                $self->error( ref($self) . "->conf argument not a HASHREF" );
                return undef;
            }
        }
        else {
            $conf = {};
        }
        my @req = $self->conf_keys;
        my @err;
        foreach my $k (@req) {
            unless ( exists( $conf->{$k} ) && defined( $conf->{$k} ) ) {
                my $evar = uc( $self->conf_envprefix . $k );
                $conf->{$k} = $ENV{$evar} if ( defined $ENV{$evar} );
            }
            my $v = $conf->{$k};
            push( @err, $k ) unless ( defined($v) );
        }
        if (@err) {
            $self->error(
                ref($self) . "->conf: missing info: " . join( ", ", @err ) );
            return undef;
        }
        $self->{_conf} = $conf;
    }
    return $self->{_conf};
}

=head2 lwp

Creats LWP::UserAgent object and caches.

Returns the LWP::UserAgent object.

=cut

sub lwp {
    my $self = shift;
    unless ( exists( $self->{_lwp} ) ) {
        $self->{_lwp} = LWP::UserAgent->new();
    }
    return $self->{_lwp};
}

=head2 type([SOAP|JSON])

Creats ZCS::API::* object and caches.

Returns the ZCS::API::* object.

* is either SOAP or JSON.

defaults to JSON.

Note: the first time this is called caches the object and can not be changed once it exists.

=cut

sub type {
    my $self = shift;
    my $type = shift || "JSON";
    unless ( exists( $self->{_type} ) ) {
        my $module = "ZCS::API::" . $type;
        $self->{_type} = $module->new();
    }
    return $self->{_type};
}

=head2 zimbra

Creats ZCS::API::Zimbra object if one doesn't exist and caches.

Returns the ZCS::API::Zimbra object.

=cut

sub zimbra {
    my $self = shift;
    unless ( exists( $self->{_zimbra} ) ) {
        my $module = "ZCS::API::Zimbra";
        unless ( $self->{_zimbra} = $module->new($self) ) {
            $self->error( "Failed to new $module: " . $module->error );
            return undef;
        }
    }
    return $self->{_zimbra};
}

=head2 submit(hash)

Convert hash to type format protocol and send HTTP request to server SOAP API.

We should remove retry code or make it configurable to enable or disable. Only a subset of errors are worth retrying so this becomes a waist of time in many cases. The retry is useful in some situations like our huge batch jobs with very loaded servers but that is an edge case to me.

=cut

sub submit {
    my $self = shift;
    my $hash = shift;

    my $resp = $self->_reauth($hash);
    unless ($resp) {

        # support retrying request up to retry times
        if ( $self->retry ) {
            my ( $try, $sec ) = ( 0, 0 );
            while ( !$resp && $try++ < $self->retry ) {
                my $resp = $self->_reauth($hash);
                $sec += $try;    # back off a little more on each retry
                CORE::warn( "try#$try sleep($sec) error: " . $self->error )
                  if ( $self->warn );
                sleep($sec);
            }
        }
    }
    return $resp;
}

# Support updating credentials when they expire
sub _reauth {
    my $self = shift;
    my $hash = shift;

    my $resp = $self->_do($hash);
    unless ($resp) {
        if ( $self->error =~ /auth credentials have expired/ ) {
            CORE::warn( "reauth triggered by: " . $self->error )
              if ( $self->warn );
            if ( my $header = $self->reauth( $hash->{Header} ) ) {
                $hash->{Header} = $header;
                $resp = $self->_do($hash);
            }
            else {
                return undef;
            }
        }
    }
    return $resp;
}

# basic http request response to server.
sub _do {
    my $self = shift;
    my $hash = shift;

    my $req = HTTP::Request->new( POST => $self->conf->{SOAPURI} );
    $req->content_type( $self->type->mime );
    my $mesg = $self->type->fromhash($hash);

    if ( $self->debug ) {
        print "Hash Request: " . Dumper($hash) . "\n";
        print "HTTP Request: " . $mesg . "\n";
    }

    $req->content($mesg);
    my $resp = $self->lwp->request($req);
    my $rhash = $self->type->tohash( $resp->content ) if ( defined($resp) );

    if ( $self->debug ) {
        print "HTTP Response: " . $resp->content . "\n";
        print "HASH Response: " . Dumper($rhash) . "\n" if ( defined($resp) );
    }

    if ( !$resp->is_success ) {
        my $name = ( keys %{ $hash->{Body} } )[0];
        $self->error(
            "error: $name: "
              . (
                defined($rhash)
                ? $self->fault($rhash)
                : $resp->status_line
              )
        );
        return undef;
    }
    return $rhash;
}

=head2 header

Get auth token from auth request and cache header with token for future calls.

  my $atest = $za->header;

Uses the account configured through the config file. If it is not a admin account all admin functionality will fail.

=cut

sub header {
    my $self = shift;
    unless ( exists( $self->{_zimbra_header} ) ) {

        # authenticate with zimbra to get AuthToken
        my $hash =
          $self->auth( $self->conf->{SOAPUser}, $self->conf->{SOAPPass} );
        return undef unless $hash;

        # Convert authToken into value that can be passed to zimbra requests
        # and cache for all future requests
        my $token = "";
        if ( ref( $hash->{Body}{AuthResponse}{authToken} ) eq "ARRAY" ) {
            $token = $hash->{Body}{AuthResponse}{authToken}[0]{_content};
        }
        else {
            $token = $hash->{Body}{AuthResponse}{authToken}{_content};
        }
        $self->{_zimbra_header} = {
            context => {
                _jsns     => "urn:zimbra",
                authToken => { _content => $token }
            }
        };
        if ( ref( $self->type ) eq "ZCS::API::JSON" ) {
            $self->{_zimbra_header}{format} = { type => "js" };
        }
    }
    return $self->{_zimbra_header};
}

=head2 delegateheader(account)

Get auth token from delegate auth request and cache header with token for future calls.

  my $autest = $za->delegateheader("test@domain.com");

Requires an admin account be used from auth and a admin URI. 

=cut

sub delegateheader {
    my ( $self, $account ) = @_;

    unless ( exists( $self->{_zimbra_delegateheader}{$account} ) ) {
        my $hash = $self->delegateauth($account);
        return undef unless $hash;

        # Convert authToken into value that can be passed to zimbra requests
        # and cache for all future requests
        my $token = "";
        if ( ref( $hash->{Body}{DelegateAuthResponse}{authToken} ) eq "ARRAY" )
        {
            $token =
              $hash->{Body}{DelegateAuthResponse}{authToken}[0]{_content};
        }
        else {
            $token = $hash->{Body}{DelegateAuthResponse}{authToken}{_content};
        }
        $self->{_zimbra_delegateheader}{$account} = {
            context => {
                _jsns     => "urn:zimbra",
                authToken => { _content => $token }
            }
        };
        $self->{_zimbra_delegateheader}{$account}{format} = { type => "js" }
          if ( ref( $self->type ) eq "ZCS::API::JSON" );
    }
    return $self->{_zimbra_delegateheader}{$account};
}

=head2 reauth(header)

Must pass either the header value or delegateheader value that you want to reauthenticate.

This shouldn't ever need to be called directly call should detect when a
token is no longer valid and automatically attempt to generate a new one
using this method.

  $za->reauth($self->header);                         # re-auth admin
  $za->reauth($self->delegateheader("test@test.com")) # re-auth "test@test.com"

=cut

sub reauth {
    my ( $self, $auth ) = @_;
    if ( $auth == $self->{_zimbra_header} ) {
        delete( $self->{_zimbra_header} );
        return $self->header;
    }
    elsif ( exists( $self->{_zimbra_delegateheader} ) ) {
        foreach my $account ( keys %{ $self->{_zimbra_delegateheader} } ) {
            if ( $auth == $self->{_zimbra_delegateheader}{$account} ) {
                delete( $self->{_zimbra_delegateheader}{$account} );
                return $self->delegateheader($account);
            }
        }
    }
}

=head2 fault(hash)

Returns the fault text from the hash response.

=cut

sub fault {
    my $self  = shift;
    my $hash  = shift;
    my $fault = "";
    if ( ref( $hash->{Body}{Fault}{Reason}{Text} ) eq "HASH" ) {
        $fault = $hash->{Body}{Fault}{Reason}{Text}{_content};
    }
    else {
        $fault = $hash->{Body}{Fault}{Reason}{Text};
    }
    return $fault;
}

=head2 token(account)

Returns current delegated auth authtoken for specified account.

If account is not specified returns the current authtoken for the user specified in the configuration file.

=cut

sub token {
    my ( $self, $account ) = @_;

    if ($account) {
        unless ( exists( $self->{_zimbra_delegateheader}{$account} ) ) {
            return undef unless $self->delegateheader($account);
        }
        return $self->{_zimbra_delegateheader}{$account}{context}
          {authToken}{_content};
    }
    else {
        unless ( exists( $self->{_zimbra_header} ) ) {
            return undef unless $self->header;
        }
        return $self->{_zimbra_header}{context}{authToken}{_content};
    }
}

=head2 resturl(account)

returns the rest URL for the sepecified account

=cut

sub resturl {
    my ( $self, $account ) = @_;
    my $result = $self->getinfo($account);
    return $result->{Body}{GetInfoResponse}{rest};
}

=head2 getrest(account,path)

Simple equivelant of zmmailbox getRestURL. Not an actual JSON or REST call but we have everything available to easly make rest calls from this API.

=cut

sub getrest {
    my ( $self, $account, $path ) = @_;

    my $url = $self->resturl($account) . $path;
    print "HTTP Get: " . $url . "\n" if ( $self->debug );
    my $req = HTTP::Request->new( GET => $url );
    $req->header( Cookie => "ZM_AUTH_TOKEN=" . $self->token($account) );
    my $resp = $self->lwp->request($req);
    print "HTTP Response: " . $resp->content . "\n" if ( $self->debug );
    if ( !$resp->is_success ) {
        $self->error( $resp->status_line );
        return undef;
    }
    return $resp->content;
}

=head2 getaccountid(acct)

Can either pass a string of the users e-mail address or the results from getaccount request.

=cut

sub getaccountid {
    my ( $self, $value ) = @_;

    if ( $value =~ /\@/ ) {    # account name get Zimbra HASH to find id
        $value = $self->getaccount($value);
    }
    if ( ref($value) eq "HASH" ) {
        my $id = "";
        if ( ref( $value->{Body}{GetAccountResponse}{account} ) eq "ARRAY" ) {
            $id = $value->{Body}{GetAccountResponse}{account}[0]{id};
        }
        else {
            $id = $value->{Body}{GetAccountResponse}{account}{id};
        }
        $value = $id;
    }

    return $value;
}

=head2 getdistributionlistid(acct)

Can either pass a string of the distribution list e-mail address or the results from getdistributionlist request.

=cut

sub getdistributionlistid {
    my ( $self, $value ) = @_;

    if ( $value =~ /\@/ ) {    # account name get Zimbra HASH to find id
        $value = $self->getdistributionlist($value);
    }
    if ( ref($value) eq "HASH" ) {
        my $id = "";
        if ( ref( $value->{Body}{GetDistributionListResponse}{dl} ) eq "ARRAY" )
        {
            $id = $value->{Body}{GetDistributionListResponse}{dl}[0]{id};
        }
        else {
            $id = $value->{Body}{GetDistributionListResponse}{dl}{id};
        }
        $value = $id;
    }

    return $value;
}

=head2 getcosid(cos)

Can either pass a string of the cos name, id, or the results from getcos
request.

=cut

sub getcosid {
    my ( $self, $value ) = @_;

    if (
        ref($value) eq "" &&    # passed a SCALAR
        $value !~ /$UUIDRE/i
      )
    {                           # not UUID so assume name
        $value = $self->getcos($value);
    }
    if ( ref($value) eq "HASH" ) {
        my $id = "";
        if ( ref( $value->{Body}{GetCosResponse}{cos} ) eq "ARRAY" ) {
            $id = $value->{Body}{GetCosResponse}{cos}[0]{id};
        }
        else {
            $id = $value->{Body}{GetCosResponse}{cos}{id};
        }
        $value = $id;
    }

    return $value;
}

=head2 getserverid(server)

Can either pass a string of the server name, id, or the results from getserver
request.

=cut

sub getserverid {
    my ( $self, $value ) = @_;

    if (
        ref($value) eq "" &&    # passed a SCALAR
        $value !~ /$UUIDRE/i
      )
    {                           # not UUID so assume name
        $value = $self->getserver($value);
    }
    if ( ref($value) eq "HASH" ) {
        my $id = "";
        if ( ref( $value->{Body}{GetServerResponse}{server} ) eq "ARRAY" ) {
            $id = $value->{Body}{GetServerResponse}{server}[0]{id};
        }
        else {
            $id = $value->{Body}{GetServerResponse}{server}{id};
        }
        $value = $id;
    }

    return $value;
}

=head2 getfolderid(account,path)

Can either pass a string of the path name, id, or the results from getfolder
request.

=cut

sub getfolderid {
    my ( $self, $account, $value ) = @_;

    if (
        ref($value) eq "" &&    # passed a SCALAR
        $value !~ /\d/
      )
    {                           # not ID so assume name
        $value = $self->getfolder( $account, $value );
    }
    if ( ref($value) eq "HASH" ) {
        my $id = "";
        if ( ref( $value->{Body}{GetFolderResponse}{folder} ) eq "ARRAY" ) {
            $id = $value->{Body}{GetFolderResponse}{folder}[0]{id};
        }
        else {
            $id = $value->{Body}{GetFolderResponse}{folder}{id};
        }
        $value = $id;
    }

    return $value;
}

=head2 DESTROY

place holder to avoid issues with autoload.

=cut

sub DESTROY {
}

=head2 AUTOLOAD

Support calling all methods available in ZCS::API::Zimbra;

=cut

sub AUTOLOAD {
    my $self   = shift;
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;
    if ( $self->zimbra->can($method) ) {

        # get basic hash
        if ( my $hash = $self->zimbra->$method(@_) ) {

            # return results from sending hash
            return $self->submit($hash);
        }
        else {
            $self->error( "$method failed: " . $self->zimbra->error );
        }
    }
    else {
        $self->error("$method is not a supported SOAP call");
    }
    return undef;
}

1;

=head1 AUTHORS

Phil Pearl, C<< <plobbes at cpan.org> >>
Matthew McGillis, C<< <matthew at mcgillis.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-zcs-api at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=ZCS-API>.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2015 Phil Pearl, Matthew McGillis.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
