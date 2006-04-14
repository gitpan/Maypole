package Maypole::Model::CDBI;
use strict;

=head1 NAME

Maypole::Model::CDBI - Model class based on Class::DBI

=head1 DESCRIPTION

This is a master model class which uses L<Class::DBI> to do all the hard
work of fetching rows and representing them as objects. It is a good
model to copy if you're replacing it with other database abstraction
modules.

It implements a base set of methods required for a Maypole Data Model.

It inherits accessor and helper methods from L<Maypole::Model::Base>.

When specified as the application model, it will use Class::DBI::Loader
to generate the model classes from the provided database. If you do not
wish to use this functionality, use L<Maypole::Model::CDBI::Plain> which
will instead use Class::DBI classes provided.

=cut

use base qw(Maypole::Model::Base Class::DBI);
use Maypole::Model::CDBI::AsForm;
use CGI::Untaint;
use Class::DBI::Plugin::Type;
use Class::DBI::FromCGI;
use Class::DBI::Loader;
use Class::DBI::AbstractSearch;
use Class::DBI::Plugin::RetrieveAll;
use Class::DBI::Pager;

use Lingua::EN::Inflect::Number qw(to_PL);
use attributes ();

use Data::Dumper;

###############################################################################
# Helper methods

=head1 Action Methods

Action methods are methods that are accessed through web (or other public) interface.

=head2 do_edit

If there is an object in C<$r-E<gt>objects>, then it should be edited
with the parameters in C<$r-E<gt>params>; otherwise, a new object should
be created with those parameters, and put back into C<$r-E<gt>objects>.
The template should be changed to C<view>, or C<edit> if there were any
errors. A hash of errors will be passed to the template.

=cut

sub do_edit : Exported {
  my ($self, $r, $obj) = @_;

  my $config   = $r->config;
  my $table    = $r->table;

  # handle cancel button hits
  if ( $r->{params}->{cancel} ) {
    $r->template("list");
    $r->objects( [$self->retrieve_all] );
    return;
  }

  my $required_cols = $config->{$table}->{required_cols} || [];
  my $ignored_cols = $r->{config}{ $r->{table} }{ignore_cols} || [];

  ($obj, my $fatal, my $creating) = $self->_do_update_or_create($r, $obj, $required_cols, $ignored_cols);

  # handle errors, if none, proceed to view the newly created/updated object
  my %errors = $fatal ? (FATAL => $fatal) : $obj->cgi_update_errors;

  if (%errors) {
    # Set it up as it was:
    $r->template_args->{cgi_params} = $r->params;

    #
    # replace user unfriendly error messages with something nicer

    foreach (@{$config->{$table}->{required_cols}}) {
      next unless ($errors{$_});
      my $key = $_;
      s/_/ /g;
      $r->template_args->{errors}{ucfirst($_)} = 'This field is required, please provide a valid value';
      $r->template_args->{errors}{$key} = 'This field is required, please provide a valid value';
      delete $errors{$key};
    }

    foreach (keys %errors) {
      my $key = $_;
      s/_/ /g;
      $r->template_args->{errors}{ucfirst($_)} = 'Please provide a valid value for this field';
      $r->template_args->{errors}{$key} = 'Please provide a valid value for this field';
    }

    undef $obj if $creating;

    die "do_update failed with error : $fatal" if ($fatal);
    $r->template("edit");
  } else {
    $r->template("view");
  }



  $r->objects( $obj ? [$obj] : []);
}

# split out from do_edit to be reported by Mp::P::Trace
sub _do_update_or_create {
  my ($self, $r, $obj, $required_cols, $ignored_cols) = @_;

  my $fatal;
  my $creating = 0;

  my $h = CGI::Untaint->new( %{$r->params} );

  # update or create
  if ($obj) {
    # We have something to edit
    eval { $obj->update_from_cgi( $h => {
					 required => $required_cols,
					 ignore => $ignored_cols,
					} );
	   $obj->update(); # pos fix for bug 17132 'autoupdate required by do_edit'
	 };
    $fatal = $@;
  } else {
    eval {
      $obj = $self->create_from_cgi( $h => {
					    required => $required_cols,
					    ignore => $ignored_cols,
					   } )
    };

    if ($fatal = $@) {
      warn "FATAL ERROR: $fatal" if $r->debug;
#      $self->dbi_rollback;
    } else {
#      $self->dbi_commit;
    }
    $creating++;
  }

  return $obj, $fatal, $creating;
}


=head2 delete

Deprecated method that calls do_delete or a given classes delete method, please
use do_delete instead

=head2 do_delete

Unsuprisingly, this command causes a database record to be forever lost.

This method replaces the, now deprecated, delete method provided in prior versions

=cut

sub delete : Exported {
  my $self = shift;
  my ($sub) = (caller(1))[3];
  # So subclasses can still send delete down ...
  $sub =~ /^(.+)::([^:]+)$/;
  if ($1 ne "Maypole::Model::Base" && $2 ne "delete") {
    $self->SUPER::delete(@_);
  } else {
    warn "Maypole::Model::CDBI delete method is deprecated\n";
    $self->do_delete(@_);
  }
}

sub do_delete {
  my ( $self, $r ) = @_;
  # FIXME: handle fatal error with exception
  $_->SUPER::delete for @{ $r->objects || [] };
#  $self->dbi_commit;
  $r->objects( [ $self->retrieve_all ] );
  $r->{template} = "list";
  $self->list($r);
}

=head2 search

Deprecated searching method - use do_search instead.

=head2 do_search

This action method searches for database records, it replaces
the, now deprecated, search method previously provided.

=cut

sub search : Exported {
  my $self = shift;
  my ($sub) = (caller(1))[3];
  $sub =~ /^(.+)::([^:]+)$/;
  # So subclasses can still send search down ...
  return ($1 ne "Maypole::Model::Base" && $2 ne "search") ?
    $self->SUPER::search(@_) : $self->do_search(@_);
}

sub do_search : Exported {
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

=head2 list

The C<list> method fills C<$r-E<gt>objects> with all of the
objects in the class. The results are paged using a pager.

=cut

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

#######################
# _process_local_srch #
#######################

# Makes the local part of the db search query
# Puts search prams local to this table  in where array.
# Returns a  where array ref and search criteria string. 
# This is factored out of do_search so sub classes can override this part
sub _process_local_srch {
	my ($self, $hashed)  = @_;
	my %fields = map { $_ => 1 } $self->columns;
	my $moniker = $self->moniker;
	my %colnames    = $self->column_names;
	my $srch_crit = '';
	my ($oper, $wc);
	my @where = map { 
		# prelim 
		$srch_crit .= ' '.$colnames{$_}." = '".$hashed->{$_}."'";
		$oper = $self->sql_search_oper($_);
		$wc   = $oper =~ /LIKE/i ? '%':''; # match any substr
	 	"$moniker.$_ $oper '$wc" .  $hashed->{$_} . "$wc'"; #the where clause
		}
		grep { defined $hashed->{$_} && length ($hashed->{$_}) && $fields{$_} }
		keys %$hashed;

	return (\@where, $srch_crit);
}

#########################
# _process_foreign_srch #
#########################

# puts foreign search fields into select statement 
# changes  @where  by ref and return sel and srch_criteria string
sub _process_foreign_srch {
	my ($self, $hashed, $sel, $where, $srch_crit) = @_;
	my %colnames    = $self->column_names;
	my $moniker     = $self->moniker; 
	my %foreign;
	foreach (keys  %$hashed) { 
		$foreign{$_} =  delete $hashed->{$_} if ref $hashed->{$_};
	}
	my %accssr_class = %{$self->accessor_classes};
	while (my ( $accssr, $prms) =  each %foreign ) {
		my $fclass = $accssr_class{$accssr};
		my %fields = map { $_ => 1 } $fclass->columns;
		my %colnames = $fclass->column_names;
		my ($oper, $wc);
		my @this_where =
		   # TODO make field name match in all cases in srch crit
			map { 
				# prelim
				$srch_crit.= ' '.$colnames{$_}." = '".$prms->{$_}."'";
				$oper = $fclass->sql_search_oper($_);
				$wc   = $oper =~ /LIKE/i ? '%':'';
			     "$accssr.$_ $oper '$wc".$prms->{$_}."$wc'"; # the where 
				}
			grep { defined $prms->{$_} && length ($prms->{$_}) && $fields{$_} }
			keys %$prms;

		next unless @this_where;
		$sel .= ", " . $fclass->table . " $accssr"; # add foreign tables to from

		# map relationships -- TODO use constraints in has_many and mhaves
		# and make general
		my $pk = $self->primary_column;
		if ($fclass->find_column('owner_id') && $fclass->find_column('owner_table') ) {
			unshift @this_where, ("$accssr.owner_id = $moniker.$pk", 
		                        "$accssr.owner_table = '" . $self->table ."'");
		}
		# for has_own, has_a  where foreign id is in self's table 
		elsif ( my $fk = $self->find_column($fclass->primary_column) ) {
			unshift @this_where, "$accssr." . $fk->name . " = $moniker." . $fk->name;
		}
		push @$where, @this_where; 
	}
	return ($sel, $srch_crit);
}

###############################################################################
# Helper methods

=head1 Helper Methods


=head2 adopt

This class method is passed the name of a model class that represensts a table
and allows the master model class to do any set-up required.

=cut

sub adopt {
    my ( $self, $child ) = @_;
    $child->autoupdate(1);
    if ( my $col = $child->stringify_column ) {
        $child->columns( Stringify => $col );
    }
}

=head2 is_class

Tell if action is a class method (See Maypole::Plugin::Menu)

=cut

sub is_class {
	my ( $self, $method, $attrs ) = @_;
	die "Usage: method must be passed as first arg" unless $method;
	$attrs = join(' ',$self->method_attrs($method)) unless ($attrs);
	return 1 if $attrs  =~ /\bClass\b/i;
	return 1 if $method =~ /^list$/;  # default class actions
	return 0;
}

=head2 is_object

Tell if action is a object method (See Maypole::Plugin::Menu)

=cut

sub is_object {
	my ( $self, $method, $attrs ) = @_;
	die "Usage: method must be passed as first arg" unless $method;
	$attrs = join(' ',$self->method_attrs($method)) unless ($attrs);
	return 1 if $attrs  =~ /\bObject\b/i;
	return 1 if $method =~ /(^view$|^edit$|^delete$)/;  # default object actions
	return 0;
}


=head2 related

This method returns a list of has-many accessors. A brewery has many
beers, so C<BeerDB::Brewery> needs to return C<beers>.

=cut

sub related {
    my ( $self, $r ) = @_;
    return keys %{ $self->meta_info('has_many') || {} };
}


=head2 related_class

Given an accessor name as a method, this function returns the class this accessor returns.

=cut

sub related_class {
     my ( $self, $r, $accessor ) = @_;
     my $meta = $self->meta_info;
     my @rels = keys %$meta;
     my $related;
     foreach (@rels) {
         $related = $meta->{$_}{$accessor};
         last if $related;
     }
     return unless $related;

     my $mapping = $related->{args}->{mapping};
     if ( $mapping and @$mapping ) {
       return $related->{foreign_class}->meta_info('has_a')->{$$mapping[0]}->{foreign_class};
     }
     else {
         return $related->{foreign_class};
     }
 }

=head2 related_meta

  $class->related_meta($col);

Given a column  associated with a relationship it will return the relatation
ship type and the meta info for the relationship on the column.

=cut

sub related_meta {
    my ($self,$r, $accssr) = @_;
    $self->_croak("You forgot to put the place holder for 'r' or forgot the accssr parameter") unless $accssr;
    my $class_meta = $self->meta_info;
    if (my ($rel_type) = grep { defined $class_meta->{$_}->{$accssr} }
        keys %$class_meta)
    { return  $rel_type, $class_meta->{$rel_type}->{$accssr} };
}


=head2 isa_class

Returns class of a column inherited by is_a.

=cut

# Maybe put this in IsA?
sub isa_class {
  my ($class, $col) = @_;
  $class->_croak( "Need a column for isa_class." ) unless $col;
  my $isaclass;
  my $isa = $class->meta_info("is_a") || {}; 
  foreach ( keys %$isa ) {
    $isaclass = $isa->{$_}->foreign_class; 
    return $isaclass if ($isaclass->find_column($col));
  }
  return 0;			# col not in a is_a class 
}

=head2 accessor_classes

Returns hash ref of classes for accessors.

This is an attempt at a more efficient method than calling "related_class()"
a bunch of times when you need it for many relations.
It may be good to call at startup and store in a global config. 

=cut

sub accessor_classes {
	my ($self, $class) = @_; # can pass a class arg to get accssor classes for
	$class ||= $self;
	my $meta = $class->meta_info;
	my %res;
	foreach my $rel (keys %$meta) {
		my $rel_meta = $meta->{$rel};
		%res = ( %res, map { $_ => $rel_meta->{$_}->{foreign_class} } 
						   keys %$rel_meta );
	}
	return \%res;

	# 2 liner to get class of accessor for $name
	#my $meta = $class->meta_info;
	#my ($isa) = map $_->foreign_class, grep defined, 
	# map $meta->{$_}->{$name}, keys %$meta;

}


=head2 stringify_column

   Returns the name of the column to use when stringifying
   and object.

=cut

sub stringify_column {
    my $class = shift;
    return (
        $class->columns("Stringify"),
        ( grep { /^(name|title)$/i } $class->columns ),
        ( grep { /(name|title)/i } $class->columns ),
        ( grep { !/id$/i } $class->primary_columns ),
    )[0];
}

=head2 do_pager

   Sets the pager template argument ($r->{template_args}{pager})
   to a Class::DBI::Pager object based on the rows_per_page
   value set in the configuration of the application.

   This pager is used via the pager macro in TT Templates, and
   is also accessible via Mason.

=cut

sub do_pager {
    my ( $self, $r ) = @_;
    if ( my $rows = $r->config->rows_per_page ) {
        return $r->{template_args}{pager} =
          $self->pager( $rows, $r->query->{page} );
    }
    else { return $self }
}


=head2 order

    Returns the SQL order syntax based on the order parameter passed
    to the request, and the valid columns.. i.e. 'title ASC' or 'date_created DESC'.

    $sql .= $self->order($r);

    If the order column is not a column of this table,
    or an order argument is not passed, then the return value is undefined.

    Note: the returned value does not start with a space.

=cut

sub order {
    my ( $self, $r ) = @_;
    my %ok_columns = map { $_ => 1 } $self->columns;
    my $q = $r->query;
    my $order = $q->{order};
    return unless $order and $ok_columns{$order};
    $order .= ' DESC' if $q->{o2} and $q->{o2} eq 'desc';
    return $order;
}

=head2 setup

  This method is inherited from Maypole::Model::Base and calls setup_database,
  which uses Class::DBI::Loader to create and load Class::DBI classes from
  the given database schema.

=cut

=head2 setup_database

The $opts argument is a hashref of options.  The "options" key is a hashref of
Database connection options . Other keys may be various Loader arguments or
flags.  It has this form:
 {
   # DB connection options
   options { AutoCommit => 1 , ... },
   # Loader args
   relationships => 1,
   ...
 }

=cut

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

    my @table_class = map { $_ . " => " . $config->{loader}->_table2class($_) } @{ $config->{tables} };
    warn( 'Loaded tables to classes: ' . join ', ', @table_class )
      if $namespace->debug;
}

=head2 class_of

  returns class for given table

=cut

sub class_of {
    my ( $self, $r, $table ) = @_;
    return $r->config->loader->_table2class($table); # why not find_class ?
}

=head2 fetch_objects

Returns 1 or more objects of the given class when provided with the request

=cut

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


###############################################################################
# private / internal functions and classes

sub _column_info {
	my $class =  shift;
	$class = ref $class || $class;
	no strict 'refs';
	return ${$class . '::COLUMN_INFO'};
}

1;
