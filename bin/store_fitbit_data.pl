#!/usr/bin/env perl

# like store_geo_temp.pl and store_coffee_rest.pl, stores FitBit data
# in a way that can be included in my prompt.

# data to be stored includes
#   - days since last successful check
#   - days since last sync
#   - low battery
#   - steps today

use strict;
use warnings;
use utf8;
use feature qw{ postderef say signatures state };
no warnings qw{ experimental::postderef experimental::signatures };

use DateTime;
use DateTime::Format::ISO8601;
use JSON::XS;
use Mojo::UserAgent;
use YAML::XS qw{ DumpFile LoadFile };

my $json = JSON::XS->new->pretty->canonical;
my $mojo = Mojo::UserAgent->new;

my ( $id, $token ) = config();
my ( $days, $battery ) = check_device( $id, $token );
my ($steps) = check_steps( $id, $token );
my $now     = DateTime->now()->set_time_zone('America/Indianapolis');
my $data    = {
    batteryLevel         => $battery,
    date                 => $now->iso8601,
    epoch                => $now->epoch,
    days_since_last_sync => $days,
    steps                => $steps,
};
DumpFile( '/home/jacoby/.fitbit_data.yml', $data );
exit;

sub check_steps ( $id, $token ) {
    my $date   = DateTime->now()->set_time_zone('floating')->ymd;
    my $server = 'https://api.fitbit.com';
    my $url    = join '/', $server, 1, 'user', $id, 'activities', 'date',
        $date . '.json';
    my $res =
        $mojo->get( $url, { 'Authorization' => "Bearer $token", } )->result;
    if ( $res->is_success ) {
        my $obj = $json->decode( $res->body );
        return $obj->{summary}{steps};
    }
    return 0;
}

sub check_device ( $id, $token ) {
    my $server = 'https://api.fitbit.com';
    my $url = join '/', $server, 1, 'user', '-', 'devices.json';
    my $res =
        $mojo->get( $url, { 'Authorization' => "Bearer $token", } )->result;
    if ( $res->is_success ) {
        my $obj                  = $json->decode( $res->body );
        my $batteryLevel         = $obj->[0]{batteryLevel};
        my $days_since_last_sync = check_sync( $obj->[0]{lastSyncTime} );
        return $days_since_last_sync, $batteryLevel;
    }
    exit;
}

sub check_sync ( $lastSyncTime ) {
    my $f    = 'floating';
    my $iso  = DateTime::Format::ISO8601->new;
    my $last = $iso->parse_datetime($lastSyncTime)->set_time_zone($f);
    my $now  = DateTime->now()->set_time_zone($f);
    my $diff = $now->subtract_datetime($last)->in_units('days');
    return $diff;
}

sub config () {
    my $file = '/home/jacoby/.fitbit.yml';
    if ( -f $file ) {
        my $yaml = LoadFile($file);
        return $yaml->{id}, $yaml->{token};
    }
    exit;
}

# my $token =
# 'eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyMjg3M0giLCJzdWIiOiIyM0Y5U0siLCJpc3MiOiJGaXRiaXQiLCJ0eXAiOiJhY2Nlc3NfdG9rZW4iLCJzY29wZXMiOiJ3aHIgd3BybyB3bnV0IHdzbGUgd3dlaSB3c29jIHdzZXQgd2FjdCB3bG9jIiwiZXhwIjoxNTQ3NTA5MjAwLCJpYXQiOjE1NDY5MDQ0MDB9.riPJQPcl37erNNR0BpXc_uz5voG8xCJybS6lnI3abTU';
# my $server = 'https://api.fitbit.com';
# my $id     = '23F9SK';
# my $date   = DateTime->now()->set_time_zone('floating')->ymd;

# my $profile = join '/', $server, 1, 'user', '-', 'profile.json';
# my $activities = join '/', $server, 1, 'user', $id, 'activities', 'date',
#     $date . '.json';

# # GET https://api.fitbit.com/1/user/[user-id]/activities/date/[date].json
# say $activities;
# say $profile;

# my $res =
#     $mojo->get( $activities, { 'Authorization' => "Bearer $token", } )->result;
# say $res->{code};
# if ( $res->is_success ) {
#     my $obj = $json->decode( $res->body );
#     say $json->encode($obj);
# }
# elsif ( $res->is_error ) { croak $res->message }
# else                     { croak $res->message }

# __DATA__
# $ curl -i -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiIyMjg3M0giLCJzdWIiOiIyM0Y5U0siLCJpc3MiOiJGaXRiaXQiLCJ0eXAiOiJhY2Nlc3NfdG9rZW4iLCJzY29wZXMiOiJ3aHIgd3BybyB3bnV0IHdzbGUgd3dlaSB3c29jIHdzZXQgd2FjdCB3bG9jIiwiZXhwIjoxNTQ3NTA5MjAwLCJpYXQiOjE1NDY5MDQ0MDB9.riPJQPcl37erNNR0BpXc_uz5voG8xCJybS6lnI3abTU"
# https://api.fitbit.com/1/user/-/profile.json

# GET https://api.fitbit.com/1/user/[user-id]/activities/date/[date].json
