#!/usr/bin/perl -w
use strict;
use Test::More;
BEGIN {
    if (eval { require Apache::Request }) {
        plan tests => 2;
    } else {
        Test::More->import(skip_all =>"Apache::Request is not installed: $@");
    }
}

require_ok('Apache::MVC');
ok($Apache::MVC::VERSION, 'defines $VERSION');
# defines $VERSION
# uses mod_perl
# @ISA = 'Maypole'
# sets APACHE2 constant
# loads Apache::Request
# loads mod_perl2 modules if APACHE2
# otherwise, loads Apache
# get_request()
# ... sets 'ar' to new Apache::Request object
# parse_location()
# ... sets path() to request URI - base URI
# ... calls parse_path
# ... calls parse_args
# parse_args()
# ... calls _mod_perl_args(), to set params
# ... calls _mod_perl_args(), to set query
# send_output()
# ... sets get_request->content_type to r->content_type
# ... appends document_encoding() if content_type is text
# ... sets Content-Length header
# ... calls get_request->send_http_header unless APACHE2
# ... prints the request output
# get_template_root()
# ... catdir(document_root, location)
# _mod_perl_args()
# ... returns a hash of args from get_request->param
