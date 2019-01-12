#!/usr/bin/env perl

# Checks the FitBit API to see what the battery level and 
# last sync were, and if too low or too long, sends message 
# via Pushover

# to be run daily at 7 am

use strict;
use warnings;
use utf8;
use feature qw{ postderef say signatures state };
no warnings qw{ experimental::postderef experimental::signatures };

use DateTime;
use DateTime::Format::ISO8601;
use IO::Interactive qw{interactive};
use JSON;
use Mojo::UserAgent;
use YAML qw{LoadFile};

use lib '/home/jacoby/lib';
use Pushover;

my $json = JSON->new->pretty->canonical;
my $mojo = Mojo::UserAgent->new;

my $token    = get_token();
my $response = check_fitbit($token);

exit;

sub check_fitbit( $token ) {
    my $server = 'https://api.fitbit.com';
    my $id     = '23F9SK'; # should not be hardcoded
    my $url    = join '/', $server, 1, 'user', '-', 'devices.json';
    my $res =
        $mojo->get( $url, { 'Authorization' => "Bearer $token", } )->result;
    if ( $res->is_success ) {
        my $obj                  = $json->decode( $res->body );
        my $batteryLevel         = $obj->[0]{batteryLevel};
        my $days_since_last_sync = check_sync( $obj->[0]{lastSyncTime} );
        if ( $batteryLevel < 20 || $days_since_last_sync > 2 ) {
            send_message( $batteryLevel, $days_since_last_sync );
        }
        say {interactive} $json->encode($obj);
        say {interactive} $batteryLevel;
        say {interactive} $days_since_last_sync;
    }
    else {
        fix_fitbit();
        exit;
    }
}

sub check_sync ( $lastSyncTime ) {
    my $f    = 'floating';
    my $iso  = DateTime::Format::ISO8601->new;
    my $last = $iso->parse_datetime($lastSyncTime)->set_time_zone($f);
    my $now  = DateTime->now()->set_time_zone($f);
    my $diff = $now->subtract_datetime($last)->in_units('days');
    return $diff;
}

sub send_message ( $batteryLevel, $days_since_last_sync ) {
    my $message;
    $message->{title}   = 'FitBit: Maintenance Required';
    $message->{message} = <<"END";
Battery Level: ${batteryLevel}%
${days_since_last_sync} days since last sync
END
    say $json->encode($message);
    pushover($message);
}

sub fix_fitbit () {
    my $message;
    $message->{title}   = 'Fix FitBit';
    $message->{message} = 'Token did not work';
    pushover($message);
}

sub get_token () {
    my $file = '/home/jacoby/.fitbit.yml';
    if ( -f $file ) {
        my $yaml = LoadFile($file);
        return $yaml->{token};
    }
    exit;
}

