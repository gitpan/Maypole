# vim:ft=perl
use Test::More;
use lib 'ex'; # Where BeerDB should live
BEGIN { if (eval { require BeerDB }) { 
            plan tests => 12;
        } else { Test::More->import(skip_all =>"SQLite not working or BeerDB module could not be loaded: $@") }
      }
use Maypole::CLI qw(BeerDB);
use Maypole::Constants;
$ENV{MAYPOLE_TEMPLATES} = "t/templates";

isa_ok( (bless {},"BeerDB") , "Maypole");

like(BeerDB->call_url("http://localhost/beerdb/"), qr/frontpage/, "Got the front page");
like(BeerDB->call_url("http://localhost/beerdb/beer/list"), qr/Organic Best/, "Found a beer in the list");
my (%classdata)=split /\n/, BeerDB->call_url("http://localhost/beerdb/beer/classdata");
is ($classdata{plural},'beers','classdata.plural');
is ($classdata{moniker},'beer','classdata.moniker');
like ($classdata{cgi},qr/^HTML::Element/,'classdata.cgi');
is ($classdata{table},'beer','classdata.table');
is ($classdata{name},'BeerDB::Beer','classdata.name');
is ($classdata{colnames},'Abv','classdata.colnames');
is($classdata{columns}, 'abv brewery id name notes price score style url',
   'classdata.columns');
is($classdata{list_columns}, 'score name price style brewery url',
   'classdata.list_columns');
is ($classdata{related_accessors},'pubs','classdata.related_accessors');

