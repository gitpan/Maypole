package Maypole;
use base qw(Class::Accessor::Fast Class::Data::Inheritable);
use UNIVERSAL::require;
use strict;
use warnings;
use Maypole::Config;
use Maypole::Constants;
use Maypole::Headers;

our $VERSION = '2.05';

__PACKAGE__->mk_classdata($_) for qw( config init_done view_object );
__PACKAGE__->mk_accessors(
    qw( ar params query objects model_class template_args output path
        args action template error document_encoding content_type table
        headers_in headers_out )
);
__PACKAGE__->config( Maypole::Config->new() );
__PACKAGE__->init_done(0);

sub debug { 0 }

sub setup {
    my $calling_class = shift;
    $calling_class = ref $calling_class if ref $calling_class;
    {
        no strict 'refs';
        no warnings 'redefine';

        # Naughty.
        *{ $calling_class . "::handler" } =
          sub { Maypole::handler( $calling_class, @_ ) };
    }
    my $config = $calling_class->config;
    $config->model || $config->model("Maypole::Model::CDBI");
    $config->model->require;
    die "Couldn't load the model class $config->model: $@" if $@;
    $config->model->setup_database( $config, $calling_class, @_ );
    for my $subclass ( @{ $config->classes } ) {
        no strict 'refs';
        unshift @{ $subclass . "::ISA" }, $config->model;
        $config->model->adopt($subclass)
          if $config->model->can("adopt");
    }
}

sub init {
    my $class  = shift;
    my $config = $class->config;
    $config->view || $config->view("Maypole::View::TT");
    $config->view->require;
    die "Couldn't load the view class " . $config->view . ": $@" if $@;
    $config->display_tables
      || $config->display_tables( $class->config->tables );
    $class->view_object( $class->config->view->new );
    $class->init_done(1);

}

sub handler {

    # See Maypole::Workflow before trying to understand this.
    my ( $class, $req ) = @_;
    $class->init unless $class->init_done;

    # Create the request object
    my $r = bless {
        template_args => {},
        config        => $class->config
    }, $class;
    $r->headers_out(Maypole::Headers->new);
    $r->get_request($req);
    $r->parse_location();
    my $status = $r->handler_guts();
    return $status unless $status == OK;
    $r->send_output;
    return $status;
}

# The root of all evil
sub handler_guts {
    my $r = shift;
    $r->model_class( $r->config->model->class_of( $r, $r->{table} ) );

    my $applicable = $r->is_applicable;
    unless ( $applicable == OK ) {

        # It's just a plain template
        delete $r->{model_class};
        $r->{path} =~ s{/$}{};    # De-absolutify
        $r->template( $r->{path} );
    }

    # We authenticate every request, needed for proper session management
    my $status;
    eval { $status = $r->call_authenticate };
    if ( my $error = $@ ) {
        $status = $r->call_exception($error);
        if ( $status != OK ) {
            warn "caught authenticate error: $error";
            return $r->debug ? $r->view_object->error( $r, $error ) : ERROR;
        }
    }
    if ( $r->debug and $status != OK and $status != DECLINED ) {
        $r->view_object->error( $r,
            "Got unexpected status $status from calling authentication" );
    }
    return $status unless $status == OK;

    # We run additional_data for every request
    $r->additional_data;
    if ( $applicable == OK ) {
        eval { $r->model_class->process($r) };
        if ( my $error = $@ ) {
            $status = $r->call_exception($error);
            if ( $status != OK ) {
                warn "caught model error: $error";
                return $r->debug ? $r->view_object->error( $r, $error ) : ERROR;
            }
        }
    }
    if ( !$r->{output} ) {    # You might want to do it yourself
        eval { $status = $r->view_object->process($r) };
        if ( my $error = $@ ) {
            $status = $r->call_exception($error);
            if ( $status != OK ) {
                warn "caught view error: $error" if $r->debug;
                return $r->debug ? $r->view_object->error( $r, $error ) : ERROR;
            }
        }
        return $status;
    }
    else { return OK; }
}

sub is_applicable {
    my $self   = shift;
    my $config = $self->config;
    $config->ok_tables || $config->ok_tables( $config->display_tables );
    $config->ok_tables( { map { $_ => 1 } @{ $config->ok_tables } } )
      if ref $config->ok_tables eq "ARRAY";
    warn "We don't have that table ($self->{table}).\n"
      . "Available tables are: "
      . join( ",", @{ $config->{display_tables} } )
      if $self->debug
      and not $config->ok_tables->{ $self->{table} }
      and $self->{action};
    return DECLINED() unless exists $config->ok_tables->{ $self->{table} };

    # Is it public?
    return DECLINED unless $self->model_class->is_public( $self->{action} );
    return OK();
}

sub call_authenticate {
    my $self = shift;

    # Check if we have a model class
    if ( $self->{model_class} ) {
        return $self->model_class->authenticate($self)
          if $self->model_class->can("authenticate");
    }
    return $self->authenticate($self);   # Interface consistency is a Good Thing
}

sub call_exception {
    my $self = shift;
    my ($error) = @_;

    # Check if we have a model class
    if (   $self->{model_class}
        && $self->model_class->can('exception') )
    {
        my $status = $self->model_class->exception( $self, $error );
        return $status if $status == OK;
    }
    return $self->exception($error);
}

sub additional_data { }

sub authenticate { return OK }

sub exception { return ERROR }

sub parse_path {
    my $self = shift;
    $self->{path} ||= "frontpage";
    my @pi = split /\//, $self->{path};
    shift @pi while @pi and !$pi[0];
    $self->{table}  = shift @pi;
    $self->{action} = shift @pi;
    $self->{action} ||= "index";
    $self->{args}   = \@pi;
}

sub param { # like CGI::param(), but read-only
    my $r = shift;
    my ($key) = @_;
    if (defined $key) {
        unless (exists $r->{params}{$key}) {
            return wantarray() ? () : undef;
        }
        my $val = $r->{params}{$key};
        if (wantarray()) {
            return ref $val ? @$val : $val;
        } else {
            return ref $val ? $val->[0] : $val;
        }
    } else {
        return keys %{$r->{params}};
    }
}

sub get_template_root { "." }
sub get_request       { }

sub parse_location {
    die "Do not use Maypole directly; use Apache::MVC or similar";
}

sub send_output {
    die "Do not use Maypole directly; use Apache::MVC or similar";
}

=head1 NAME

Maypole - MVC web application framework

=head1 SYNOPSIS

See L<Maypole::Application>.

=head1 DESCRIPTION

This documents the Maypole request object. See the L<Maypole::Manual>, for a
detailed guide to using Maypole.

Maypole is a Perl web application framework to Java's struts. It is 
essentially completely abstracted, and so doesn't know anything about
how to talk to the outside world.

To use it, you need to create a package which represents your entire
application. In our example above, this is the C<BeerDB> package.

This needs to first use L<Maypole::Application> which will make your package
inherit from the appropriate platform driver such as C<Apache::MVC> or
C<CGI::Maypole>, and then call setup.  This sets up the model classes and
configures your application. The default model class for Maypole uses
L<Class::DBI> to map a database to classes, but this can be changed by altering
configuration. (B<Before> calling setup.)

=head2 CLASS METHODS

=head3 config

Returns the L<Maypole::Config> object

=head3 setup

    My::App->setup($data_source, $user, $password, \%attr);

Initialise the maypole application and model classes. Your application should
call this after setting configuration via L<"config">

=head3 init

You should not call this directly, but you may wish to override this to
add
application-specific initialisation.

=head3 view_object

Get/set the Maypole::View object

=head3 debug

    sub My::App::debug {1}

Returns the debugging flag. Override this in your application class to
enable/disable debugging.

=head2 INSTANCE METHODS

=head3 parse_location

Turns the backend request (e.g. Apache::MVC, Maypole, CGI) into a
Maypole
request. It does this by setting the C<path>, and invoking C<parse_path>
and
C<parse_args>.

You should only need to define this method if you are writing a new
Maypole
backend.

=head3 path

Returns the request path

=head3 parse_path

Parses the request path and sets the C<args>, C<action> and C<table> 
properties

=head3 table

The table part of the Maypole request path

=head3 action

The action part of the Maypole request path

=head3 args

A list of remaining parts of the request path after table and action
have been
removed

=head3 headers_in

A L<Maypole::Headers> object containing HTTP headers for the request

=head3 headers_out

A L<HTTP::Headers> object that contains HTTP headers for the output

=head3 parse_args

Turns post data and query string paramaters into a hash of C<params>.

You should only need to define this method if you are writing a new
Maypole
backend.

=head3 param

An accessor for request parameters. It behaves similarly to CGI::param() for
accessing CGI parameters.

=head3 params

Returns a hash of request parameters. The source of the parameters may vary
depending on the Maypole backend, but they are usually populated from request
query string and POST data.

B<Note:> Where muliple values of a parameter were supplied, the
C<params> 
value
will be an array reference.

=head3 get_template_root

Implementation-specific path to template root.

You should only need to define this method if you are writing a new
Maypole
backend. Otherwise, see L<Maypole::Config/"template_root">

=head3 get_request

You should only need to define this method if you are writing a new
Maypole backend. It should return something that looks like an Apache
or CGI request object, it defaults to blank.


=head3 is_applicable

Returns a Maypole::Constant to indicate whether the request is valid.

The default implementation checks that C<$r-E<gt>table> is publicly
accessible
and that the model class is configured to handle the C<$r-E<gt>action>

=head3 authenticate

Returns a Maypole::Constant to indicate whether the user is
authenticated for
the Maypole request.

The default implementation returns C<OK>

=head3 model_class

Returns the perl package name that will serve as the model for the
request. It corresponds to the request C<table> attribute.

=head3 additional_data

Called before the model processes the request, this method gives you a
chance
to do some processing for each request, for example, manipulating
C<template_args>.

=head3 objects

Get/set a list of model objects. The objects will be accessible in the
view
templates.

If the first item in C<$r-E<gt>args> can be C<retrieve()>d by the model
class,
it will be removed from C<args> and the retrieved object will be added
to the
C<objects> list. See L<Maypole::Model> for more information.

=head3 template_args

    $r->template_args->{foo} = 'bar';

Get/set a hash of template variables.

=head3 template

Get/set the template to be used by the view. By default, it returns
C<$r-E<gt>action>

=head3 exception

This method is called if any exceptions are raised during the
authentication 
or
model/view processing. It should accept the exception as a parameter and 
return
a Maypole::Constant to indicate whether the request should continue to
be
processed.

=head3 error

Get/set a request error

=head3 output

Get/set the response output. This is usually populated by the view
class. You
can skip view processing by setting the C<output>.

=head3 document_encoding

Get/set the output encoding. Default: utf-8.

=head3 content_type

Get/set the output content type. Default: text/html

=head3 send_output

Sends the output and additional headers to the user.

=head3 call_authenticate

This method first checks if the relevant model class
can authenticate the user, or falls back to the default
authenticate method of your Maypole application.


=head3 call_exception

This model is called to catch exceptions, first after authenticate, then after
processing the model class, and finally to check for exceptions from the view
class.

This method first checks if the relevant model class
can handle exceptions the user, or falls back to the default
exception method of your Maypole application.


=head3 handler

This method sets up the class if it's not done yet, sets some
defaults and leaves the dirty work to handler_guts.

=head3 handler_guts

This is the core of maypole. You don't want to know.

=head1 SEE ALSO

There's more documentation, examples, and a information on our mailing lists
at the Maypole web site:

L<http://maypole.perl.org/>

L<Maypole::Application>, L<Apache::MVC>, L<CGI::Maypole>.

=head1 AUTHOR

Maypole is currently maintained by Simon Flack C<simonflk#cpan.org>

=head1 AUTHOR EMERITUS

Simon Cozens, C<simon#cpan.org>

=head1 THANKS TO

Danijel Milicevic, Dave Slack, Jesse Sheidlower, Jody Belka, Marcus Ramberg,
Mickael Joanne, Randal Schwartz, Simon Flack, Steve Simms, Veljko Vidovic
and all the others who've helped.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
