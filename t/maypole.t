#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 108;
use Test::MockModule;

# module compilation
require_ok('Maypole');
my $OK       = Maypole::Constants::OK();
my $DECLINED = Maypole::Constants::DECLINED();
my $ERROR    = Maypole::Constants::ERROR();

ok($Maypole::VERSION, 'defines $VERSION');
ok($INC{'Maypole/Config.pm'}, 'loads Maypole::Config');
ok($INC{'UNIVERSAL/require.pm'}, 'loads UNIVERSAL::require');
ok($INC{'Maypole/Constants.pm'}, 'loads Maypole::Constants');
ok($INC{'Maypole/Headers.pm'}, 'loads Maypole::Headers');
ok($INC{'Class/Accessor/Fast.pm'}, 'loads Class::Accessor::Fast');
ok($INC{'Class/Data/Inheritable.pm'}, 'loads Class::Data::Inheritable');
ok(Maypole->can('config'), 'defines a config attribute');
ok(Maypole->config->isa('Maypole::Config'), 'config is a Maypole::Config object');
ok(Maypole->can('init_done'), 'defines an init_done attribute');
ok(! Maypole->init_done, '... which is false by default');
ok(Maypole->can('view_object'), 'defines a view_object attribute');
is(Maypole->view_object, undef, '... which is undefined');
ok(Maypole->can('ar'), 'defines an "ar" accessor');
ok(Maypole->can('params'), 'defines a "params" accessor');
ok(Maypole->can('query'), 'defines a "query" accessor');
ok(Maypole->can('objects'), 'defines an "objects" accessor');
ok(Maypole->can('model_class'), 'defines a "model_class" accessor');
ok(Maypole->can('template_args'), 'defines a "template_args" accessor');
ok(Maypole->can('output'), 'defines an "output" accessor');
ok(Maypole->can('path'), 'defines a "path" accessor');
ok(Maypole->can('args'), 'defines an "args" accessor');
ok(Maypole->can('action'), 'defines an "action" accessor');
ok(Maypole->can('template'), 'defines a "template" accessor');
ok(Maypole->can('error'), 'defines an "error" accessor');
ok(Maypole->can('document_encoding'), 'defines a "document_encoding" accessor');
ok(Maypole->can('content_type'), 'defines a "content_type" accessor');
ok(Maypole->can('table'), 'defines a "table" accessor');
ok(Maypole->can('headers_in'), 'defines a "headers_in" accessor');
ok(Maypole->can('headers_out'), 'defines a "headers_out" accessor');

# simple test class that inherits from Maypole
package MyDriver;
@MyDriver::ISA = 'Maypole';
@MyDriver::VERSION = 1;
package main;
my $driver_class = 'MyDriver';

# Mock the model class
my (%required, @db_args, @adopted);
my $model_class = 'Maypole::Model::CDBI';
my $table_class = $driver_class . '::One';
my $mock_model = Test::MockModule->new($model_class);
$mock_model->mock(
    require        => sub {$required{+shift} = 1},
    setup_database => sub {
        push @db_args, \@_;
        $_[1]->{classes} = ["$model_class\::One", "$model_class\::Two"];
        $_[1]->{tables}  = [qw(one two)];
    },
    adopt          => sub {push @adopted, \@_},
);

# setup()
can_ok($driver_class => 'setup');
my $handler = $driver_class->can('handler');
is($handler, Maypole->can('handler'), 'calling package inherits handler()');
$driver_class->setup('dbi:foo'); # call setup()
isnt($handler, $driver_class->can('handler'), 'setup() installs new handler()');
ok($required{$model_class}, '... requires model class');
is($driver_class->config->model(),
   'Maypole::Model::CDBI', '... default model is CDBI');
is(@db_args, 1, '... calls model->setup_database');
like(join (' ', @{$db_args[0]}),
     qr/$model_class Maypole::Config=\S* $driver_class dbi:foo/,
     '... setup_database passed setup() args');
is(@adopted, 2, '... calls model->adopt foreach class in the model');
ok($adopted[0][0]->isa($model_class),
   '... sets up model subclasses to inherit from model');
$driver_class->config->model('NonExistant::Model');
eval {$driver_class->setup};
like($@, qr/Couldn't load the model class/,
     '... dies if unable to load model class');
$@ = undef; $driver_class->config->model($model_class);

# Mock the view class
my $view_class = 'Maypole::View::TT';
my $mock_view = Test::MockModule->new($view_class);
$mock_view->mock(
    new     => sub {bless{}, shift},
    require => sub {$required{+shift} = 1},
);

# init()
can_ok($driver_class => 'init');
$driver_class->init();
ok($required{$view_class}, '... requires the view class');
is($driver_class->config->view, $view_class, '... the default view class is TT');
is(join(' ', @{$driver_class->config->display_tables}), 'one two',
   '... config->display_tables defaults to all tables');
ok($driver_class->view_object->isa($view_class),
   '... creates an instance of the view object');
ok($driver_class->init_done, '... sets init_done');
$driver_class->config->view('NonExistant::View');
eval {$driver_class->init};
like($@, qr/Couldn't load the view class/,
     '... dies if unable to load view class');
$@ = undef; $driver_class->config->view($view_class);


my ($r, $req); # request objects
{
    no strict 'refs';
    my $init = 0;
    my $status = 0;
    my %called;
    my $mock_driver = Test::MockModule->new($driver_class, no_auto => 1);
    $mock_driver->mock(
        init           => sub {$init++; shift->init_done(1)},
        get_request    => sub {($r, $req) = @_; $called{get_request}++},
        parse_location => sub {$called{parse_location}++},
        handler_guts   => sub {$called{handler_guts}++; $status},
        send_output    => sub {$called{send_output}++},
    );

    # handler()
    can_ok($driver_class => 'handler');
    my $rv = $driver_class->handler();
    ok($r && $r->isa($driver_class), '... created $r');
    ok($called{get_request}, '... calls get_request()');
    ok($called{parse_location}, '... calls parse_location');
    ok($called{handler_guts}, '... calls handler_guts()');
    ok($called{send_output}, '... call send_output');
    is($rv, 0, '... return status (should be ok?)');
    ok(!$init, "... doesn't call init() if init_done()");
    ok($r->headers_out && $r->headers_out->isa('Maypole::Headers'),
       '... populates headers_out() with a Maypole::Headers object');
    # call again, testing other branches
    $driver_class->init_done(0);
    $status = -1;
    $rv = $driver_class->handler();
    ok($called{handler_guts} == 2 && $called{send_output} == 1,
       '... returns early if handler_guts failed');
    is($rv, -1, '... returning the error code from handler_guts');
    $driver_class->handler();
    ok($init && $driver_class->init_done, "... init() called if !init_done()");
}

{
    # handler_guts()
    {
        no strict 'refs';
        @{$table_class . "::ISA"} = $model_class;
    }

    my ($applicable, %called, $status);
    my $mock_driver = new Test::MockModule($driver_class, no_auto => 1);
    my $mock_table  = new Test::MockModule($table_class, no_auto => 1);
    $mock_driver->mock(
        is_applicable   => sub {push @{$called{applicable}},\@_; $applicable},
        get_request     => sub {($r, $req) = @_},
        additional_data => sub {$called{additional_data}++},
    );
    $mock_table->mock(
        table_process   => sub {push @{$called{process}},\@_},
    );
    $mock_model->mock(
        class_of        => sub {push @{$called{class_of}},\@_; $table_class},
        process         => sub {push @{$called{model_process}}, \@_},
    );
    $mock_view->mock(
        process         => sub {push @{$called{view_process}}, \@_; $OK}
    );
    can_ok(Maypole => 'handler_guts');

    $applicable = $OK;
    $r->{path} = '/table/action';    $r->parse_path;
    $status = $r->handler_guts();

    is($r->model_class, $table_class, '... sets model_class from table()');
    ok($called{additional_data}, '... call additional_data()');
    is($status, $OK, '... return status = OK');
    ok($called{model_process},
       '... if_applicable, call model_class->process');

    %called = ();
    $applicable = $DECLINED;
    $r->{path} = '/table/action';
    $r->parse_path;
    $status = $r->handler_guts();
    is($r->template, $r->path,
       '... if ! is_applicable set template() to path()');
    ok(!$called{model_process},
       '... !if_applicable, call model_class->process');
    is_deeply($called{view_process}[0][1], $r,
              ' ... view_object->process called');
    is($status, $OK, '... return status = OK');

    %called = ();
    $r->parse_path;
    $r->{output} = 'test';
    $status = $r->handler_guts();
    ok(!$called{view_process},
       '... unless output, call view_object->process to get output');

    $mock_driver->mock(call_authenticate => sub {$DECLINED});
    $status = $r->handler_guts();
    is($status, $DECLINED,
       '... return DECLINED unless call_authenticate == OK');

    # ... TODO authentication error handling
    # ... TODO model error handling
    # ... TODO view processing error handling
}

# is_applicable()
can_ok(Maypole => 'is_applicable');
$r->config->display_tables([qw(one two)]);
$r->config->ok_tables(undef);
$r->model_class($table_class);
$r->table('one');
$r->action('unittest');
my $is_public;
$mock_model->mock('is_public', sub {0});
my $status = $r->is_applicable;
is($status, $DECLINED,
   '... return DECLINED unless model_class->is_public(action)');
$mock_model->mock('is_public', sub {$is_public = \@_; 1});
$status = $r->is_applicable;
is($status, $OK, '... returns OK if table is in ok_tables');
is_deeply($is_public, [$r->model_class, 'unittest'],
          '... calls model_class->is_public with request action');
is_deeply($r->config->ok_tables, {one => 1, two => 1},
          '... config->ok_tables defaults to config->display_tables');
delete $r->config->ok_tables->{one};
$status = $r->is_applicable;
is($status, $DECLINED, '... return DECLINED unless $r->table is in ok_tables');

# call_authenticate()
can_ok(Maypole => 'call_authenticate');
my $mock_driver = new Test::MockModule($driver_class, no_auto => 1);
my $mock_table  = new Test::MockModule($table_class, no_auto => 1);
my %auth_calls;
$mock_table->mock(
    authenticate => sub {$auth_calls{model_auth} = \@_; $OK}
);
$status = $r->call_authenticate;
is_deeply($auth_calls{model_auth}, [$table_class, $r],
          '... calls model_class->authenticate if it exists');
is($status, $OK, '... and returns its status (OK)');
$mock_table->mock(authenticate => sub {$DECLINED});
$status = $r->call_authenticate;
is($status, $DECLINED, '... or DECLINED, as appropriate');

$mock_table->unmock('authenticate');
$mock_driver->mock(authenticate => sub {return $DECLINED});
$status = $r->call_authenticate;
is($status, $DECLINED, '... otherwise it calls authenticte()');
$mock_driver->unmock('authenticate');
$status = $r->call_authenticate;
is($status, $OK, '... the default authenticate is OK');

# call_exception()
can_ok(Maypole => 'call_exception');
my %ex_calls;
$mock_table->mock(
    exception => sub {$ex_calls{model_exception} = \@_; $OK}
);
$mock_driver->mock(
    exception => sub {$ex_calls{driver_exception} = \@_; 'X'}
);
$status = $r->call_exception('ERR');
is_deeply($ex_calls{model_exception}, [$table_class, $r, 'ERR'],
          '... calls model_class->exception if it exists');
is($status, $OK, '... and returns its status (OK)');
$mock_table->mock(exception => sub {$DECLINED});
$status = $r->call_exception('ERR');
is_deeply($ex_calls{driver_exception}, [$r, 'ERR'],
          '... or calls driver->exception if model returns !OK');
is($status, 'X', '... and returns the drivers status');

$mock_table->unmock('exception');
$mock_driver->unmock('exception');
$status = $r->call_exception('ERR');
is($status, $ERROR, '... the default exception is ERROR');

# additional_data()
can_ok(Maypole => 'additional_data');

# authenticate()
can_ok(Maypole => 'authenticate');
is(Maypole->authenticate(), $OK, '... returns OK');

# exception()
can_ok(Maypole => 'exception');
is(Maypole->exception(), $ERROR, '... returns ERROR');

# parse_path()
can_ok(Maypole => 'parse_path');
$r->path(undef);
$r->parse_path;
is($r->path, 'frontpage', '... path() defaults to "frontpage"');

$r->path('/table');
$r->parse_path;
is($r->table, 'table', '... parses "table" from the first part of path');
ok(@{$r->args} == 0, '... "args" default to empty list');

$r->path('/table/action');
$r->parse_path;
ok($r->table eq 'table' && $r->action eq 'action',
   '... action is parsed from second part of path');

$r->path('/table/action/arg1/arg2');
$r->parse_path;
is_deeply($r->args, [qw(arg1 arg2)],
   '... "args" are populated from remaning components');

# ... action defaults to index
$r->path('/table');
$r->parse_path;
is($r->action, 'index', '... action defaults to index');

# get_template_root()
can_ok(Maypole => 'get_template_root');
is(Maypole->get_template_root(), '.', '... returns "."');

# get_request()
can_ok(Maypole => 'get_request');

# parse_location()
can_ok(Maypole => 'parse_location');
eval {Maypole->parse_location()};
like($@, qr/Do not use Maypole directly/, '... croaks - must be overriden');

# send_output()
can_ok(Maypole=> 'send_output');
eval {Maypole->send_output};
like($@, qr/Do not use Maypole directly/, '... croaks - must be overriden');
