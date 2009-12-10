# Copyright (c) 2009 Oleksandr Tymoshenko <gonzo@bluezbox.com>
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

package FB2::Book::Description;

use Moose;
use FB2::Book::Description::TitleInfo;

has 'title_info' =>  (
    isa     => 'Object', 
    is      => 'rw', 
    handles => {
        book_title  => 'book_title',
        authors     => 'all_authors',
        translators => 'all_translators',
        genres      => 'all_genres',
        lang        => 'lang',
    },
);

# TODO: more handlers
has 'src_title_info' =>  (
    isa     => 'Object', 
    is      => 'rw', 
    handles => {
        src_book_title => 'book_title',
    },
);

has 'publish_info' =>  (
    isa     => 'Object', 
    is      => 'rw', 
    handles => {
        publication_title   => 'book_name',
        publisher           => 'publisher',
        publication_city    => 'city',
        publication_year    => 'year',
        isbn                => 'isbn',
    },
);

sub load
{
    my ($self, $node) = @_;
    my @title_info_nodes = $node->findnodes('title-info');

    if (@title_info_nodes != 1) {
        croak ("Wrong number of <title-info> element");
        return;
    }

    my $title_info = FB2::Book::Description::TitleInfo->new();
    $title_info->load( $title_info_nodes[0]);
    $self->title_info($title_info);

    my @src_title_info_nodes = $node->findnodes('src-title-info');

    if (@src_title_info_nodes > 1) {
        croak ("Wrong number of <src-title-info> element");
        return;
    }

    if (@src_title_info_nodes) {
        my $src_title_info = FB2::Book::Description::TitleInfo->new();
        $src_title_info->load( $src_title_info_nodes[0]);
        $self->src_title_info($src_title_info);
    }

    my @publish_info_nodes = $node->findnodes('publish-info');

    if (@publish_info_nodes > 1) {
        croak ("Wrong number of <publish-info> element");
        return;
    }

    if (@publish_info_nodes) {
        my $publish_info = FB2::Book::Description::TitleInfo->new();
        $publish_info->load( $publish_info_nodes[0]);
        $self->publish_info($publish_info);
    }

    # TODO: add <custom-info> and <output> handlers
}

1;
