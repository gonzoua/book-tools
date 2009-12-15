#!/usr/bin/env perl
# Copyright (C) 2009 by Oleksandr Tymoshenko. All rights reserved.

use strict;

use EPUB::Package;
use FB2::Book;
use XML::Writer;
use XML::DOM;

my $verbose = 0;

# my $epub = EPUB::Container::Zip->new("test.epub");
# $epub->add_path("t/OPS", "OPS/");
# $epub->add_root_file("OPS/content.opf", "application/oebps-package+xml");
# $epub->write();

my %ids_map;
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
$package->set_identifier('1234');
$package->add_language($fb2->lang());

my @authors = $fb2->authors();
foreach my $a (@authors) {
    $package->add_author($a->to_str());
}

my @binaries = $fb2->all_binaries();
my $img_c = 0;
foreach my $b (@binaries) {
    my $ctype = $b->content_type();
    my $ext = 'gif';
    if ($ctype =~/jpeg/) {
        $ext = 'jpg';
    }
    elsif ($ctype =~/png/) {
        $ext = 'png';
    }
    elsif ($ctype =~/gif/) {
        $ext = 'gif';
    }
    elsif ($ctype =~/svg/) {
        $ext = 'svg';
    }
    my $img_name = sprintf("img%04d", $img_c);
    $img_c ++;
    $img_name .= ".$ext";
    $package->add_image($img_name, $b->data(), $b->content_type());
    $ids_map{$b->id()} = $img_name;
}

my @bodies = $fb2->all_bodies();

my $chapter = 1;
my $play_order = 1;
# Create map between <section> element and files, collect xlink ids
# and transform them to cross-document form
foreach my $body (@bodies) {
    my $name = $body->name();
    my @sections = @{$body->sections};
    my $s = 1;
    foreach my $section (@sections) {
        my $filename = "ch$chapter-$s.xhtml";
        my @ids = collect_ids($section->data);
        foreach my $id (@ids) {
            $ids_map{$id} = $filename;
        }
        $s++;
    }
    $chapter++;
}


$chapter = 1;
foreach my $body (@bodies) {
    my $name = $body->name();
    my $linear = 'yes';

    if (defined($name) && ($name eq 'notes')) {
        $linear = 'no'
    }
    my @sections = @{$body->sections};
    my $s = 1;
    foreach my $section (@sections) {
        my $filename = "ch$chapter-$s.xhtml";
        my $xhtml = create_chapter($section);
        $package->add_xhtml($filename, $xhtml,
            linear  => $linear,
        );
        $package->add_navpoint(
            label       => "Chapter $chapter/$s",
            id          => "np-$chapter-$s",
            content     => $filename,
            play_order  => $play_order,
        );
        $s++;
        $play_order++;
    }
    $chapter++;
}
$package->copy_stylesheet("style.css", "style.css");
$package->copy_file("fonts/CharisSILB.ttf", "CharisSILB.ttf", "application/x-font-ttf");
$package->copy_file("fonts/CharisSILBI.ttf", "CharisSILBI.ttf", "application/x-font-ttf");
$package->copy_file("fonts/CharisSILI.ttf", "CharisSILI.ttf", "application/x-font-ttf");
$package->copy_file("fonts/CharisSILR.ttf", "CharisSILR.ttf", "application/x-font-ttf");
$package->pack_zip("book.epub");

#
# Helper functions
#

sub create_chapter 
{
    my $section = shift;
    my $section_xhtml = "";
    my $writer = new XML::Writer(OUTPUT => \$section_xhtml);
    my $xhtml =<<__EOHEAD__;
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title/>
<link rel="stylesheet" href="style.css" type="text/css"/>
</head>
__EOHEAD__
    $writer->startTag('body');
    transform_section($section, $writer);
    $writer->endTag('body');
    $writer->end();
    $xhtml .= $section_xhtml;
    $xhtml .= "</html>";
    return $xhtml;
}

sub transform_section 
{
    my ($section, $writer) = @_;

    if (@{$section->subsections}) {
        foreach my $s (@{$section->subsections}) {
            transform_section($s, $writer);
        }
    }
    else {
        to_xhtml($section->data(), $writer);
    }

}

sub to_xhtml
{
    my ($node, $writer) = @_;
    my $type = $node->getNodeType;
    if ($type == ELEMENT_NODE) {
        my $tag = lc ($node->getTagName);
        my @args = ();
        my $id = $node->getAttribute('id');
        if ($id ne '') {
            push @args, 'id', $id;
        }

        if ($tag eq 'section') {
            push @args, 'class', $tag;
            $writer->startTag('div', @args);
        }
        elsif (grep {$tag eq $_} 
            qw(p cite annotation epigraph empty-line text-author poem stanza code title v subtitle)) {
            push @args, 'class', $tag;
            $writer->startTag('p', @args);
        }
        elsif ($tag eq 'a') {
            my $args = $node->getAttributes;
            my $href;

            my $i = 0;
            while ($i < $args->getLength) {
                my $item = $args->item($i);
                if ($item->getName =~ /:href/) {
                    $href = $item->getValue;
                    last;
                }
                $i++;
            }

            if (defined($href)) {
                $href =~ s/^#//;
                # get file for this id
                my $file = $ids_map{$href};
                if (defined($file)) {
                    push @args, "href", "$file#$href";
                }
                print "$href -> $file#$href\n";
            }

            $writer->startTag($tag, @args);
        }
        else {
            #leave tags as is with all attributes
            @args = ();
            foreach my $arg ($node->getAttributes) {
            }
            $writer->startTag($tag, @args);
        }

        foreach my $kid ($node->getChildNodes) {
            to_xhtml($kid, $writer);
        }

        $writer->endTag();
    }
    elsif ($type == TEXT_NODE) {
        $writer->characters($node->getData());
    }
    else
    {
        print "Unknown: $type!\n"
    }
}

#
# For some reason XPath expression *[@id] does not work
# so we make it with old school recursion
#
sub collect_ids
{
    my $node = shift;
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    push @result, $id if ($id ne '');

    # do the same for children
    foreach my $kid ($node->getChildNodes) {
        next if ($kid->getNodeType() != ELEMENT_NODE);
        my @kid_ids = collect_ids($kid);
        push @result, @kid_ids;
    }

    return @result;
}
