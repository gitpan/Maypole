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
#use Class::DBI::Plugin::Type;
use Class::DBI::Loader;
use Class::DBI::AbstractSearch;
use Class::DBI::Plugin::RetrieveAll;
use Class::DBI::Pager;
use Lingua::EN::Inflect::Number qw(to_PL);
use attributes ();

use Maypole::Model::CDBI::AsForm;
use Maypole::Model::CDBI::FromCGI; 
use CGI::Untaint::Maypole;

=head2 Untainter

Set the class you use to untaint and validate form data
Note it must be of type CGI::Untaint::Maypole (takes $r arg) or CGI::Untaint

=cut
sub Untainter { 'CGI::Untaint::Maypole' };

# or if you like bugs 

#use Class::DBI::FromCGI;
#use CGI::Untaint;
#sub Untainter { 'CGI::Untaint' };


__PACKAGE__->mk_classdata($_) for (qw/COLUMN_INFO/);

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

  # handle cancel button hit
  if ( $r->{params}->{cancel} ) {
    $r->template("list");
    $r->objects( [$self->retrieve_all] );
    return;
  }

  my $required_cols = $config->{$table}{required_cols} || [];
  my $ignored_cols  = $config->{$table}{ignore_cols} || [];

  ($obj, my $fatal, my $creating) = $self->_do_update_or_create($r, $obj, $required_cols, $ignored_cols);

  # handle errors, if none, proceed to view the newly created/updated object
  my %errors = $fatal ? (FATAL => $fatal) : $obj->cgi_update_errors;

  if (%errors) {
    # Set it up as it was:
    $r->template_args->{cgi_params} = $r->params;

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

  my $h = $self->Untainter->new( %{$r->params} );

  # update or create
  if ($obj) {
    # We have something to edit
    eval { $obj->update_from_cgi( $r => {
					 required => $required_cols,
					 ignore => $ignored_cols,
					}); 
	   $obj->update(); # pos fix for bug 17132 'autoupdate required by do_edit'
	 };
    $fatal = $@;
  } else {
    	eval {
      	$obj = $self->create_from_cgi( $r => {
					    required => $required_cols,
					    ignore => $ignored_cols,
					   } );
    	};
    	$fatal = $@;
    	$creating++;
  }
  return $obj, $fatal, $creating;
}


# split out from do_edit to be reported by Mp::P::Trace
#sub _do_update_or_create {
#  my ($self, $r, $obj, $required_cols, $ignored_cols) = @_;
#
#  my $fatal;
#  my $creating = 0;
#
#  my $h = $self->Untainter->new( %{$r->params} );
#
#  # update or create
#  if ($obj) {
#    # We have something to edit
#    eval { $obj->update_from_cgi( $h => {
#					 required => $required_cols,
#					 ignore => $ignored_cols,
#					} );
#	   $obj->update(); # pos fix for bug 17132 'autoupdate required by do_edit'
#	 };
#    $fatal = $@;
#  } else {
#    	eval {
#      	$obj = $self->create_from_cgi( $h => {
#					    required => $required_cols,
#					    ignore => $ignored_cols,
#					   } );
#    	};
#    	$fatal = $@;
#    	$creating++;
#  }
#
#  return $obj, $fatal, $creating;
#}

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

Returns the hash ref of relationship meta info for a given column.

=cut

sub related_meta {
    my ($self,$r, $accssr) = @_;
    $self->_croak("You forgot to put the place holder for 'r' or forgot the accssr parameter") unless $accssr;
    my $class_meta = $self->meta_info;
    if (my ($rel_type) = grep { defined $class_meta->{$_}->{$accssr} }
        keys %$class_meta)
    { return  $class_meta->{$rel_type}->{$accssr} };
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





=head2 _isa_class

Private method to return the class a column 
belongs to that was inherited by an is_a relationship.
This should probably be public but need to think of API

=cut

sub _isa_class {
    my ($class, $col) = @_;
    $class->_croak( "Need a column for _isa_class." ) unless $col;
    my $isaclass;
    my $isa = $class->meta_info("is_a") || {};
    foreach ( keys %$isa ) {
        $isaclass = $isa->{$_}->foreign_class;
        return $isaclass if ($isaclass->find_column($col));
    }
    return; # col not in a is_a class
}



# Thanks to dave baird --  form builder for these private functions
sub _column_info {
    my $self = shift;
	my $dbh = $self->db_Main;
	return $self->COLUMN_INFO if ref $self->COLUMN_INFO;

	my $meta;  # The info we are after
	my ($catalog, $schema) = (undef, undef); 
	# Dave is suspicious this (above undefs) could 
	# break things if driver useses this info

 	# '%' is a search pattern for columns - matches all columns
    if ( my $sth = $dbh->column_info( $catalog, $schema, $self->table, '%' ) )
    {
        $dbh->errstr && die "Error getting column info sth: " . $dbh->errstr;
        $self->COLUMN_INFO( $self->_hash_type_meta( $sth ) );    
#	use Data::Dumper; warn "col info for typed is " . Dumper($self->COLUMN_INFO);
    }
    else
    {
        $self->COLUMN_INFO( $self->_hash_typeless_meta( ) );    
#		use Data::Dumper; warn "col info TYPELESS is " . Dumper($self->COLUMN_INFO);
    }
	return $self->COLUMN_INFO;
}

sub _hash_type_meta
{
    my ($self, $sth) = @_;
	my $meta;
    while ( my $row = $sth->fetchrow_hashref )
	
    {
        my ($col_meta, $col_name);
        
        foreach my $key ( keys %$row)
        {
            my $value = $row->{$key} || $row->{ uc $key };
            $col_meta->{$key} = $value;
            $col_name = $row->{COLUMN_NAME} || $row->{column_name};
        }
        
        $meta->{$col_name} =  $col_meta;    
    }
	return $meta;
}

# typeless db e.g. sqlite
sub _hash_typeless_meta
{
    my ( $self ) = @_;

    $self->set_sql( fb_meta_dummy => 'SELECT * FROM __TABLE__ WHERE 1=0' )
        unless $self->can( 'sql_fb_meta_dummy' );

    my $sth = $self->sql_fb_meta_dummy;
    
    $sth->execute or die "Error executing column info: "  . $sth->errstr;;
    
    # see 'Statement Handle Attributes' in the DBI docs for a list of available attributes
    my $cols  = $sth->{NAME};
    my $types = $sth->{TYPE};
    # my $sizes = $sth->{PRECISION};    # empty
    # my $nulls = $sth->{NULLABLE};     # empty
    
    # we haven't actually fetched anything from the sth, so need to tell DBI we're not going to
    $sth->finish;
    
    my $order = 0;
    my $meta;
    foreach my $col ( @$cols )
    {
        my $col_meta;
        
        $col_meta->{NULLABLE}    = 1;
        
        # in my limited testing, the columns are returned in the same order as they were defined in the schema
        $col_meta->{ORDINAL_POSITION} = $order++;
        
        # type_name is taken literally from the schema, but is not actually used by sqlite, 
        # so it can be anything, e.g. varchar or varchar(xxx) or VARCHAR etc.
		my $type = shift( @$types );  
		$type =~ /(\w+)\((\w+)\)/;
        $col_meta->{type} = $type; 
		$col_meta->{TYPE_NAME} = $1;
		my $size = $2;
		$col_meta->{COLUMN_SIZE} = $size if $type =~ /(CHAR|INT)/i; 
  		$meta->{$col} = $col_meta;
    }
	return $meta;
}



=head2 column_type

    my $type = $class->column_type('column_name');

This returns the 'type' of this column (VARCHAR(20), BIGINT, etc.)
For now, it returns "BOOL" for tinyints. 

TODO :: TEST with enums and postgres

=cut
sub column_type {
    my $class = shift;
    my $col = shift or die "Need a column for column_type";
	my $info = $class->_column_info->{$col} || 
			   eval { $class->_isa_class($col)->_column_info($col) } ||
			   return '';
			   
    my $type = $info->{mysql_type_name} || $info->{type};
   	unless ($type) {
		$type =  $info->{TYPE_NAME};
		if ($info->{COLUMN_SIZE}) { $type .= "($info->{COLUMN_SIZE})"; }
    }
	# Bool if tinyint
	if ($type and $type =~ /^tinyint/i and $info->{COLUMN_SIZE} == 1) { 
			$type = 'BOOL'; 
	}
	return $type;
}

=head2 column_nullable

Returns true if a column can be NULL and false if not.

=cut

sub column_nullable {
    my $class = shift;
    my $col = shift or $class->_croak( "Need a column for column_nullable" );
	my $info = $class->_column_info->{$col} || 
			   eval { $class->_isa_class($col)->_column_info($col) } ||
			   return 1;
    return $info->{NULLABLE};
}

=head2 column_default

Returns default value for column or the empyty string. 
Columns with NULL, CURRENT_TIMESTAMP, or Zeros( 0000-00...) for dates and times
have '' returned.

=cut

sub column_default {
    my $class = shift;
    my $col = shift or $class->_croak( "Need a column for column_default");
	#return unless $class->find_column($col); # not a real column

	my $info = $class->_column_info->{$col} || 
			   eval { $class->_isa_class($col)->_column_info($col) } ||
			   return '';
	
    my $def = $info->{COLUMN_DEF};
    $def = '' unless defined $def; # is this good?
	return $def;
}





=head2 get_classmetadata

Gets class meta data *excluding cgi input* for the passed in class or the
calling class. *NOTE* excludes cgi inputs. This method is handy to call from 
templates when you need some metadata for a related class.

=cut

sub get_classmetadata {
    my ($self, $class) = @_; # class is class we want data for
    $class ||= $self;
    $class = ref $class || $class;

    my %res;
    $res{name}          = $class;
    $res{colnames}      = {$class->column_names};
    $res{columns}       = [$class->display_columns];
    $res{list_columns}  = [$class->list_columns];
    $res{moniker}       = $class->moniker;
    $res{plural}        = $class->plural_moniker;
    $res{table}         = $class->table;
    \%res;
}


1;
