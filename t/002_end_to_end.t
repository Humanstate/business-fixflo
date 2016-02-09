#!perl

use strict;
use warnings;

use Test::Most;
use Test::Deep;
use Test::Exception;

use lib 'lib';
use Business::Fixflo;
use Business::Fixflo::Agency;

plan skip_all => "FIXFLO_ENDTOEND required"
    if ! $ENV{FIXFLO_ENDTOEND};

# this is an "end to end" test - it will call the fixflo API
# using the details defined in the ENV variables below. you
# will need at least one issue (with a photo uploaded) and
# one agency for this test to pass
my ( $username,$password,$api_key,$domain,$tp_username,$tp_password,$server,$scheme )
    = @ENV{qw/
        FIXFLO_USERNAME
        FIXFLO_PASSWORD
        FIXFLO_API_KEY
        FIXFLO_CUSTOM_DOMAIN
        FIXFLO_3RD_PARTY_USERNAME
        FIXFLO_3RD_PARTY_PASSWORD
        FIXFLO_TEST_SERVER
        FIXFLO_URL_SCHEME
    /};

my $ff = Business::Fixflo->new(
    api_key       => $api_key,
    username      => $username,
    password      => $password,
    custom_domain => $domain,
    url_suffix    => $server ? $server : 'fixflo.com',
    url_scheme    => $scheme ? $scheme : 'https',
);

isa_ok(
    my $issues = $ff->issues,
    'Business::Fixflo::Paginator',
    '->issues'
);

cmp_deeply(
    $issues,
    bless({
        'class'  => 'Business::Fixflo::Issue',
        'client' => ignore(),
        'links' => {
            'next'     => ignore(),
            'previous' => ignore(),
        },
        'objects' => ignore(),
    },'Business::Fixflo::Paginator' ),
    '->issues'
);

cmp_deeply(
    $issues->objects->[0],
    methods(
        'client' => ignore(),
        'url'    => re( "https://$domain.$server/api/v2/issue/[^/]+" ),
    ),
    ' ... ->objects'
);

isa_ok(
    my $issue = $issues->objects->[0]->get,
    'Business::Fixflo::Issue',
    ' ... ->get'
);

ok( $issue->FaultCategory,'issue populated' );
ok( $issue->PropertyAddressId,'issue has PropertyAddressId' );

cmp_deeply(
    $issue,
    bless( {
        'Address' => {
            'AddressLine1' => ignore(),
            'AddressLine2' => ignore(),
            'Country'      => ignore(),
            'County'       => ignore(),
            'PostCode'     => ignore(),
            'Town'         => ignore(),
        },
        ( map { $_ => ignore() } qw/
            CallbackId
            ContactNumber
            Created
            DirectEmailAddress
            DirectMobileNumber
            EmailAddress
            FaultCategory
            FaultNotes
            FaultPriority
            FaultTitle
            Firstname
            Id
            Media
            Property
            PropertyAddressId
            Salutation
            Status
            StatusChanged
            Surname
            TenantAcceptComplete
            TenantId
            TenantNotes
            TenantPresenceRequested
            TermsAccepted
            Title
            VulnerableOccupiers
            client
            url
        / ),
        },'Business::Fixflo::Issue'
    ),
    '->issue'
);

ok( $issue->report,' ... ->report' );

isa_ok( $issue->property,'Business::Fixflo::Property' );

isa_ok(
    $ff->issue( $issue->Id ),
    'Business::Fixflo::Issue',
    '->issue'
);

isa_ok(
    my $Address = Business::Fixflo::Address->new(
        client       => $ff->client,
        AddressLine1 => '1 some street',
        AddressLine2 => 'some district',
        Town         => 'some town',
        County       => 'some country',
        PostCode     => 'AB1 2CD',
        Country      => 'UK',
    ),
    'Business::Fixflo::Address'
);

isa_ok(
    my $IssueDraft = Business::Fixflo::IssueDraft->new(
        client     => $ff->client,
        IssueTitle => 'Bees in my house',
        FaultNotes => 'There are bees in my house!',
        Address    => $Address,
    ),
    'Business::Fixflo::IssueDraft'
);

eval {
    ok( $IssueDraft->create,'->create' );
    ok( $IssueDraft->update,'->update' );
    isa_ok( my $Issue = $IssueDraft->commit,'Business::Fixflo::Issue' );
    ok( $IssueDraft->create,'->create' );
    ok( $IssueDraft->delete,'->delete' );
    1;
} or do { fail( $@ ) };

isa_ok(
    my $IssueDraftMedia = Business::Fixflo::IssueDraftMedia->new(
        client          => $ff->client,
        ContentType     => "text/plain",
        IssueDraftId    => 1,
        ShortDesc       => "bees",
        EncodedByteData => "bees",
    ),
    'Business::Fixflo::IssueDraftMedia'
);

eval {
    ok( $IssueDraftMedia->create,'->create' );
    is( $IssueDraftMedia->download,'bees','->download' );
    ok( $IssueDraftMedia->delete,'->delete' );
    1;
} or do { fail( $@ ) };

my $landlord_name = time;

isa_ok(
    my $Landlord = Business::Fixflo::Landlord->new(
        client          => $ff->client,
        CompanyName     => $landlord_name,
    ),
    'Business::Fixflo::Landlord'
);

ok( $Landlord->create,'->create' );
ok( $Landlord->update,'->update' );

my $property_id = time;

isa_ok(
    my $NewProperty = Business::Fixflo::Property->new(
        client              => $ff->client,
        ExternalPropertyRef => "PP$property_id",
        Address             => $Address,
    ),
    'Business::Fixflo::Property'
);

# even though we call ->create we get back an existing property
# as fixflo will match on the address and return a matching one
ok( $NewProperty->create,'->create' );

cmp_deeply(
    $NewProperty,
    bless( {
      'Address' => bless( {
        'AddressLine1' => '1 some street',
        'AddressLine2' => 'some district',
        'Country' => '',
        'County' => '',
        'PostCode' => 'AB1 2CD',
        'Town' => 'some town',
        'client' => 0
      }, 'Business::Fixflo::Address' ),
      'ExternalPropertyRef' => "PP$property_id",
      'Id' => ignore(),
      'PropertyAddressId' => ignore(),
      'PropertyId' => 0,
      'client' => bless( {
        'api_key' => '',
        'api_path' => '/api/v2',
        'base_url' => 'https://pptestagency.test.fixflo.com',
        'custom_domain' => 'pptestagency',
        'password' => '8XTUmRHkQvGm9G',
        'url_scheme' => 'https',
        'url_suffix' => 'test.fixflo.com',
        'user_agent' => ignore(),
        'username' => 'laurent@g3s.ch'
      }, 'Business::Fixflo::Client' )
    }, 'Business::Fixflo::Property' ),
    '->create'
);

isa_ok(
    my $properties = $ff->properties(
        Keywords => 'AB1 2CD',
    ),
    'Business::Fixflo::Paginator',
    '->properties'
);

cmp_deeply(
    $properties,
    bless({
        'class'  => 'Business::Fixflo::Property',
        'client' => ignore(),
        'links' => {
            'next'     => ignore(),
            'previous' => ignore(),
        },
        'objects' => ignore(),
    },'Business::Fixflo::Paginator' ),
    '->properties'
);

cmp_deeply(
    $properties->objects->[0],
    methods(
        'client' => ignore(),
        'url'    => re( "https://$domain.$server/api/v2/Property/[^/]+" ),
    ),
    ' ... ->objects'
);

isa_ok(
    my $Property = $properties->objects->[0]->get,
    'Business::Fixflo::Property',
    ' ... ->get'
);

isa_ok(
    my $landlords = $ff->landlords(
        Keywords => $landlord_name,
    ),
    'Business::Fixflo::Paginator',
    '->landlords'
);

isa_ok(
    $Landlord = $landlords->objects->[0]->get,
    'Business::Fixflo::Landlord',
    ' ... ->get'
);

isa_ok(
    $Landlord = $ff->landlord( $Landlord->Id ),
    'Business::Fixflo::Landlord',
    ' ... ->landlord'
);

isa_ok(
    my $Paginator = $Property->Issues,
    'Business::Fixflo::Paginator',
    ' ... ->Issues'
);

isa_ok(
    my $property_addresses = $ff->property_addresses,
    'Business::Fixflo::Paginator',
    '->property_addresses'
);

cmp_deeply(
    $property_addresses,
    bless({
        'class'  => 'Business::Fixflo::PropertyAddress',
        'client' => ignore(),
        'links' => {
            'next'     => ignore(),
            'previous' => ignore(),
        },
        'objects' => ignore(),
    },'Business::Fixflo::Paginator' ),
    '->property_addresses'
);

cmp_deeply(
    $property_addresses->objects->[0],
    methods(
        'client' => ignore(),
    ),
    ' ... ->objects'
);

isa_ok(
    my $PropertyAddress = $property_addresses->objects->[0]->get,
    'Business::Fixflo::PropertyAddress',
    ' ... ->get'
);

# merge property / property address
$Property = $PropertyAddress->property;
my $AlternatePropertyAddress = $property_addresses->objects->[1]->get;

ok( $AlternatePropertyAddress->merge( $Property ),'->merge' );
ok( $AlternatePropertyAddress->split,'->split' );

my $qvps = [
    sort { $a->QVPTypeId <=> $b->QVPTypeId }
    $ff->quick_view_panels
];
isa_ok( my $QVP = $qvps->[0],'Business::Fixflo::QuickViewPanel' );

cmp_deeply(
    $QVP,
    bless( {
        'DataTypeName' => 'IssueStatusSummary',
        'Explanation'  => 'Summarises all outstanding issues by status',
        'QVPTypeId'    => 1,
        'Title'        => 'Issue status',
        'Url'          => re( '/qvp/issue(status)?summary/\d+$' ),
        'client'       => ignore(),
    },'Business::Fixflo::QuickViewPanel' ),
    'QVP',
);

cmp_deeply(
    ( $QVP->issue_status_summary || $QVP->issue_summary ),
    [
        {
        'Count'       => ignore(),
        'HtmlColor'   => '#6386BA',
        'HtmlColorHi' => '#76A0DF',
        'Label'       => 'Reported',
        'Status'      => 'Reported',
        'StatusId'    => 0
        }
    ],
    ' ... issue_status_summary / issue_summary',
);

my ( $issues_of_properties_without_ext_ref ) = grep { $_->QVPTypeId == 40 }
    $ff->quick_view_panels;

foreach my $qvp (
    sort { $a->QVPTypeId <=> $b->QVPTypeId }
    $ff->quick_view_panels
) {
    diag( sprintf( "%d - %s",$qvp->QVPTypeId,$qvp->Explanation ) );
}

cmp_deeply(
    $issues_of_properties_without_ext_ref->get,
    [
        {
            'Key'   => ignore(),
            'Value' => ignore(),
        }
    ],
    'key_value_pairs',
);

# to create/update/delete agencies we need to use the third party api
$ff = Business::Fixflo->new(
    username      => $tp_username,
    password      => $tp_password,
    url_suffix    => 'test.fixflo.com',
);

isa_ok(
    my $NewAgency = Business::Fixflo::Agency->new(
        client       => $ff->client,
        Id           => undef,
        AgencyName   => join( '_','bff_end_to_end',time,$$ ),
        EmailAddress => time . '_' . $$ . '_leejo@cpan.org',
        Locale       => 'en-GB',
        DefaultTimeZoneId => 'UTC',
        IssueTreeRoot => 2,
    ),
    'Business::Fixflo::Agency'
);

ok( $NewAgency->create,'->create' );

cmp_deeply(
    $NewAgency,
    bless( {
        'AgencyName'    => re( '^bff_end_to_end_\d+_\d+$' ),
        'Created'       => re( '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}' ),
        'CustomDomain'  => ignore(),
        'EmailAddress'  => ignore(),
        'FeatureType'   => 0,
        'Id'            => ignore(),
        'IsDeleted'     => ignore(),
        'IssueTreeRoot' => ignore(),
        'SiteBaseUrl'   => ignore(),
        'DefaultTimeZoneId' => 'UTC',
        'Locale'        => 'en-GB',
        'ApiKey'        => ignore(),
        'Password'      => ignore(),
        'TermsAcceptanceDate' => ignore(),
        'TermsAcceptanceUrl'  => ignore(),
        client          => ignore(),
    },'Business::Fixflo::Agency' ),
    ' ... updates object',
);

isa_ok(
    my $agencies = $ff->agencies,
    'Business::Fixflo::Paginator',
    '->agencies'
);

cmp_deeply(
    $agencies,
    bless( {
        'class' => 'Business::Fixflo::Agency',
        'client' => ignore(),
        'links' => {
            'next'     => ignore(),
            'previous' => ignore(),
        },
        'objects' => ignore(),
    },'Business::Fixflo::Paginator' ),
    '->agencies'
);

cmp_deeply(
    $agencies->objects->[0],
    methods(
        'client' => ignore(),
        'url'    => re( "https://api.test.fixflo.com/api/v2/agency/[^/]+" ),
    ),
    ' ... ->objects'
);

isa_ok(
    my $agency = $agencies->objects->[0]->get,
    'Business::Fixflo::Agency',
    ' ... ->get'
);

cmp_deeply(
    $agency,
    bless( {
        ( map { $_ => ignore() } qw/
            ApiKey
            Password
            AgencyName
            Created
            CustomDomain
            EmailAddress
            FeatureType
            Id
            IsDeleted
            IssueTreeRoot
            SiteBaseUrl
            DefaultTimeZoneId
            Locale
            TermsAcceptanceDate
            TermsAcceptanceUrl
            client
            url
        / ),
    },'Business::Fixflo::Agency' ),
    '->agency',
);

ok( $agency->delete,'->delete' );
is( $agency->IsDeleted,1,'IsDeleted' );
ok( $agency->undelete,'->undelete' );
is( $agency->IsDeleted,0,'! IsDeleted' );

done_testing();

# vim: ts=4:sw=4:et
