package Maypole::Model::CDBI::AsForm;

#TODO -- 
# lots of doc
# _to_select_or_create  -- select input stays
# _to_create_or_select  -- create input trumps
# 

# TESTED and Works --
#  has_many select -- $obj->to_field($has_many_col);   # select one form many
#                  -- $class->to_field($has_many_col); # foreign inputs  
#  $class->search_inputs; /


use strict;
use warnings;

use base 'Exporter';
use Data::Dumper;
use Class::DBI::Plugin::Type ();
use HTML::Element;
use Carp qw/cluck/;

our $OLD_STYLE = 0;
# pjs  --  Added new methods to @EXPORT 
our @EXPORT = 
	qw( 
		to_cgi to_field  make_element_foreign search_inputs unselect_element
		_field_from_how _field_from_relationship _field_from_column
		_to_textarea _to_textfield _to_select  _select_guts
		_to_foreign_inputs _to_enum_select _to_bool_select
		_to_hidden _to_link_hidden _rename_foreign_input _to_readonly
		_options_from_objects _options_from_arrays _options_from_hashes 
		_options_from_array _options_from_hash _to_select_or_create
    );
				
our $VERSION = '.10'; 

=head1 NAME

Maypole::Model:CDBI::AsForm - Produce HTML form elements for database columns

=head1 SYNOPSIS

    package Music::CD;
    use Maypole::Model::CDBI::AsForm;
    use base 'Class::DBI';
    use CGI;
    ...

    sub create_or_edit {
        my $self = shift;
        my %cgi_field = $self->to_cgi;
        return start_form,
               (map { "<b>$_</b>: ". $cgi_field{$_}->as_HTML." <br>" } 
                    $class->Columns),
               end_form;
    }

# Example of has_many select
package Job;
__PACKAGE__->has_a('job_employer' => 'Employer');
__PACKAGE__->has_a('contact'  => 'Contact')

package Contact;
__PACKAGE__->has_a('cont_employer' => 'Employer');
__PACKAGE__->has_many('jobs'  => 'Job',
        { join => { job_employer => 'cont_employer' },
          constraint => { 'finshed' => 0  },
          order_by   => "created ASC",
        }
);

package Employer;
__PACKAGE__->has_many('jobs'  => 'Job',);
__PACKAGE__->has_many('contacts'  => 'Contact',
            order_by => 'name DESC',
);


  # Choose some jobs to add to a contact (has multiple attribute).
  my $job_sel = Contact->to_field('jobs'); # Uses constraint and order by
    

  # Choose a job from $contact->jobs 
  my $job_sel = $contact->to_field('jobs');
    


=head1 DESCRIPTION

This module helps to generate HTML forms for creating new database rows
or editing existing rows. It maps column names in a database table to
HTML form elements which fit the schema. Large text fields are turned
into textareas, and fields with a has-a relationship to other
C<Class::DBI> tables are turned into select drop-downs populated with
objects from the joined class.


=head1 ARGUMENTS HASH

This provides a convenient way to tweak AsForm's behavior in exceptional or 
not so exceptional instances. Below describes the arguments hash and 
example usages. 


  $beer->to_field($col, $how, $args); 
  $beer->to_field($col, $args);

Not all _to_* methods pay attention to all arguments. For example, '_to_textfield' does not look in $args->{'items'} at all.
 
=over

=item name -- the name the element will have , this trumps the derived name.

  $beer->to_field('brewery', 'readonly', {
 		name => 'brewery_id'
  });
  
=item value -- the initial value the element will have, trumps derived value

  $beer->to_field('brewery', 'textfield', { 
		name => 'brewery_id', value => $beer->brewery,
		# however, no need to set value since $beer is object
  });
 
=item items -- array of items generally used to make select box options

Can be array of objects, hashes, arrays, or strings, or just a hash.

   # Rate a beer
   $beer->to_field(rating =>  select => {
		items => [1 , 2, 3, 4, 5],
   });
 
   # Select a Brewery to visit in the UK
   Brewery->to_field(brewery_id => {
		items => [ Brewery->search_like(location => 'UK') ],
   });

  # Make a select for a boolean field
  $Pub->to_field('open' , { items => [ {'Open' => 1, 'Closed' => 0 } ] }); 

=item selected -- something representing which item is selected in a select box

   $beer->to_field('brewery', {
		selected => $beer->brewery, # again not necessary since caller is obj.
   });

Can be an simple scalar id, an object, or an array of either

=item class -- the class for which the input being made for field pertains to.

This in almost always derived in cases where it may be difficult to derive, --
   # Select beers to serve on handpump
   Pub->to_field(handpumps => select => {
   		class => 'Beer', order_by => 'name ASC', multiple => 1,
	});

=item column_type -- a string representing column type
   
  $pub->to_field('open', 'bool_select', {
		column_type => "bool('Closed', 'Open'),
  });

=item column_nullable -- flag saying if column is nullable or not

Generally this can be set to get or not get a null/empty option added to
a select box.  AsForm attempts to call "$class->column_nullable" to set this
and it defaults to true if there is no shuch method.
  
  $beer->to_field('brewery', { column_nullable => 1 });    

=item r or request  -- the mapyole request object 

=item uri -- uri for a link , used in methods such as _to_link_hidden

 $beer->to_field('brewery', 'link_hidden', 
      {r => $r, uri => 'www.maypole.perl.org/brewery/view/'.$beer->brewery}); 
 # an html link that is also a hidden input to the object. R is required to
 # make the uri  unless you  pass a  uri

=item order_by, constraint, join

These are used in making select boxes. order_by is a simple order by clause
and constraint and join are hashes used to limit the rows selected. The
difference is that join uses methods of the object and constraint uses 
static values. You can also specify these in the relationship arguments.

  BeerDB::LondonBeer->has_a('brewery', 'BeerDB::Brewery', 
           order_by     => 'brewery_name ASC',
	   constraint   => {location  => 'London'},
	   'join'       => {'brewery_tablecolumn  => 'beer_obj_column'}, 
	  );
	   
=item no_hidden_constraints -- 

Tell AsForm not to make hidden inputs for relationship constraints. It does
this  sometimes when making foreign inputs . 

=back

=head2 to_cgi

  $self->to_cgi([@columns, $args]); 

This returns a hash mapping all the column names to HTML::Element objects 
representing form widgets.  It takes two opitonal arguments -- a list of 
columns and a hashref of hashes of arguments for each column.  If called with an object like for editing, the inputs will have the object's values.

  $self->to_cgi(); # uses $self->columns;  # most used
  $self->to_cgi(qw/brewery style rating/); # sometimes
  # and on rare occassions this is desireable if you have a lot of fields
  # and dont want to call to_field a bunch of times just to tweak one or 
  # two of them.
  $self->to_cgi(@cols, {brewery => {  
                                     how => 'textfield' # too big for select 
								   }, 
                        style   => { 
						             column_nullable => 0, 
						             how => 'select', 
								     items => ['Ale', 'Lager']
								   }
						}

=cut

sub to_cgi {
	my ($class, @columns) = @_; # pjs -- added columns arg
	my $args = {};
	if (not @columns) {
		@columns = $class->columns; 
	}
	else {
		if ( ref $columns[-1] eq 'HASH' ) { $args = pop @columns; }
	}
	map { $_ => $class->to_field($_, $args->{$_}) } @columns;
}

=head2 to_field($field [, $how][, $args])

This maps an individual column to a form element. The C<how> argument
can be used to force the field type into any you want. It tells AsForm how
to make the input ie-- forces it to use the method "_to_$how".
If C<how> is specified but the class cannot call the method it maps to,
then AsForm will issue a warning and the default input will be made. 
You can write your own "_to_$how" methods and AsForm comes with many.
See C<HOW Methods>. You can also pass this argument in $args->{how}.


=cut

sub to_field {
	my ($self, $field, $how, $args) = @_;
    if (ref $how)   { $args = $how; $how = ''; }
	unless ($how)   { $how = $args->{how} || ''; }
#warn "In to_field field is $field how is $how. args ar e" . Dumper($args) . " \n";

    #if (ref $field) { $args = $field; $field = '' }

	#use Data::Dumper;
	#warn "args to_field  are $field, . " . Dumper($how) . " ,  " . Dumper($args);
	

	return	$self->_field_from_how($field, $how, $args)   || 
	       	$self->_field_from_relationship($field, $args) ||
		   	$self->_field_from_column($field, $args)  ||
	  		$self->_to_textfield($field, $args);
}

=head2 search_inputs

  my $cgi = $class->search_inputs ([$args]); # optional $args

Returns hash or hashref of search inputs elements for a class making sure the
inputs are empty of any initial values.
You can specify what columns you want inputs for in
$args->{columns} or
by the method "search_columns". The default is  "display_columns".
If you want to te search on columns in related classes you can do that by
specifying a one element hashref in place of the column name where
the key is the related "column" (has_a or has_many method for example) and
the value is a list ref of columns to search on in the related class.

Example:
  sub  BeerDB::Beer::search_columns {
     return ( 'name' , 'rating', { brewery => [ 'name', 'location'] } );
  }

  # Now foreign inputs are made for Brewery name and location and the
  # there will be no name clashing and processing can be automated.

=cut


sub search_inputs {
    my ($class, $args) = @_;
    $class = ref $class || $class;
    #my $accssr_class = { $class->accessor_classes };
    my %cgi;

    $args->{columns} ||= $class->can('search_columns') ?[$class->search_columns] : [$class->display_columns];

    foreach my $field ( @{ $args->{columns} } ) {
		my $base_args = {
			no_hidden_constraints => 1,
			column_nullable => 1, # empty option on select boxes
			value  => '',
		};
        if ( ref $field eq "HASH" ) { # foreign search fields
            my ($accssr, $cols)  = each %$field;
			$base_args->{columns} = $cols;
            unless (  @$cols ) {
                # default to search fields for related
                #$cols =  $accssr_class->{$accssr}->search_columns;
                die ("$class search_fields error: Must specify at least one column to search in the foreign object named '$accssr'");
            }
            my $fcgi  = $class->to_field($accssr, 'foreign_inputs', $base_args);

            # unset the default values for a select box
            foreach (keys %$fcgi) {
	      		my $el = $fcgi->{$_};
				if ($el->tag eq 'select') {
					
					$class->unselect_element($el);
					my ($first, @content) = $el->content_list;
					my @fc = $first->content_list;
					my $val = $first ? $first->attr('value') : undef;  
					if ($first and (@fc > 0 or (defined $val and $val ne '')) ) { # something ( $first->attr('value') ne '' or 
					              
					   #(defined $first->attr('value') or $first->attr('value') ne ''))  
					   # push an empty option on stactk
					   $el->unshift_content(HTML::Element->new('option'));
				    }
				}
					
            }
            $cgi{$accssr} = $fcgi;
			delete $base_args->{columns};
		}
        else {
            $cgi{$field} = $class->to_field($field, $base_args); #{no_select => $args->{no_select}{$field} });
	      	my $el = $cgi{$field};
			if ($el->tag eq 'select') {
				$class->unselect_element($el);
				my ($first, @content) = $el->content_list;
				if ($first and $first->content_list) { # something 
					   #(defined $first->attr('value') or $first->attr('value') ne ''))  
					   # push an empty option on stactk
					   $el->unshift_content(HTML::Element->new('option'));
		  		}
			}
        }
    }
    return \%cgi;
}




=head2 unselect_element

  unselect any selected elements in a HTML::Element select list widget

=cut
sub unselect_element {
   my ($self, $el) = @_;
   #unless (ref $el eq 'HTML::Element') {
   #$self->_croak ('Need an HTML::Element to unselect. You gave a ' . Dumper($el)); }
   if ($el->tag eq 'select') {
       foreach my $opt ($el->content_list) {
           $opt->attr('selected', undef) if $opt->attr('selected');
       }
   }
}

=head2 _field_from_how($field, $how,$args)

Returns an input element based the "how" parameter or nothing at all.
Override at will. 

=cut

sub _field_from_how {
	my ($self, $field, $how, $args) = @_;
	#if (ref $how) { $args = $how; $how = undef; }
#warn "In filed from how . filed is $field how is $how. args ar e" . Dumper($args) . " \n";
	return unless $how;
	$args ||= {};
	no strict 'refs';
	my $meth = "_to_$how";
	if (not $self->can($meth)) { 
		warn "Class can not $meth";
		return;
	}
	return $self->$meth($field, $args); 
	return;
}

=head2 _field_from_relationship($field, $args)

Returns an input based on the relationship associated with the field or nothing.
Override at will.

For has_a it will give select box

=cut

sub _field_from_relationship {
	my ($self, $field, $args) = @_;
#warn "In filed from rel . filed is $field \n";
	return unless $field;
	my $rel_meta = $self->related_meta('r',$field) || return; 
	my $rel_name = $rel_meta->{name};
	#my $meta = $self->meta_info;
	#grep{ defined $meta->{$_}{$field} } keys %$meta;
	my $fclass = $rel_meta->foreign_class;
	my $fclass_is_cdbi = $fclass ? $fclass->isa('Class::DBI') : 0;

	# maybe has_a select 
	#warn "Dumper of relmeta. " . Dumper($rel_meta);
	if ($rel_meta->{name} eq 'has_a' and $fclass_is_cdbi) {
	    # This condictions allows for trumping of the has_a args
		if  (not $rel_meta->{args}{no_select} and not $args->{no_select}) 
		{
    		$args->{class} = $fclass;
    		return  $self->_to_select($field, $args);
		}
		return;
	}
	# maybe has many select
	if ($rel_meta->{name} eq 'has_many' and $fclass_is_cdbi and ref $self) {
	    # This condictions allows for trumping of the has_a args
		if  (not $rel_meta->{args}{no_select} and not $args->{no_select}) 
		{
    		$args->{class} = $fclass;
			$args->{items} = $self->$field;
    		return  $self->_to_select($field, $args);
		}
		return;
	}

		
	
	#NOOO!  maybe select from has_many 
#	if ($rel_type eq 'has_many' and ref $self) {
#		$args->{items} ||= [$self->$field];
#		# arg name || fclass pk name || field
#		if (not $args->{name}) {
#			$args->{name} =  eval{$fclass->primary_column->name} || $field; 
#		}
#    	return  $self->_to_select($field, $args);
#	}
#
	# maybe foreign inputs 
	my %local_cols = map { $_ => 1 } $self->columns; # includes is_a cols
	if ($fclass_is_cdbi and (not $local_cols{$field} or $rel_name eq 'has_own'))
	{
		$args->{related_meta} = $rel_meta; # suspect faster to set these args 
		return $self->_to_foreign_inputs($field, $args);
	}
	return;
}
			
=head2 _field_from_column($field, $args)

Returns an input based on the column's characteristics, namely type, or nothing.
Override at will.

=cut

sub _field_from_column {
	my ($self, $field, $args) = @_;
	return unless $field;
	my $class = ref $self || $self;
	#warn "Class is $class\n";
	# Get column type	
    unless ($args->{column_type}) { 
			$args->{column_type} = $class->column_type($field);
    	if ($class->can('column_type')) {
			$args->{column_type} = $class->column_type($field);
		}	
		else {
    		# Right, have some of this
    		eval "package $class; Class::DBI::Plugin::Type->import()";
    		$args->{column_type} = $class->column_type($field);
		}
    }
    my $type = $args->{column_type};

	return $self->_to_textfield($field, $args)
		if $type  and $type =~ /(VAR)?CHAR/i;  #common type
	return $self->_to_textarea($field, $args)
		if $type and $type =~ /^(TEXT|BLOB)$/i;
	return $self->_to_enum_select($field, $args)  
		if $type and  $type =~ /^ENUM\((.*?)\)$/i; 
	return $self->_to_bool_select($field, $args)
		if $type and  $type =~ /^BOOL/i; 
	return $self->_to_readonly($field, $args)
	    if $type and $type =~ /^readonly$/i;
	return;
}


sub _to_textarea {
	my ($self, $col, $args) = @_;
 	# pjs added default	
    $args ||= {};
    my $val =  $args->{value}; 
    
    unless (defined $val) {
        if (ref $self) {
			$val = $self->$col; 
		}
		else { 
			$val = eval {$self->column_default($col);}; 
	    	$val = '' unless defined $val;  
		}
	}
    my ($rows, $cols) = _box($val);
    $rows = $args->{rows} if $args->{rows};
    $cols = $args->{cols} if $args->{cols};;
    my $name = $args->{name} || $col; 
	my $a =
		HTML::Element->new("textarea", name => $name, rows => $rows, cols => $cols);
	$a->push_content($val);
	$OLD_STYLE && return $a->as_HTML;
	$a;
}

sub _to_textfield {
    my ($self, $col, $args ) = @_;
    $args ||= {};
    my $val  = $args->{value}; 
    my $name = $args->{name} || $col; 

    unless (defined $val) {
        if (ref $self) {
            # Case where column inflates.
            # Input would get stringification which could be not good.
            #  as in the case of Time::Piece objects
            $val = $self->can($col) ? $self->$col : ''; # in case it is a virtual column
            if (ref $val) {
				if (my $meta = $self->related_meta('',$col)) {
				#warn "Meta for $col";
               		if (my $code = $meta->{args}{deflate4edit} || $meta->{args}{deflate} ) {
                    	$val  = ref $code ? &$code($val) : $val->$code;
					}
					elsif ( $val->isa('Class::DBI') ) {
					    $val  = $val->id;
					}
					else { 
						#warn "No deflate4edit code defined for $val of type " . 
					     #ref $val . ". Using the stringified value in textfield..";
					}
               	}
				else {
					#warn "No meta for $col but ref $val.\n";
					$val  = $val->id if $val->isa("Class::DBI"); 
               }
        	}
			
        }
       	else {
         	$val = eval {$self->column_default($col);};
           	$val = '' unless defined $val;
        }
    }
    my $a = HTML::Element->new("input", type => "text", name => $name, value =>
								$val);

    $OLD_STYLE && return $a->as_HTML;
    $a;
}


# Too expensive version -- TODO
#sub _to_select {
#	my ($self, $col, $hint) = @_;
#	my $fclass = $hint || $self->__hasa_rels->{$col}->[0];
#	my @objs        = $fclass->retrieve_all;
#	my $a           = HTML::Element->new("select", name => $col);
#	for (@objs) {
#		my $sel = HTML::Element->new("option", value => $_->id);
#		$sel->attr("selected" => "selected")
#			if ref $self
#			and eval { $_->id eq $self->$col->id };
#		$sel->push_content($_->stringify_self);
#		$a->push_content($sel);
#	}
#	$OLD_STYLE && return $a->as_HTML;
#	$a;
#}



# pjs 
# -- Rewrote this to be efficient -- no object creation. 
# -- Added option for CDBI classes to specify a limiting clause
# via "has_a_select_limit". 
# -- Added selected argument to set a selected 

=head2 recognized arguments
 
  selected => $object|$id,
  name     => $name,
  value    => $value,
  where    => SQL 'WHERE' clause,
  order_by => SQL 'ORDER BY' clause,
  limit    => SQL 'LIMIT' clause,
  items    => [ @items_of_same_type_to_select_from ],
  class => $class_we_are_selecting_from
  stringify => $stringify_coderef|$method_name
  
  


# select box requirements
# 1. a select box for objecs of a has_a related class -- DONE 
=head2  1. a select box out of a has_a or has_many related class.
  # For has_a the default behavior is to make a select box of every element in 
  # related class and you choose one. 
  #Or explicitly you can create one and pass options like where and order
  BeerDB::Beer->to_field('brewery','select', {where => "location = 'Germany'");
  
  # For has_many the default is to get a multiple select box with all objects.
  # If called as an object method, the objects existing ones will be selected. 
  Brewery::BeerDB->to_field('beers','select', {where => "rating > 5"}); 
  

=head2  2. a select box for objects of arbitrary class -- say BeerDB::Beer for fun. 
  # general 
  BeerDB::Beer->to_field('', 'select', $options)

  BeerDB::Beer->to_field('', 'select'); # Select box of all the rows in class
                                  # with PK as ID, $Class->to_field() same.
  BeerDB::Beer->to_field('','select',{ where => "rating > 3 AND class like 'Ale'", order_by => 'rating DESC, beer_id ASC' , limit => 10});
  # specify exact where clause 

=head2 3. If you already have a list of objects to select from  -- 

  BeerDB:;Beer->to_field($col, 'select' , {items => $objects});

# 3. a select box for arbitrary set of objects 
 # Pass array ref of objects as first arg rather than field 
 $any_class_or_obj->to_field([BeerDB::Beer->search(favorite => 1)], 'select',);
 

=cut

sub _to_select {
    my ($self, $col, $args) = @_;
    $args ||= {};
# Do we have items already ? Go no further. 
    if ($args->{items} and ref $args->{items}) {  
       	my $a = $self->_select_guts($col,  $args);
    	$OLD_STYLE && return $a->as_HTML;
		if ($args->{multiple}) { $a->attr('multiple', 'multiple');}
		return $a;
	}

# Else what are we making a select box out of ?  
	# No Column parameter --  means making a select box of args->class or self 
    # Using all rows from class's table
    if (not $col) { 
		unless ($args->{class}) {
        	$args->{class} = ref $self || $self;
			# object selected if called with one
            $args->{selected} = { $self->id => 1} 
				if not $args->{selected} and ref $self;
		}
        $col = $args->{class}->primary_column;
    }
    # Related Class maybe ? 
    elsif (my $rel_meta =  $self->related_meta('r:)', $col) ) {
        $args->{class} = $rel_meta->{foreign_class};
        # related objects pre selected if object
				
		# "Has many" -- Issues:
		# 1) want to select one from list if self is an object
		# Thats about all we can do really, 
		# 2) except for mapping which is TODO and  would 
		# do something like add to and take away from list of permissions for
		# example.

		# Hasmany select one from list if ref self
		if ($rel_meta->{name} =~ /has_many/i and ref $self) {
			$args->{items} = [ $self->$col ];
			my $a = $self->_select_guts($col,  $args);
		    $OLD_STYLE && return $a->as_HTML;
		    return $a;
		}
		else {
			$args->{selected} ||= [ $self->$col ] if  ref $self; 
			#warn "selected is " . Dumper($args->{selected});
			my $c = $rel_meta->{args}{constraint} || {};
			my $j = $rel_meta->{args}{join} || {};
			my @join ; 
			if (ref $self) {
				@join   =  map { $_ ." = ". $self->_attr($_) } keys %$j; 
			}
			my @constr= map { "$_ = '$c->{$_}'"} keys %$c; 
			$args->{where}    ||= join (' AND ', (@join, @constr));
			$args->{order_by} ||= $rel_meta->{args}{order_by};
			$args->{limit}    ||= $rel_meta->{args}{limit};
		}
			
    }
    # We could say :Col is name and we are selecting  out of class arg.
	# DIE for now
	else {
		#$args->{name} = $col;
		die "Usage _to_select. $col not related to any class to select from. ";
		
    }
		
    # Set arguments 
	unless ( defined  $args->{column_nullable} ) {
	    $args->{column_nullable} = $self->can('column_nullable') ?
			 $self->column_nullable($col) : 1;
	}

	# Get items to select from
    $args->{items} = _select_items($args);
    #warn "Items selecting from are " . Dumper($args->{items});
#use Data::Dumper;
#warn "Just got items. They are  " . Dumper($args->{items});

	# Make select HTML element
	$a = $self->_select_guts($col, $args);

	if ($args->{multiple}) {$a->attr('multiple', 'multiple');}

	# Return 
    $OLD_STYLE && return $a->as_HTML;
    $a;

}


##############
# Function # 
# #############
# returns the intersection of list refs a and b
sub _list_intersect {
	my ($a, $b) = @_;
	my %isect; my %union;
    foreach my $e (@$a, @$b) { $union{$e}++ && $isect{$e}++ }
	return  %isect;
}
############
# FUNCTION #
############
# Get Items 
sub _select_items { 
	my $args = shift;
	my $fclass = $args->{class};
    my @disp_cols = @{$args->{columns} || []};
    @disp_cols = $fclass->columns('SelectBox') unless @disp_cols;
    @disp_cols = $fclass->columns('Stringify')unless @disp_cols;
    @disp_cols = $fclass->_essential unless @disp_cols;
	unshift @disp_cols,  $fclass->columns('Primary');
	#my %isect = _list_intersect(\@pks, \@disp_cols);
	#foreach (@pks) { push @sel_cols, $_ unless $isect{$_}; } 
    #push @sel_cols, @disp_cols;		

	#warn "in select items. args are : " . Dumper($args);
	my $distinct = '';
	if ($args->{'distinct'}) {
    	$distinct = 'DISTINCT ';
	}

    my $sql = "SELECT $distinct" . join( ', ', @disp_cols) . 
	          " FROM " . $fclass->table;

	$sql .=	" WHERE " . $args->{where}   if $args->{where};
	$sql .= " ORDER BY " . $args->{order_by} if $args->{order_by};
	$sql .= " LIMIT " . $args->{limit} if $args->{limit};
#warn "_select_items sql is : $sql";

	return $fclass->db_Main->selectall_arrayref($sql);

}


# Makes a readonly input box out of column's value
# No args makes object to readonly
sub _to_readonly {
    my ($self, $col, $val) = @_;
    if (! $col) { # object to readonly
        $val = $self->id;
        $col = $self->primary_column;
    }
    unless (defined $val) {
        $self->_croak("Cannot get value in _to_readonly .")
            unless ref $self;
        $val = $self->$col;
    }
    my $a = HTML::Element->new('input', 'type' => 'text', readonly => '1',
        'name' => $col, 'value'=>$val);
$OLD_STYLE && return $a->as_HTML;
    $a;
}


=head2 _to_enum_select

$sel_box = $self->_to_enum_select($column, "ENUM('Val1','Val2','Val3')");

Returns an enum select box given a column name and an enum string.
NOTE: The Plugin::Type does not return an enum string for mysql enum columns.
This will not work unless you write your own column_type method in your model.

=cut

sub _to_enum_select {
    my ($self, $col, $args) = @_;
	my $type = $args->{column_type};
    $type =~ /ENUM\((.*?)\)/i;
    (my $enum = $1) =~ s/'//g;
    my @enum_vals = split /\s*,\s*/, $enum;

    # determine which is pre selected --
    # if obj, the value is , otherwise use column_default which is the first
    # value in the enum list unless it has been overridden
    my $selected = eval { $self->$col  };
    $selected = eval{$self->column_default($col)} unless defined $selected;
    $selected = $enum_vals[0]               unless defined $selected;

    my $a = HTML::Element->new("select", name => $col);
    for ( @enum_vals ) {
        my $sel = HTML::Element->new("option", value => $_);
        $sel->attr("selected" => "selected") if $_ eq $selected ;
        $sel->push_content($_);
        $a->push_content($sel);
    }
    $OLD_STYLE && return $a->as_HTML;
    $a;
}


=head2 _to_bool_select

  my $sel = $self->_to_bool_select($column, $bool_string);

This  makes select input for boolean column.  You can provide a
bool string of form: Bool('zero','one') and those are used for option
content. Onthervise No and Yes are used.
TODO -- test without bool string.

=cut

# TCODO fix this mess with args
sub _to_bool_select {
    my ($self, $col, $args) = @_;
	#warn "In to_bool select\n";
	my $type = $args->{column_type};
	my @bool_text = ('No', 'Yes');	
	if ($type =~ /BOOL\((.+?)\)/i) {
		(my $bool = $1) =~ s/'//g;
		@bool_text = split /,/, $bool;
	}

	# get selectedod 
	
	my $selected = $args->{value} if defined $args->{value};
	$selected = $args->{selected} unless defined $selected;
	$selected =  ref $self ? eval {$self->$col;} : $self->column_default($col)
		unless (defined $selected);

    my $a = HTML::Element->new("select", name => $col);
    if ($args->{column_nullable} || $args->{value} eq '') {
		my $null =  HTML::Element->new("option");
		$null->attr('selected', 'selected') if  $args->{value} eq '';
	    $a->push_content( $null ); 
	}
	   
    my ($opt0, $opt1) = ( HTML::Element->new("option", value => 0),
						  HTML::Element->new("option", value => 1) ); 
    $opt0->push_content($bool_text[0]); 
    $opt1->push_content($bool_text[1]); 
	unless ($selected eq '') { 
    	$opt0->attr("selected" => "selected") if not $selected; 
    	$opt1->attr("selected" => "selected") if $selected; 
	}
    $a->push_content($opt0, $opt1);
    $OLD_STYLE && return $a->as_HTML;
    $a;
}


=head2 _to_hidden($col, $args)

This makes a hidden html element. Give it a name and value or if name is
a ref it will use the PK name and value of the object.

=cut

sub _to_hidden {
    my ($self, $name, $val) = @_;
    my $args = {};
    my $obj;
    if (ref $name and $name->isa("Class::DBI")) {
       $obj = $name;
       $name= ($obj->primary_columns)[0]->name;
    }
    if (ref $val) {
		$args = $val;
        $val = $args->{value};
        $name = $args->{name} if $args->{name};
    }
    elsif (not $name ) { # hidding object caller
        $self->_croak("No object available in _to_hidden") unless ref $self;
        $name = ($self->primary_column)[0]->name;
        $val  = $self->id;
    }
    return HTML::Element->new('input', 'type' => 'hidden',
                              'name' => $name, 'value'=>$val
    );
}

=head2 _to_link_hidden($col, $args) 

Makes a link with a hidden input with the id of $obj as the value and name.
Name defaults to the objects primary key. The object defaults to self.

=cut

sub _to_link_hidden {
    my ($self, $accessor, $args) = @_;
    my $r =  eval {$self->controller} || $args->{r} || '';
    my $uri = $args->{uri} || '';
   use Data::Dumper;
    $self->_croak("_to_link_hidden cant get uri. No  Maypole Request class (\$r) or uri arg. Need one or other.")
        unless $r;
    my ($obj, $name);
    if (ref $self) { # hidding linking self
         $obj  = $self;
         $name = $args->{name} || $obj->primary_column->name;
    }
    elsif ($obj = $args->{items}->[0]) {
        $name = $args->{name} || $accessor || $obj->primary_column->name; 
		# TODO use meta data above maybe
    }
    else {           # hiding linking related object with id in args
        $obj  = $self->related_class($r, $accessor)->retrieve($args->{id});
        $name = $args->{name} || $accessor ; #$obj->primary_column->name;
		# TODO use meta data above maybe
    }
    $self->_croak("_to_link_hidden has no object") unless ref $obj;
    my $href =  $uri || $r->config->{uri_base} . "/". $obj->table."/view/".$obj->id;
    my $a = HTML::Element->new('a', 'href' => $href);
    $a->push_content("$obj");
    $a->push_content($self->_to_hidden($name, $obj->id));
	$OLD_STYLE && return $a->as_HTML;
    $a;
}

=head2 _to_foreign_inputs

$html_els = $class_or_obj->_to_foreign_inputs($accssr, [$fields, $accssr_meta]);

Get inputs for the accessor's class.  Pass an array ref of fields to get
inputs for only those fields. Otherwise display_columns or all columns is used. 
If you have the meta info handy for the accessor you can pass that too.

TODO make AsForm know more about the request like what action we are doing
so it can use edit columns or search_columns

NOTE , this names the foreign inputs is a particular way so they can be
processed with a general routine and so there are not name clashes.

args -
related_meta -- if you have this, great, othervise it will determine or die
columns  -- list of columns to make inputs for 

=cut

sub _to_foreign_inputs {
	my ($self, $accssr, $args) = @_;
	my $rel_meta = $args->{related_meta} || $self->related_meta('r',$accssr); 
	my $fields 		= $args->{columns};
	if (!$rel_meta) {
		$self->_croak( "No relationship for accessor $accssr");
	}

	my $rel_type = $rel_meta->{name};
	my $classORobj = ref $self && ref $self->$accssr ? $self->$accssr : $rel_meta->{foreign_class};
	
	unless ($fields) { 	
		$fields = $classORobj->can('display_columns') ? 
			[$classORobj->display_columns] : [$classORobj->columns];
	}
	
	# Ignore our fkey in them to  prevent infinite recursion 
	my $me 	        = eval {$rel_meta->{args}{foreign_column}} || '';  
	my $constrained = $rel_meta->{args}{constraint}; 
	my %inputs;
	foreach ( @$fields ) {
		next if $constrained->{$_} || ($_ eq $me); # don't display constrained
		$inputs{$_} =  $classORobj->to_field($_);
	}

	# Make hidden inputs for constrained columns unless we are editing object
	# TODO -- is this right thing to do?
	unless (ref $classORobj || $args->{no_hidden_constraints}) {
		$inputs{$_} = $classORobj->_to_hidden($_, $constrained->{$_}) 
			foreach ( keys %$constrained );  
	}
	$self->_rename_foreign_input($accssr, \%inputs);
	return \%inputs;
}


=head2 _hash_selected

Method to make sense out of the "selected" argument which can be in a number
of formats perhaps.  It returns a hashref with the the values of options to be
as the keys. 

Below handles these formats for the "selected" slot in the arguments hash:
  Object (with id method)
  Scalar (assumes it is value)
  Array ref *OF* objects, arrays of data (0 elmnt used), hashes of data
    (id key used), and simple scalars.
    

=cut 
 
############
# FUNCTION #
############
sub _hash_selected {
	my ($args) = shift;
	my $selected = $args->{value} || $args->{selected};
    return $selected unless $selected and ref $selected ne 'HASH'; 
	#warn "Selected dump : " . Dumper($selected);
	my $type = ref $selected;
	# Single Object 
    if ($type and $type ne 'ARRAY') {
       return  {$selected->id => 1};
    }
    # Single Scalar id 
	elsif (not $type) {
		return { $selected => 1}; 
	}
	

	# Array of objs, arrays, hashes, or just scalalrs. 
	elsif ($type eq 'ARRAY') {
		my %hashed;
		my $ltype = ref $selected->[0];
		# Objects
		if ($ltype and $ltype ne 'ARRAY')  {
			%hashed = map { $_->id  => 1 } @$selected;
       	}
		# Arrays of data with id first 
	    elsif ($ltype and $ltype eq 'ARRAY') {
			%hashed = map { $_->[0]  => 1 } @$selected; 
		}
		# Hashes using pk or id key
		elsif ($ltype and $ltype eq 'HASH') {
			my $pk = $args->{class}->primary_column || 'id';
			%hashed = map { $_->{$pk}  => 1 } @$selected; 
		}
		# Just Scalars
        else { 
			%hashed = map { $_  => 1 } @$selected; 
		}
		return \%hashed;
	}
	else { warn "AsForm Could not hash the selected argument: $selected"; }
} 
		



=head2 _select_guts 

Internal api  method to make the actual select box form elements.

3 types of lists making for -- 
  Hash, Array, 
  Array of CDBI objects.
  Array of scalars , 
  Array or  Array refs with cols from class,
  Array of hashes 

=cut



sub _select_guts {
    my ($self, $col, $args) = @_; #$nullable, $selected_id, $values) = @_;

    #$args->{stringify} ||=  'stringify_selectbox';
    $args->{selected} = _hash_selected($args) if defined $args->{selected};
	my $name = $args->{name} || $col;
    my $a = HTML::Element->new('select', name => $name);
	$a->attr( %{$args->{attr}} ) if $args->{attr};
    
    if ($args->{column_nullable}) {
		my $null_element = HTML::Element->new('option', value => '');
        $null_element->attr(selected => 'selected')
	    	if ($args->{selected}{'null'});
        $a->push_content($null_element);
    }

 	my $items = $args->{items};
    my $type = ref $items;
	my $proto = eval { ref $items->[0]; } || "";
	my $optgroups = $args->{optgroups} || '';
	
	# Array of hashes, one for each optgroup
	if ($optgroups) {
		my $i = 0;
		foreach (@$optgroups) {
			my $ogrp=  HTML::Element->new('optgroup', label => $_);
			$ogrp->push_content($self->_options_from_hash($items->[$i], $args));
			$a->push_content($ogrp);
			$i++;
		}
	}		
    # Single Hash
    elsif ($type eq 'HASH') {
        $a->push_content($self->_options_from_hash($items, $args));
    }
    # Single Array
    elsif ( $type eq 'ARRAY' and not ref $items->[0] ) {
        $a->push_content($self->_options_from_array($items, $args));
    }
    # Array of Objects
    elsif( $type eq 'ARRAY' and $proto !~ /ARRAY|HASH/i ) {
        # make select  of objects
        $a->push_content($self->_options_from_objects($items, $args));
    }
    # Array of Arrays
    elsif ( $type eq 'ARRAY' and $proto eq 'ARRAY' ) {
        $a->push_content($self->_options_from_arrays($items, $args));
    }
    # Array of Hashes
    elsif ( $type eq 'ARRAY' and $proto eq 'HASH' ) {
        $a->push_content($self->_options_from_hashes($items, $args));
    }
    else {
        die "You passed a weird type of data structure to me. Here it is: " .
	Dumper($items );
    }

    return $a;


}

=head2 _options_from_objects ( $objects, $args);

Private method to makes a options out of  objects. It attempts to call each
objects stringify method specified in $args->{stringify} as the content. Otherwise the default stringification prevails.

=cut
sub _options_from_objects {
    my ($self, $items, $args) = @_;
	my $selected = $args->{selected} || {};
	my $stringify = $args->{stringify} || '';
    my @res;
	for (@$items) {
		my $opt = HTML::Element->new("option", value => $_->id);
		$opt->attr(selected => "selected") if $selected->{$_->id}; 
		my $content = $stringify ? $_->stringify :  "$_";
		$opt->push_content($content);
		push @res, $opt; 
	}
    return @res;
}

sub _options_from_arrays {
    my ($self, $items, $args) = @_;
	my $selected = $args->{selected} || {};
    my @res;
	my $class = $args->{class} || '';
	my $stringify = $args->{stringify} || '';
	for my $item (@$items) {
	    my @pks; # for future multiple key support
	    push @pks, shift @$item foreach $class->columns('Primary');
		my $id = $pks[0];
		$id =~ ~ s/^0+//;  # In case zerofill is on .
		my $opt = HTML::Element->new("option", value => $id );
		$opt->attr(selected => "selected") if $selected->{$id};
		
		my $content = ($class and $stringify and $class->can($stringify)) ? 
		              $class->$stringify($_) : 
			          join( '/', map { $_ if $_; }@{$item} );
		$opt->push_content( $content );
        push @res, $opt; 
    }
    return @res;
}


sub _options_from_array {
    my ($self, $items, $args) = @_;
    my $selected = $args->{selected} || {};
    my @res;
    for (@$items) {
        my $opt = HTML::Element->new("option", value => $_ );
        #$opt->attr(selected => "selected") if $selected =~/^$id$/;
        $opt->attr(selected => "selected") if $selected->{$_};
        $opt->push_content( $_ );
        push @res, $opt;
    }
    return @res;
}

sub _options_from_hash {
    my ($self, $items, $args) = @_;
    my $selected = $args->{selected} || {};
    my @res;

    my @values = values %$items;
    # hash Key is the option content  and the hash value is option value
    for (sort keys %$items) {
        my $opt = HTML::Element->new("option", value => $items->{$_} );
        #$opt->attr(selected => "selected") if $selected =~/^$id$/;
        $opt->attr(selected => "selected") if $selected->{$items->{$_}};
        $opt->push_content( $_ );
        push @res, $opt;
    }
    return @res;
}


sub _options_from_hashes {
    my ($self, $items, $args) = @_;
	my $selected = $args->{selected} || {};
	my $pk = eval {$args->{class}->primary_column} || 'id';
	my $fclass = $args->{class} || '';
	my $stringify = $args->{stringify} || '';
	my @res;
	for (@$items) {
		my $val = $_->{$pk};
		my $opt = HTML::Element->new("option", value => $val );
		$opt->attr(selected => "selected") if $selected->{$val};
		my $content = ($fclass and $stringify and $fclass->can($stringify)) ? 
		              $fclass->$stringify($_) : 
			          join(' ', @$_);
		$opt->push_content( $content );
        push @res, $opt; 
    }
	return @res;
}

sub _to_select_or_create {
	my ($self, $col, $args) = @_;
	$args->{name} ||= $col;
	my $select = $self->to_field($col, 'select', $args);
	$args->{name} = "create_" . $args->{name};
	my $create = $self->to_field($col, 'foreign_inputs', $args);
	$create->{'__select_or_create__'} = 
		$self->to_field('__select_or_create__',{ name => '__select_or_create__' , value => 1 } );
	return ($select, $create);
}
	
# 
# checkboxes: if no data in hand (ie called as class method), replace
# with a radio button, in order to allow this field to be left
# unspecified in search / add forms.
# 
# Not tested
# TODO  --  make this general checkboxse
# 
#
sub _to_checkbox {
    my ($self, $col, $args) = @_;
    my $nullable = eval {self->column_nullable($col)} || 0; 
    return $self->_to_radio($col) if !ref($self) || $nullable;
    my $value = $self->$col;
    my $a = HTML::Element->new("input", type=> "checkbox", name => $col);
    $a->attr("checked" => 'true') if $value eq 'Y';
    return $a;
}


# TODO  -- make this general radio butons
#
sub _to_radio {
    my ($self, $col) = @_;
    my $value = ref $self && $self->$col || '';
    my $nullable = eval {self->column_nullable($col)} || 0; 
    my $a = HTML::Element->new("span");
    my $ry = HTML::Element->new("input", type=> "radio", name=>$col, value=>'Y' );
    my $rn = HTML::Element->new("input", type=> "radio", name=>$col, value=>'N' );
    my $ru = HTML::Element->new("input", type=> "radio", name=>$col, value=>'' ) if $nullable;
    $ry->push_content('Yes'); $rn->push_content('No');
    $ru->push_content('n/a') if $nullable;
    if ($value eq 'Y') { $ry->attr("checked" => 'true') }
    elsif ($value eq 'N') { $rn->attr("checked" => 'true') }
    elsif ($nullable) { $ru->attr("checked" => 'true') }
    $a->push_content($ry, $rn);
    $a->push_content($ru) if $nullable;
    return $a;
}



############################ HELPER METHODS ######################
##################################################################

=head2 _rename_foreign_input

_rename_foreign_input($html_el_or_hash_of_them); # changes made by reference

Recursively renames the foreign inputs made by _to_foreign_inputs so they 
can be processed generically.  The format is "accessor__AsForeign_colname". 

So if an Employee is a Person who has_own  Address and you call 

  Employee->to_field("person")  
  
then you will get inputs for the Person as well as their Address (by default,
override _field_from_relationship to change logic) named like this: 

  person__AsForeign__address__AsForeign__street
  person__AsForeign__address__AsForeign__city
  person__AsForeign__address__AsForeign__state  
  person__AsForeign__address__AsForeign__zip  

And the processor would know to create this address, put the address id in
person->address data slot, create the person and put the person id in the employee->person data slot and then create the employee with that data.

Overriede make_element_foreign to change how you want a foreign param labeled.

=head2 make_element_foreign

  $class->make_element_foreign($accessor, $element);
  
Makes an HTML::Element type object foreign elemen representing the 
class's accessor.  (IE this in an input element for $class->accessor :) )

=cut

sub make_element_foreign {
	my ($self, $accssr, $element)  = @_;
	$element->attr( name => $accssr . "__AsForeign__" . $element->attr('name'));
}



sub _rename_foreign_input {
	my ($self, $accssr, $element) = @_;
	if ( ref $element ne 'HASH' ) {
	#	my $new_name = $accssr . "__AsForeign__" . $input->attr('name');
		$self->make_element_foreign($accssr, $element);
	}
	else {
		$self->_rename_foreign_input($accssr, $element->{$_}) 
			foreach (keys %$element);
	}
}
=head2 _box($value) 

This functions computes the dimensions of a textarea based on the value 
or the defaults.

=cut

our ($min_rows, $max_rows, $min_cols, $max_cols) = (2 => 50, 20 => 100);
sub _box
{
    my $text = shift;
    if ($text) {
	my @rows = split /^/, $text;
	my $cols = $min_cols;
	my $chars = 0;
	for (@rows) {
	    my $len = length $_;
	    $chars += $len;
	    $cols = $len if $len > $cols;
	    $cols = $max_cols if $cols > $max_cols;
	}
	my $rows = @rows;
	$rows = int($chars/$cols) + 1 if $chars/$cols > $rows;
	$rows = $min_rows if $rows < $min_rows;
	$rows = $max_rows if $rows > $max_rows;
	($rows, $cols)
    }
    else { ($min_rows, $min_cols) }
}


1;


=head1 CHANGES

=head1 MAINTAINER 

Maypole Developers

=head1 AUTHORS

Peter Speltz, Aaron Trevena 

=head1 AUTHORS EMERITUS

Simon Cozens, Tony Bowden

=head1 TODO

  Documenting 
  Testing - lots
  chekbox generalization
  radio generalization
  select work
  Make link_hidden use standard make_url stuff when it gets in Maypole
  How do you tell AF --" I want a has_many select box for this every time so,
     when you call "to_field($this_hasmany)" you get a select box

=head1 BUGS and QUERIES

Please direct all correspondence regarding this module to:
 Maypole list. 

=head1 COPYRIGHT AND LICENSE

Copyright 2003-2004 by Simon Cozens / Tony Bowden

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<Class::DBI>, L<Class::DBI::FromCGI>, L<HTML::Element>.

=cut

