#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'POEx::Role::TCPServer' );

}

diag( "Testing POEx::Role::TCPServer $POEx::Role::TCPServer::VERSION, Perl $], $^X" );
