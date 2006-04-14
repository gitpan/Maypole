package Maypole::Config;
use base qw(Class::Accessor::Fast);
use attributes ();

use strict;
use warnings;

our $VERSION = "1." . sprintf "%04d", q$Rev: 334 $ =~ /: (\d+)/;

# Public accessors.
__PACKAGE__->mk_accessors(
     qw( view view_options uri_base template_root template_extension model
         loader display_tables ok_tables rows_per_page dsn user pass opts
         application_name)
);

# Should only be modified by model.
__PACKAGE__->mk_ro_accessors(qw( classes tables));

1;

=head1 NAME

Maypole::Config - Maypole Configuration Class

=head1 DESCRIPTION

This class stores all configuration data for your Maypole application.

=head1 METHODS

=head2 View related

=head3 application_name

This should be a string containing your application's name.

Optional. Is used in the factory templates.

=head3 rows_per_page

This is the number of rows your application should display per page.

Optional.

=head3 tables

Contains a list of all tables, if supported by model.

=head3 template_extension

Optional template file extension.

=head3 template_root

This is where your application can find its templates.

=head3 uri_base

This is the URI base that should be prepended to your application when Maypole
makes URLs.

=head3 view

The name of the view class for your Maypole Application. Defaults to
"Maypole::View::TT".

=head3 view_options

A hash of configuration options for the view class. Consult the documentation
for your chosen view class for information on available configuration options.

=head2 Model-Related

=head3 classes

This config variable contains a list of your view classes. This is set
up by the
model class, and should not be changed in the view or the config.

=head3 display_tables

This is a list of the tables that are public to your Maypole 
application. Defaults to all the tables in the database.

=head3 dsn

The DSN to your database. Follows standard DBD syntax.

=head3 loader

This is the loader object (n.b. an instance, not a class name). It's set
up by the CDBI model to an instance of "Class::DBI::Loader" if it's not
initialized before calling setup().

=head3 model

The name of the model class for your Maypole Application. Defaults to
"Maypole::Model::CDBI".

=head3 ok_tables

This is a hash of the public tables. It is populated automatically by 
Maypole from the list in display_tables and should not be changed.

=head3 pass

Password for database user.

=head3 opts

Other options to the DBI connect call.

=head3 user

Username to log into the database with.

=head2 Adding additional configuration data

If your modules need to store additional configuration data for their 
own use or to make available to templates, add a line like this to your 
module:

   Maypole::Config->mk_accessors(qw(variable or variables));

Care is needed to avoid conflicting variable names.

=head1 SEE ALSO

L<Maypole>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>

=head1 AUTHOR EMERITUS

Simon Cozens, C<simon@cpan.org>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

