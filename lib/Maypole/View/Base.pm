package Maypole::View::Base;
use File::Spec;
use UNIVERSAL::moniker;
use strict;
use Maypole::Constants;

sub new { bless {}, shift } # By default, do nothing.

sub paths {
    my ($self, $r) = @_;
    my $root = $r->{config}{template_root} || $r->get_template_root;
    return (
        $root,
        ($r->model_class && 
            File::Spec->catdir($root, $r->model_class->moniker)),
        File::Spec->catdir($root, "custom"),
        File::Spec->catdir($root, "factory")
    );
}

sub vars {
    my ($self, $r) = @_;
    my $class = $r->model_class;
    my %args = (
        request => $r,
        objects => $r->objects,
        base    => $r->config->{uri_base},
        config  => $r->config
        # ...
    ) ;
    if ($class) { 
        $args{classmetadata} = {
            name => $class,
            table => $class->table,
            columns => [ $class->display_columns ],
            colnames => { $class->column_names },
            related_accessors => [ $class->related($r) ],
            moniker => $class->moniker,
            plural  => $class->plural_moniker,
            cgi => { $class->to_cgi },
        };

        # User-friendliness facility for custom template writers.
        if (@{$r->objects || []} > 1) { 
            $args{$r->model_class->plural_moniker} = $r->objects;
        } else {
            ($args{$r->model_class->moniker}) = @{$r->objects ||[]};
        }
    }

    # Overrides
    %args = (%args, %{$r->{template_args}||{}});
    %args;
}

sub process {
    my ($self, $r) = @_;
    my $status = $self->template($r);
    return $self->error($r) if $status != OK;
    $r->{content_type} ||= "text/html";
    return OK;
}

sub error {
    my ($self, $r) = @_;
    warn $r->{error};
    if ($r->{error} =~ /not found$/) { return -1 }
    $r->{content_type} = "text/plain";
    $r->{output} = $r->{error};
    $r->send_output;
    return ERROR;
}

sub template { die shift()." didn't define a decent template method!" }

1;
