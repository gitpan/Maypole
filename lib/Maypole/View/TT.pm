package Maypole::View::TT;
use base 'Maypole::View::Base';
use Maypole::Constants;
use Template;

sub template {
    my ( $self, $r ) = @_;
    my $template = Template->new( { INCLUDE_PATH => [ $self->paths($r) ] } );
    my $output;
    if ( $template->process( $r->template, { $self->vars($r) }, \$output ) ) {
        $r->{output} = $output;
        return OK;
    }
    else {
        $r->{error} = $template->error;
        return ERROR;
    }
}

1;

=head1 NAME

Maypole::View::TT - A Template Toolkit view class for Maypole

=head1 SYNOPSIS

    BeerDB->config->view("Maypole::View::TT"); # The default anyway

=head1 DESCRIPTION

This is the default view class for Maypole; it uses the Template Toolkit
to fill in templates with the objects produced by Maypole's model classes.
Please see the Maypole manual, and in particular, the C<View> chapter,
for the template variables available and for a refresher on how template
components are resolved.

=over 4

=item template


Processes the template and sets the output. See L<Maypole::View::Base>

=back


=head1 AUTHOR

Simon Cozens

=cut

