#!/usr/bin/perl
# Ensure get and gets can mirror flags + CAS properly when not inlining the
# ascii response header.

# The same test as in inline_asciihdr.t but using rejig commands instead.

use strict;
use Test::More tests => 19;
use FindBin qw($Bin);
use lib "$Bin/lib";
use MemcachedTest;
use MemcachedTestRejig;

my $server = new_memcached('-o no_inline_ascii_resp');
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

# 0 flags and size
print $sock "rj $config_id $fragment_id set foo 0 0 0\r\n\r\n";
is(scalar <$sock>, "STORED\r\n", "stored");

mem_get_is($sock, "foo", "");

for my $flags (0, 123, 2**16-1, 2**31, 2**32-1) {
    print $sock "rj $config_id $fragment_id set foo $flags 0 6\r\nfooval\r\n";
    is(scalar <$sock>, "STORED\r\n", "stored foo");
    rejig_mem_get_is({ sock => $sock,
                 flags => $flags }, $config_id, $fragment_id, "foo", "fooval", "got flags $flags back");
    my @res = mem_gets($sock, "foo");
    rejig_mem_gets_is({ sock => $sock,
                  flags => $flags }, $config_id, $fragment_id, $res[0], "foo", "fooval", "got flags $flags back");

}


