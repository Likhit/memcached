#!/usr/bin/perl
# Networked logging tests.

# The same test as in watcher.t but using rejig commands instead.

use strict;
use warnings;
use Socket qw/SO_RCVBUF/;

use Test::More tests => 8;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached('-m 60 -o watcher_logbuf_size=8');
my $client = $server->sock;
my $watcher = $server->new_sock;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;
my $sock = $server->sock;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

# This doesn't return anything.
print $watcher "watch\n";
my $res = <$watcher>;
is($res, "OK\r\n", "watcher enabled");

print $client "rj $config_id $fragment_id get foo\n";
$res = <$client>;
is($res, "END\r\n", "basic get works");
my $spacer = "X"x180;

# This is a flaky test... depends on buffer sizes. Could either have memc
# shrink the watcher buffer, or loop this and keep doubling until we get some
# skipped values.
for (1 .. 80000) {
    print $client "rj $config_id $fragment_id get foo$_$spacer\n";
    $res = <$client>;
}

# Let the logger thread catch up before we start reading.
sleep 1;
my $do_fetch = 0;
#print STDERR "RESULT: $res\n";
while (my $log = <$watcher>) {
    # The "skipped" line won't actually print until some space frees up in the
    # buffer, so we need to occasionally cause new lines to generate.
    if (($do_fetch++ % 100) == 0) {
         print $client "rj $config_id $fragment_id get foo\n";
         $res = <$client>;
    }
    next unless $log =~ m/skipped/;
    like($log, qr/skipped=/, "skipped some lines");
    # This should unjam more of the text.
    print $client "rj $config_id $fragment_id get foob\n";
    $res = <$client>;
    last;
}
$res = <$watcher>;
like($res, qr/ts=\d+\.\d+\ gid=\d+ type=item_get/, "saw a real log line after a skip");

# test combined logs
# fill to evictions, then enable watcher, set again, and look for both lines

{
    my $value = "B"x11000;
    my $keycount = 8000;

    for (1 .. $keycount) {
        print $client "rj $config_id $fragment_id set n,foo$_ 0 0 11000 noreply\r\n$value\r\n";
    }

    $watcher = $server->new_sock;
    print $watcher "watch mutations evictions\n";
    $res = <$watcher>;
    is($res, "OK\r\n", "new watcher enabled");
    my $watcher2 = $server->new_sock;
    print $watcher2 "watch evictions\n";
    $res = <$watcher2>;
    is($res, "OK\r\n", "evictions watcher enabled");

    print $client "rj $config_id $fragment_id set bfoo 0 0 11000 noreply\r\n$value\r\n";
    my $found_log = 0;
    my $found_ev  = 0;
    while (my $log = <$watcher>) {
        $found_log = 1 if ($log =~ m/type=item_store/);
        $found_ev = 1 if ($log =~ m/type=eviction/);
        last if ($found_log && $found_ev);
    }
    is($found_log, 1, "found rawcmd log entry");
    is($found_ev, 1, "found eviction log entry");
}
