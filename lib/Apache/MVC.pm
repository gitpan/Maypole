package Apache::MVC;

use strict;
use warnings;

use base 'Maypole';
use mod_perl;

use constant APACHE2 => $mod_perl::VERSION >= 1.99;

if (APACHE2) {
    require Apache2;
    require Apache::RequestRec;
    require Apache::RequestUtil;
    require APR::URI;
}
else { require Apache }
require Apache::Request;

our $VERSION = "2.03";

sub get_request {
    my ( $self, $r ) = @_;
    $self->{ar} = Apache::Request->new($r);
}

sub parse_location {
    my $self = shift;
    $self->{path} = $self->{ar}->uri;
    my $loc = $self->{ar}->location;
    no warnings 'uninitialized';
    $self->{path} =~ s/^($loc)?\///;
    $self->parse_path;
    $self->parse_args;
}

sub parse_args {
    my $self = shift;
    $self->{params} = { $self->_mod_perl_args( $self->{ar} ) };
    $self->{query}  = { $self->_mod_perl_args( $self->{ar} ) };
}

sub send_output {
    my $r = shift;
    $r->{ar}->content_type(
        $r->{content_type}  =~ m/^text/ ?
	$r->{content_type} . "; charset=" . $r->{document_encoding} :
	$r->{content_type} );
    $r->{ar}->headers_out->set( "Content-Length" => length $r->{output} );
    APACHE2 || $r->{ar}->send_http_header;
    $r->{ar}->print( $r->{output} );
}

sub get_template_root {
    my $r = shift;
    $r->{ar}->document_root . "/" . $r->{ar}->location;
}

sub _mod_perl_args {
    my ( $self, $apr ) = @_;
    my %args;
    foreach my $key ( $apr->param ) {
        my @values = $apr->param($key);
        $args{$key} = @values == 1 ? $values[0] : \@values;
    }
    return %args;
}

1;

=head1 NAME

Apache::MVC - Apache front-end to Maypole

=head1 SYNOPSIS

    package BeerDB;
    use base 'Apache::MVC';
    BeerDB->setup("dbi:mysql:beerdb");
    BeerDB->config->uri_base("http://your.site/");
    BeerDB->config->display_tables([qw[beer brewery pub style]]);
    # Now set up your database:
    # has-a relationships
    # untaint columns

    1;

=head1 DESCRIPTION

Maypole is a Perl web application framework to Java's struts. It is 
essentially completely abstracted, and so doesn't know anything about
how to talk to the outside world. C<Apache::MVC> is a mod_perl based
subclass of Maypole.

To use it, you need to create a package which represents your entire
application. In our example above, this is the C<BeerDB> package.

This needs to first inherit from C<Apache::MVC>, and then call setup.
This will give your package an Apache-compatible C<handler> subroutine,
and then pass any parameters onto the C<setup_database> method of the
model class. The default model class for Maypole uses L<Class::DBI> to 
map a database to classes, but this can be changed by messing with the
configuration. (B<Before> calling setup.)

Next, you should configure your application through the C<config>
method. Configuration parameters at present are:

=over

=item uri_base

You B<must> specify this; it is the base URI of the application, which
will be used to construct links.

=item display_tables

If you do not want all of the tables in the database to be accessible,
then set this to a list of only the ones you want to display

=item rows_per_page

List output is paged if you set this to a positive number of rows.

=back

You should also set up relationships between your classes, such that,
for instance, calling C<brewery> on a C<BeerDB::Beer> object returns an
object representing its associated brewery.

For a full example, see the included "beer database" application.

=head1 INSTALLATION

Create a driver module like the one above.

Put the following in your Apache config:

    <Location /beer>
        SetHandler perl-script
        PerlHandler BeerDB
    </Location>

Copy the templates found in F<templates/factory> into the
F<beer/factory> directory off the web root. When the designers get
back to you with custom templates, they are to go in
F<beer/custom>. If you need to do override templates on a
database-table-by-table basis, put the new template in
F<beer/I<table>>. 

This will automatically give you C<add>, C<edit>, C<list>, C<view> and
C<delete> commands; for instance, a list of breweries, go to 

    http://your.site/beer/brewery/list

For more information about how the system works and how to extend it,
see L<Maypole>.

=head1 Implementation

This class overrides a set of methods in the base Maypole class to provide it's
functionality. See L<Maypole> for these:

=over

=item get_request

=item get_template_root

=item parse_args

=item parse_location

=item send_output

=back

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>
Marcus Ramberg, C<marcus@thefeed.no>
Screwed up by Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.
