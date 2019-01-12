#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw{ postderef say signatures state };
no warnings qw{ experimental::postderef experimental::signatures };

use DateTime::Format::ISO8601;
use DateTime;
use Getopt::Long;
use IO::Interactive qw{interactive};
use JSON;
use Mojo::UserAgent;
use Pod::Usage;
use YAML qw{LoadFile};

use lib '/home/jacoby/lib';
use Pushover;

my $json = JSON->new->pretty->canonical;
my $mojo = Mojo::UserAgent->new;

my $config   = config();
my $token    = get_token();
my $response = check_fitbit($token);
for my $device ( $response->@* ) {
    my $id = $device->{id};
    my $alarms = get_alarms( $token, $id );
    if ( $config->{json} ) {
        say $json->encode( $alarms->{trackerAlarms} );
    }
    else {
        for my $alarm ( sort { $a->{time} cmp $b->{time} }
            $alarms->{trackerAlarms}->@* )
        {
            next unless $alarm->{enabled};
            my $r = $alarm->{recurring} == 1 ? 1 : 0;
            my $t = $alarm->{time};
            my $d = join ', ', map { substr $_, 0, 3 } $alarm->{weekDays}->@*;
            say join "\t", '', $t, qq{($r)}, $d,;
        }
    }
    if ( $config->{time} ) {
        my $alarm = {};
        $alarm->{'tracker-id'} = $device->{id};
        $alarm->{enabled}      = 1;
        $alarm->{time}         = $config->{time};
        $alarm->{recurring} =
            defined $config->{recurring} ? $config->{recurring} : 0;
        $alarm->{weekDays} = join ',', $config->{days}->@*;
        my $r = set_alarm( $token, $alarm );
        say $json->encode( { r => $r } );
        say $json->encode( { a => $alarm } );
    }

    # say $json->encode($device);

    # say $json->encode($config);
}

exit;

sub set_alarm ( $token, $alarm ) {
    say $json->encode($alarm);
    my $server = 'https://api.fitbit.com';
    my $url = join '/', $server, 1, 'user', '-', 'devices', 'tracker',
        $alarm->{'tracker-id'},
        'alarms.json';
    my $res =
        $mojo->post(
        $url => { 'Authorization' => "Bearer $token" } => form => $alarm )
        ->result;
    if ( $res->is_success ) {
        my $obj = $json->decode( $res->body );
        return $obj;
    }
}

sub get_alarms ( $token, $id ) {
    my $server = 'https://api.fitbit.com';
    my $url = join '/', $server, 1, 'user', '-', 'devices', 'tracker', $id,
        'alarms.json';
    my $res =
        $mojo->get( $url, { 'Authorization' => "Bearer $token", } )->result;
    if ( $res->is_success ) {
        my $obj = $json->decode( $res->body );
        return $obj;
    }
    return {};
}

sub check_fitbit( $token ) {
    my $server = 'https://api.fitbit.com';
    my $url = join '/', $server, 1, 'user', '-', 'devices.json';
    my $res =
        $mojo->get( $url, { 'Authorization' => "Bearer $token", } )->result;
    if ( $res->is_success ) {
        my $obj = $json->decode( $res->body );
        return $obj;
    }
    else {
        fix_fitbit();
        exit;
    }
    return [];
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

sub config () {
    my $config;
    GetOptions(
        'days=s'    => \$config->{days}->@*,
        'recurring' => \$config->{recurring},
        'time=s'    => \$config->{time},
        'json'      => \$config->{json},
        'help'      => \$config->{help},
        'man'       => \$config->{man},
    );
    pod2usage( -verbose => 2, -exitval => 1 ) if $config->{man};
    pod2usage( -verbose => 1, -exitval => 1 ) if $config->{help};
    map      { delete $config->{$_} }
        grep { !defined $config->{$_} } keys $config->%*;
    if ( grep { /all/i } $config->{days}->@* ) {
        $config->{days}->@* = qw{MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY
            SATURDAY SUNDAY};
    }
    elsif ( grep { /weekends/i } $config->{days}->@* ) {
        $config->{days}->@* = qw{SATURDAY SUNDAY};
    }
    elsif ( grep { /weekdays/i } $config->{days}->@* ) {
        $config->{days}->@* = qw{ MONDAY TUESDAY WEDNESDAY THURSDAY FRIDAY};
    }
    elsif ( scalar $config->{days}->@* ) {
        $config->{days}->@* = map { uc $_ } $config->{days}->@*;
    }
    return $config;
}

sub get_token () {
    my $file = '/home/jacoby/.fitbit.yml';
    if ( -f $file ) {
        my $yaml = LoadFile($file);
        return $yaml->{token};
    }
    exit;
}

