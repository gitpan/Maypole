#!/usr/bin/perl
use strict;
use warnings;
use Test::More tests => 304;
use Test::MockModule;

# module compilation
use Maypole;

# simple test class that inherits from Maypole
{
    package MyDriver;
    @MyDriver::ISA = 'Maypole';
    @MyDriver::VERSION = 1;
}

# back to package main;
my $driver_class = 'MyDriver';

my $r = $driver_class->new;

# make_uri
{
    my @bases = ( '/', '/foo', '/foo/', '', 'http://www.example.com', 
                    'http://www.example.com/', 'http://www.example.com/foo',
                    'http://www.example.com/foo/', );
                    
    my $query = { string => 'baz',
                  number => 4,
                  list   => [ qw/ fee fi fo / ],
                  };
                  
    my $query_string = '?number=4&string=baz&list=fee&list=fi&list=fo';
                    
    my @uris = ( 
                 { expect   =>'',
                   send     => [ '' ],
                   },
                 { expect   => '',
                   send     => [ () ],
                   },
                 { expect   => '/table',
                   send     => [ qw( table ) ],
                   },
                 { expect   => '/table/action',
                   send     => [ qw( table action ) ],
                   },
                 { expect   => '/table/action/id',
                   send     => [ qw( table action id ) ],
                   },
                 
                 
                 { expect   =>'',
                   send     => [ '', $query ],
                   },
                 { expect   => '',
                   send     => [ $query ],
                   },
                 { expect   => '/table',
                   send     => [ qw( table ), $query ],
                   },
                 { expect   => '/table/action',
                   send     => [ qw( table action ), $query ],
                   },
                 { expect   => '/table/action/id',
                   send     => [ qw( table action id ), $query ],
                   },
                 
                 );
                    
    foreach my $base (@bases)
    {
        $driver_class->config->uri_base($base);
        
        (my $base_no_slash = $base) =~ s|/$||;
        my $base_or_slash = $base_no_slash || '/';
        
        my $i = 1; 
        
        foreach my $test (@uris)
        {
            #diag "BASE: $base - URI #$i"; $i++;
        
            my @s      = @{ $test->{send} };
            my $expect = $test->{expect};
        
            my $uri = $r->make_uri(@s);
            
            like("$uri", qr/^\Q$base_or_slash\E/, 
                "'$uri' starts with '$base_or_slash'");
            
            my $q = ref $s[-1] ? $query_string : '';
                        
            my $msg = 
                sprintf "'%s' is '%s%s%s': base - '%s' segments - '%s'", 
                        $uri, $base_no_slash, $expect, $q, $base, 
                            @s ? join(', ', @s) : '()';
                            
            my $reconstructed = $expect =~ m|^/| ? "$base_no_slash$expect$q" :
                                                   "$base_or_slash$expect$q";
                                                   
            cmp_ok("$uri", 'eq', "$reconstructed" || '/', $msg);
        }
    }
}

# make_path
{
    my @bases = ( '/', '/foo', '/foo/', '', 'http://www.example.com', 
                    'http://www.example.com/', 'http://www.example.com/foo',
                    'http://www.example.com/foo/', );
                    
    my $query = { string => 'baz',
                  number => 4,
                  list   => [ qw/ fee fi fo / ],
                  };
                  
    my $query_string = '?number=4&string=baz&list=fee&list=fi&list=fo';
                    
                 # expect       # send
    my @uris = ( 
                 { expect   => '/table/action',
                   send     => [ qw( table action ) ],
                   },
                 { expect   => '/table/action/id',
                   send     => [ qw( table action id ) ],
                   },
                 
                 
                 { expect   => '/table/action',
                   send     => [ qw( table action ), $query ],
                   },
                 );
                    
    foreach my $base (@bases)
    {
        $driver_class->config->uri_base($base);
        
        (my $base_no_slash = $base) =~ s|/$||;
        my $base_or_slash = $base_no_slash || '/';
        
        my $i = 1; 
        
        foreach my $test (@uris)
        {
            #diag "BASE: $base - URI #$i"; $i++;
        
            my @args = @{ $test->{send} };
            
            my %args = ( table  => $args[0],
                         action => $args[1],
                         additional => $args[2],
                         );
                         
            my %arg_sets = ( array => \@args, 
                             hash  => \%args, 
                             hashref => \%args,
                             );
            
            my $expect = $test->{expect};
            my @s      = @{ $test->{send} };
        
            foreach my $set (keys %arg_sets)
            {
            
                my $path;
                $path = $r->make_path(@{ $arg_sets{$set} }) if $set eq 'array';
                $path = $r->make_path(%{ $arg_sets{$set} }) if $set eq 'hash';
                $path = $r->make_path($arg_sets{$set})   if $set eq 'hashref';
            
                like($path, qr/^\Q$base_or_slash\E/, 
                    "'$path' starts with '$base_or_slash'");
                
                my $q = ref $s[-1] ? $query_string : '';
                            
                my $msg = 
                    sprintf "'%s' is '%s%s%s': base - '%s' segments - '%s'", 
                            $path, $base_no_slash, $expect, $q, $base, 
                                @s ? join(', ', @s) : '()';
                                
                my $reconstructed = $expect =~ m|^/| 
                    ? "$base_no_slash$expect$q" :
                      "$base_or_slash$expect$q";
                                                    
                cmp_ok($path, 'eq', "$reconstructed" || '/', $msg);
            }
        }
    }
}

