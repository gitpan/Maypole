package Maypole;
use base qw(Class::Accessor Class::Data::Inheritable);
use attributes ();
use UNIVERSAL::require;
use strict;
use warnings;
our $VERSION = "1.6";
__PACKAGE__->mk_classdata($_) for qw( config init_done view_object );
__PACKAGE__->mk_accessors ( qw( ar params query objects model_class
args action template ));
__PACKAGE__->config({});
__PACKAGE__->init_done(0);
use Maypole::Constants;

sub debug { 0 }

sub setup {
    my $calling_class = shift;
    $calling_class = ref $calling_class if ref $calling_class;
    {
      no strict 'refs';
      # Naughty.
      *{$calling_class."::handler"} = sub { Maypole::handler($calling_class, @_) };
    }
    my $config = $calling_class->config;
    $config->{model} ||= "Maypole::Model::CDBI";
    $config->{model}->require;
    die "Couldn't load the model class $config->{model}: $@" if $@;
    $config->{model}->setup_database($config, $calling_class, @_);
    for my $subclass (@{$config->{classes}}) {
        no strict 'refs';
        unshift @{$subclass."::ISA"}, $config->{model};
        $config->{model}->adopt($subclass)
           if $config->{model}->can("adopt");
    }
}

sub init {
    my $class = shift;
    my $config = $class->config;
    $config->{view}  ||= "Maypole::View::TT";
    $config->{view}->require;
    die "Couldn't load the view class $config->{view}: $@" if $@;
    $config->{display_tables} ||= [ @{$class->config->{tables}} ];
    $class->view_object($class->config->{view}->new);
    $class->init_done(1);

}

sub handler {
    # See Maypole::Workflow before trying to understand this.
    my $class = shift;
    $class->init unless $class->init_done;
    my $r = bless { config => $class->config }, $class;
    $r->get_request();
    $r->parse_location();
    my $status = $r->handler_guts();
    return $status unless $status == OK;
    $r->send_output;
    return $status;
}

sub handler_guts {
    my $r = shift;
    $r->model_class($r->config->{model}->class_of($r, $r->{table}));
    my $status = $r->is_applicable;
    if ($status == OK) { 
        $status = $r->call_authenticate;
        if ($r->debug and $status != OK and $status != DECLINED) {
            $r->view_object->error($r,
                "Got unexpected status $status from calling authentication");
        }
        return $status unless $status == OK;
        $r->additional_data();
    
        $r->model_class->process($r);
    } else { 
        # Otherwise, it's just a plain template.
        delete $r->{model_class};
        $r->{path} =~ s{/}{}; # De-absolutify
        $r->template($r->{path});
    }
    if (!$r->{output}) { # You might want to do it yourself
        return $r->view_object->process($r);
    } else { return OK; }
}

sub is_applicable {
    my $self = shift;
    my $config = $self->config;
    $config->{ok_tables} ||= $config->{display_tables};
    $config->{ok_tables} = {map {$_=>1} @{$config->{ok_tables}}}
       if ref $config->{ok_tables} eq "ARRAY";
    warn "We don't have that table ($self->{table})"
        if $self->debug and not $config->{ok_tables}{$self->{table}};
    return DECLINED() unless exists $config->{ok_tables}{$self->{table}};

    # Does the action method exist?
    my $cv = $self->model_class->can($self->{action});
    warn "We don't have that action ($self->{action})" 
        if $self->debug and not $cv;
    return DECLINED() unless $cv;

    # Is it exported?
    $self->{method_attribs} = join " ", attributes::get($cv);
    do { warn "$self->{action} not exported" if $self->debug;
    return DECLINED() 
     } unless $self->{method_attribs} =~ /\bExported\b/i;
    return OK();
}

sub call_authenticate {
    my $self = shift;
    return $self->model_class->authenticate($self) if 
        $self->model_class->can("authenticate"); 
    return $self->authenticate($self); # Interface consistency is a Good Thing
}

sub additional_data {}

sub authenticate { return OK }

sub parse_path {
    my $self = shift;
    $self->{path} ||= "frontpage";
    my @pi = split /\//, $self->{path};
    shift @pi while @pi and !$pi[0];
    $self->{table} = shift @pi;
    $self->{action} = shift @pi;
    $self->{args} = \@pi;
}

=head1 NAME

Maypole - MVC web application framework

=head1 SYNOPSIS

See L<Maypole>.

=head1 DESCRIPTION

A large number of web programming tasks follow the same sort of pattern:
we have some data in a datasource, typically a relational database. We
have a bunch of templates provided by web designers. We have a number of
things we want to be able to do with the database - create, add, edit,
delete records, view records, run searches, and so on. We have a web
server which provides input from the user about what to do. Something in
the middle takes the input, grabs the relevant rows from the database,
performs the action, constructs a page, and spits it out.

Maypole aims to be the most generic and extensible "something in the
middle" - an MVC-based web application framework.

An example would help explain this best. You need to add a product
catalogue to a company's web site. Users need to list the products in
various categories, view a page on each product with its photo and
pricing information and so on, and there needs to be a back-end where
sales staff can add new lines, change prices, and delete out of date
records. So, you set up the database, provide some default templates
for the designers to customize, and then write an Apache handler like
this:

    package ProductDatabase;
    use base 'Apache::MVC';
    __PACKAGE__->set_database("dbi:mysql:products");
    ProductDatabase->config->{uri_base} = "http://your.site/catalogue/";
    ProductDatabase::Product->has_a("category" => ProductDatabase::Category); 
    # ...

    sub authenticate {
        my ($self, $request) = @_;
        return OK if $request->{ar}->get_remote_host() eq "sales.yourcorp.com";
        return OK if $request->{action} =~ /^(view|list)$/;
        return DECLINED;
    }
    1;

You then put the following in your Apache config:

    <Location /catalogue>
        SetHandler perl-script
        PerlHandler ProductDatabase
    </Location>

And copy the templates found in F<templates/factory> into the
F<catalogue/factory> directory off the web root. When the designers get
back to you with custom templates, they are to go in
F<catalogue/custom>. If you need to do override templates on a
database-table-by-table basis, put the new template in
F<catalogue/I<table>>. 

This will automatically give you C<add>, C<edit>, C<list>, C<view> and
C<delete> commands; for instance, a product list, go to 

    http://your.site/catalogue/product/list

For a full example, see the included "beer database" application.

=head1 HOW IT WORKS

There's some documentation for the workflow in L<Maypole::Workflow>,
but the basic idea is that a URL part like C<product/list> gets
translated into a call to C<ProductDatabase::Product-E<gt>list>. This
propagates the request with a set of objects from the database, and then 
calls the C<list> template; first, a C<product/list> template if it
exists, then the C<custom/list> and finally C<factory/list>. 

If there's another action you want the system to do, you need to either
subclass the model class, and configure your class slightly differently:

    package ProductDatabase::Model;
    use base 'Maypole::Model::CDBI';

    sub supersearch :Exported {
        my ($self, $request) = @_;
        # Do stuff, get a bunch of objects back
        $r->objects(\@objects);
        $r->template("template_name");
    }

Then your top-level application package should change the model class:
(Before calling C<setup>)

    ProductDatabase->config->{model} = "ProductDatabase::Model";

(The C<:Exported> attribute means that the method can be called via the
URL C</I<table>/supersearch/...>.)

Alternatively, you can put the method directly into the specific model
class for the table:

    sub ProductDatabase::Product::supersearch :Exported { ... }

By default, the view class uses Template Toolkit as the template
processor, and the model class uses C<Class::DBI>; it may help you to be
familiar with these modules before going much further with this,
although I expect there to be other subclasses for other templating
systems and database abstraction layers as time goes on. The article at
C<http://www.perl.com/pub/a/2003/07/15/nocode.html> is a great
introduction to the process we're trying to automate.

=head1 USING MAYPOLE

You should probably not use Maypole directly. Maypole is an abstract
class which does not specify how to communicate with the outside world.
The most popular subclass of Maypole is L<Apache::MVC>, which interfaces
the Maypole framework to Apache mod_perl; another important one is
L<CGI::Maypole>.

If you are implementing Maypole subclasses, you need to provide at least
the C<parse_location> and C<send_output> methods. You may also want to
provide C<get_request> and C<get_template_root>. See the
L<Maypole::Workflow> documentation for what these are expected to do.

=cut

sub get_template_root { "." }
sub get_request { }
sub parse_location { die "Do not use Maypole directly; use Apache::MVC or similar" }
sub send_output{ die "Do not use Maypole directly; use Apache::MVC or similar" }

=head1 SEE ALSO

There's more documentation, examples, and a wiki at the Maypole web site:

http://maypole.simon-cozens.org/

L<Apache::MVC>, L<CGI::Maypole>.

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;

