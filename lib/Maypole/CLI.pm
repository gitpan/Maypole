package Maypole::CLI;
use UNIVERSAL::require;
use URI; use URI::QueryParam;

use strict;
use warnings;
my $package;
our $buffer;
sub import { 
    $package = $_[1];
    $package->require;
    die "Couldn't require $package - $@" if $@;
    no strict 'refs';
    unshift @{$package."::ISA"}, "Maypole::CLI";
}

sub get_request {}
sub get_template_root { $ENV{MAYPOLE_TEMPLATES} || "." }

sub parse_location {
    my $self = shift;
    my $url = URI->new(shift @ARGV);
    my $root = URI->new($self->config->{uri_base})->path;
    $self->{path} = $url->path;
    $self->{path} =~ s/^$root//i if $root;
    $self->parse_path;
    $self->{query} = $url->query_form_hash;
}

sub send_output { $buffer = shift->{output} }

# Do it!
CHECK { if ((caller(0))[1] eq "-e") { 
            $package->handler() and print $buffer; 
       } }

1;

=head1 NAME

Maypole::CLI - Command line interface to Maypole for testing and debugging

=head1 SYNOPSIS

  % setenv MAYPOLE_TEMPLATES /var/www/beerdb/
  % perl -MMaypole::CLI=BeerDB -e1 http://localhost/beerdb/brewery/frontpage

=head1 DESCRIPTION

This module is used to test Maypole sites without going through a web
server or modifying them to use a CGI frontend. To use it, you should
first either be in the template root for your Maypole site or set the
environment variable C<MAYPOLE_TEMPLATES> to the right value.

Next, you import the C<Maypole::CLI> module specifying your base Maypole
subclass. The usual way to do this is with the C<-M> flag: 
C<perl -MMaypole::CLI=MyApp>. This is equivalent to:

    use Maypole::CLI qw(MyApp);

Now Maypole will automatically call your application's handler with the
URL specified as the first command line parameter. This should be the
full URL, starting from whatever you have defined as the C<uri_base> in
your application's configuration, and may include query parameters.

The Maypole HTML output should then end up on standard output.

=head1 Support for testing

The module can also be used as part of a test script. 

When used programmatically, rather than from the command line, its
behaviour is slightly different. 

Although the URL is taken from C<@ARGV> as normal, your application's
C<handler> method is not called automatically, as it is when used on the
command line; you need to call it manually. Additionally, when
C<handler> is called, the output is not printed to standard output but
stored in C<$Maypole::CLI::buffer>, to allow you to check the contents
more easily.

For instance, a test script could look like this:

    use Test::More tests => 5;
    use Maypole::CLI qw(BeerDB);
    $ENV{MAYPOLE_TEMPLATES} = "t/templates";

    # Hack because isa_ok only supports object isa not class isa
    isa_ok( (bless {},"BeerDB") , "Maypole");

    @ARGV = ("http://localhost/beerdb/");
    is(BeerDB->handler, 200, "OK");
    like($Maypole::CLI::buffer, qr/frontpage/, "Got the front page");

    @ARGV = ("http://localhost/beerdb/beer/list");
    is(BeerDB->handler, 200, "OK");
    like($Maypole::CLI::buffer, qr/Organic Best/, "Found a beer in the list");

