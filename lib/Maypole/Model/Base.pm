package Maypole::Model::Base;
our %remember;
sub MODIFY_CODE_ATTRIBUTES { $remember{$_[1]} = $_[2]; () }

sub FETCH_CODE_ATTRIBUTES { $remember{$_[1]} } 
sub view :Exported { }
sub edit :Exported { }

sub process {
    my ($class, $r) = @_;
    my $method = $r->action;
    return if $r->{template}; # Authentication has set this, we're done.

    $r->{template} = $method;
    $r->objects([]);
    my $obj = $class->retrieve( $r->{args}->[0] );
    if ($obj) {
        $r->objects([ $obj ]);
        shift @{$r->{args}};
    }
    $class->$method($r);
}

sub display_columns { 
    sort shift->columns;
}

=head1 NAME

Maypole::Model::Base - Base class for model classes

=head1 DESCRIPTION

Anyone subclassing this for a different database abstraction mechanism
needs to provide the following methods:

=head2 do_edit

If there is an object in C<$r-E<gt>objects>, then it should be edited
with the parameters in C<$r-E<gt>params>; otherwise, a new object should
be created with those parameters, and put back into C<$r-E<gt>objects>.
The template should be changed to C<view>, or C<edit> if there were any
errors. A hash of errors will be passed to the template.

=cut

sub do_edit { die "This is an abstract method" }

=head2 setup_database

    $model->setup_database($config, $namespace, @data)

Uses the user-defined data in C<@data> to specify a database- for
example, by passing in a DSN. The model class should open the database,
and create a class for each table in the database. These classes will
then be C<adopt>ed. It should also populate C<< $config->{tables} >> and
C<< $config->{classes} >> with the names of the classes and tables
respectively. The classes should be placed under the specified
namespace. For instance, C<beer> should be mapped to the class
C<BeerDB::Beer>.

=head2 class_of

    $model->class_of($r, $table)

This maps between a table name and its associated class.

=head2 retrieve

This turns an ID into an object of the appropriate class.

=head2 adopt

This is called on an model class representing a table and allows the
master model class to do any set-up required. 

=head2 related

This can go either in the master model class or in the individual
classes, and returns a list of has-many accessors. A brewery has many
beers, so C<BeerDB::Brewery> needs to return C<beers>.

=head2 columns

This is a list of all the columns in a table. You may also override
C<display_columns>, which is the list of columns you want to view, in
the right order.

=head2 table

This is the name of the table.

=head2 Commands

=over

=item list

The C<list> method should fill C<< $r-> objects >> with all of the
objects in the class. You may want to page this using C<Data::Page> or
similar.

=back

=cut

sub class_of       { die "This is an abstract method" }
sub setup_database { die "This is an abstract method" }
sub list :Exported { die "This is an abstract method" };

=pod

Also, see the exported commands in C<Maypole::Model::CDBI>.

=head1 Other overrides

Additionally, individual derived model classes may want to override the
following methods:

=head2 column_names

Return a hash mapping column names with human-readable equivalents.

=cut

sub column_names { my $class = shift; map { 
        my $col = $_;
        $col =~ s/_+(\w)?/ \U\1/g;
        $_ => ucfirst $col } $class->columns }

=head2 description

A description of the class to be passed to the template.

=cut

sub description { "A poorly defined class" }

1;

