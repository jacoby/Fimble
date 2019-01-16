#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw{ postderef say signatures state };
no warnings qw{ experimental::postderef experimental::signatures };

use DateTime::Format::ISO8601;
use DateTime::Duration;
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

my $day = DateTime->now()->set_time_zone('America/New_York');
my $days = {};

for ( 00 .. 20 ) {
    $day->subtract(days=>1);
    my $date =  $day->ymd;
    say $date;
    my $sleep = get_sleep($token,$date);
    $days->{$date} = $sleep->{summary};
    say $json->encode($days);
    sleep 30;
}

if ( open my $fh ,'>', 'sleep.json') {
    say $fh $json->encode($days);
}



# my @days ;
# push @days, get_sleep( $token) ;
# push @days, get_sleep( $token, '2019-01-14' ) ;
# push @days, get_sleep( $token, '2018-11-20' ) ;

exit;

exit;

sub get_sleep ( $token , $date='' ) {
    if ( $date eq '' ) {
        $date = DateTime->now()->set_time_zone('floating')->ymd;
    }
    my $server = 'https://api.fitbit.com';
    my $url = join '/', $server, 1.2, 'user', '-', 
        'sleep', 'date',$date . '.json';
    say $date;
    say $url;
    my $res =
        $mojo->get( $url, { 'Authorization' => "Bearer $token", } )->result;
    if ( $res->is_success ) {
        my $obj = $json->decode( $res->body );
        say $json->encode($obj);
        return $obj;
    } else {
        say STDERR $res->code;
    }
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

=head1 NAME

fb_alarms.pl - add an alarm to your FitBit

=head1 SYNOPSIS

    fb_alarms.pl 
    fb_alarms.pl -j
    fb_alarms.pl -h
    fb_alarms.pl -m
    fb_alarms.pl -t (24-hour time)+|-(timezone offset) ][-r]
                 [-d (name of day|weekdays|weekends|all)]

=head1 DESCRIPTION

This program creates a QR Code from the message specified

=head1 OPTIONS

=over 4

=item B<-j>, B<--json>

Display output of current state of alarms in JSON

=item B<-t>, B<--time>

The time the alert should occur, in the form I<HH:MMTimezoneOffset>, so 
for Noon in Indianapolis during winter, it would be I<12:00-05:00>. 

=item B<-r>, B<--recurring>

Run this task more than once. requires B<-d>

=item B<-d>, B<--days>

Lists the days the alarm will be set for. Takes the full name of the day
(i.e., "monday", not "mon") or "weekdays", "weekends" or "all". Required for

=item B<-m>, B<--manual>
=item B<-h>, B<--help>

Shows the documentation, in either extended or abbreviated form

=back

=head1 LICENSE

This is released under the Artistic 
License. See L<perlartistic>.

=head1 AUTHOR

Dave Jacoby L<jacoby.david@gmail.com>

=cut

