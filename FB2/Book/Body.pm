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

package FB2::Book::Body;
use Moose;

has name => ( isa => 'Str', is => 'rw' );
has title => ( isa => 'Str', is => 'rw' );
has epigraph => ( isa => 'Str', is => 'rw' );
has image => ( isa => 'Str', is => 'rw' );
has sections => ( 
    isa     => 'ArrayRef',
    is      => 'ro',
    default => sub { [] },
);

sub load
{
    my ($self, $node) = @_;

    my $anode = $node->getAttribute("name");
    if (defined($anode)) {
        $self->name($anode);
    }

    my @nodes = $node->findnodes("title");
    if (@nodes) {
        $self->title(XML::XPath::XMLParser::as_string($nodes[0]));
    }
    @nodes = $node->findnodes("epigraph");
    if (@nodes) {
        $self->epigraph(XML::XPath::XMLParser::as_string($nodes[0]));
    }

    # TODO: Add image support
    @nodes = $node->findnodes("section");
    foreach my $n (@nodes) {
        push @{$self->sections()}, 
            XML::XPath::XMLParser::as_string($n);
    }
}

1;
