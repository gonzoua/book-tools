package FB2::Book::Description::TitleInfo;
use Moose;

has [qw/book_title keyword date lang src_lang/] => (isa => 'String', is => 'rw');
sub load
{
    my ($self, $node) = @_;
           my $nodeset = $node->find('current()//title-info'); # find all paragraphs

           foreach my $n ($nodeset->get_nodelist) {
               print "FOUND\n\n",
                   XML::XPath::XMLParser::as_string($n),
                   "\n\n";
           }

    my @nodes = $node->findnodes("/*/author");
    if (@nodes) {
        print "Title: " . $nodes[0]->string_value();
        $self->book_title($nodes[0]->getValue());
    }
}

1;
