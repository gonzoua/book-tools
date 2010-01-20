#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'EPUB' ) || print "Bail out!
";
}

diag( "Testing EPUB $EPUB::VERSION, Perl $], $^X" );
