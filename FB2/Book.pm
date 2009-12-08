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

package FB2::Book;

use Moose;
use XML::XPath;
use XML::XPath::XMLParser;

use FB2::Book::Description;
use FB2::Book::Binary;
use FB2::Book::Body;

has description => ( isa => 'Object', is => 'rw', 
                        handles => {
                            title => 'book_title',
                            lang => 'lang',
                            authors => 'authors'
                        },
                   );

has bodies => (isa => 'ArrayRef', is => 'ro', default => sub { [] });
has binaries => (isa => 'ArrayRef', is => 'ro', default => sub { [] });

sub load
{
    my ($self, $file) = @_;
    my $xp = XML::XPath->new(filename => $file);

    my @nodes = $xp->findnodes('/FictionBook/description'); 
    if (@nodes != 1) {
        warn "Wrong number of <description> element";
        return;
    }

    my $desc = FB2::Book::Description->new();
    $desc->load($nodes[0]);
    $self->description($desc);

    # load binaries 
    @nodes = $xp->findnodes('/FictionBook/binary'); 
    foreach my $node (@nodes) {
        my $bin = FB2::Book::Binary->new();
        $bin->load($node);
        push @{$self->binaries()}, $bin;
    }


    # Load bodies 
    @nodes = $xp->findnodes('/FictionBook/body'); 
    foreach my $node (@nodes) {
        my $bin = FB2::Book::Body->new();
        $bin->load($node);
        push @{$self->binaries()}, $bin;
    }



    # XXX: handle stylesheet?
    return 1;
}

1;
