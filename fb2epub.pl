#!/usr/bin/env perl
# Copyright (C) 2009-2013 by Oleksandr Tymoshenko. All rights reserved.

use strict;

use Cwd;
use Getopt::Std;

BEGIN {
    use FindBin;
    my $path = $FindBin::Bin;
    $ENV{FB2EPUB_ROOT} = Cwd::realpath(File::Spec->rel2abs($path)) ;
}

use lib  (
    "$ENV{FB2EPUB_ROOT}/lib",
);

use Utils::Fonts;
use Converter::EPUB;

my %opts;
getopts('ef:l', \%opts); 

if ($opts{'l'}) {
	my @fonts = Utils::Fonts::valid_fonts();
	print "Fonts:\n";
	foreach my $f (@fonts) {
		$f =~ s/([\^ ])(\w)/\1\U\2/g;
		print "  " . ucfirst($f) . "\n";
	}
	exit (0);
}

if (@ARGV  != 2) {
    print "Usage: \n";
    print "    List fonts: fb2epub.pl -l\n";
    print "    Convert: fb2epub.pl [-e -f font] book.fb2 book.epub\n";
    print "        -e\t\tencrypt embedded fonts\n";
    print "        -f font\t\tembed specified font\n";
    exit (0);
}

my $fb2book = $ARGV[0];
my $epubbook = $ARGV[1];
my $font_family = $opts{'f'};
my $c = Converter::EPUB->new(encrypt_fonts => $opts{'e'});
if (!$c->convert($fb2book, $epubbook, $font_family)) {
    print "$fb2book: failed\n";
    print "Reason: " . $c->reason() . "\n";
}
else {
    print "$fb2book: converted\n";
}

