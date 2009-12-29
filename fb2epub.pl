#!/usr/bin/env perl
# Copyright (C) 2009 by Oleksandr Tymoshenko. All rights reserved.

use strict;

use EPUB::Package;
use FB2::Book;
use XML::Writer;
use XML::DOM;
use File::Temp qw/tempdir/;

use Utils::XHTMLFile;
use Utils::ChapterManager;

my $verbose = 0;

# Maps xlink id to filename in resulting ePUB
my %ids_map;
# maps fb2 image id to filename in resulting ePUB
my %img_ids_map;
# maps section/body to respecive filename
my %filename_map;

my $fb2book = "example.fb2";
my $epubbook = "book.epub";
my $has_notes;

my $fb2 = FB2::Book->new();
die "Failed to load $fb2book" unless ($fb2->load($fb2book));

# Create helper objects
my $tmp_dir = tempdir( CLEANUP => 1 );
my $chapter_manager = Utils::ChapterManager->new(tmp_dir => $tmp_dir);

# Create EPUB parts: package/container
my $package = EPUB::Package->new();

#
# Set author/title/ID/language
#
$package->set_title($fb2->title);
my @authors = $fb2->authors();
foreach my $a (@authors) {
    $package->add_author($a->to_str());
}
$package->add_language($fb2->lang());
# XXX: FixMe
$package->set_identifier('1234');

# Add all images to EPUB package
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
    $img_ids_map{$b->id()} = $img_name;
}

my @bodies = $fb2->all_bodies();
my $play_order = 1;

# Create pages with cover images
foreach my $img_id ($fb2->coverpages) {
    my $xhtml_file = $chapter_manager->current_chapter_file;
    $xhtml_file->open;
    my $writer = $xhtml_file->writer;
    my $xhtml = write_cover_xhtml($img_id, $writer);
    $xhtml_file->close;
    
    $chapter_manager->next_file;
}

#  
# Map each section/body to it's own file
# Skip "notes" bodies
#
foreach my $body (@bodies) {
    my $name = lc($body->name());
    next if ($name eq 'notes');

    # Page for body with image/title/epiraph
    $filename_map{$body} = $chapter_manager->current_chapter_file;
    $chapter_manager->next_file;

    my @sections = @{$body->sections};
    foreach my $section (@sections) {
        build_chapters_map($section);
    }
}

# Collect elements with "id" attributes and map them
# to respective filenames
foreach my $body (@bodies) {
    my $name = lc($body->name());
    next if ($name eq 'notes');

    my @sections = @{$body->sections};
    foreach my $section (@sections) {
        build_ids_map($section);
    }
}

# Now map all ids in notes to notes.xhtml file 
foreach my $body (@bodies) {
    my $name = lc($body->name());
    next if (!defined($name) || ($name ne 'notes'));

    $has_notes = 1;
    my @sections = @{$body->sections};
    foreach my $section (@sections) {
        map_all_ids($section, 'notes.xhtml');
    }
}

# write all files 
foreach my $body (@bodies) {
    my $name = $body->name();

    next if(defined($name) && ($name eq 'notes'));
    
    # Write page with image/title/epigraph
    my $xhtml_file = $filename_map{$body};

    $xhtml_file->open;
    my $writer = $xhtml_file->writer;
    write_body_cover_xhtml($body, $writer);
    $xhtml_file->close;

    my @sections = @{$body->sections};
    foreach my $section (@sections) {
        transform_sections($section, \&write_section_file, 1);
    }
}

# write notes 
if ($has_notes) {
    my $xhtml_file = Utils::XHTMLFile->new(path => "$tmp_dir/notes.xhtml");
    $xhtml_file->open;
    my $writer = $xhtml_file->writer;
    $writer->startTag('body');
    foreach my $body (@bodies) {
        my $name = lc($body->name());
        next unless($name eq 'notes');

        my @sections = @{$body->sections};
        foreach my $section (@sections) {
            write_section($section, $writer);
        }
    }
    $writer->endTag('body');
    $xhtml_file->close();
}

# Create navigation points. Do our best
foreach my $body (@bodies) {
    my $name = $body->name();
    next if (defined($name) && ($name eq 'notes'));
    my @sections = @{$body->sections};

    foreach my $section (@sections) {
        my $chapter_file = $filename_map{$section};
        my $filename = $chapter_file->filename;

        my $section_title = $section->plaintext_title;
        my $nav_point;
        if (defined($section_title)) {
            $nav_point = $package->add_navpoint(
                label       => $section_title,
                id          => $section->id,
                content     => "$filename#" . $section->id,
                play_order  => $play_order,
            );
            add_subsection_navigation($section, $nav_point);
            $play_order++;
        }
    }
}

# Add CSS and fonts
$package->copy_stylesheet("style.css", "style.css");
$package->copy_file("fonts/CharisSILB.ttf", "CharisSILB.ttf", "application/x-font-ttf");
$package->copy_file("fonts/CharisSILBI.ttf", "CharisSILBI.ttf", "application/x-font-ttf");
$package->copy_file("fonts/CharisSILI.ttf", "CharisSILI.ttf", "application/x-font-ttf");
$package->copy_file("fonts/CharisSILR.ttf", "CharisSILR.ttf", "application/x-font-ttf");

# add book content
foreach my $chapter (@{$chapter_manager->chapter_files}) {
    # Close opened file
    if ($chapter->opened) {
        $chapter->writer->endTag('body');
        $chapter->close;
    }
    $package->copy_xhtml($chapter->path, $chapter->filename);
}

# Add notes file
$package->copy_xhtml("$tmp_dir/notes.xhtml", "notes.xhtml",
    linear => 'no'
);

$package->pack_zip($epubbook);

# Exit here
exit(0);

#
# Helper functions
#

sub xhtml_prologue
{
    my $writer = shift;
    $writer->xmlDecl("UTF-8");
    $writer->startTag("html", "xmlns" => "http://www.w3.org/1999/xhtml");
    $writer->startTag("head");
    $writer->emptyTag("title");
    $writer->emptyTag("link",
        rel     => "stylesheet",
        href    => "style.css",
        type    => "text/css",
    );
    $writer->endTag("head");
}

sub write_body_cover_xhtml
{
    my ($body, $writer) = @_;
    $writer->startTag('body', class => 'cover');
    $writer->startTag('center');

    my $img_id = $body->image;
    if (defined($img_id) && defined($img_ids_map{$img_id})) {
        $writer->emptyTag('img', 'src' => $img_ids_map{$img_id});
    }

    if (defined($body->title)) {
        $writer->startTag('div', class => "title1");
        foreach my $kid ($body->title->getChildNodes) {
            to_xhtml($kid, $writer, 'title');
        }
        $writer->endTag('div', class => "title1");
    }

    foreach my $e (@{$body->epigraphs}) {
        to_xhtml($e, $writer);
    }

    $writer->endTag('center');
    $writer->endTag('body');
}

sub write_cover_xhtml
{
    my ($img_id, $writer) = @_;
    $writer->startTag('body');
    $writer->startTag('center');
    if (defined($img_ids_map{$img_id})) {
        $writer->emptyTag('img', 'src' => $img_ids_map{$img_id});
    }
    $writer->endTag('center');
    $writer->endTag('body');
}

sub transform_sections
{
    my ($section, $transform_sub, $level) = @_;

    $transform_sub->($section, $level);

    if (@{$section->subsections}) {
        foreach my $s (@{$section->subsections}) {
            transform_sections($s, $transform_sub, $level + 1);
        }
    }
}

sub write_section
{
    my ($section, $writer, $level) = @_;

    $level = 1 unless(defined($level));
    $level = 6 if($level > 6);
    # Assume that section always has id
    $writer->startTag('div', 
        class   => 'section',
        id      => $section->id()
    );

    # Write image
    if ($section->image) {
        to_xhtml($section->image, $writer);
    }

    # write title
    if ($section->title) {
        $writer->startTag('div', class => "title$level");
        foreach my $kid ($section->title->getChildNodes) {
            to_xhtml($kid, $writer, 'title');
        }
        $writer->endTag('div');
    }

    # write epigraphs
    foreach my $e (@{$section->epigraphs}) {
        to_xhtml($e, $writer);
    }

    # if there are no subsections, just convert content to xhtml
    if (@{$section->subsections} == 0) {
        to_xhtml($section->data(), $writer);
    }

    $writer->endTag('div');
}

sub write_section_file
{
    my ($section, $level) = @_;
    my $xhtml_file = $filename_map{$section};

    my $writer;
    if (!$xhtml_file->opened) {
        $xhtml_file->open;
        $writer = $xhtml_file->writer;
        $writer->startTag('body');
    }
    else {
        $writer = $xhtml_file->writer;
    }

    write_section($section, $writer, $level);
}

sub to_classed_element 
{
    my ($node, $writer, $element_name, $context_prefix) = @_;
    my $tag = lc ($node->getTagName);
    my $id = $node->getAttribute('id');
    my @args;

    if ($id ne '') {
        push @args, 'id', $id;
    }

    $tag = "$context_prefix-$tag" if (defined($context_prefix));

    push @args, 'class', $tag;

    $writer->startTag($element_name, @args);
    foreach my $kid ($node->getChildNodes) {
        to_xhtml($kid, $writer);
    }

    $writer->endTag($element_name);
}

sub to_anchor
{
    my ($node, $writer) = @_;
    my $tag = lc ($node->getTagName);
    my @args;
    my $href;

    my $args = $node->getAttributes;

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


    $writer->startTag('a', @args);

    foreach my $kid ($node->getChildNodes) {
        to_xhtml($kid, $writer);
    }

    $writer->endTag();
}

sub to_img
{
    my ($node, $writer) = @_;
    my $tag = lc ($node->getTagName);
    my @args;

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
        my $file = $img_ids_map{$href};
        if (defined($file)) {
            push @args, "src", "$file";
        }

        print "[img] $href -> $file\n";
    }

    $writer->startTag('center');
    $writer->emptyTag('img', @args);
    $writer->endTag('center');
}

sub to_xhtml
{
    my ($node, $writer, $context_prefix) = @_;
    my $type = $node->getNodeType;
    if ($type == ELEMENT_NODE) {
        my $tag = lc ($node->getTagName);
        if ($tag eq 'section') {
            foreach my $kid ($node->getChildNodes) {
                to_xhtml($kid, $writer);
            }
        }
        elsif (grep {$tag eq $_} qw(style)) {
            to_classed_element($node, $writer, 'span', $context_prefix);
        } 
        elsif (grep {$tag eq $_} qw(epigraph poem stanza cite)) {
            to_classed_element($node, $writer, 'div', $context_prefix);
        } 
        elsif (grep {$tag eq $_} qw(p annotation empty-line text-author code title v subtitle)) {
            to_classed_element($node, $writer, 'p', $context_prefix);
        }
        elsif ($tag eq 'a') {
            to_anchor($node, $writer);
        }
        elsif ($tag eq 'image') {
            to_img($node, $writer);
        }

        else {
            #leave tags as is with all attributes
            my @args = ();

            my $args = $node->getAttributes;

            my $i = 0;
            while ($i < $args->getLength) {
                my $item = $args->item($i);
                push @args, $item->getName, $item->getValue;
                $i++;
            }

            $writer->startTag($tag, @args);
            foreach my $kid ($node->getChildNodes) {
                to_xhtml($kid, $writer, $context_prefix);
            }
            $writer->endTag();
        }
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
sub build_ids_map
{
    my $section = shift;
    my $node = $section->data;
    my $filename = $filename_map{$section};
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    $ids_map{$id} = $filename if ($id ne '');

    # do the same for children
    if (@{$section->subsections}) {
        foreach my $s (@{$section->subsections}) {
            build_ids_map($s);
        }
    }
    else {
        my @ids = collect_ids($node);
        foreach my $id (@ids) {
            $ids_map{$id} = $filename;
        }
    }
}

sub map_all_ids
{
    my ($section, $filename) = @_;
    my $node = $section->data;
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    $ids_map{$id} = $filename if ($id ne '');

    # do the same for children
    if (@{$section->subsections}) {
        foreach my $s (@{$section->subsections}) {
            map_all_ids($s, $filename);
        }
    }
    else {
        my @ids = collect_ids($node);
        foreach my $kid_id (@ids) {
            $ids_map{$kid_id} = $filename;
        }
    }
}

sub collect_ids
{
    my $node = shift;
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    push @result, $id if (defined($id) && ($id ne ''));
    foreach my $kid ($node->getChildNodes) {
        next if ($kid->getNodeType() != ELEMENT_NODE);
        my @kid_ids = collect_ids($kid);
        push @result, @kid_ids;
    }

    return @result;
}

sub build_chapters_map
{
    my ($section) = @_;
    $filename_map{$section} = $chapter_manager->current_chapter_file;
    if (!$section->id) {
        $section->id('epubchapter' . $chapter_manager->section_id);
        # and increase counter
        $chapter_manager->next_section;
    }

    if (@{$section->subsections}) {
        foreach my $s (@{$section->subsections}) {
            build_chapters_map($s);
        }
    }
    else {
        # Advance to the next file
        $chapter_manager->next_file;
    }
}

sub add_subsection_navigation
{
    my ($section, $section_navpoint, $level) = @_;

    foreach my $s (@{$section->subsections}) {
        my $chapter_file = $filename_map{$s};
        my $filename = $chapter_file->filename;

        my $section_title = $s->plaintext_title;
        my $nav_point;
        if (defined($section_title)) {
            $nav_point = $section_navpoint->add_navpoint(
                label       => $section_title,
                id          => $s->id,
                content     => "$filename#" . $s->id,
                play_order  => $play_order,
            );
            $play_order++;

            add_subsection_navigation($s, $nav_point, $level + 1);
        }
    }
}
