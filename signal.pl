#!/usr/bin/env perl
use 5.14.0;
use warnings;
use AnyEvent;
use AnyEvent::Run;

@ARGV == 1 || @ARGV == 2 or die "usage: $0 device [interval]\n";
my $device = shift;
my $interval = shift || 5;

$| = 1;

my $cv = AnyEvent->condvar;

my $rfcomm_handle;
my $rfcomm_timer;
sub rfcomm {
  my @cmd = ('rfcomm', 'connect', 1, $device);
  warn((join ' ', @cmd) . "\n");

  return AnyEvent::Run->new(
    cmd => \@cmd,
    on_read => sub {
      my $handle = shift;
      chomp $handle->{rbuf};
      warn "… rfcomm: $handle->{rbuf}\n" if length $handle->{rbuf};
      $handle->{rbuf} = "";
    },
    on_error => sub {
      my ($handle, $fatal, $msg) = @_;
      undef $rfcomm_handle;
      warn "… rfcomm error: $msg\n";

      $rfcomm_timer = AnyEvent->timer(
        after => $interval,
        cb => sub {
          undef $rfcomm_timer;
          $rfcomm_handle = rfcomm();
        },
      );
    },
  );
}
$rfcomm_handle = rfcomm();

my $rssi_timer = AnyEvent->timer(
  after => $interval,
  interval => $interval,
  cb => sub {
    my $rssi = `hcitool rssi $device 2>&1`;
    chomp $rssi;

    if ($rssi =~ /^RSSI return value: (-?\d+)$/m) {
      my $strength = $1;
      print "$strength\n";
    } else {
      warn "… hcitool: $rssi\n";
    }
  },
);

$cv->recv;
