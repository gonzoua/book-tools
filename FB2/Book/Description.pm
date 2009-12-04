package FB2::Book::Description;

use Moose;
use FB2::Book::Description::TitleInfo;

has [qw/title_info src_title_info/] => (isa => 'Object', is => 'rw');

sub load
{
    my ($self, $node) = @_;
    my @title_info_nodes = $node->findnodes('title-info');
    my @src_title_info_nodes = $node->findnodes('src-title-info');
    if (@title_info_nodes != 1) {
        croak ("Wrong number of <title-info> element");
        return;
    }

    my $title_info = FB2::Book::Description::TitleInfo->new();
    if($title_info->load( $title_info_nodes[0])) {
        $self->title_info($title_info);
    }
}

1;
