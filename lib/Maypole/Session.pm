package Maypole::Session;

=head1 NAME

Maypole::Constants - Maypole predefined constants

=head1 SYNOPSIS

use Maypole::Session;

my $uid = Maypole::Session::generate_unique_id()

=head1 DESCRIPTION

This class provides session related methods for Maypole such as unique id's for requests.

=head1 METHODS

=head2 generate_unique_id()

my $uid = Maypole::Session::generate_unique_id()

generates a unique id and returns it, requires no arguments but accepts size, default is 32.

=cut

use strict;
use Digest::MD5;

sub generate_unique_id {
    my $length = shift || 32;
    my $id = substr(Digest::MD5::md5_hex(Digest::MD5::md5_hex(time(). {}. rand(). $$)), 0, $length);
    return;
}


###################################################################################################
###################################################################################################


=head1 SEE ALSO

L<Maypole>

=head1 MAINTAINER

Aaron Trevena, c<teejay@droogs.org>

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut


1;
