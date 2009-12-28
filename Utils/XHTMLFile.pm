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

package Utils::XHTMLFile;

use Moose;
use XML::Writer;
use File::Basename;

has path => (
    isa         => 'Str',
    is          => 'rw',
    required    => 1,
);

has opened => (
    isa         => 'Bool',
    is          => 'rw',
);

has writer => (
    isa         => 'Ref',
    is          => 'rw',
);

has output => (
    isa         => 'Ref',
    is          => 'rw',
);

has style => (
    isa         => 'Str',
    is          => 'rw',
    default     => 'style.css',
);

sub filename
{
    my $self = shift;
    my ($basename, undef, undef) = fileparse($self->path);
    return $basename;
}

sub open
{
    my $self = shift;

    my $output = new IO::File(">" . $self->path);
    binmode($output, ':utf8');
    my $writer = new XML::Writer(OUTPUT => $output);
    $self->output($output);
    $self->writer($writer);
    $self->write_xhtml_prologue;
    $self->opened(1);
}

sub close
{
    my $self = shift;
    $self->writer->endTag('html');
    $self->writer->end;
    $self->output->close;
    $self->opened(0);
}

# Helper routine
sub write_xhtml_prologue
{
    my $self = shift;
    $self->writer->xmlDecl("UTF-8");
    $self->writer->startTag("html", "xmlns" => "http://www.w3.org/1999/xhtml");
    $self->writer->startTag("head");
    $self->writer->emptyTag("title");
    $self->writer->emptyTag("link",
        rel     => "stylesheet",
        href    => $self->style,
        type    => "text/css",
    );
    $self->writer->endTag("head");
}

# Finalize class
my $meta = __PACKAGE__->meta;
$meta->make_immutable; 
no Moose;

1;
