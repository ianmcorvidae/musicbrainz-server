package MusicBrainz::Server::Edit::Release::EditBarcodes;
use Moose;
use namespace::autoclean;

use MusicBrainz::Server::Edit::Utils qw( conditions_without_autoedit );
use MusicBrainz::Server::Constants qw( $EDIT_RELEASE_EDIT_BARCODES );
use MusicBrainz::Server::Edit::Types qw( Nullable );
use MusicBrainz::Server::Translation qw ( N_l );
use MooseX::Types::Moose qw( ArrayRef Int Str );
use MooseX::Types::Structured qw( Dict );

extends 'MusicBrainz::Server::Edit';
with 'MusicBrainz::Server::Edit::Release';
with 'MusicBrainz::Server::Edit::Release::RelatedEntities';

use aliased 'MusicBrainz::Server::Entity::Barcode';
use aliased 'MusicBrainz::Server::Entity::Release';

sub edit_name { N_l('Edit barcodes') }
sub edit_type { $EDIT_RELEASE_EDIT_BARCODES }

has '+data' => (
    isa => Dict[
        submissions => ArrayRef[Dict[
            release => Dict[
                id => Int,
                name => Str
            ],
            barcode => Str,
            old_barcode => Nullable[Str]
        ]],
        client_version => Nullable[Str]
    ]
);

around edit_conditions => sub {
    my ($orig, $self, @args) = @_;
    return conditions_without_autoedit($self->$orig(@args));
};

sub release_ids { map { $_->{release}{id} } @{ shift->data->{submissions} } }

sub alter_edit_pending
{
    my $self = shift;
    return {
        Release => [ $self->release_ids ],
    }
}

sub foreign_keys
{
    my ($self) = @_;
    return {
        Release => { map { $_ => [ 'ArtistCredit' ] } $self->release_ids },
    };
}

sub build_display_data
{
    my ($self, $loaded) = @_;
    return {
        submissions => [
            map +{
                release => $loaded->{Release}->{ $_->{release}{id} }
                    || Release->new( name => $_->{release}{name} ),
                new_barcode => Barcode->new($_->{barcode}),
                exists $_->{old_barcode} ?
                    (old_barcode => Barcode->new($_->{old_barcode})) : ()
            }, @{ $self->data->{submissions} }
        ]
    }
}

sub accept {
    my ($self) = @_;
    for my $submission (@{ $self->data->{submissions} }) {
        $self->c->model('Release')->update(
            $submission->{release}{id},
            { barcode => $submission->{barcode} }
        )
    }
}

sub initialize {
    my ($self, %opts) = @_;
    $opts{submissions} = [
        map +{
            release => {
                id => $_->{release}->id,
                name => $_->{release}->name,
            },
            barcode => $_->{barcode},
            old_barcode => $_->{release}->barcode->code
        }, @{ $opts{submissions} }
    ];
    $self->data(\%opts);
}

1;
