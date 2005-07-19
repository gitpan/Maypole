package Maypole::Model::CDBI;
use base qw(Maypole::Model::Base Class::DBI);
use Class::DBI::AsForm;
use Class::DBI::FromCGI;
use Class::DBI::Loader;
use Class::DBI::AbstractSearch;
use Class::DBI::Plugin::RetrieveAll;
use Class::DBI::Pager;

use Lingua::EN::Inflect::Number qw(to_PL);
use CGI::Untaint;
use strict;

=head1 NAME

Maypole::Model::CDBI - Model class based on Class::DBI

=head1 DESCRIPTION

This is a master model class which uses L<Class::DBI> to do all the hard
work of fetching rows and representing them as objects. It is a good
model to copy if you're replacing it with other database abstraction
modules.

It implements a base set of methods required for a Maypole Data Model.
See L<Maypole::Model::Base> for these:

=over 4

=item adopt

=item class_of

=item do_edit

=item list

=item related

=item setup_database

=item fetch_objects

=back 

=head1 Additional Actions

=over 

=item delete

Unsuprisingly, this command causes a database record to be forever lost.

=item search

The search action 

=back

=head1 Helper Methods

=over 

=item order

=item stringify_column

=item do_pager

=item related_class

Given an accessor name as a method, this function returns the class this accessor returns.

=back

=cut

sub related {
    my ( $self, $r ) = @_;
    return keys %{ $self->meta_info('has_many') || {} };
}

sub related_class {
    my ( $self, $r, $accessor ) = @_;

    my $related = $self->meta_info( has_many => $accessor ) ||
                  $self->meta_info( has_a    => $accessor ) ||
                  return;

    my $mapping = $related->{args}->{mapping};
    if ( @$mapping ) {
        return $related->{foreign_class}->meta_info('has_a')->{ $$mapping[0] }
          ->{foreign_class};
    }
    else {
        return $related->{foreign_class};
    }
}

sub do_edit : Exported {
    my ( $self, $r ) = @_;
    my $h        = CGI::Untaint->new( %{ $r->{params} } );
    my $creating = 0;
    my ($obj) = @{ $r->objects || [] };
    my $fatal;
    if ($obj) {
        # We have something to edit
        eval {
            $obj->update_from_cgi( $h =>
                { required => $r->{config}{ $r->{table} }{required_cols} || [], }
            );
        };
        $fatal = $@;
    }
    else {
        eval {
            $obj =
                $self->create_from_cgi( $h =>
                    { required => $r->{config}{ $r->{table} }{required_cols} || [], }
            );
        };
        if ($fatal = $@) {
            warn "$fatal" if $r->debug;
        }
        $creating++;
    }
    if ( my %errors = $fatal ? (FATAL => $fatal) : $obj->cgi_update_errors ) {

        # Set it up as it was:
        $r->{template_args}{cgi_params} = $r->{params};
        $r->{template_args}{errors}     = \%errors;

        undef $obj if $creating;
        $r->template("edit");
    }
    else {
        $r->{template} = "view";
    }
    $r->objects( $obj ? [$obj] : []);
}

sub delete : Exported {
    return shift->SUPER::delete(@_) if caller ne "Maypole::Model::Base";
    my ( $self, $r ) = @_;
    $_->SUPER::delete for @{ $r->objects || [] };
    $r->objects( [ $self->retrieve_all ] );
    $r->{template} = "list";
    $self->list($r);
}

sub stringify_column {
    my $class = shift;
    return (
        $class->columns("Stringify"),
        ( grep { /^(name|title)$/i } $class->columns ),
        ( grep { /(name|title)/i } $class->columns ),
        ( grep { !/id$/i } $class->primary_columns ),
    )[0];
}

sub adopt {
    my ( $self, $child ) = @_;
    $child->autoupdate(1);
    if ( my $col = $child->stringify_column ) {
        $child->columns( Stringify => $col );
    }
}

sub search : Exported {
    return shift->SUPER::search(@_) if caller ne "Maypole::Model::Base";

    # A real CDBI search.
    my ( $self, $r ) = @_;
    my %fields = map { $_ => 1 } $self->columns;
    my $oper   = "like";                                # For now
    my %params = %{ $r->{params} };
    my %values = map { $_ => { $oper, $params{$_} } }
      grep { defined $params{$_} && length ($params{$_}) && $fields{$_} }
      keys %params;

    $r->template("list");
    if ( !%values ) { return $self->list($r) }
    my $order = $self->order($r);
    $self = $self->do_pager($r);
    $r->objects(
        [
            $self->search_where(
                \%values, ( $order ? { order_by => $order } : () )
            )
        ]
    );
    $r->{template_args}{search} = 1;
}

sub do_pager {
    my ( $self, $r ) = @_;
    if ( my $rows = $r->config->rows_per_page ) {
        return $r->{template_args}{pager} =
          $self->pager( $rows, $r->query->{page} );
    }
    else { return $self }
}

sub order {
    my ( $self, $r ) = @_;
    my %ok_columns = map { $_ => 1 } $self->columns;
    my $q = $r->query;
    my $order = $q->{order};
    return unless $order and $ok_columns{$order};
    $order .= ' DESC' if $q->{o2} and $q->{o2} eq 'desc';
    return $order;
}

sub list : Exported {
    my ( $self, $r ) = @_;
    my $order = $self->order($r);
    $self = $self->do_pager($r);
    if ($order) {
        $r->objects( [ $self->retrieve_all_sorted_by($order) ] );
    }
    else {
        $r->objects( [ $self->retrieve_all ] );
    }
}

sub setup_database {
    my ( $class, $config, $namespace, $dsn, $u, $p, $opts ) = @_;
    $dsn  ||= $config->dsn;
    $u    ||= $config->user;
    $p    ||= $config->pass;
    $opts ||= $config->opts;
    $config->dsn($dsn);
    warn "No DSN set in config" unless $dsn;
    $config->loader || $config->loader(
        Class::DBI::Loader->new(
            namespace => $namespace,
            dsn       => $dsn,
            user      => $u,
            password  => $p,
	    %$opts,
        )
    );
    $config->{classes} = [ $config->{loader}->classes ];
    $config->{tables}  = [ $config->{loader}->tables ];
    warn( 'Loaded tables: ' . join ',', @{ $config->{tables} } )
      if $namespace->debug;
}

sub class_of {
    my ( $self, $r, $table ) = @_;
    return $r->config->loader->_table2class($table);
}

sub fetch_objects {
    my ($class, $r)=@_;
    my @pcs = $class->primary_columns;
    if ( $#pcs ) {
    my %pks;
        @pks{@pcs}=(@{$r->{args}});
        return $class->retrieve( %pks );
    }
    return $class->retrieve( $r->{args}->[0] );
}

1;
