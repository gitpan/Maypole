#!/usr/bin/perl -w
use strict;
use Test::More tests => 10;

require_ok('Maypole::Application');
ok($INC{'Maypole.pm'}, 'requires Maypole');
ok($INC{'Maypole/Config.pm'}, 'requires Maypole::Config');

for (qw(Apples Pears Oranges)) {
    $INC{"Maypole/Plugin/$_.pm"} = 1;
}

package Maypole::Test;
import Maypole::Application qw(Oranges Apples Pears);
package main;

local $ENV{MOD_PERL}; #unlikely to be set when running unit tests, but you
                      #never know
ok($INC{'CGI/Maypole.pm'}, 'requires CGI::Maypole');
ok (Maypole::Test->isa('Maypole'), '... calling application isa(Maypole)');

is_deeply \@Maypole::Test::ISA, [qw(
    Maypole::Plugin::Oranges
    Maypole::Plugin::Apples
    Maypole::Plugin::Pears
    Maypole::Application
)], q[import sets up caller's @ISA in correct order];

isa_ok (Maypole::Test->config, 'Maypole::Config');

# -Debug
ok (!Maypole::Test->debug, '$caller->debug() is false by default');
package Maypole::Test;
import Maypole::Application qw(-Debug);
package main;

ok (Maypole::Test->debug, '-Debug option enables $caller->debug');

# -Setup
my $called_setup;
package Maypole::Test;
sub setup { $called_setup++ };
import Maypole::Application qw(-Setup);
package main;
ok ($called_setup, '-Setup option invokes $caller->setup');
