package Maypole::Model::CDBI::Plain;
use base 'Maypole::Model::CDBI';
sub setup_database {
    my ($self, $config, $namespace, $classes) = @_;
    $config->{classes} = $classes;
    $config->{table_to_class}  = { map { $_->table => $_ } @$classes };
    $config->{tables} = [ keys %{$config->{table_to_class}} ];
}

sub class_of {
    my ($self, $r, $table) = @_;
    return $r->config->{table_to_class}->{$table};
}

1;

=head1 NAME

Maypole::Model::CDBI::Plain - Class::DBI model without ::Loader

=head1 SYNOPSIS

    package Foo;
    use base 'Apache::DBI';
    use Foo::SomeTable;
    use Foo::Other::Table;

    Foo->config->{model_class} = "Maypole::Model::CDBI::Plain";
    Foo->setup([qw/ Foo::SomeTable Foo::Other::Table /]);

=head1 DESCRIPTION

This module allows you to use Maypole with previously set-up
C<Class::DBI> classes; simply call C<setup> with a list reference
of the classes you're going to use, and Maypole will work out the
tables and set up the inheritance relationships as normal.

=cut
