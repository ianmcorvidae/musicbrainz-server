package MusicBrainz::Server::Edit::URL::Edit;
use 5.10.0;
use Moose;

use Clone qw( clone );
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict Optional );

use MusicBrainz::Server::Constants qw( $EDIT_URL_EDIT );
use MusicBrainz::Server::Edit::Exceptions;
use MusicBrainz::Server::Edit::Types qw( Nullable );
use MusicBrainz::Server::Edit::Utils qw( changed_display_data );
use MusicBrainz::Server::Translation qw( l N_l );
use MusicBrainz::Server::Validation qw( normalise_strings );

extends 'MusicBrainz::Server::Edit::Generic::Edit';
with 'MusicBrainz::Server::Edit::URL';
with 'MusicBrainz::Server::Edit::CheckForConflicts';

use aliased 'MusicBrainz::Server::Entity::URL';

sub edit_name { N_l('Edit URL') }
sub edit_type { $EDIT_URL_EDIT }
sub _edit_model { 'URL' }
sub url_id { shift->entity_id }

sub change_fields
{
    return Dict[
        url => Optional[Str],
        description => Nullable[Str],
    ];
}

has '+data' => (
    isa => Dict[
        entity => Dict[
            id => Int,
            name => Str
        ],
        old => change_fields(),
        new => change_fields(),
    ]
);

sub foreign_keys
{
    my $self = shift;
    return {
        URL => [ $self->url_id ]
    };
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    my $data = changed_display_data($self->data, $loaded,
        uri => 'url',
        description => 'description'
    );
    $data->{url} = $loaded->{URL}->{ $self->url_id }
        || URL->new( url => $self->data->{entity}{name} );

    return $data;
}

sub allow_auto_edit
{
    my $self = shift;

    my ($old_desc, $new_desc) = normalise_strings($self->data->{old}{description},
						  $self->data->{new}{description});
    return 0 if $old_desc ne $new_desc;
    return 0 if exists $self->data->{old}{url};

    return 1;
}

around accept => sub {
    my ($orig, $self) = @_;

    MusicBrainz::Server::Edit::Exceptions::FailedDependency->throw(
        l('This URL has already been merged into another URL')
    ) unless $self->c->model('URL')->get_by_any_id($self->url_id);

    my $new_id = $self->c->model( $self->_edit_model )->update(
        $self->entity_id,
        $self->merge_changes
    );

    $self->data->{entity}{id} = $new_id;

    # Check for any releases that might need updating
    $self->c->model('CoverArt')->url_updated($new_id);
};

sub current_instance {
    my $self = shift;
    $self->c->model('URL')->get_by_any_id($self->url_id),
}

around extract_property => sub {
    my ($orig, $self) = splice(@_, 0, 2);
    my ($property, $ancestor, $current, $new) = @_;
    given ($property) {
        when ('url') {
            return (
                [ $ancestor->{url}, $ancestor->{url} ],
                [ $current->url->as_string, $current->url->as_string ],
                [ $new->{url}, $new->{url} ]
            );
        }

        default {
            return ($self->$orig(@_));
        }
    }
};

__PACKAGE__->meta->make_immutable;
no Moose;
1;
