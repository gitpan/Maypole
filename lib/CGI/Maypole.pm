package CGI::Maypole;
use base 'Maypole';

use strict;
use warnings;
our $VERSION = "0.3";

sub run {
	my $self = shift;
	return $self->handler();
}

sub get_request {
	require CGI::Simple;
	shift->{cgi} = CGI::Simple->new();
}

sub parse_location {
     my $self = shift;
     $self->{path} = $self->{cgi}->url(-absolute=>1, -path_info=>1);
     my $loc = $self->{cgi}->url(-absolute=>1);
     no warnings 'uninitialized';
     $self->{path} =~ s/^($loc)?\///;
     $self->parse_path;
     $self->{params} = { $self->{cgi}->Vars };
     $self->{query}  = { $self->{cgi}->Vars };
}

sub send_output {
     my $r = shift;	
	print $r->{cgi}->header(-type => $r->{content_type},
					  -content_length => length $r->{output},
					  );
     print $r->{output};
}

sub get_template_root {
     my $r = shift;
     $r->{cgi}->document_root . "/". $r->{cgi}->url(-relative=>1);
}


1;

=head1 NAME

CGI::Maypole - CGI-based front-end to Maypole

=head1 SYNOPSIS

     package BeerDB;
     use base 'CGI::Maypole;
     BeerDB->setup("dbi:mysql:beerdb");
     BeerDB->config->{uri_base} = "http://your.site/cgi-bin/beer.cgi/";
     BeerDB->config->{display_tables} = [qw[beer brewery pub style]];
     # Now set up your database:
     # has-a relationships
     # untaint columns

     1;

     ## example beer.cgi:
	
     #!/usr/bin/perl -w
     use strict;
     use BeerDB;
     BeerDB->run();

=head1 DESCRIPTION

This is a handler for Maypole which will use the CGI instead of Apache's
C<mod_perl> 1.x. This handler can also be used for Apache 2.0.

=head1 AUTHORS

Dave Ranney C<dave@sialia.com>

Simon Cozens C<simon@cpan.org>