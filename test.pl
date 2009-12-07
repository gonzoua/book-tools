#!/usr/bin/env perl
# Copyright (C) 2009 by Oleksandr Tymoshenko. All rights reserved.

use strict;
use EPUB::Container::Zip;
use FB2::Book;

# my $epub = EPUB::Container::Zip->new("test.epub");
# $epub->add_path("t/OPS", "OPS/");
# $epub->add_root_file("OPS/content.opf", "application/oebps-package+xml");
# $epub->write();
my $fb2 = FB2::Book->new();
if ($fb2->load("book2.fb2")) {
    print "Title: " . $fb2->title();
    print "\n";
}
