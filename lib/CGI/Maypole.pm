package CGI::Maypole;
use base 'Maypole';

use strict;
use warnings;
use CGI::Simple;
use Maypole::Headers;

our $VERSION = '2.09';

sub run {
    my $self = shift;
    return $self->handler();
}

sub get_request {
    shift->{cgi} = CGI::Simple->new();
}


sub parse_location {
    my $self = shift;
    my $cgi = $self->{cgi};

    # Reconstruct the request headers (as far as this is possible)
    $self->headers_in(Maypole::Headers->new);
    for my $http_header ($cgi->http) {
        (my $field_name = $http_header) =~ s/^HTTPS?_//;
        $self->headers_in->set($field_name => $cgi->http($http_header));
    }

    $self->{path} = $cgi->url( -absolute => 1, -path_info => 1 );
    my $loc = $cgi->url( -absolute => 1 );
    no warnings 'uninitialized';
    $self->{path} .= '/' if $self->{path} eq $loc;
    $self->{path} =~ s/^($loc)?\///;
    $self->parse_path;
    $self->parse_args;
}

sub parse_args {
    my $self = shift;
    my (%vars) = $self->{cgi}->Vars;
    while ( my ( $key, $value ) = each %vars ) {
        my @values = split "\0", $value;
        $vars{$key} = @values <= 1 ? $values[0] : \@values;
    }
    $self->{params} = {%vars};
    $self->{query}  = {%vars};
}

sub send_output {
    my $r = shift;

    # Collect HTTP headers
    my %headers = (
        -type            => $r->{content_type},
        -charset         => $r->{document_encoding},
        -content_length  => do { use bytes; length $r->{output} },
    );
    foreach ($r->headers_out->field_names) {
        next if /^Content-(Type|Length)/;
        $headers{"-$_"} = $r->headers_out->get($_);
    }

    print $r->{cgi}->header(%headers), $r->{output};
}

sub get_template_root {
    my $r = shift;
    $r->{cgi}->document_root . "/" . $r->{cgi}->url( -relative => 1 );
}

1;

=head1 NAME

CGI::Maypole - CGI-based front-end to Maypole

=head1 SYNOPSIS

     package BeerDB;
     use base 'CGI::Maypole';
     BeerDB->setup("dbi:mysql:beerdb");
     BeerDB->config->uri_base("http://your.site/cgi-bin/beer.cgi/");
     BeerDB->config->display_tables([qw[beer brewery pub style]]);
     BeerDB->config->template_root("/var/www/beerdb/");
     # Now set up your database:
     # has-a relationships
     # untaint columns

     1;

     ## example beer.cgi:

     #!/usr/bin/perl -w
     use strict;
     use BeerDB;
     BeerDB->run();

Now to access the beer database, type this URL into your browser:
http://your.site/cgi-bin/beer.cgi/frontpage

=head1 DESCRIPTION

This is a CGI platform driver for Maypole. Your application can inherit from
CGI::Maypole directly, but it is recommended that you use
L<Maypole::Application>.


=head1 METHODS

=over

=item run

Call this from your CGI script to start the Maypole application.

=back

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

=head1 AUTHORS

Dave Ranney C<dave@sialia.com>

Simon Cozens C<simon@cpan.org>

=cut
