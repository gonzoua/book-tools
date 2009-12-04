#!/usr/bin/perl -w
# Copyright (C) 2009 by Oleksandr Tymoshenko. All rights reserved.

use strict;
use EPUB::Container::Zip;

my $epub = EPUB::Container::Zip->new("test.epub");
$epub->addPath("t/OPS", "OPS/");
$epub->addRootFile("OPS/content.opf", "application/oebps-package+xml");
$epub->write();
