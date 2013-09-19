package Converter::MOBI;

use strict;
use warnings;
use EBook::MOBI;
use EBook::FB2;
use XML::Writer;
use XML::DOM;
use Archive::Zip qw/:ERROR_CODES :CONSTANTS/;
use File::Temp qw/tempdir :mktemp/;
use File::Spec;
use File::Path;
use List::MoreUtils qw(uniq);

use Utils::XHTMLFile;
use Utils::Fonts;
use Data::UUID;
use Font::Subsetter;
use Encode;

use utf8;

sub new
{
    my ($class, %params) = @_;
    my $tmp_dir = tempdir();
    my $self = {
        ids_map => {},
        img_map => {},
        filename_map => {},
        has_code => 0,
        symbols => [],
        play_order => 1,
        mobi_converter => EBook::MOBI::Converter->new(),
    	mobi_book => EBook::MOBI->new(),
        tags_stack => [],
        tmp_dir => $tmp_dir,
    };
    mkdir($tmp_dir);

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
    my ($self, $fb2book, $mobibook, $font_family) = @_;

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
        if (@members > 1) {
            $self->{'fail_reason'} = 'zip archive contains more then 1 fb2 file';
            return;
        }
        if (@members < 1) {
            $self->{'fail_reason'} = 'no fb2 file in zip archive';
            return;
        }
        my $tmp_fb2 = mktemp( "$tmpdir/fb2XXXXX" );    
        if ($fb2zip->extractMember($members[0], $tmp_fb2) != AZ_OK) {
            $self->{'fail_reason'} = 'Invalid archive: failed to extract fb2 file';
            return;
        }

        if (!$fb2->load($tmp_fb2)) {
            unlink $tmp_fb2;
            $self->{'fail_reason'} = 'Invalid fb2 file';
            return;
        }

        # Remove tmp fB2 anyway
        unlink $tmp_fb2;
    }
    else {
        if  (!$fb2->load($fb2book)) {
            $self->{'fail_reason'} = 'Invalid fb2 file';
            return;
        }
    }


    # Create MOBI parts: package/container

    #
    # Set author/title/ID/language
    #
    # $self->{mobi_book}->debug_on(sub { print STDERR @_; print STDERR "\n" });
    $self->{mobi_book}->set_encoding(':encoding(UTF-8)');

    my $book_title = $fb2->description->book_title;
    $book_title = '' if(!defined($book_title));
    my $book_title_utf = encode("utf8", $book_title);
    $self->{mobi_book}->set_title($book_title_utf);
    my @authors = $fb2->description->authors();

    my @author_names;
    foreach my $a (@authors) {
        push @author_names, $a->to_str();
    }
    my $authors = join ", ", @author_names;
    my $authors_utf = encode("utf8", $authors);
    $self->{mobi_book}->set_author($authors_utf);
    $self->{mobi_book}->set_filename($mobibook);
    # $self->{mobi_book}->set_encoding(':encoding(UTF-8)');

    my @bodies = $fb2->bodies();

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
        my $img_file = $self->{tmp_dir} . "/$img_name";
        $self->{img_map}->{$b->id()} = $img_file;
        open IMG_FILE, "> $img_file";
        binmode IMG_FILE;
        print IMG_FILE  $b->data();
        close IMG_FILE;
    }

    # create title page
    if (defined($book_title) || defined($authors)) {
        $self->{mobi_book}->add_mhtml_content("\n<center>\n");
        my $text = $self->{mobi_converter}->text($book_title);
        $self->{mobi_book}->add_mhtml_content("\n <h1>$text</h1>\n");
        $text = $self->{mobi_converter}->text($authors);
        $self->{mobi_book}->add_mhtml_content("\n <h2>$text</h2>\n");
        $self->{mobi_book}->add_mhtml_content("\n</center>\n");
        $self->{mobi_book}->add_pagebreak();
    }

    # Create pages with cover images
    my @cover_ids = $fb2->description->coverpages;
    if (@cover_ids) {
        my $orig_id = $cover_ids[0];
        if (defined($self->{img_map}->{$orig_id})) {
            my $file = $self->{img_map}->{$orig_id};
            $self->{mobi_book}->set_cover_image($file);
            $self->{mobi_book}->set_cover_thumbnail_image($file);
        }
    }

    foreach my $cover_id (@cover_ids) {
        if (defined($self->{img_map}->{$cover_id})) {
            my $file = $self->{img_map}->{$cover_id};
            my $mhtml = $self->{mobi_converter}->image($file);
            $self->{mobi_book}->add_mhtml_content("\n<center>\n");
            $self->{mobi_book}->add_mhtml_content($mhtml);
            $self->{mobi_book}->add_mhtml_content("\n</center>\n");
            $self->{mobi_book}->add_pagebreak();
        }
    }

    # Collect elements with "id" attributes and map them
    # to respective filenames
    foreach my $body (@bodies) {
        my $name = lc($body->name());

        foreach my $section ($body->sections) {
            $self->build_ids_map($section, $name);
        }
    }

    my $c = EBook::MOBI::Converter->new();

    # write all files 
    foreach my $body (@bodies) {
        my $name = lc($body->name());

        next if(defined($name) && ($name eq 'notes'));
        
        # TODO: set cover for body

        foreach my $section ($body->sections) {
            $self->transform_sections($section, \&write_section, 1);
        }
    }

    # Notes should go last
    foreach my $body (@bodies) {
        my $name = lc($body->name());
        next unless($name eq 'notes');

        foreach my $section ($body->sections) {
            $self->transform_sections($section, \&write_section, 2);
        }
    }

    $self->{mobi_book}->add_toc_once();
    $self->{mobi_book}->make();
    $self->{mobi_book}->save();

    # open F, "> mhtml";
    # binmode F;
    # print F $self->{mobi_book}->print_mhtml('foo');
    # close F;

    return ('OK', '-');
}

#
# Helper functions
#

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
    my ($self, $section, $level) = @_;

    $level = 1 unless(defined($level));
    $level = 6 if($level > 6);

    my $c = $self->{mobi_converter};
    my $section_title = $c->text($section->plaintext_title);
    my $section_id = $section->id();

    $self->{mobi_book}->add_mhtml_content( "\n<a id=\"$section_id\" />\n");

    if (defined($section_title) && ($section_title ne '')) {
        $self->{mobi_book}->add_mhtml_content( "\n<h$level>$section_title</h$level>\n");
    }

    if ($section->image) {
        $self->to_xhtml($section->image, $self->{mobi_book});
    }

    foreach my $e ($section->epigraphs) {
        $self->to_xhtml($e, $self->{mobi_book});
    }

    # if there are no subsections, just convert content to xhtml
    if (!$section->subsections) {
        $self->to_xhtml($section->data(), $self->{mobi_book});
    }
}

sub to_classed_element 
{
    my ($self, $node, $book, $element_name) = @_;
    my $tag = lc ($node->getTagName);
    my $id = $node->getAttribute('id');
    my @args;

    if ($id ne '') {
        push @args, 'id', $id;
    }

    push @args, 'class', $tag;

    $self->startTag($book, $element_name, @args);

    foreach my $kid ($node->getChildNodes) {
        $self->to_xhtml($kid, $book);
    }

    $self->endTag($book, $element_name);
}

sub to_element
{
    my ($self, $node, $book, $tag) = @_;
    my @args;
    my $href;

    my $args = $node->getAttributes;

    my $i = 0;
    while ($i < $args->getLength) {
        my $item = $args->item($i);
        push @args, ($item->getName, $item->getValue);
        $i++;
    }

    $self->startTag($book, $tag, @args);

    foreach my $kid ($node->getChildNodes) {
        $self->to_xhtml($kid, $book);
    }

    $self->endTag($book);
}



sub to_anchor
{
    my ($self, $node, $book) = @_;
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

    my $body = '';
    if (defined($href)) {
        $href =~ s/^#//;
        # get file for this id
        $body = $self->{ids_map}->{$href};
        $body = '' if(!defined($body));
        print "$href -> $body#$href\n";
        push @args, "href", "#$href";
    }

    push @args, 'filepos';
    push @args, '00000000';

    $self->startTag($book, 'a', @args);
    $self->startTag($book, 'sup') if ($body eq 'notes');

    foreach my $kid ($node->getChildNodes) {
        $self->to_xhtml($kid, $book);
    }

    $self->endTag($book) if ($body eq 'notes');
    $self->endTag($book);
}

sub to_img
{
    my ($self, $node, $book) = @_;
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
        return if(!defined($self->{img_map}->{$href}));
        my $file = $self->{img_map}->{$href};
        my $mhtml = $self->{mobi_converter}->image($file);
        $book->add_mhtml_content($mhtml);
    }

    # $self->startTag($book, 'center');
    # $book->emptyTag('img', @args);
    # $self->endTag($book, 'center');
}

sub to_xhtml
{
    my ($self, $node, $book) = @_;
    my $type = $node->getNodeType;
    if ($type == ELEMENT_NODE) {
        my $tag = lc ($node->getTagName);
        if ($tag eq 'section') {
            foreach my $kid ($node->getChildNodes) {
                $self->to_xhtml($kid, $book);
            }
        }
        elsif (grep {$tag eq $_} qw(style)) {
            $self->to_classed_element($node, $book, 'span');
        } 
        elsif (lc($tag) eq 'emphasis') {
            $self->to_element($node, $book, 'em');
        }
        elsif (lc($tag) eq 'empty-line') {
            $book->add_mhtml_content("<br/>");
            $book->add_mhtml_content("<br/>");
        }
        elsif (grep {$tag eq $_} qw(epigraph poem stanza cite)) {
            $self->to_classed_element($node, $book, 'div');
        } 
        elsif (grep {$tag eq $_} qw(annotation text-author v subtitle)) {
            $self->to_classed_element($node, $book, 'p');
        }
        elsif ($tag eq 'a') {
            $self->to_anchor($node, $book);
        }
        elsif ($tag eq 'image') {
            $self->to_img($node, $book);
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

            $self->startTag($book, $tag, @args);
            foreach my $kid ($node->getChildNodes) {
                $self->to_xhtml($kid, $book);
            }
            $self->endTag($book);
        }
    }
    elsif ($type == TEXT_NODE) {
        $book->add_mhtml_content($self->{mobi_converter}->text($node->getData()));
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
    my ($self, $section, $body) = @_;
    my $node = $section->data;
    my @result;

    # Node could have own id
    my $id = $node->getAttribute('id');
    $self->{ids_map}->{$id} = $body if ($id ne '');

    # do the same for children
    if ($section->subsections) {
        foreach my $s ($section->subsections) {
            $self->build_ids_map($s, $body);
        }
    }
    else {
        my @ids = $self->collect_ids($node);
        foreach my $id (@ids) {
            $self->{ids_map}->{$id} = $body;
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

sub startTag
{
    my $self = shift;
    my $book = shift;
    my $tag = shift;
    my @args = @_;

    push @{$self->{tags_stack}}, $tag;

    my $tag_line = "<$tag";
    my $i = 0;
    while ($i < $#args) {
        $tag_line .= " $args[$i]=\"" . $args[$i+1] . "\"";
        $i += 2;
    }
    $tag_line .= ">";
    $book->add_mhtml_content($tag_line);
}

sub endTag
{
    my $self = shift;
    my $book = shift;
    my $tag = shift;
    die "endTag: Empty tag stack" if (!@{$self->{tags_stack}});
    my $orig_tag = pop @{$self->{tags_stack}};

    if (!defined($tag)) {
        $tag = $orig_tag;
    }
    else {
        die "endTag: tag mismatch: $tag vs $orig_tag" if ($tag ne $orig_tag);
    }
    $book->add_mhtml_content("</$tag>");
}

1;
