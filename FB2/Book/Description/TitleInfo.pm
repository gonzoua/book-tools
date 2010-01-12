# Copyright (c) 2009, 2010 Oleksandr Tymoshenko <gonzo@bluezbox.com>
# All rights reserved.

# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.

# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

package FB2::Book::Description::TitleInfo;
use Moose;
use FB2::Book::Description::Author;
use FB2::Book::Description::Genre;
use FB2::Book::Description::Sequence;

has [qw/book_title keywords date lang src_lang/] => (
    isa     => 'Str',
    is      => 'rw'
);

has genres => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Object]',
    is      => 'rw',
    default => sub { [] },
    handles => {
       all_genres   => 'elements',
    },
);

has authors => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Object]',
    is      => 'rw',
    default => sub { [] },
    handles => {
       all_authors   => 'elements' 
    }
);

has translators => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Object]',
    is      => 'rw',
    default => sub { [] },
    handles => {
       all_translators   => 'elements' 
    }
);

has sequences => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Object]',
    is      => 'rw',
    default => sub { [] },
    handles => {
       all_sequences   => 'elements' 
    }
);

has coverpages => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Object]',
    is      => 'rw',
    default => sub { [] },
    handles => {
       all_coverpages   => 'elements' 
    }
);

sub load
{
    my ($self, $node) = @_;

    my @nodes = $node->findnodes('book-title');
    if (@nodes) {
        $self->book_title($nodes[0]->string_value);
    }

    @nodes = $node->findnodes('keywords');
    if (@nodes) {
        $self->keywords($nodes[0]->string_value);
    }

    @nodes = $node->findnodes('lang');
    if (@nodes) {
        $self->lang($nodes[0]->string_value);
    }

    @nodes = $node->findnodes('src_lang');
    if (@nodes) {
        $self->src_lang($nodes[0]->string_value);
    }

    @nodes = $node->findnodes('date');
    if (@nodes) {
        # TODO: parse node to ::Data object
        $self->date($nodes[0]->string_value);
    }

    # Now handle multiple entities
    @nodes = $node->findnodes('author');
    foreach my $node (@nodes) {
        my $author = FB2::Book::Description::Author->new;
        $author->load($node);
        $self->add_author($author);
    }

    @nodes = $node->findnodes('translator');
    foreach my $node (@nodes) {
        my $translator = FB2::Book::Description::Author->new;
        $translator->load($node);
        $self->add_translator($translator);
    }

    @nodes = $node->findnodes('genre');
    foreach my $node (@nodes) {
        my $genre = FB2::Book::Description::Genre->new;
        $genre->load($node);
        $self->add_genre($genre);
    }

    @nodes = $node->findnodes('sequence');
    foreach my $node (@nodes) {
        my $seq = FB2::Book::Description::Sequence->new;
        $seq->load($node);
        $self->add_sequence($seq);
    }

    @nodes = $node->findnodes('coverpage/image');
    foreach my $node (@nodes) {
        my $map = $node->getAttributes;
        # find href attribute, a litle bit hackerish
        my $i = 0;
        while ($i < $map->getLength) {
            my $item = $map->item($i);
            if ($item->getName =~ /:href/i) {
                my $id = $item->getValue;
                $id =~ s/^#//;
                $self->add_coverpage($id);
            }
            $i++;
        }
    }
}

sub add_author
{
    my ($self, $author) = @_;
    push @{$self->authors}, $author;
}

sub add_translator
{
    my ($self, $translator) = @_;
    push @{$self->translators}, $translator;
}

sub add_genre
{
    my ($self, $genre) = @_;
    push @{$self->genres}, $genre;
}

sub add_sequence
{
    my ($self, $seq) = @_;
    push @{$self->sequences}, $seq;
}

sub add_coverpage
{
    my ($self, $id) = @_;
    push @{$self->coverpages}, $id;
}

1;
