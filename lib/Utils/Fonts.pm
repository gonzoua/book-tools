package Utils::Fonts;

our $fonts = {
    charis => {
        bold => 'CharisSILB.ttf',
        bolditalic => 'CharisSILBI.ttf',
        italic => 'CharisSILI.ttf',
        normal => 'CharisSILR.ttf',
    },

    'pt sans' => {
        bold => 'PTS75F.ttf',
        bolditalic => 'PTS76F.ttf',
        italic => 'PTS56F.ttf',
        normal => 'PTS55F.ttf',
    },

    'liberation sans' => {
        bold => 'LiberationSans-Bold.ttf',
        bolditalic => 'LiberationSans-BoldItalic.ttf',
        italic => 'LiberationSans-Italic.ttf',
        normal => 'LiberationSans-Regular.ttf',
    },

    'liberation serif' => {
        bold => 'LiberationSerif-Bold.ttf',
        bolditalic => 'LiberationSerif-BoldItalic.ttf',
        italic => 'LiberationSerif-Italic.ttf',
        normal => 'LiberationSerif-Regular.ttf',
    },

    'droid serif' => {
        bold => 'DroidSerif-Bold.ttf',
        bolditalic => 'DroidSerif-BoldItalic.ttf',
        italic => 'DroidSerif-Italic.ttf',
        normal => 'DroidSerif-Regular.ttf',
    },

    'linux libertine' => {
        bold => 'LinLibertine_Bd-4.0_.2_.ttf',
        bolditalic => 'LinLibertine_BI-4.0_.3_.ttf',
        italic => 'LinLibertine_It-4.0_.3_.ttf',
        normal => 'LinLibertine_Re-4.1_.8_.ttf',
    },

    'dejavu serif' => {
        bold => 'DejaVuSerif-Bold.ttf',
        bolditalic => 'DejaVuSerif-BoldItalic.ttf',
        italic => 'DejaVuSerif-Italic.ttf',
        normal => 'DejaVuSerif.ttf',
    },
};

sub valid_fonts
{
    return keys %{$fonts};
}

#
# Helper that generates one font-family description
#

sub make_entry 
{
    my ($family, $weight, $style, $file) = @_;
my $entry = <<__EOCSS__;
\@font-face {
    font-family: '$family';
    font-style: $style;
    font-weight: $weight;
    src: url($file)
}

__EOCSS__
    return $entry;
}

sub make_font_description 
{
    my ($family) = @_;
    return '' unless($fonts->{lc($family)});
    my $css = '';
    
    $css .= make_entry($family, 'normal', 'normal', 
        $fonts->{lc($family)}->{normal}) if ($fonts->{lc($family)}->{normal});
    $css .= make_entry($family, 'bold', 'normal', 
        $fonts->{lc($family)}->{bold}) if ($fonts->{lc($family)}->{bold});
    $css .= make_entry($family, 'normal', 'italic', 
        $fonts->{lc($family)}->{italic}) if ($fonts->{lc($family)}->{italic});
    $css .= make_entry($family, 'bold', 'italic', 
        $fonts->{lc($family)}->{bolditalic}) if ($fonts->{lc($family)}->{bolditalic});

}

sub get_font_files
{
    my ($family) = @_;
    return  unless($fonts->{lc($family)});
    my @result;
    foreach my $key (keys %{$fonts->{lc($family)}}) {
        push @result, $fonts->{lc($family)}->{$key};
    }

    return @result;
}

1;
