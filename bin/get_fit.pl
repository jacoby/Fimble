#!/usr/bin/env perl

use strict;
use warnings;
use utf8;
use feature qw{ postderef say signatures state switch };
no warnings
    qw{ experimental::postderef experimental::smartmatch experimental::signatures };

use DateTime;
use Data::Dumper;
use YAML qw{ LoadFile };
use JSON::XS;
use IO::Interactive qw{interactive};

binmode STDOUT, ":utf8";

my $data_file = $ENV{HOME} . '/.fitbit_data.yml';
my $json      = JSON::XS->new->pretty->canonical;
my $now       = DateTime->now()->set_time_zone('America/Indianapolis');

if ( defined $data_file && -f $data_file ) {
    my $output = LoadFile($data_file);
    my $last = DateTime->from_epoch( epoch => $output->{epoch} );
    my $diff = $now->subtract_datetime($last)->in_units('days');

    if ( $diff >= 1 ) {
        print 'No Token';
    }
    elsif ( $output->{days_since_last_sync} > 0 ) {
        print 'No Sync';
    }
    else {
        # my $batt  = qq{$output->{batteryLevel}%};
        my $batt = get_battery($output->{batteryLevel});
        my $steps = qq{$output->{steps}s};
        print qq{$batt  $steps};
    }
}

sub get_battery ( $level ) {
    if ( $level > 80 ) {  return "" }
    if ( $level > 60 ) {  return "" }
    if ( $level > 40 ) {  return "" }
    if ( $level > 20 ) {  return "" }
    return '' ;
}

