package ZCS::API::Zimbra;

use strict;
use warnings;

our $DEBUG = 0;
our $ERROR = '';

=head1 NAME

ZCS::API::Zimbra - perl module for specific SOAP calls.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 new(api)

=cut

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;
    if ( ref( $_[0] ) eq "ZCS::API" ) {
        $self->{_api} = $_[0];
        return $self;
    }
    else {
        $self->error("ZCS::API referance was not passed with new");
        return undef;
    }
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

=head2 api

=cut

sub api {
    return $_[0]->{_api};
}

=head2 auth(user,password)

Generate AuthRequest hash using user and password values.

=cut

sub auth {
    my ( $self, $user, $password ) = @_;

    my $header = {
        context => {
            _jsns     => "urn:zimbra",
            nosession => {}
        }
    };
    if ( ref( $self->api->type ) eq "ZCS::API::JSON" ) {
        $header->{format} = { type => "js" };
    }

    return {
        Header => $header,
        Body   => {
            AuthRequest => {
                _jsns    => "urn:zimbraAdmin",
                name     => { _content => $user },
                password => { _content => $password }
            }
        }
    };
}

=head2 delegateauth(user)

Generate DelegateAuthRequest hash using user value.

=cut

sub delegateauth {
    my ( $self, $user ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            DelegateAuthRequest => {
                _jsns   => "urn:zimbraAdmin",
                account => {
                    by       => "name",
                    _content => $user
                }
            }
        }
    };
}

=head2 getaccount(account)

Generate GetAccountRequest hash using account value.

account is email address.

=cut

sub getaccount {
    my ( $self, $account ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            GetAccountRequest => {
                _jsns   => "urn:zimbraAdmin",
                account => {
                    by       => "name",
                    _content => $account
                }
            }
        }
    };
}

=head2 getinfo(account,sections,rights)

Generate GetInfoRequst hash using account,sections, and rights value.

account is email address.

sections, and rights are optional should be either a true or false value.

=cut

sub getinfo {
    my ( $self, $account, $sections, $rights ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = { GetInfoRequest => { _jsns => "urn:zimbraAccount", } };
    $body->{GetInfoRequst}{"sections"} = 1 if ($sections);
    $body->{GetInfoRequst}{"rights"}   = 1 if ($rights);
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 createaccount(account,password,attr)

Generate CreateAccountRequest hash using account, password, and attr value.

Must include account as a full e-mail address.

Must include password.

The attr value is optional but can be used to set any account attribute value. If used it must be a hash of properties to set.

  my $attr = { 
    "zimbraArchiveEnabled" => "FALSE",
    "displayName"          => "User1 Test"
    .....
  };

=cut

sub createaccount {
    my ( $self, $account, $password, $attr ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        CreateAccountRequest => {
            _jsns => "urn:zimbraAdmin",
            name  => $account
        }
    };
    $body->{CreateAccountRequest}{password} = $password if ($password);
    if ( defined($attr) ) {
        my $a = $body->{CreateAccountRequest}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 modifyaccount(account,attr)

Generate ModifyAccountRequest hash using account, and attr value.

Can either use email address, id or HASH result from getaccount as account
value.

The attr value is optional but can be used to set any account attribute value. If used it must be a hash of properties to set.

  my $attr = { 
    "zimbraArchiveEnabled" => "FALSE",
    "displayName"          => "User1 Test"
    .....
  };

=cut

sub modifyaccount {
    my ( $self, $account, $attr ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $id = $self->api->getaccountid($account);

    my $body = {
        ModifyAccountRequest => {
            _jsns => "urn:zimbraAdmin",
            id    => { _content => $id }
        }
    };
    if ( defined($attr) ) {
        my $a = $body->{ModifyAccountRequest}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 deleteaccount(account)

Generate DeleteAccountRequest hash using account value.

Can either use email address, id or HASH result from getaccount as account
value.

=cut

sub deleteaccount {
    my ( $self, $account ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $id = $self->api->getaccountid($account);
    return undef unless ($id);

    return {
        Header => $header,
        Body   => {
            DeleteAccountRequest => {
                _jsns => "urn:zimbraAdmin",
                id    => $id
            }
        }
    };
}

=head2 getdistributionlist(account)

Generate GetDistributionListRequest hash using account value.

account is email address.

=cut

sub getdistributionlist {
    my ( $self, $account ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            GetDistributionListRequest => {
                _jsns => "urn:zimbraAdmin",
                dl    => {
                    by       => "name",
                    _content => $account
                }
            }
        }
    };
}

=head2 createdistributionlist(name,attr)

Generate CreateDistributionListRequest hash using name, and attr value.

Must include name as a full e-mail address.

The attr value is optional but can be used to set any distribution list  attribute value. If used it must be a hash of properties to set.

  my $attr = { 
    "zimbraArchiveEnabled" => "FALSE",
    "displayName"          => "User1 Test"
    .....
  };

=cut

sub createdistributionlist {
    my ( $self, $name, $attr ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        CreateDistributionListRequest => {
            _jsns => "urn:zimbraAccount",
            name  => { _content => $name }
        }
    };
    if ( defined($attr) ) {
        my $a = $body->{CreateDistributionListRequest}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 deletedistributionlist(account)

Generate DeleteDistributionListRequest hash using account value.

Can either use email address, id or HASH result from getaccount as account
value.

=cut

sub deletedistributionlist {
    my ( $self, $account ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $id = $self->api->getdistributionlistid($account);
    return undef unless ($id);

    return {
        Header => $header,
        Body   => {
            DeleteDistributionListRequest => {
                _jsns => "urn:zimbraAdmin",
                id    => $id
            }
        }
    };
}

=head2 createmountpoint(account,path,link)

Generate CreateMountpointRequest hash using name, and attr value.

Must include account as a full e-mail address.
Path is optional it will generate proper name and l values for the link hash if specified. 
The link value is a hash ref of the link attributes it must include the name, and l value but if path is specified they will be generated so in this case passing a link hash is not strictly required. All though you will probably want to set other attributes so will still pass in a link hash.

For a specified path like "/foo/TestCalendar" we call getfolder for "/foo" to get that folders id for the l value and set name equal to "TestCalendar".

The link is a hash ref used to set any mount attribute value. It must be a hash of properties to set.

  my $link = { 
    "name"  => "TestCalendar",
    "l"     => 1,
    "view"  => "appointment",
    "owner" => 'test@nsd.org',
    "path"  => "/Calendar",
    .....
  };

=cut

sub createmountpoint {
    my ( $self, $account, $path, $link ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = { CreateMountpointRequest => { _jsns => "urn:zimbraMail" } };
    my $l = $body->{CreateMountpointRequest}{link} = {};
    foreach my $item ( keys %$link ) {
        $l->{$item} = $link->{$item};
    }
    if ( defined($path) && $path =~ /(.*)\/([^\/]*)/ ) {
        my $folder = $1 || "/";
        my $name   = $2;
        my $id     = $self->api->getfolderid( $account, $folder );
        if ( defined($id) ) {
            $l->{name} = $name;
            $l->{l}    = $id;
        }
        else {
            $self->error(
                "failed to find path for $account:" . $self->api->error );
            return undef;
        }
    }
    else {
        $self->error("$path is not a valid path");
        return undef;
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 addaccountalias(id,alias)

Generate AddAccountRequest hash using id, and alias value.

=cut

sub addaccountalias {
    my ( $self, $id, $alias ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            AddAccountAliasRequest => {
                _jsns => "urn:zimbraAdmin",
                id    => { _content => $id },
                alias => { _content => $alias }
            }
        }
    };
}

=head2 emptycontacts(account)

Generate FolderActionRequest hash using account to empty contacts.

=cut

# contacts are hardcoded to folder 7
sub emptycontacts {
    my ( $self, $account ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            FolderActionRequest => {
                _jsns  => "urn:zimbraMail",
                action => {
                    op => "empty",
                    id => "7"
                }
            }
        }
    };
}

=head2 getfolder(account,path,l)

Generate GetFolderRequest hash using account, path or l values.

=cut

sub getfolder {
    my ( $self, $account, $path, $l ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        GetFolderRequest => {
            _jsns  => "urn:zimbraMail",
            folder => {}
        }
    };
    $body->{GetFolderRequest}{folder}{path} = $path if ( defined($path) );
    $body->{GetFolderRequest}{folder}{l}    = $l    if ( defined($l) );
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 createfolder(account,path)

Generate CreateFolderRequest hash using account, and path values.

=cut

sub createfolder {
    my ( $self, $account, $path ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        CreateFolderRequest => {
            _jsns  => "urn:zimbraMail",
            folder => { name => $path }
        }
    };
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 folderaction(account,action)

Generate folderaction hash using account, and action value.

account is email address.

action is hash ref of action values.

  my $action = {
        id => 260,
        op => "move",
        l  => 3,
        ...
  }

=cut

sub folderaction {
    my ( $self, $account, $action ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            FolderActionRequest => {
                _jsns  => "urn:zimbraMail",
                action => $action
            }
        }
    };
}

=head2 createcontact(account,attr)

Generate CreateContactRequest hash using account, and attr values.

Must include account as a full e-mail address.

The attr value is optional but is used to set any contact attribute value. If used it must be a hash of properties to set.

  my $attr = { 
    "firstName" => "John",
    "lastName"  => "Doe"
    "email"     => "john.doe@abc.xyz.com"
    .....
  };

To find out a current list of available values do something like:

  $zmmailbox -z -m user@abc.xyz.com cct test testing
  ERROR: service.INVALID_REQUEST (invalid request: invalid attr: test, valid values: [assistantPhone, birthday, anniversary, callbackPhone, canExpand, carPhone, company, dn, phoneticCompany, companyPhone, description, department, dlist, email, email2, email3, fileAs, firstName, phoneticFirstName, fullName, groupMember, homeCity, homeCountry, homeFax, homePhone, homePhone2, homePostalCode, homeState, homeStreet, homeURL, image, initials, jobTitle, lastName, phoneticLastName, maidenName, member, middleName, mobilePhone, namePrefix, nameSuffix, nickname, notes, office, otherCity, otherCountry, otherFax, otherPhone, otherPostalCode, otherState, otherStreet, otherURL, pager, tollFree, userCertificate, userSMIMECertificate, workCity, workCountry, workFax, workPhone, workPhone2, workPostalCode, workState, workStreet, workURL, type, homeAddress, imAddress1, imAddress2, imAddress3, workAddress, workEmail1, workEmail2, workEmail3, workMobile, workIM1, workIM2, workAltPhone, otherDepartment, otherOffice, otherProfession, otherAddress, otherMgrName, otherAsstName, otherAnniversary, otherCustom1, otherCustom2, otherCustom3, otherCustom4, vCardUID, vCardXProps, zimbraId]) (cause: java.lang.IllegalArgumentException No enum constant com.zimbra.common.mailbox.ContactConstants.Attr.test)

=cut

sub createcontact {
    my ( $self, $account, $attr ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = { CreateContactRequest => { _jsns => "urn:zimbraMail", } };
    if ( defined($attr) ) {
        my $a = $body->{CreateContactRequest}{cn} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 createcontactgroup(account,gname,members)

Generate CreateContactRequest hash using account, gname and members values.

account is email address of account to added contact group to.

gname is string value of new group contact name to create.

members is an array ref of all members of the form:

  $members = [ {type=>"I",value=>"jon.doe@abc.xyz.com"},
               {type=>"I",value=>"bob.dow@abc.xyz.com"},
               ...]

=cut

sub createcontactgroup {
    my ( $self, $account, $gname, $members ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        CreateContactRequest => {
            _jsns => "urn:zimbraMail",
            cn    => {
                a => [
                    { n => "type",     _content => "group" },
                    { n => "fileAs",   _content => "8:" . $gname },
                    { n => "nickname", _content => $gname }
                ]
            }
        }
    };
    if ( defined($members) ) {
        my $m = $body->{CreateContactRequest}{cn}{m} = [];
        foreach my $item (@$members) {
            push( @$m, $item );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 getdatasources(account)

Generate GetDataSourcesRequest hash using id value.

Can either use email address, id or HASH result from getaccount as account
value.

=cut

sub getdatasources {
    my ( $self, $account ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $id = $self->api->getaccountid($account);
    return undef unless ($id);

    return {
        Header => $header,
        Body   => {
            GetDataSourcesRequest => {
                _jsns => "urn:zimbraAdmin",
                id    => $id
            }
        }
    };
}

=head2 createdatasource(account,name,type,attr)

Generate CreateDataSourcesRequest hash using account, name, type, and attr
values.

Can either use email address, id or HASH result from getaccount as account
value.

name is the data source name

type is the data source type

attr is a hash ref of attributes to set for the data source:

  my $attr = {
      zimbraDataSourceName      => "Testing",
      zimbraDataSourceIsEnabled => "TRUE",
      zimbraDataSourceHost      => "pop.abc.xyz.com",
      ....
  }

=cut

sub createdatasource {
    my ( $self, $account, $name, $type, $attr ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $id = $self->api->getaccountid($account);
    return undef unless ($id);

    my $body = {
        CreateDataSourceRequest => {
            _jsns      => "urn:zimbraAdmin",
            id         => $id,
            dataSource => {
                name => $name,
                type => $type
            }
        }
    };
    if ( defined($attr) ) {
        my $a = $body->{CreateDataSourceRequest}{dataSource}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 modifydatasource(account,id,attr)

Generate ModifyDataSourcesRequest hash using account, dsid, and attr values.

Can either use email address, id or HASH result from getaccount as account
value.

id is the data source id to modify

attr is a hash ref of attributes to modify for the data source:

  my $attr = {
      zimbraDataSourceIsEnabled => "FALSE",
      ....
  }

=cut

sub modifydatasource {
    my ( $self, $account, $dsid, $attr ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $id = $self->api->getaccountid($account);
    return undef unless ($id);

    my $body = {
        ModifyDataSourceRequest => {
            _jsns      => "urn:zimbraAdmin",
            id         => $id,
            dataSource => { id => $dsid }
        }
    };
    if ( defined($attr) ) {
        my $a = $body->{CreateDataSourceRequest}{dataSource}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 getsignatures(account)

Generate GetSignaturesRequest hash using account value.

account is email address.

=cut

sub getsignatures {
    my ( $self, $account ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = { GetSignaturesRequest => { _jsns => "urn:zimbraAccount" } };

    return {
        Header => $header,
        Body   => $body
    };
}

=head2 createsignature(account,id,name,data)

Generate CreateSignaturesRequest hash using account, id, name, and data value.

account is email address.

id is the signature id to modify optional

name is the signature name to modify optional

data is an array ref of hash values of the form:

  my $data = [
               { cid => 123e4567-e89b-12d3-a456-42665544000},
               { content => "my signature content", type => "text/plain" },
               { content => "my signature content", type => "text/html" }
             ]

=cut

sub createsignature {
    my ( $self, $account, $id, $name, $data ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        CreateSignatureRequest => {
            _jsns     => "urn:zimbraAccount",
            signature => {}
        }
    };
    $body->{CreateSignatureRequest}{signature}{id}   = $id   if ($id);
    $body->{CreateSignatureRequest}{signature}{name} = $name if ($name);
    my ( $content, $cid );
    foreach my $value (@$data) {
        if ( exists( $value->{content} ) ) {
            $content = $body->{CreateSignatureRequest}{signature}{content} = []
              unless (
                exists( $body->{CreateSignatureRequest}{signature}{content} ) );
            my $item = { _content => $value->{content} };
            $item->{type} = $value->{type} if ( exists( $value->{type} ) );
            push( @$content, $item );
        }
        elsif ( exists( $value->{cid} ) ) {
            $body->{CreateSignatureRequest}{signature}{cid} =
              { _content => $value->{cid} };
        }
        else {
            print STDERR "WARN: createsignature does not understand data ("
              . join( ", ", %$value ) . ")\n";
        }
    }

    return {
        Header => $header,
        Body   => $body
    };
}

=head2 modifysignature(account,id,name,data)

Generate ModifySignaturesRequest hash using account, id, name, and data value.

account is email address.

id is the signature id to modify optional

name is the signature name to modify optional

data is an array ref of hash values of the form:

  my $data = [
               { cid => 123e4567-e89b-12d3-a456-42665544000},
               { content => "my signature content", type => "text/plain" },
               { content => "my signature content", type => "text/html" }
             ]

=cut

sub modifysignature {
    my ( $self, $account, $id, $name, $data ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        ModifySignatureRequest => {
            _jsns     => "urn:zimbraAccount",
            signature => {}
        }
    };
    $body->{CreateSignatureRequest}{signature}{id}   = $id   if ($id);
    $body->{CreateSignatureRequest}{signature}{name} = $name if ($name);
    my ( $content, $cid );
    foreach my $value (@$data) {
        if ( exists( $value->{content} ) ) {
            $content = $body->{CreateSignatureRequest}{signature}{content} = []
              unless (
                exists( $body->{CreateSignatureRequest}{signature}{content} ) );
            my $item = { _content => $value->{content} };
            $item->{type} = $value->{type} if ( exists( $value->{type} ) );
            push( @$content, $item );
        }
        elsif ( exists( $value->{cid} ) ) {
            $body->{CreateSignatureRequest}{signature}{cid} =
              { _content => $value->{cid} };
        }
        else {
            print STDERR "WARN: createsignature does not understand data ("
              . join( ", ", %$value ) . ")\n";
        }
    }

    return {
        Header => $header,
        Body   => $body
    };
}

=head2 getidentities(account)

Generate GetIdentitiesRequest hash using account value.

account is email address.

=cut

sub getidentities {
    my ( $self, $account ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => { GetIdentitiesRequest => { _jsns => "urn:zimbraAccount", } }
    };
}

=head2 createidentity(account,id,name,attr)

Generate CreateIdentityRequest hash using account, id, name, and attr value.

account is email address.

=cut

sub createidentity {
    my ( $self, $account, $id, $name, $attr ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        CreateIdentityRequest => {
            _jsns    => "urn:zimbraAccount",
            identity => {}
        }
    };
    $body->{CreateIdentityRequest}{identity}{id}   = $id   if ($id);
    $body->{CreateIdentityRequest}{identity}{name} = $name if ($name);
    if ( defined($attr) ) {
        my $a = $body->{CreateIdentityRequest}{identity}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 modifyidentity(account,id,name,attr)

Generate CreateIdentityRequest hash using account, id, name, and attr value.

account is email address.

=cut

sub modifyidentity {
    my ( $self, $account, $id, $name, $attr ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        ModifyIdentityRequest => {
            _jsns    => "urn:zimbraAccount",
            identity => {}
        }
    };
    $body->{CreateIdentityRequest}{identity}{id}   = $id   if ($id);
    $body->{CreateIdentityRequest}{identity}{name} = $name if ($name);
    if ( defined($attr) ) {
        my $a = $body->{CreateIdentityRequest}{identity}{a} = [];
        foreach my $item ( keys %$attr ) {
            push( @$a, { n => $item, _content => $attr->{$item} } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 getcos(cos)

Generate GetCosRequest hash using cos value.

cos is either the cos name or can be a hash ref of the form:

  { by => "name", cos => "default" }

Both of these are identical:

  my $a = $zaz->getcos("default"); 
  my $b = $zaz->getcos({ by=>"name",cos=>"default"}); 

=cut

sub getcos {
    my ( $self, $arg ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    # if $arg is not a ref then consider it a cos name
    $arg = ref($arg) ? $arg : { value => $arg };
    $arg->{by} ||= "name";

    return {
        Header => $header,
        Body   => {
            GetCosRequest => {
                _jsns => "urn:zimbraAdmin",
                cos   => {
                    by       => $arg->{by},
                    _content => $arg->{value}
                }
            }
        }
    };
}

=head2 getserver(server)

Generate GetServerRequest hash using server value.

server is either the server name or can be a hash ref of the form:

  { by => "name", server => "abc.xyx.com" }

Both of these are identical:

  my $a = $zaz->getcos("abc.xyz.com"); 
  my $b = $zaz->getcos({ by=>"name",server=>"abc.xyz.com"}); 

=cut

sub getserver {
    my ( $self, $arg ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    # if $arg is not a ref then consider it a server name
    $arg = ref($arg) ? $arg : { value => $arg };
    $arg->{by} ||= "name";

    return {
        Header => $header,
        Body   => {
            GetServerRequest => {
                _jsns  => "urn:zimbraAdmin",
                server => {
                    by       => $arg->{by},
                    _content => $arg->{value}
                }
            }
        }
    };
}

=head2 movemessages(account,messages,folder)

Generate msgaction hash using account, messages, and folder value.

account is email address.

messages is a string of comma seperated message id's to move.

folder is a string of the full path of the folder to move the messages to.

=cut

sub movemessages {
    my ( $self, $account, $messages, $folder ) = @_;

    my $action = {
        id => $messages,
        op => "move",
        l  => $self->api->getfolderid( $account, $folder )
    };

    return $self->msgaction( $account, $action );
}

=head2 msgaction(account,action)

Generate msgaction hash using account, and action value.

account is email address.

action is hash ref of action values.

  my $action = {
        id => 260,
        op => "move",
        l  => 3,
        ...
  }

=cut

sub msgaction {
    my ( $self, $account, $action ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            MsgActionRequest => {
                _jsns  => "urn:zimbraMail",
                action => $action
            }
        }
    };
}

=head2 search(account,query)

Generate search hash using account, and query value.

account is email address.

query is a string of search tokens.

See /opt/zimbra/docs/query.txt for list of query tokens.

Simple Example:

  my $query = "before:1/1/15 after:12/31/13 from:bill"

=cut

sub search {
    my ( $self, $account, $query, $search ) = @_;

    my $header = $self->api->delegateheader($account);
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        SearchRequest => {
            _jsns => "urn:zimbraMail",
            query => { _content => $query }
        }
    };
    if ( defined($search) ) {
        foreach my $item ( keys %$search ) {
            $body->{SearchRequest}{$item} = $search->{$item};
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 backup(settings,accounts)

Generate BackupRequest hash using settings, and accounts value.

=cut

sub backup {
    my ( $self, $settings, $accounts ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        BackupRequest => {
            _jsns  => "urn:zimbraAdmin",
            backup => {}
        }
    };
    if ( defined($settings) ) {
        foreach my $item ( keys %$settings ) {
            $body->{BackupRequest}{backup}{$item} = $settings->{$item};
        }
    }
    if ( defined($accounts) ) {
        my $a = $body->{BackupRequest}{backup}{account} = [];
        foreach my $item (@$accounts) {
            push( @$a, { name => $item } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 restore(settings,accounts)

Generate RestoreRequest hash using settings, and accounts value.

=cut

sub restore {
    my ( $self, $settings, $accounts ) = @_;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    my $body = {
        RestoreRequest => {
            _jsns   => "urn:zimbraAdmin",
            restore => {}
        }
    };
    if ( defined($settings) ) {
        foreach my $item ( keys %$settings ) {
            $body->{RestoreRequest}{restore}{$item} = $settings->{$item};
        }
    }
    if ( defined($accounts) ) {
        my $a = $body->{RestoreRequest}{restore}{account} = [];
        foreach my $item (@$accounts) {
            push( @$a, { name => $item } );
        }
    }
    return {
        Header => $header,
        Body   => $body
    };
}

=head2 exportmailbox(export)

Generate ExportMailboxRequest hash using export value. Same SOAP call used by zmmailboxmove.

export is a hash of the form:

  {
    name       => "<email>",
    dest       => "<server>",
    [destPort  => "<port>",]
    [tempDir   => "<port>",]
    [overwrite => "<port>",]
  }

  $za->exportmailbox({name=>'user1@zimbra.com',dest=>'z1.zimbra.com'});

  must be called against the source server

=cut

sub exportmailbox {
    my $self = shift;
    my $a    = shift;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            ExportMailboxRequest => {
                _jsns   => "urn:zimbraAdmin",
                account => $a
            }
        }
    };
}

=head2 movemailbox(move)

Generate MoveMailboxRequest hash using move value. Same SOAP call used by zmmboxmove.

move is a hash of the form:

  {
    name       => "<email>",
    dest       => "<server>",
    src        => "<server>",
    [blobs               => "<include|exclude|config>",]
    [secondaryBlobs      => "<include|exclude|config>",]
    [searchIndex         => "<include|exclude|config>",]
    [maxSyncs            => "<max-syncs>",]
    [syncFinishThreshold => "<synnc-finish-threshold-millisecs>",]
    [sync                => "<sync>",]
  }

  $za->exportmailbox({name=>'user1@zimbra.com',dest=>'z1.zimbra.com'});

  usually called against the destination box

=cut

# zmmboxmove
sub movemailbox {
    my $self = shift;
    my $a    = shift;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            MoveMailboxRequest => {
                _jsns   => "urn:zimbraAdmin",
                account => $a
            }
        }
    };
}

=head2 purgemovedmailbox(purge)

Generate PurgeMovedMailboxRequest hash using purge value. Same SOAP call used by "zmmailboxmove -pe" or zmpurgeoldmbox.

purge is a hash of the form:

  {
    name       => "<email>"
  }

  $za->purgemovedmailbox({name=>'user1@zimbra.com'});

  usually called against the source box

=cut

# zmmboxmove
sub purgemovedmailbox {
    my $self = shift;
    my $a    = shift;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            PurgeMovedMailboxRequest => {
                _jsns => "urn:zimbraAdmin",
                mbox  => $a
            }
        }
    };
}

=head2 getallconfig()

Generate GetAllConfigRequest. Same SOAP call used by "zmprov gacf".

  $za->gatallconfig();

=cut

# getallconfig
sub getallconfig {
    my $self = shift;

    my $header = $self->api->header;
    unless ($header) {
        $self->error( $self->api->error );
        return undef;
    }

    return {
        Header => $header,
        Body   => {
            GetAllConfigRequest => {
                _jsns => "urn:zimbraAdmin"
            }
        }
    };
}

1;
