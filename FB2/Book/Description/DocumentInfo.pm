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

package FB2::Book::Description::DocumentInfo;
use Moose;

has [qw/program_used date src_ocr id version history/] => (isa => 'Str', is => 'rw');
has authors => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has src_urls => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has publishers => (isa => 'ArrayRef', is => 'ro', default => sub { [] });

sub load
{
    my @nodes = $node->findnodes('program-used');
    if (@nodes) {
        $self->program_used($nodes[0]->string_value());
    }

    # TODO: parse date

    @nodes = $node->findnodes('src-ocr');
    if (@nodes) {
        $self->src_ocr($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('id');
    if (@nodes) {
        $self->id($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('version');
    if (@nodes) {
        $self->version($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('history');
    if (@nodes) {
        $self->history($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('author');
    foreach my $node (@nodes) {
        my $translator = FB2::Book::Description::Author->new();
        $translator->load($node);
        $self->add_author($translator);
    }

    @nodes = $node->findnodes('publisher');
    foreach my $node (@nodes) {
        $self->add_publisher($node->string_value());
    }

    @nodes = $node->findnodes('src-url');
    foreach my $node (@nodes) {
        $self->add_src_url($node->string_value());
    }

}

sub add_author
{
    my ($self, $author) = @_;
    push @{$self->authors()}, $author;
}

sub add_publisher
{
    my ($self, $publisher) = @_;
    push @{$self->publishers()}, $publisher;
}

sub add_src_url
{
    my ($self, $src_url) = @_;
    push @{$self->src_urls()}, $src_url;
}
