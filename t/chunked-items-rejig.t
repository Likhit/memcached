#!/usr/bin/perl
# Networked logging tests.

use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached('-m 48 -o slab_chunk_max=16384');
my $sock = $server->sock;
my $config_id = 1;
my $fragment_num = 1;
my $fragment_lease_time = 300;

# We're testing to ensure item chaining doesn't corrupt or poorly overlap
# data, so create a non-repeating pattern.
my @parts = ();
for (1 .. 8000) {
    push(@parts, $_);
}
my $pattern = join(':', @parts);

my $plen = length($pattern);

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_num conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_num grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

print $sock "rj $config_id $fragment_num set pattern 0 0 $plen\r\n$pattern\r\n";
is(scalar <$sock>, "STORED\r\n", "stored pattern successfully");

rejig_mem_get_is($sock, $config_id, $fragment_num, "pattern", $pattern);

for (1..5) {
    my $size = 400 * 1024;
    my $data = "x" x $size;
    print $sock "rj $config_id $fragment_num set foo$_ 0 0 $size\r\n$data\r\n";
    my $res = <$sock>;
    is($res, "STORED\r\n", "stored some big items");
}

{
    my $max = 1024 * 1024;
    my $big = "a big value that's > .5M and < 1M. ";
    while (length($big) * 2 < $max) {
        $big = $big . $big;
    }
    my $biglen = length($big);

    for (1..100) {
        print $sock "rj $config_id $fragment_num set toast$_ 0 0 $biglen\r\n$big\r\n";
        is(scalar <$sock>, "STORED\r\n", "stored big");
        rejig_mem_get_is($sock, $config_id, $fragment_num, "toast$_", $big);
    }
}

# Test a wide range of sets.
{
    my $len = 1024 * 200;
    while ($len < 1024 * 1024) {
        my $val = "B" x $len;
        print $sock "rj $config_id $fragment_num set foo_$len 0 0 $len\r\n$val\r\n";
        is(scalar <$sock>, "STORED\r\n", "stored size $len");
        $len += 2048;
    }
}

# Test long appends and prepends.
# Note: memory bloats like crazy if we use one test per request.
{
    my $str = 'seedstring';
    my $len = length($str);
    print $sock "rj $config_id $fragment_num set appender 0 0 $len\r\n$str\r\n";
    is(scalar <$sock>, "STORED\r\n", "stored seed string for append");
    my $unexpected = 0;
    for my $part (@parts) {
        # reduce required loops but still have a pattern.
        my $todo = $part . "x" x 10;
        $str .= $todo;
        my $len = length($todo);
        print $sock "rj $config_id $fragment_num append appender 0 0 $len\r\n$todo\r\n";
        is(scalar <$sock>, "STORED\r\n", "append $todo size $len");
        print $sock "rj $config_id $fragment_num get appender\r\n";
        my $header = scalar <$sock>;
        my $body = scalar <$sock>;
        my $end = scalar <$sock>;
        $unexpected++ unless $body eq "$str\r\n";
    }
    is($unexpected, 0, "No unexpected results during appends\n");
    # Now test appending a chunked item to a chunked item.
    $len = length($str);
    print $sock "rj $config_id $fragment_num append appender 0 0 $len\r\n$str\r\n";
    is(scalar <$sock>, "STORED\r\n", "append large string size $len");
    rejig_mem_get_is($sock, $config_id, $fragment_num, "appender", $str . $str);
    print $sock "rj $config_id $fragment_num delete appender\r\n";
    is(scalar <$sock>, "DELETED\r\n", "removed appender key");
}

{
    my $str = 'seedstring';
    my $len = length($str);
    print $sock "rj $config_id $fragment_num set prepender 0 0 $len\r\n$str\r\n";
    is(scalar <$sock>, "STORED\r\n", "stored seed string for append");
    my $unexpected = 0;
    for my $part (@parts) {
        # reduce required loops but still have a pattern.
        $part .= "x" x 10;
        $str = $part . $str;
        my $len = length($part);
        print $sock "rj $config_id $fragment_num prepend prepender 0 0 $len\r\n$part\r\n";
        is(scalar <$sock>, "STORED\r\n", "prepend $part size $len");
        print $sock "rj $config_id $fragment_num get prepender\r\n";
        my $header = scalar <$sock>;
        my $body = scalar <$sock>;
        my $end = scalar <$sock>;
        $unexpected++ unless $body eq "$str\r\n";
    }
    is($unexpected, 0, "No unexpected results during prepends\n");
    # Now test prepending a chunked item to a chunked item.
    $len = length($str);
    print $sock "rj $config_id $fragment_num prepend prepender 0 0 $len\r\n$str\r\n";
    is(scalar <$sock>, "STORED\r\n", "prepend large string size $len");
    rejig_mem_get_is($sock, $config_id, $fragment_num, "prepender", $str . $str);
    print $sock "rj $config_id $fragment_num delete prepender\r\n";
    is(scalar <$sock>, "DELETED\r\n", "removed prepender key");
}

done_testing();
