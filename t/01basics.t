# vim:ft=perl
use Test::More;
use lib 'ex'; # Where BeerDB should live
BEGIN { if (eval { require BeerDB }) { 
            plan tests => 3;
        } else { Test::More->import(skip_all =>"SQLite not working or BeerDB module could not be loaded: $@") }
      }
use Maypole::CLI qw(BeerDB);
use Maypole::Constants;
$ENV{MAYPOLE_TEMPLATES} = "t/templates";

isa_ok( (bless {},"BeerDB") , "Maypole");

like(BeerDB->call_url("http://localhost/beerdb/"), qr/frontpage/, "Got the front page");
like(BeerDB->call_url("http://localhost/beerdb/beer/list"), qr/Organic Best/, "Found a beer in the list");
