package Maypole::View::Mason;
use base 'Maypole::View::Base';
use HTML::Mason;
use Maypole::Constants;

sub template {
    my ($self, $r) = @_;
    my $label = "path0";
    my $output;
    my $mason = HTML::Mason::Interp->new(
        comproot => [ map { [ $label++ => $_ ] } $self->paths($t) ],
        output_method => \$output,
        error_mode => "output" # Saves us having to handle them...
    );
    $mason->exec($r->template, $self->vars($r))
    $r->{output} = $output;
    return OK;
}

1;

=head1 NAME

Maypole::View::Mason - A HTML::Mason view class for Maypole

=head1 SYNOPSIS

   BeerDB->config->{view} = "Maypole::View::Mason"; 

And then:

    <%args>
        @breweries
    </%args>

    % for my $brewery (@breweries) {
        ...
        <TD><% $brewery->name %></TD>
    % }
    ...

=head1 DESCRIPTION

This class allows you to use C<HTML::Mason> components for your Maypole
templates. It provides precisely the same path searching and template
variables as the Template Toolkit view class, although you will need
to produce your own set of templates as the factory-supplied templates
are, of course, Template Toolkit ones. 

Please see the Maypole manual, and in particular, the C<View> chapter,
for the template variables available and for a refresher on how template
components are resolved.

=head1 AUTHOR

Simon Cozens

=head1 THANKS

This module was made possible thanks to a Perl Foundation grant.

=cut
