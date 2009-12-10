#!/usr/bin/env perl
# Copyright (C) 2009 by Oleksandr Tymoshenko. All rights reserved.

use strict;
use EPUB::Container::Zip;
use EPUB::Package;
use FB2::Book;
use XML::Writer;

use XML::LibXSLT;
use XML::LibXML;

my $verbose = 0;

# my $epub = EPUB::Container::Zip->new("test.epub");
# $epub->add_path("t/OPS", "OPS/");
# $epub->add_root_file("OPS/content.opf", "application/oebps-package+xml");
# $epub->write();

my $fb2book = "book3.fb2";
my $epubbook = "book.epub";

my $fb2 = FB2::Book->new();
die "Failed to load $fb2book" unless ($fb2->load($fb2book));


# Create EPUB parts: package/container
my $package = EPUB::Package->new();
my $container = EPUB::Container::Zip->new($epubbook);

if ($verbose) {
    print "FB2 data:\n";
    print "  Title: ", $fb2->title, "\n";
    print "  Authors:\n";
    my @authors = $fb2->authors();
    foreach my $a (@authors) {
        print "    ", $a->to_str(), "\n";
    }
}

$package->set_title($fb2->title);
my @authors = $fb2->authors();
foreach my $a (@authors) {
    $package->add_author($a->to_str());
}

my @binaries = $fb2->all_binaries();
foreach my $b (@binaries) {
    $package->add_image($b->id(), $b->content_type());
}

my @bodies = $fb2->all_bodies();
my $c = 1;

# prepare transformation sheets


my $xslt = XML::LibXSLT->new();

my $style_doc = XML::LibXML->load_xml(location=>'fb2epub.xsl', no_cdata=>1);
my $stylesheet = $xslt->parse_stylesheet($style_doc);

foreach my $body (@bodies) {
    my $name = $body->name();
    my $linear = 'yes';

    if (defined($name) && ($name eq 'notes')) {
        $linear = 'no'
    }
    my @sections = @{$body->sections};
    my $s = 1;
    foreach my $section (@sections) {
        $package->add_xhtml("ch$c-$s.xhtml", $section,
            linear  => $linear,
        );
        $s++;
    }
    $c++;
}

$package->pack_zip("book.epub");
