#!/usr/bin/perl -w
use Test::More;
use lib 'ex'; # Where BeerDB should live
BEGIN {
   plan tests => 35;
}

$db     	= 'test';
$dbuser 	= 'test';
$dbpasswd   = '';
$table = "beer_test";
$sql = "
create table $table (
    id integer auto_increment primary key,
    name char(30) NOT NULL default 'noname',
    url varchar(120),
    score smallint(2),
    price decimal(3,2),
    abv varchar(10),
    image blob,
    notes text,
    tasted date NOT NULL,
    created timestamp default CURRENT_TIMESTAMP,
    modified datetime  default NULL,
    style mediumint(8) NOT NULL default 1,
    brewery integer default NULL
);";

# correct column types and the ones we test
%correct_types = (
		  id 		=> 	'int', # mysql 4.1 stores this for 'integer' 
		  brewery 	=> 	'int',
		  style 	=> 	'int',
		  name 		=> 	'char',
		  url 		=>  'varchar',
		  tasted 	=>	'date',
		  created 	=>	'(time|time)',
		  modified 	=>	'(date|time)',
		  score 	=>	'smallint',
		  price 	=> 	'decimal',
		  abv 		=>	'varchar',
		  notes 	=>  '(text|blob)',
		  image 	=>	'blob',
);

# correct defaults 
%correct_defaults = (
		  created 	=>	'CURRENT_TIMESTAMP', 
		  modified 	=>	undef, 
		  style 	=> 1,	
		  name      => 'noname',
);

# correct nullables 
%correct_nullables = (
		  brewery   => 1, 
		  modified 	=> 1,
		  style 	=> 0,	
		      name      => 0, 
		  tasted    => 0,
);


# Runs tests on column_* method of $class using %correct data hash  
# usage: run_method_tests ($class, $method, %correct);
sub run_method_tests { 
  ($class, $method,  %correct)  = @_;
  for $col (sort keys %correct) {
#    warn "class : $class\n";
#    warn "ISA : ", join(', ',@BeerDB::BeerTestmysql::ISA);
    $val = $class->$method($col);

    # Hacks for various val types
    $val = lc $val if $method eq 'column_type';

    my $correct = $correct{$col};
    like($val, qr/$correct/,"$method $col is $val");
  }
}


# mysql test

# Make test class 
package BeerDB::BeerTestmysql;
use base Maypole::Model::CDBI;
package main;

$DB_Class = 'BeerDB::BeerTestmysql';

my $drh = DBI->install_driver("mysql");
my %databases = map { $_ => 1 } $drh->func('localhost', 3306, '_ListDBs');

unless ($databases{test}) {
  my $rc = $drh->func("createdb", 'test', 'admin');
}

%databases = map { $_ => 1 } $drh->func('localhost', 3306, '_ListDBs');

if ($databases{test}) {
  eval {$DB_Class->connection("dbi:mysql:$db", "$dbuser", "$dbpasswd"); };
  $err = $@;
  $skip_msg = "Could not connect to MySQL using database 'test', username 'test', and password ''. Check privileges and try again.";
} else {
  $err = 'no test db';
  $skip_msg = "Could not connect to MySQL using database 'test' as it doesn't exist, sorry";
}

$skip_howmany = 22;

SKIP: {
   	skip $skip_msg, $skip_howmany  if $err;
	$DB_Class->db_Main->do("drop table if exists $table;");
	$DB_Class->db_Main->do($sql);
	$DB_Class->table($table);
	run_method_tests($DB_Class,'column_type', %correct_types);
	run_method_tests($DB_Class,'column_default', %correct_defaults);
	run_method_tests($DB_Class,'column_nullable', %correct_nullables);
};

# SQLite  test

package BeerDB::BeerTestsqlite;
use base Maypole::Model::CDBI;
package main;
use Cwd;

$DB_Class = 'BeerDB::BeerTestsqlite';

$err = undef;
if ( !-e "t/test.db" ) {
	eval {make_sqlite_db($sql)};
	$err = $@;
	if ($err) { print "Skipping sql tests because couldnt make sqlite test db
		because of error: $err";};
}
unless ($err) {
	my $driver = sqlite_driver();
	warn "using driver : $driver";
	my $cwd = cwd;
	eval { $DB_Class->connection("dbi:$driver:dbname=$cwd/t/test.db");};
	$err = $@;
}

$skip_msg = "Could not connect to SQLite database 't/test.db'";
$skip_howmany = 13;

SKIP: {
   	skip $skip_msg, $skip_howmany  if $err; 
	$DB_Class->table($table); 
#use Data::Dumper; 
	run_method_tests($DB_Class,'column_type', %correct_types);
	# No support default
	#run_method_tests($DB_Class,'column_default', %correct_defaults);
	# I think sqlite driver allows everything to be nullable.
	#run_method_tests($DB_Class,'column_nullable', %correct_nullables);

};


# Helper methods, TODO -- put these somewhere where tests can use them.

# returns "best" available sqlite driver or dies
sub sqlite_driver { 
    my $driver = 'SQLite';
    eval { require DBD::SQLite } or do {
        print "Error loading DBD::SQLite, trying DBD::SQLite2\n";
        eval {require DBD::SQLite2} ? $driver = 'SQLite2'
            : die "DBD::SQLite2 is not installed";
   };
	return $driver;
}


# make_sqlite_db -- makes an sqlite database from params
# usage -- make_sqlite_db($sql [, $dbname ]);   
sub make_sqlite_db {
	my ($sql, $dbname) = @_;
	die "Must provide SQL string" unless length $sql;
	$dbname ||= 't/test.db';
	print "Making SQLite DB $dbname\n";
    my $driver = sqlite_driver; 
    require DBI;
    my $dbh = DBI->connect("dbi:$driver:dbname=$dbname");

    for my $statement ( split /;/, $sql ) {
        $statement =~ s/\#.*$//mg;           # strip # comments
        $statement =~ s/auto_increment//g;
        next unless $statement =~ /\S/;
        eval { $dbh->do($statement) };
        die "$@: $statement" if $@;
    }
	$dbh->disconnect;
	print "Successfully made  SQLite DB $dbname\n";
	return 1;
}
