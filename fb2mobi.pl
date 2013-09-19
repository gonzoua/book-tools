#!/usr/bin/env perl
# Copyright (C) 2009-2013 by Oleksandr Tymoshenko. All rights reserved.

use strict;

use Cwd;

BEGIN {
    use FindBin;
    my $path = $FindBin::Bin;
    $ENV{FB2MOBI_ROOT} = Cwd::realpath(File::Spec->rel2abs($path)) ;
}

use lib  (
    "$ENV{FB2MOBI_ROOT}/lib",
);

use Converter::MOBI;

my %opts;
if (@ARGV  != 2) {
    print "Usage: \n";
    print "    Convert: fb2mobi.pl book.fb2 book.mobi\n";
    exit (0);
}

my $fb2book = $ARGV[0];
my $mobibook = $ARGV[1];
my $c = Converter::MOBI->new();
if (!$c->convert($fb2book, $mobibook)) {
    print "$fb2book: failed\n";
    print "Reason: " . $c->reason() . "\n";
}
else {
    print "$fb2book: converted\n";
}

