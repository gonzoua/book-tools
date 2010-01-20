#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'FB2' ) || print "Bail out!
";
}

diag( "Testing FB2 $FB2::VERSION, Perl $], $^X" );
