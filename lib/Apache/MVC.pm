package Apache::MVC;

our $VERSION = '2.05';

use strict;
use warnings;

use base 'Maypole';
use mod_perl;
use Maypole::Headers;

use constant APACHE2 => $mod_perl::VERSION >= 1.99;

if (APACHE2) {
    require Apache2;
    require Apache::RequestIO;
    require Apache::RequestRec;
    require Apache::RequestUtil;
    require APR::URI;
}
else { require Apache }
require Apache::Request;

sub get_request {
    my ( $self, $r ) = @_;
    $self->{ar} = Apache::Request->new($r);
}

sub parse_location {
    my $self = shift;

    # Reconstruct the request headers
    $self->headers_in(Maypole::Headers->new);
    my %headers;
    if (APACHE2) { %headers = %{$self->{ar}->headers_in};
    } else { %headers = $self->{ar}->headers_in; }
    for (keys %headers) {
        $self->headers_in->set($_, $headers{$_});
    }

    $self->{path} = $self->{ar}->uri;
    my $loc = $self->{ar}->location;
    no warnings 'uninitialized';
    $self->{path} .= '/' if $self->{path} eq $loc;
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
          $r->{content_type} =~ m/^text/
        ? $r->{content_type} . "; charset=" . $r->{document_encoding}
        : $r->{content_type}
    );
    $r->{ar}->headers_out->set(
        "Content-Length" => do { use bytes; length $r->{output} }
    );

    foreach ($r->headers_out->field_names) {
        next if /^Content-(Type|Length)/;
        $r->{ar}->headers_out->set($_ => $r->headers_out->get($_));
    }

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

A mod_perl platform driver for Maypole. Your application can inherit from
Apache::MVC directly, but it is recommended that you use
L<Maypole::Application>.

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

=cut
