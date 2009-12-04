package FB2::Book;

use strict;
use XML::XPath;
use XML::XPath::XMLParser;

use FB2::Book::Description;

sub new
{
    my ($class, %opts) = @_;
    my $self = {};

    return bless $self, $class;
}

sub load
{
    my ($self, $file) = @_;
    my $xp = XML::XPath->new(filename => $file);
    my $nodeset = $xp->find('/FictionBook/description'); # find all paragraphs

    my @nodes = $nodeset->get_nodelist;

    if (@nodes != 1) {
        warn "Wrong number of <description> element";
        return;
    }

    my $desc = FB2::Book::Description->new();
    $desc->load($nodes[0]);
}

1;
