package Maypole::View::Base;
use File::Spec;
use UNIVERSAL::moniker;
use strict;
use Maypole::Constants;

sub new { bless {}, shift }    # By default, do nothing.

sub paths {
    my ( $self, $r ) = @_;
    my $root = $r->config->template_root || $r->get_template_root;
    return (
        $root,
        (
            $r->model_class
              && File::Spec->catdir( $root, $r->model_class->moniker )
        ),
        File::Spec->catdir( $root, "custom" ),
        File::Spec->catdir( $root, "factory" )
    );
}

sub vars {
    my ( $self, $r ) = @_;
    my $class = $r->model_class;
    my $base  = $r->config->uri_base;
    $base =~ s/\/+$//;
    my %args = (
        request => $r,
        objects => $r->objects,
        base    => $base,
        config  => $r->config

          # ...
    );
    if ($class) {
        $args{classmetadata} = {
            name              => $class,
            table             => $class->table,
            columns           => [ $class->display_columns ],
            list_columns      => [ $class->list_columns ],
            colnames          => { $class->column_names },
            related_accessors => [ $class->related($r) ],
            moniker           => $class->moniker,
            plural            => $class->plural_moniker,
            cgi               => { $class->to_cgi },
        };

        # User-friendliness facility for custom template writers.
        if ( @{ $r->objects || [] } > 1 ) {
            $args{ $r->model_class->plural_moniker } = $r->objects;
        }
        else {
            ( $args{ $r->model_class->moniker } ) = @{ $r->objects || [] };
        }
    }

    # Overrides
    %args = ( %args, %{ $r->{template_args} || {} } );
    %args;
}

sub process {
    my ( $self, $r ) = @_;
    $r->{content_type}      ||= "text/html";
    $r->{document_encoding} ||= "utf-8";
    my $status = $self->template($r);
    return $self->error($r) if $status != OK;
    return OK;
}

sub error {
    my ( $self, $r ) = @_;
    warn $r->{error};
    if ( $r->{error} =~ /not found$/ ) {

        # This is a rough test to see whether or not we're a template or
        # a static page
        return -1 unless @{ $r->{objects} || [] };

        $r->{error} = <<EOF;

<H1> Template not found </H1>

This template was not found while processing the following request:

<B>@{[$r->{action}]}</B> on table <B>@{[ $r->{table} ]}</B> with objects:

<PRE>
@{[join "\n", @{$r->{objects}}]}
</PRE>

Looking for template <B>@{[$r->{template}]}</B> in paths:

<PRE>
@{[ join "\n", $self->paths($r) ]}
</PRE>
EOF
        $r->{content_type} = "text/html";
        $r->{output}       = $r->{error};
        return OK;
    }
    $r->{content_type} = "text/plain";
    $r->{output}       = $r->{error};
    $r->send_output;
    return ERROR;
}

sub template { die shift() . " didn't define a decent template method!" }

1;


=head1 NAME

Maypole::View::Base - Base cl

=head1 DESCRIPTION

This is the base class for Maypole view classes. This is an abstract class
meant to define the interface, and can't be used directly.

=head2 process

This is the engine of this module. It populates all the relevant variables
and calls the requested action.

Anyone subclassing this for a different database abstraction mechanism
needs to provide the following methods:

=head2 template 

In this method you do the actual processing of your template. it should use L<paths> 
to search for components, and provide the templates with easy access to the contents
of L<vars>. It should put the result in $r->{output} and return OK if processing was
sucessfull, or populate $r->{error} and return ERROR if it fails.

=head1 Other overrides

Additionally, individual derived model classes may want to override the

=head2 new

The default constructor does nothing. You can override this to perform actions
during view initialization.

=head2 paths

Returns search paths for templates. the default method returns factory, custom and
<tablename> under the configured template root.

=head2 vars

returns a hash of data the template should have access to. The default one populates
classmetadata if there is a class, as well as setting the data objects by name if 
there is one or more objects available.

=head2 error


=cut
