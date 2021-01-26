#!/usr/bin/env perl
use 5.14.0;
use warnings;
use AnyEvent;

@ARGV == 1 || @ARGV == 2 or die "usage: $0 device [interval]\n";
my $device = shift;
my $interval = shift || 5;

$| = 1;

my $cv = AnyEvent->condvar;

my $rssi_timer = AnyEvent->timer(
  after => $interval,
  interval => $interval,
  cb => sub {
    for (`btmgmt find`) {
      if (/dev_found: \Q$device\E.*\brssi (-?\d+)\b/) {
        my $strength = $1;
        print "$strength\n";
      }
    }
  },
);

$cv->recv;
