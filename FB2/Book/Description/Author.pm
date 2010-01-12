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

package FB2::Book::Description::Author;
use Moose;

has [qw/first_name middle_name last_name nickname home_page email id/] => (
    isa     => 'Str',
    is      => 'rw'
);

sub load
{
    my ($self, $node) = @_;

    my @nodes = $node->findnodes('first-name');
    if (@nodes) {
        $self->first_name($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('middle-name');
    if (@nodes) {
        $self->middle_name($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('last-name');
    if (@nodes) {
        $self->last_name($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('nickname');
    if (@nodes) {
        $self->nickname($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('home-page');
    if (@nodes) {
        $self->home_page($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('email');
    if (@nodes) {
        $self->email($nodes[0]->string_value());
    }

    @nodes = $node->findnodes('id');
    if (@nodes) {
        $self->id($nodes[0]->string_value());
    }
}

sub to_str
{
    my $self = shift;
    my $name = $self->first_name;
    $name .= ' ' . $self->middle_name if defined($self->middle_name);
    if ($name ne '') {
        $name .= ' "' . $self->nickname . '"' 
            if defined($self->nickname);
    }
    else {
        $name = $self->nickname if defined($self->nickname);
    }

    $name .= ' ' . $self->last_name if defined($self->last_name);

    return $name;
}

1;
