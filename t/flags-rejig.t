#!/usr/bin/perl

# The same test as in flags.t but using rejig commands instead.

use strict;
use Test::More tests => 10;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached();
my $sock = $server->sock;
my $config_id = 1;
my $fragment_id = 1;
my $fragment_lease_time = 300;

# Initialize the config and number of fragments.
print $sock "rj $config_id $fragment_id conf 0 0 12\r\ndummy_config\r\n";
is(scalar <$sock>, "STORED\r\n", "stored config");

# Grant a lease on the fragment
print $sock "rj $config_id $fragment_id grant $fragment_lease_time\r\n";
is(scalar <$sock>, "GRANTED\r\n", "granted lease");

# set foo (and should get it)
for my $flags (0, 123, 2**16-1, 2**31) {
    print $sock "rj $config_id $fragment_id set foo $flags 0 6\r\nfooval\r\n";
    is(scalar <$sock>, "STORED\r\n", "stored foo");
    rejig_mem_get_is({ sock => $sock,
                 flags => $flags }, $config_id, $fragment_id, "foo", "fooval", "got flags $flags back");
}
