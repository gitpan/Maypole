package Maypole::Application;

use strict;
use warnings;
use UNIVERSAL::require;
use Maypole;

our @ISA;

sub import {
    my ( $self, @plugins ) = @_;
    my $caller = caller(0);
    no strict 'refs';
    push @{"${caller}::ISA"}, $self;
    foreach (@plugins) {
        if    (/^\-Setup$/) { $caller->setup }
        elsif (/^\-Debug$/) {
            *{"$caller\::debug"} = sub { 1 };
            warn "Debugging enabled";
        }
        elsif (/^-.*$/) { warn "Unknown flag: $_" }
        else {

            # The plugin caller should be our application class
            eval "package $caller; require Maypole::Plugin::$_";
            if ($@) { warn qq(Loading plugin "Maypole::Plugin::$_" failed: $@) }
            else {
                warn "Loaded plugin: Maypole::Plugin::$_" if $caller->debug;
                unshift @ISA, "Maypole::Plugin::$_";
            }
        }
    }
}

if ( $ENV{MOD_PERL} ) {
    Apache::MVC->require or die "Loading Apache frontend failed: $@";
    push @ISA, 'Apache::MVC';
}
else {
    CGI::Maypole->require or die "Loading CGI frontend failed: $@";
    push @ISA, 'CGI::Maypole';
}

1;

=head1 NAME

Maypole::Application - Maypole Universal Frontend

=head1 SYNOPSIS

    use Maypole::Application;

    use Maypole::Application qw(Config::YAML);

    use Maypole::Application qw(-Debug Config::YAML -Setup);

    use Maypole::Application qw(Config::YAML Loader -Setup -Debug);

=head1 DESCRIPTION

This is a universal frontend for mod_perl1, mod_perl2 and CGI.

You can omit the Maypole::Plugin:: prefix from plugins.
So Maypole::Plugin::Config::YAML becomes Config::YAML.

    use Maypole::Application qw(Config::YAML);

You can also set special flags like -Setup and -Debug.

    use Maypole::Application qw(-Debug Config::YAML -Setup);

The position of plugins and flags in the chain is important,
because they are loaded/executed in the same order they appear.

=head2 -Setup

    use Maypole::Application qw(-Setup);

is equivalent to

    use Maypole::Application;
    MyApp->setup;

=head2 -Debug

    use Maypole::Application qw(-Debug);

is equivalent to

    use Maypole::Application;
    sub debug { 1 }

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>
Idea by Marcus Ramberg, C<marcus@thefeed.no>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.
