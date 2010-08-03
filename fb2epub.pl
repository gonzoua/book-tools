#!/usr/bin/env perl
# Copyright (C) 2009, 2010 by Oleksandr Tymoshenko. All rights reserved.

use strict;
# use lib qw@ /Users/gonzo/Projects/EBook-FB2/blib/lib /Users/gonzo/Projects/EBook-EPUB/blib/lib /Users/gonzo/Projects/book-tools @;

use EBook::EPUB;
use EBook::FB2;
use XML::Writer;
use XML::DOM;
use Archive::Zip qw/:ERROR_CODES :CONSTANTS/;
use File::Temp qw/tempdir :mktemp/;
use File::Spec;
use List::MoreUtils qw(uniq);
use Cwd;

BEGIN {
    $ENV{FB2EPUB_ROOT} = Cwd::realpath(File::Spec->rel2abs($FindBin::Bin)) ;
}

use lib  (
    "$ENV{FB2EPUB_ROOT}/lib",
);

use Utils::XHTMLFile;
use Utils::ChapterManager;
use Utils::Fonts;
use Data::UUID;
use Font::Subsetter;
use Converter;

if ((@ARGV < 2) || (@ARGV > 3)) {
    print "Usage: fb2epub.pl book.fb2 book.epub [fontfamily]\n";
    exit (0);
}

my $fb2book = $ARGV[0];
my $epubbook = $ARGV[1];
my $font_family = $ARGV[2] if (@ARGV > 2);
my $c = Converter->new(encrypt_fonts => 0);
my ($code, $msg) = $c->convert($fb2book, $epubbook, $font_family);
