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

package Utils::ChapterManager;

use Moose;
use Utils::ChapterFile;
use File::Basename;

has file_id => (
    isa     => 'Int',
    is      => 'rw',
    default => 1
);

has section_id => (
    isa     => 'Int',
    is      => 'rw',
    default => 1,
);

has current_chapter_file => (
    isa     => 'Object',
    is      => 'rw',
);

has chapter_files => (
    isa     => 'ArrayRef',
    is      => 'ro',
    default => sub { [] },
);

has tmp_dir => (
    isa         => 'Str',
    is          => 'rw',
    required    => 1,
);

sub BUILD
{
    my ($self) = @_;
    my $ch = $self->file_id;
    my $name = sprintf("page%04d.xhtml", $ch);
    # XXX: Unix-only
    $name = $self->tmp_dir . "/" . $name;
    my $chfile = Utils::ChapterFile->new(path => $name);
    $self->current_chapter_file($chfile);
}

sub next_file
{
    my ($self) = @_;
    push @{$self->chapter_files}, 
        $self->current_chapter_file;
    $self->file_id($self->file_id + 1);

    my $ch = $self->file_id;
    my $name = sprintf("page%04d.xhtml", $ch);
    # XXX: Unix-only
    $name = $self->tmp_dir . "/" . $name;
    my $chfile = Utils::ChapterFile->new(path => $name);
    $self->current_chapter_file($chfile);
}

sub next_section
{
    my ($self) = @_;
    $self->section_id($self->section_id + 1);
}

sub add_file
{
    my ($self, $filename, $linear) = @_;
}

1;
