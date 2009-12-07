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

package FB2::Book::Description::PublishInfo;
use Moose;

has [qw/book-name publisher city year isbn/] => (isa => 'Str', is => 'rw');
has sequences => (isa => 'ArrayRef', is => 'ro', default => sub { [] });

sub load
{
    my ($self, $node) = @_;

    my @nodes = $node->findnodes('book-name');
    if (@nodes) {
        $self->book_name($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('publisher');
    if (@nodes) {
        $self->publisher($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('city');
    if (@nodes) {
        $self->city($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('year');
    if (@nodes) {
        $self->year($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('isbn');
    if (@nodes) {
        $self->isbn($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('sequence');
    foreach my $node (@nodes) {
        my $seq = FB2::Book::Description::Sequence->new();
        $seq->load($node);
        $self->add_sequence($seq);
    }
}

sub add_sequence
{
    my ($self, $seq) = @_;
    push @{$self->sequnces()}, $seq;
}
