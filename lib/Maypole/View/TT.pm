package Maypole::View::TT;
use Apache::Constants;
use Lingua::EN::Inflect;
use Template;
use File::Spec;
use UNIVERSAL::moniker;
use strict;


sub new { bless {}, shift } # Not worth having

sub _tt {
    my ($self, $r) = @_;
    # This bit sucks.
    my $root = $r->{config}{template_root} || $r->get_template_root;
    Template->new({ INCLUDE_PATH => [
        $root,
        ($r->model_class && File::Spec->catdir($root, $r->model_class->moniker)),
        File::Spec->catdir($root, "custom"),
        File::Spec->catdir($root, "factory")
    ]});
}

sub _args {
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
            columns => [ $class->display_columns ],
            colnames => { $class->column_names },
            related_accessors => [ $class->related($r) ],
            moniker => $class->moniker,
            plural  => $class->plural_moniker,
            cgi => { $class->to_cgi },
            description => $class->description
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
    my $template = $self->_tt($r);
    my $output;
    $template->process($r->template, { $self->_args($r) }, \$output)
    || return $self->error($r, $template->error);

    $r->{content_type} ||= "text/html";
    $r->{output} = $output;
    return 200;
}

sub error {
    my ($self, $r, $error) = @_;
    warn $error;
    if ($error =~ /not found$/) { return DECLINED }
    $r->{content_type} = "text/plain";
    $r->{output} = $error;
    $r->send_output;
    exit;
}

1;
