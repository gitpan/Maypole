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

This is a master model class which uses C<Class::DBI> to do all the hard
work of fetching rows and representing them as objects. It is a good
model to copy if you're replacing it with other database abstraction
modules.

=cut

sub related {
    my ($self, $r) = @_;
    return keys %{$self->meta_info('has_many') || {}};
}

sub do_edit :Exported {
    my ($self, $r) = @_;
    my $h = CGI::Untaint->new(%{$r->{params}});
    my $creating = 0;
    my ($obj) = @{$r->objects || []};
    if ($obj) {
        # We have something to edit
        $obj->update_from_cgi($h => {
           required => $r->{config}{$r->{table}}{required_cols} || [],
                                    });
    } else {
        $obj = $self->create_from_cgi($h => {
           required => $r->{config}{$r->{table}}{required_cols} || [],
                                    });
        $creating++;
    }
    if (my %errors = $obj->cgi_update_errors) {
        # Set it up as it was:
        $r->{template_args}{cgi_params} = $r->{params};
        $r->{template_args}{errors} = \%errors;
        $r->{template} = "edit";
        undef $obj if $creating; # Couldn't create
    } else {
        $r->{template} = "view";
    }
    $r->objects([ $obj ]);
}

sub delete :Exported {
    return shift->SUPER::delete(@_) if caller ne "Maypole::Model::Base";
    my ($self, $r) = @_;
    $_->SUPER::delete for @{ $r->objects || [] };
    $r->objects([ $self->retrieve_all ]);
    $r->{template} = "list";
    $self->list($r);
}

sub stringify_column {
    my $class = shift;
    return ($class->columns("Stringify"),
                (grep { /(name|title)/i } $class->columns),
                (grep { !/id$/i } $class->primary_columns),
               )[0];
}

sub adopt {
    my ($self, $child) = @_;
    $child->autoupdate(1);
    if (my $col = $child->stringify_column) {
        $child->columns( Stringify => $col );
    }
}

sub search :Exported {
    return shift->SUPER::search(@_) if caller ne "Maypole::Model::Base";
                                    # A real CDBI search.
    my ($self, $r) = @_;
    my %fields = map {$_ => 1 } $self->columns;
    my $oper = "like"; # For now
    my %params = %{$r->{params}};
    my %values = map { $_ => {$oper, $params{$_} } }
                 grep { $params{$_} and $fields{$_} } keys %params;

    $r->template("list");
    if (!%values) { return $self->list($r) }
    my $order = $self->order($r);
    $self = $self->do_pager($r);
    $r->objects([ $self->search_where(\%values), 
                  ($order ? { order => $order } : ())  
                ]);
    $r->{template_args}{search} = 1;
}

sub do_pager {
    my ($self, $r) = @_;
    if ( my $rows = $r->config->{rows_per_page}) {
        return $r->{template_args}{pager} = $self->pager($rows, $r->query->{page});
    } else { return $self } 
}

sub order {
    my ($self, $r) = @_;
    my $order;
    my %ok_columns = map {$_ => 1} $self->columns;
    if ($order = $r->query->{order} and $ok_columns{$order}) {
       $order .= ($r->query->{o2} eq "desc" && " DESC")
    }
    $order;
}

sub list :Exported {
    my ($self, $r) = @_;
    my $order = $self->order($r);
    $self = $self->do_pager($r);
    if ($order) { 
        $r->objects([ $self->retrieve_all_sorted_by( $order )]);
    } else {
        $r->objects([ $self->retrieve_all ]);
    }
}

sub setup_database {
    my ($self, $config, $namespace, $dsn, $u, $p, $opts) = @_;
    $config->{dsn} = $dsn;
    $config->{loader} = Class::DBI::Loader->new(
        namespace => $namespace,
        dsn => $dsn,
        user => $u,
        password => $p,
        options => $opts,
    );
    $config->{classes} = [ $config->{loader}->classes ];
    $config->{tables}  = [ $config->{loader}->tables ];
}

sub class_of {
    my ($self, $r, $table) = @_;
    return $r->config->{loader}->_table2class($table);
}

1;
