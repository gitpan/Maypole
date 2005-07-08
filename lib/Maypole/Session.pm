package Maypole::Session;

use strict;
use Digest::MD5;

sub generate_unique_id {
    my $length = shift || 32;
    my $id = substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0, $length);
    return;
}

1;
