package Maypole::Model::CDBI::Plain;
use Maypole::Config;
use base 'Maypole::Model::CDBI';
use strict;

Maypole::Config->mk_accessors(qw(table_to_class));

=head1 NAME

Maypole::Model::CDBI::Plain - Class::DBI model without ::Loader

=head1 SYNOPSIS

    package Foo;
    use 'Maypole::Application';

    Foo->config->model("Maypole::Model::CDBI::Plain");
    Foo->setup([qw/ Foo::SomeTable Foo::Other::Table /]);

    # untaint columns and provide custom actions for each class

    Foo::SomeTable->untaint_columns(email => ['email'], printable => [qw/name description/]);

    Foo::Other::Table->untaint_columns ( ... );

    sub Foo::SomeTable::SomeAction : Exported {

        . . .

    }

=head1 DESCRIPTION

This module allows you to use Maypole with previously set-up
L<Class::DBI> classes; simply call C<setup> with a list reference
of the classes you're going to use, and Maypole will work out the
tables and set up the inheritance relationships as normal.

=head1 METHODS

=head2 setup

  This method is inherited from Maypole::Model::Base and calls setup_database,
  which uses Class::DBI::Loader to create and load Class::DBI classes from
  the given database schema.

=head2 setup_database

  This method loads the model classes for the application

=cut



sub setup_database {
    my ( $self, $config, $namespace, $classes ) = @_;
    $config->{classes}        = $classes;
    foreach my $class (@$classes) { $namespace->load_model_subclass($class); }
    $namespace->model_classes_loaded(1);
    $config->{table_to_class} = { map { $_->table => $_ } @$classes };
    $config->{tables}         = [ keys %{ $config->{table_to_class} } ];
}

=head2 class_of

  returns class for given table

=cut

sub class_of {
    my ( $self, $r, $table ) = @_;
    return $r->config->{table_to_class}->{$table};
}

=head2 adopt

This class method is passed the name of a model class that represensts a table
and allows the master model class to do any set-up required.

=cut

sub adopt {
    my ( $self, $child ) = @_;
    if ( my $col = $child->stringify_column ) {
        $child->columns( Stringify => $col );
    }
}

=head1 SEE ALSO

L<Maypole::Model::Base>

L<Maypole::Model::CDBI>

=cut


1;


