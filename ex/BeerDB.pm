package BeerDB;
use base 'Maypole::Application';
use Class::DBI::Loader::Relationship;

# This is the sample application. Change this to the path to your
# database. (or use mysql or something)
BeerDB->setup("dbi:SQLite:t/beerdb.db");
#BeerDB->setup("dbi:mysql:beerdb");

# Give it a name.
BeerDB->config->{application_name} = 'The Beer Database';

# Change this to the root of the web space.
BeerDB->config->{uri_base} = "http://localhost/beerdb/";
#BeerDB->config->{uri_base} = "http://neo.trinity-house.org.uk/beerdb/";

BeerDB->config->{rows_per_page} = 10;

# Handpumps should not show up.
BeerDB->config->{display_tables} = [qw[beer brewery pub style]];
BeerDB::Brewery->untaint_columns( printable => [qw/name notes url/] );
BeerDB::Style->untaint_columns( printable => [qw/name notes/] );
BeerDB::Beer->untaint_columns(
    printable => [qw/abv name price notes url/],
    integer => [qw/style brewery score/],
    date =>[ qw/date/],
);
BeerDB->config->{loader}->relationship($_) for (
    "a brewery produces beers",
    "a style defines beers",
    "a pub has beers on handpumps");
1;
