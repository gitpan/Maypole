package Maypole::Config;
use base qw(Class::Accessor::Fast);
use attributes ();

use strict;
use warnings;

# Public accessors.
__PACKAGE__->mk_accessors(
    qw( view uri_base template_root model loader display_tables ok_tables
      rows_per_page dsn user pass opts application_name document_encoding
      content_type models)
);

# Should only be modified by model.
__PACKAGE__->mk_ro_accessors(
    qw( classes tables table_to_class
      )
);

1;

=head1 NAME

Maypole::Config - Maypole Configuration Class

=head1 DESCRIPTION

This class stores all configuration data for your Maypole application.

=head1 METHODS

=head2 View related

=head3 view

The view class for your Maypole Application. Defaults to "Maypole::View::TT"

=head3 uri_base 

This is the uri base that should be appended to your application when maypole 
makes urls.

=head3 template_root

This is where your application can find it's templates.

=head3 rows_per_page

This is the  number of rows your application should display per page.

=head2 Model-Related

=head3 display_tables 

These are the tables that are public to your maypole application

=head3 ok_tables

These are the tables that maypole should care about

=head3 model

The model class for your Maypole Application. Defaults to "Maypole::View::CDBI"

=head3 loader

This is the loader object. It's set up by the CDBI model if it's not initialized before setup.

=head3 classes

This config variable contains a list of your view classes. This set up by the
model class, and should not be changed in the view or the config.

=head3 dsn
The DSN to your database. Follows standard DBD syntax.

=head3 user

Username to log into the database with

=head3 pass

Password for database user.

=head3 opts

Other options to the dbi connect call.

=head1 SEE ALSO

L<Maypole>

=head1 MAINTAINER

Sebastian Riedel, c<sri@oook.de>

=head1 AUTHOR

Simon Cozens, C<simon@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

