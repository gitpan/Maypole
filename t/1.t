# vim:ft=perl
use Test::More;
use lib 'ex'; # Where BeerDB should live
BEGIN { if (eval { require BeerDB }) { 
            plan tests => 5;
        } else { Test::More->import(skip_all =>"SQLite not working or BeerDB module not found: $@") }
      }
use Maypole::CLI qw(BeerDB);
use Maypole::Constants;
$ENV{MAYPOLE_TEMPLATES} = "t/templates";

isa_ok( (bless {},"BeerDB") , "Maypole");

@ARGV = ("http://localhost/beerdb/");
is(BeerDB->handler, OK, "OK");
like($Maypole::CLI::buffer, qr/frontpage/, "Got the front page");

@ARGV = ("http://localhost/beerdb/beer/list");
is(BeerDB->handler, OK, "OK");
like($Maypole::CLI::buffer, qr/Organic Best/, "Found a beer in the list");
