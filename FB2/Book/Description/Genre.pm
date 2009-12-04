package FB2::Book::Description::Genre;
use Moose;

has genre => { isa => 'String', is => rw };
has percent => { isa => 'Int', is => rw };

sub load 
{
    my ($self, $node) = @_;
    my $pnode = $node->getAttribute("percent");
    if (defined($pnode)) {
        $self->percent($pnode->getNodeValue());
    }
    else {
        $self->percent(100);
    }
}

1;
