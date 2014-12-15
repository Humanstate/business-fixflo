package Business::Fixflo::Client;

=head1 NAME

Business::Fixflo::Client

=head1 DESCRIPTION

This is a class for the lower level requests to the fixflo API. generally
there is nothing you should be doing with this.

=cut

use Moo;
with 'Business::Fixflo::Utils';
with 'Business::Fixflo::Version';

use Business::Fixflo::Exception;
use Business::Fixflo::Paginator;
use Business::Fixflo::Issue;
use Business::Fixflo::Agency;

use Carp qw/ confess /;
use MIME::Base64 qw/ encode_base64 /;
use LWP::UserAgent;
use JSON ();
use Data::Dumper;

=head1 ATTRIBUTES

=cut

has [ qw/ username password custom_domain / ] => (
    is       => 'ro',
    required => 1,
);

has user_agent => (
    is      => 'ro',
    default => sub {
        # probably want more info in here, version of perl, platform, and such
        return "business-fixflo/perl/v" . $Business::Fixflo::VERSION;
    }
);

has url_suffix => (
    is       => 'ro',
    required => 0,
    default  => sub { 'fixflo.com' },
);

has 'base_url' => (
    is       => 'ro',
    required => 0,
    lazy     => 1,
    default  => sub {
        my ( $self ) = @_;
        return $ENV{FIXFLO_URL}
            ? $ENV{FIXFLO_URL}
            : 'https://' . $self->custom_domain . '.' . $self->url_suffix;
    }
);

has api_path => (
    is       => 'ro',
    required => 0,
    default  => sub { '/api/' . $Business::Fixflo::API_VERSION },
);

sub _get_issues {
    my ( $self,$params ) = @_;
    my $issues = $self->_api_request( 'GET','Issues' );

    my $Paginator = Business::Fixflo::Paginator->new(
        links  => {
            next     => $issues->{NextURL},
            previous => $issues->{PreviousURL},
        },
        client  => $self,
        class   => 'Business::Fixflo::Issue',
        objects => [ map { Business::Fixflo::Issue->new(
            client => $self,
            url    => $_,
        ) } @{ $issues->{Items} } ],
    );

    return $Paginator;
}

sub _get_agencies {
    my ( $self,$params ) = @_;
    my $agencies = $self->_api_request( 'GET','Agencies' );

    my $Paginator = Business::Fixflo::Paginator->new(
        links  => {
            next     => $agencies->{NextURL},
            previous => $agencies->{PreviousURL},
        },
        client  => $self,
        class   => 'Business::Fixflo::Agency',
        objects => [ map { Business::Fixflo::Agency->new(
            client => $self,
            url    => $_,
        ) } @{ $agencies->{Items} } ],
    );

    return $Paginator;
}

sub _get_issue {
    my ( $self,$id ) = @_;

    my $data = $self->_api_request( 'GET',"Issue/$id" );

    my $issue = Business::Fixflo::Issue->new(
        client => $self,
        %{ $data },
    );

    return $issue;
}

sub _get_agency {
    my ( $self,$id ) = @_;

    my $data = $self->_api_request( 'GET',"Agency/$id" );

    my $issue = Business::Fixflo::Agency->new(
        client => $self,
        %{ $data },
    );

    return $issue;
}

sub api_get {
    my ( $self,$path,$params ) = @_;
    return $self->_api_request( 'GET',$path,$params );
}

sub api_post {
    my ( $self,$path,$params ) = @_;
    return $self->_api_request( 'POST',$path,$params );
}

sub api_delete {
    my ( $self,$path,$params ) = @_;
    return $self->_api_request( 'DELETE',$path,$params );
}

sub _api_request {
    my ( $self,$method,$path,$params ) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->agent( $self->user_agent );

    $path = $self->_add_query_params( $path,$params )
        if $method eq 'GET';

    my $req = HTTP::Request->new(
        # passing through the absolute URL means we don't build it
        $method => $path =~ /^http/
            ? $path : join( '/',$self->base_url . $self->api_path,$path ),
    );

    $req->header( 'Authorization' =>
        "basic "
        . encode_base64( join( ":",$self->username,$self->password ) )
    );

    $req->header( 'Accept' => 'application/json' );

    if ( $method =~ /POST|PUT/ ) {
        if ( $params ) {
            $req->content_type( 'application/json' );
            $req->content( JSON->new->encode( $params ) )
        }
    }

    my $res = $ua->request( $req );

    if ( $res->is_success ) {
        my $data = $res->content;

        if ( $res->headers->header( 'content-type' ) =~ m!application/json! ) {
            $data = JSON->new->decode( $data );
        }

        return $data;
    }
    else {

        if ( $ENV{FIXFLO_DEV_TESTING} ) {
            warn Dumper $path;
            warn Dumper join( '/',$self->base_url . $self->api_path,$path );
            warn Dumper $res->content;
            warn Dumper $res->status_line;
            warn Dumper $params;
        }

        Business::Fixflo::Exception->throw({
            message  => $res->content,
            code     => $res->code,
            response => $res->status_line,
        });
    }
}

sub _add_query_params {
    my ( $self,$path,$params ) = @_;

    if ( my $query_params = $self->normalize_params( $params ) ) {
        return "$path?$query_params";
    }

    return $path;
}

=head1 AUTHOR

Lee Johnson - C<leejo@cpan.org>

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/leejo/business-fixflo

=cut

1;

# vim: ts=4:sw=4:et
