package Converter;

use strict;
use warnings;
use EBook::EPUB;
use EBook::FB2;
use XML::Writer;
use XML::DOM;
use Archive::Zip qw/:ERROR_CODES :CONSTANTS/;
use File::Temp qw/tempdir :mktemp/;
use File::Spec;
use File::Path;
use List::MoreUtils qw(uniq);

use Utils::XHTMLFile;
use Utils::ChapterManager;
use Utils::Fonts;
use Data::UUID;
use Font::Subsetter;

my $data_dir = $ENV{FB2EPUB_ROOT} || ".";

sub new
{
    my ($class, %params) = @_;
    my $tmp_dir = tempdir();
    my $self = {
        ids_map => {},
        img_map => {},
        filename_map => {},
        has_notes => 0,
        symbols => [],
        play_order => 1,
        encrypt_fonts => 1,
        chapter_manager => Utils::ChapterManager->new(tmp_dir => $tmp_dir),
        tmp_dir => $tmp_dir,
    };

    if (defined($params{encrypt_fonts})) {
        $self->{encrypt_fonts} = $params{encrypt_fonts};
    }

    return bless $self, $class;
}

sub DESTROY 
{
    my $self = shift;
    if (-d $self->{tmp_dir}) {
        rmtree ($self->{tmp_dir});
    }
}

sub convert
{
    my ($self, $fb2book, $epubbook, $font_family) = @_;

    my $tmpdir = File::Spec->tmpdir();

    my $fb2 = EBook::FB2->new();

    # Let's check if fb2 is zip-compressed
    my $fb2zip = Archive::Zip->new();
    my $zip_status;
    Archive::Zip::setErrorHandler( sub { } );
    
    eval {
	$zip_status = $fb2zip->read ( $fb2book );
    };
    if ( $zip_status == AZ_OK ) {
        my @members = $fb2zip->membersMatching( '.*\.fb2' );
        return ('FAIL', 'zip archive contains more then 1 fb2 file') if (@members > 1);
        return ('FAIL', 'no fb2 file in zip archive') if (@members < 1);
        my $tmp_fb2 = mktemp( "$tmpdir/fb2XXXXX" );    
        if ($fb2zip->extractMember($members[0], $tmp_fb2) != AZ_OK) {
            return ('FAIL', 'Invalid archive: failed to extract fb2 file');
        }

        if (!$fb2->load($tmp_fb2)) {
            unlink $tmp_fb2;
            return ('FAIL', 'Invalid fb2 file');
        }

        # Remove tmp fB2 anyway
        unlink $tmp_fb2;
    }
    else {
        return ('FAIL', 'Invalid fb2 file') unless ($fb2->load($fb2book));
    }

    # Create EPUB parts: package/container
    my $package = EBook::EPUB->new();

    #
    # Set author/title/ID/language
    #
    $package->add_title($fb2->description->book_title);
    my @authors = $fb2->description->authors();
    foreach my $a (@authors) {
        $package->add_author($a->to_str());
    }
    if (defined($fb2->description->lang())) {
        $package->add_language($fb2->description->lang());
    }
    else
    {
        # XXX: hack
        $package->add_language('ru');
    }
    my $ug = new Data::UUID;
    my $uuid = $ug->create_from_name_str(NameSpace_URL, "fb2epub.com");
    $package->add_identifier("urn:uuid:$uuid");

    # Add all images to EPUB package
    my @binaries = $fb2->binaries();
    my $img_c = 0;
    foreach my $b (@binaries) {
        my $ctype = $b->content_type();
        my $ext = 'gif';
        if ($ctype =~/jpeg/) {
            $ext = 'jpg';
        }
        elsif ($ctype =~/jpg/) {
            $ext = 'jpg';
            $ctype =~ s/jpg/jpeg/;
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
        my $new_id = $package->add_image($img_name, $b->data(), $ctype);
        $self->{img_map}->{$b->id()} = { name => $img_name, id => $new_id };
    }

    my @bodies = $fb2->bodies();

    # Create pages with cover images
    my @cover_ids = $fb2->description->coverpages;
    if (@cover_ids) {
        my $orig_id = $cover_ids[0];
        if (defined($self->{img_map}->{$orig_id})) {
            my $img_id = $self->{img_map}->{$orig_id}->{id};
            $package->add_item('cover', $img_id);
        }
    }

    foreach my $img_id (@cover_ids) {
        my $xhtml_file = $self->{chapter_manager}->current_chapter_file;
        $xhtml_file->open;
        my $writer = $xhtml_file->writer;
        my $xhtml = $self->write_cover_xhtml($img_id, $writer);
        $xhtml_file->close;
        
        $self->{chapter_manager}->next_file;
    }

    #  
    # Map each section/body to it's own file
    # Skip "notes" bodies
    #
    foreach my $body (@bodies) {
        my $name = lc($body->name());
        next if ($name eq 'notes');

        # Page for body with image/title/epiraph
        $self->{filename_map}->{$body} = $self->{chapter_manager}->current_chapter_file;
        $self->{chapter_manager}->next_file;

        foreach my $section ($body->sections) {
            $self->build_chapters_map($section);
        }
    }

    # Collect elements with "id" attributes and map them
    # to respective filenames
    foreach my $body (@bodies) {
        my $name = lc($body->name());
        next if ($name eq 'notes');

        foreach my $section ($body->sections) {
            $self->build_ids_map($section);
        }
    }

    # Now map all ids in notes to notes.xhtml file 
    foreach my $body (@bodies) {
        my $name = lc($body->name());
        next if (!defined($name) || ($name ne 'notes'));

        $self->{has_notes} = 1;
        foreach my $section ($body->sections) {
            $self->map_all_ids($section, 'notes.xhtml');
        }
    }

    # write all files 
    foreach my $body (@bodies) {
        my $name = $body->name();

        next if(defined($name) && ($name eq 'notes'));
        
        # Write page with image/title/epigraph
        my $xhtml_file = $self->{filename_map}->{$body};

        $xhtml_file->open;
        my $writer = $xhtml_file->writer;
        $self->write_body_cover_xhtml($body, $writer);
        $xhtml_file->close;

        foreach my $section ($body->sections) {
            $self->transform_sections($section, \&write_section_file, 1);
        }
    }

    # write notes 
    if ($self->{has_notes}) {
        my $xhtml_file = Utils::XHTMLFile->new(path => $self->{tmp_dir} . "/notes.xhtml");
        $xhtml_file->open;
        my $writer = $xhtml_file->writer;
        $writer->startTag('body');
        foreach my $body (@bodies) {
            my $name = lc($body->name());
            next unless($name eq 'notes');

            foreach my $section ($body->sections) {
                $self->write_section($section, $writer);
            }
        }
        $writer->endTag('body');
        $xhtml_file->close();
    }

    # Create navigation points. Do our best
    foreach my $body (@bodies) {
        my $name = $body->name();
        next if (defined($name) && ($name eq 'notes'));

        foreach my $section ($body->sections) {
            my $chapter_file = $self->{filename_map}->{$section};
            my $filename = $chapter_file->filename;

            my $section_title = $section->plaintext_title;
            my $nav_point;
            if (defined($section_title)) {
                $nav_point = $package->add_navpoint(
                    label       => $section_title,
                    id          => $section->id,
                    content     => "$filename#" . $section->id,
                    play_order  => $self->{play_order},
                );
                $self->{play_order}++;
                $self->add_subsection_navigation($section, $nav_point);
            }
        }
    }

    # Add CSS and fonts
    open F, "< $data_dir/style_template.css";
    my @lines = <F>;
    my $css = join ('', @lines);
    close F;
    if (defined($font_family) && ($font_family ne '')) {
        $css =~ s/%%FONT_FAMILY%%/font-family: '$font_family';/g;
    }
    else {
        $css =~ s/%%FONT_FAMILY%%//g;
    }

    if (defined($font_family) && ($font_family ne '')) {
        $css = Utils::Fonts::make_font_description($font_family) . $css;
        my @fonts = Utils::Fonts::get_font_files($font_family);
        my $fonts_temp = mkdtemp($self->{tmp_dir} . "/fontsXXXX");
        my $chars = join '', @{$self->{symbols}};
        foreach my $font (@fonts) {
            my $input_file = "$data_dir/fonts/$font";
            my $output_file = "$fonts_temp/$font";
            my $subsetter = new Font::Subsetter();

            $subsetter->subset($input_file, $chars, {
            });

            $subsetter->write($output_file);


            if ($self->{encrypt_fonts}) {
                $package->encrypt_file($output_file, $font, 
                    'application/octet-stream');
            }
            else {
                $package->copy_file($output_file, $font, 
                    'application/x-font-ttf');
            }
        }
        # tmp_dir will be cleaned up finally
    }

    $package->add_stylesheet("style.css", $css);

    # add book content
    foreach my $chapter (@{$self->{chapter_manager}->chapter_files}) {
        # Close opened file
        if ($chapter->opened) {
            $chapter->writer->endTag('body');
            $chapter->close;
        }
        $package->copy_xhtml($chapter->path, $chapter->filename);
    }

    # Add notes file
    if ($self->{has_notes}) {
        $package->copy_xhtml($self->{tmp_dir} . "/notes.xhtml", "notes.xhtml",
            linear => 'no'
        );
    }

    $package->pack_zip($epubbook);
    return ('OK', '-');
}

#
# Helper functions
#

sub write_body_cover_xhtml
{
    my ($self, $body, $writer) = @_;
    $writer->startTag('body', class => 'cover');
    $writer->startTag('center');

    my $img_id = $body->image;
    if (defined($img_id) && defined($self->{img_map}->{$img_id})) {
        $writer->emptyTag('img', 'src' => $self->{img_map}->{$img_id}->{name});
    }

    if (defined($body->title)) {
        $writer->startTag('div', class => "title1");
        foreach my $kid ($body->title->getChildNodes) {
            $self->to_xhtml($kid, $writer, 'title');
        }
        $writer->endTag('div', class => "title1");
    }

    foreach my $e ($body->epigraphs) {
        $self->to_xhtml($e, $writer);
    }

    $writer->endTag('center');
    $writer->endTag('body');
}

sub write_cover_xhtml
{
    my ($self, $img_id, $writer) = @_;
    $writer->startTag('body');
    $writer->startTag('center');
    if (defined($self->{img_map}->{$img_id})) {
        $writer->emptyTag('img', 'src' => $self->{img_map}->{$img_id}->{name});
    }
    $writer->endTag('center');
    $writer->endTag('body');
}

sub transform_sections
{
    my ($self, $section, $transform_sub, $level) = @_;

    $transform_sub->($self, $section, $level);

    foreach my $s ($section->subsections) {
        $self->transform_sections($s, $transform_sub, $level + 1);
    }
}

sub write_section
{
    my ($self, $section, $writer, $level) = @_;

    $level = 1 unless(defined($level));
    $level = 6 if($level > 6);
    # Assume that section always has id
    $writer->startTag('div', 
        class   => 'section',
        id      => $section->id()
    );

    # Write image
    if ($section->image) {
        $self->to_xhtml($section->image, $writer);
    }

    # write title
    if ($section->title) {
        $writer->startTag('div', class => "title$level");
        foreach my $kid ($section->title->getChildNodes) {
            $self->to_xhtml($kid, $writer, 'title');
        }
        $writer->endTag('div');
    }

    # write epigraphs
    foreach my $e ($section->epigraphs) {
        $self->to_xhtml($e, $writer);
    }

    # if there are no subsections, just convert content to xhtml
    if (!$section->subsections) {
        $self->to_xhtml($section->data(), $writer);
    }

    $writer->endTag('div');
}

sub write_section_file
{
    my ($self, $section, $level) = @_;
    my $xhtml_file = $self->{filename_map}->{$section};

    my $writer;
    if (!$xhtml_file->opened) {
        $xhtml_file->open;
        $writer = $xhtml_file->writer;
        $writer->startTag('body');
    }
    else {
        $writer = $xhtml_file->writer;
    }

    $self->write_section($section, $writer, $level);
}

sub to_classed_element 
{
    my ($self, $node, $writer, $element_name, $context_prefix) = @_;
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
        $self->to_xhtml($kid, $writer);
    }

    $writer->endTag($element_name);
}

sub to_element
{
    my ($self, $node, $writer, $tag) = @_;
    my @args;
    my $href;

    my $args = $node->getAttributes;

    my $i = 0;
    while ($i < $args->getLength) {
        my $item = $args->item($i);
        push @args, ($item->getName, $item->getValue);
        $i++;
    }

    $writer->startTag($tag, @args);

    foreach my $kid ($node->getChildNodes) {
        $self->to_xhtml($kid, $writer);
    }

    $writer->endTag();
}



sub to_anchor
{
    my ($self, $node, $writer) = @_;
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
        my $file = $self->{ids_map}->{$href};
        if (defined($file)) {
            push @args, "href", "$file#$href";
        }

        print "$href -> $file#$href\n";
    }


    $writer->startTag('a', @args);

    foreach my $kid ($node->getChildNodes) {
        $self->to_xhtml($kid, $writer);
    }

    $writer->endTag();
}

sub to_img
{
    my ($self, $node, $writer) = @_;
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
        next if(!defined($self->{img_map}->{$href}));
        my $file = $self->{img_map}->{$href}->{name};
        my $id = $self->{img_map}->{$href}->{id};
        if (defined($file)) {
            push @args, "src", "$file";
        }

        print "[img] $href -> $id/$file\n";
    }

    $writer->startTag('center');
    $writer->emptyTag('img', @args);
    $writer->endTag('center');
}

sub to_xhtml
{
    my ($self, $node, $writer, $context_prefix) = @_;
    my $type = $node->getNodeType;
    if ($type == ELEMENT_NODE) {
        my $tag = lc ($node->getTagName);
        if ($tag eq 'section') {
            foreach my $kid ($node->getChildNodes) {
                $self->to_xhtml($kid, $writer);
            }
        }
        elsif (grep {$tag eq $_} qw(style)) {
            $self->to_classed_element($node, $writer, 'span', $context_prefix);
        } 
        elsif (lc($tag) eq 'emphasis') {
            $self->to_element($node, $writer, 'em');
        }
        elsif (grep {$tag eq $_} qw(epigraph poem stanza cite)) {
            $self->to_classed_element($node, $writer, 'div', $context_prefix);
        } 
        elsif (grep {$tag eq $_} qw(p annotation empty-line text-author code title v subtitle)) {
            $self->to_classed_element($node, $writer, 'p', $context_prefix);
        }
        elsif ($tag eq 'a') {
            $self->to_anchor($node, $writer);
        }
        elsif ($tag eq 'image') {
            $self->to_img($node, $writer);
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
                $self->to_xhtml($kid, $writer, $context_prefix);
            }
            $writer->endTag();
        }
    }
    elsif ($type == TEXT_NODE) {
        my @chars = split //, $node->getData();
        if (@chars) {
            @{$self->{symbols}} = uniq (@chars, @{$self->{symbols}});
        }
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
    my ($self, $section) = @_;
    my $node = $section->data;
    my $filename = $self->{filename_map}->{$section};
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    $self->{ids_map}->{$id} = $filename if ($id ne '');

    # do the same for children
    if ($section->subsections) {
        foreach my $s ($section->subsections) {
            $self->build_ids_map($s);
        }
    }
    else {
        my @ids = $self->collect_ids($node);
        foreach my $id (@ids) {
            $self->{ids_map}->{$id} = $filename;
        }
    }
}

sub map_all_ids
{
    my ($self, $section, $filename) = @_;
    my $node = $section->data;
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    $self->{ids_map}->{$id} = $filename if ($id ne '');

    # do the same for children
    if ($section->subsections) {
        foreach my $s ($section->subsections) {
            $self->map_all_ids($s, $filename);
        }
    }
    else {
        my @ids = $self->collect_ids($node);
        foreach my $kid_id (@ids) {
            $self->{ids_map}->{$kid_id} = $filename;
        }
    }
}

sub collect_ids
{
    my ($self, $node) = @_;
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    push @result, $id if (defined($id) && ($id ne ''));
    foreach my $kid ($node->getChildNodes) {
        next if ($kid->getNodeType() != ELEMENT_NODE);
        my @kid_ids = $self->collect_ids($kid);
        push @result, @kid_ids;
    }

    return @result;
}

sub build_chapters_map
{
    my ($self, $section) = @_;
    $self->{filename_map}->{$section} = $self->{chapter_manager}->current_chapter_file;
    if (!$section->id) {
        $section->id('epubchapter' . $self->{chapter_manager}->section_id);
        # and increase counter
        $self->{chapter_manager}->next_section;
    }

    if ($section->subsections) {
        foreach my $s ($section->subsections) {
            $self->build_chapters_map($s);
        }
    }
    else {
        # Advance to the next file
        $self->{chapter_manager}->next_file;
    }
}

sub add_subsection_navigation
{
    my ($self, $section, $section_navpoint) = @_;

    foreach my $s ($section->subsections) {
        my $chapter_file = $self->{filename_map}->{$s};
        my $filename = $chapter_file->filename;

        my $section_title = $s->plaintext_title;
        my $nav_point;
        if (defined($section_title)) {
            $nav_point = $section_navpoint->add_navpoint(
                label       => $section_title,
                id          => $s->id,
                content     => "$filename#" . $s->id,
                play_order  => $self->{play_order},
            );
            $self->{play_order}++;

            $self->add_subsection_navigation($s, $nav_point);
        }
    }
}

1;
