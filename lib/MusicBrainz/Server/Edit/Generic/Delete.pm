package MusicBrainz::Server::Edit::Generic::Delete;
use Moose;
use MooseX::ABC;

use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_DELETE );
use MusicBrainz::Server::Edit::Utils qw( conditions_without_autoedit );
use MusicBrainz::Server::Data::Artist;
use MusicBrainz::Server::Edit::Exceptions;
use MusicBrainz::Server::Entity::Types;
use MusicBrainz::Server::Constants qw( :edit_status );
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );

extends 'MusicBrainz::Server::Edit';
requires '_delete_model';

around edit_conditions => sub {
    my ($orig, $self, @args) = @_;
    return conditions_without_autoedit($self->$orig(@args));
};

sub alter_edit_pending
{
    my $self = shift;
    my $model = $self->c->model( $self->_delete_model);
    if ($model->does('MusicBrainz::Server::Data::Role::Editable')) {
        return {
            $self->_delete_model => [ $self->entity_id ]
        }
    } else {
        return { }
    }
}

sub _build_related_entities
{
    my $self = shift;
    my $model = $self->c->model( $self->_delete_model);
    if ($self->status != $STATUS_APPLIED &&
            $model->does('MusicBrainz::Server::Data::Role::LinksToEdit')) {
        return {
            $model->edit_link_table => [ $self->entity_id ]
        }
    } else {
        return { }
    }
}

sub entity_id { shift->data->{entity_id} }

has '+data' => (
    isa => Dict[
        entity_id => Int,
        name      => Str
    ]
);

sub foreign_keys {
    my ($self) = @_;
    return {
        $self->_delete_model => [ $self->data->{entity_id} ]
    }
}

sub build_display_data
{
    my ($self, $loaded) = @_;

    my $model = $self->_delete_model;
    return {
        entity => $loaded->{$model}->{$self->data->{entity_id}} ||
            $self->c->model($model)->_entity_class->new(
                name => $self->data->{name}
            )
    };
}

sub initialize
{
    my ($self, %args) = @_;
    my $entity = delete $args{to_delete} or die "Required 'to_delete' object";

    $self->data({
        name      => $entity->name,
        entity_id => $entity->id,
    });
}

override 'accept' => sub
{
    my $self = shift;
    my $model = $self->c->model( $self->_delete_model );

    MusicBrainz::Server::Edit::Exceptions::FailedDependency->throw(
        'This entity cannot currently be deleted due to related data.'
    ) unless $model->can_delete( $self->entity_id );

    $model->delete($self->entity_id);
};

# We do allow auto edits for this (as ModBot needs to insert them)
sub modbot_auto_edit { 1 }

__PACKAGE__->meta->make_immutable;

no Moose;
1;
