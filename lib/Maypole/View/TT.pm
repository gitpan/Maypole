package Maypole::View::TT;
use base 'Maypole::View::Base';
use Maypole::Constants;
use Template;
use File::Spec::Functions qw(catdir tmpdir);

use strict;
our $VERSION = "1." . sprintf "%04d", q$Rev: 324 $ =~ /: (\d+)/;

sub template {
    my ( $self, $r ) = @_;

    unless ($self->{tt}) {
        my $view_options = $r->config->view_options || {};
        $self->{provider} = Template::Provider->new($view_options);
        $self->{tt}       = Template->new({
            %$view_options,
            LOAD_TEMPLATES => [ $self->{provider} ],
        });
    }

    $self->{provider}->include_path([ $self->paths($r) ]);

    my $output;
    if ($self->{tt}->process( $r->template, { $self->vars($r) }, \$output )) {
        $r->{output} = $output;
        return OK;
    }
    else {
        $r->{error} = $self->{tt}->error;
        return ERROR;
    }
}

1;

=head1 NAME

Maypole::View::TT - A Template Toolkit view class for Maypole

=head1 SYNOPSIS

    BeerDB->config->view("Maypole::View::TT"); # The default anyway

    # Set some Template Toolkit options
    BeerDB->config->view_options( {
        TRIM        => 1,
        COMPILE_DIR => '/var/tmp/mysite/templates',
    } );

=head1 DESCRIPTION

This is the default view class for Maypole; it uses the Template Toolkit to
fill in templates with the objects produced by Maypole's model classes.  Please
see the L<Maypole manual|Maypole::Manual>, and in particular, the
L<view|Maypole::Manual::View> chapter for the template variables available and
for a refresher on how template components are resolved.

The underlying Template toolkit object is configured through
C<$r-E<gt>config-E<gt>view_options>. See L<Template|Template> for available
options.

=over 4

=item template

Processes the template and sets the output. See L<Maypole::View::Base>

=back


=head1 AUTHOR

Simon Cozens

=cut

