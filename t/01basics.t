# vim:ft=perl
use Test::More;
use lib 'ex'; # Where BeerDB should live
BEGIN {
    eval { require BeerDB };
    Test::More->import( skip_all =>
        "SQLite not working or BeerDB module could not be loaded: $@"
    ) if $@;

    plan tests => 15;
}
use Maypole::CLI qw(BeerDB);
use Maypole::Constants;
$ENV{MAYPOLE_TEMPLATES} = "t/templates";

isa_ok( (bless {},"BeerDB") , "Maypole");

# Test the effect of trailing slash on config->uri_base and request URI
(my $uri_base = BeerDB->config->uri_base) =~ s:/$::;
BeerDB->config->uri_base($uri_base);
like(BeerDB->call_url("http://localhost/beerdb/"), qr/frontpage/,
     "Got frontpage, trailing '/' on request but not uri_base");
like(BeerDB->call_url("http://localhost/beerdb"), qr/frontpage/,
     "Got frontpage, no trailing '/' on request or uri_base");
BeerDB->config->uri_base($uri_base . '/');
like(BeerDB->call_url("http://localhost/beerdb/"), qr/frontpage/,
     "Got frontpage, trailing '/' on uri_base and request");
like(BeerDB->call_url("http://localhost/beerdb"), qr/frontpage/,
     "Got frontpage, trailing '/' on uri_base but not request");

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

