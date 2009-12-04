use Moose;

has [qw/first_name middle_name last_name nickname home_page email id/] =>
    (isa => 'String', is => 'rw');
