#!/usr/bin/env perl
use 5.14.0;
use warnings;
use AnyEvent;
use AnyEvent::Run;
use AnyEvent::HTTP;
use JSON;
use File::Slurp 'slurp';

@ARGV == 0 || @ARGV == 1 or die "usage: $0 [interval]\n";
my $interval = shift || 5;

my $json = JSON->new->utf8->canonical;
my $config = $json->decode(scalar slurp 'config.json');

my $cv = AnyEvent->condvar;

my $signal_handle;
my $signal_timer;
sub signal {
  my @cmd = ('./signal.pl', $config->{device}, $interval);
  warn((join ' ', @cmd) . "\n");

  return AnyEvent::Run->new(
    cmd => \@cmd,
    on_read => sub {
      my $handle = shift;
      my $buf = $handle->{rbuf};
      $handle->{rbuf} = "";

      chomp $buf;
      if ($buf =~ /^(-?\d+)$/m) {
        my $signal = $1;
        print "Signal: $signal\n";
        publish_signal(0 + $signal);
      } else {
        warn '… signal.pl: ' . $buf . "\n";
      }
    },
    on_error => sub {
      my ($handle, $fatal, $msg) = @_;
      undef $signal_handle;
      warn "… signal.pl error: $msg\n";

      $signal_timer = AnyEvent->timer(
        after => $interval,
        cb => sub {
          undef $signal_timer;
          $signal_handle = signal();
        },
      );
    },
  );
}
$signal_handle = signal();

sub publish {
  my $content = shift;

  my $content_type = 'text/plain';
  if (ref($content)) {
    $content_type = 'application/json';
    $content = $json->encode($content);
  }

  http_request(
    POST => "$config->{publishUrl}/presence/$config->{location}",
    headers => {
      'User-Agent' => $config->{pubsubUser},
      'Content-Type' => $content_type,
      'X-Pubsub-Username' => $config->{pubsubUser},
      'X-Pubsub-Password' => $config->{pubsubPass},
      'X-Pubsub-Expire-In' => 60*60,
    },
    body => $content,
    sub {},
  );
}

sub publish_signal {
  my $signal = shift;
  publish({
    signal => $signal,
    location => $config->{location},
    device => $config->{device},
  });
}

$cv->recv;
