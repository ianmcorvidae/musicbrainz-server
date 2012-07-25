package MusicBrainz::Server::Edit::Release;
use Moose::Role;
use namespace::autoclean;

use List::Util qw( max );
use MusicBrainz::Server::Translation 'l';

sub edit_category { l('Release') }

requires 'release_ids';

sub determine_quality { }
around determine_quality => sub {
    my ($orig, $self) = @_;

    return max map { $_->quality } values %{ $self->c->model('Release')->get_by_any_ids( $self->release_ids ) };
};

1;
