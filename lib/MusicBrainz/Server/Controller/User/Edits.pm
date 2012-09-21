package MusicBrainz::Server::Controller::User::Edits;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller' };

use MusicBrainz::Server::Constants ':edit_status';

__PACKAGE__->config(
    paging_limit => 25,
);

sub _edits {
    my ($self, $c, $loader) = @_;

    my $edits = $self->_load_paged($c, $loader);

    $c->model('Edit')->load_all(@$edits);
    $c->model('Vote')->load_for_edits(@$edits);
    $c->model('EditNote')->load_for_edits(@$edits);
    $c->model('Editor')->load(map { ($_, @{ $_->votes, $_->edit_notes }) } @$edits);

    $c->stash(
        edits => $edits,
        template => 'user/edits.tt',
        search => 0
    );

    return $edits;
}

sub open : Chained('/user/load') PathPart('edits/open') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    $self->_edits($c, sub {
        return $c->model('Edit')->find({
            editor => $c->stash->{user}->id,
            status => $STATUS_OPEN
        }, shift, shift);
    });
    $c->stash(
        refine_url_args => 
            { auto_edit_filter => '', order=> 'desc', negation=> 0, 
              combinator=>'and', 
              'conditions.0.field' => 'editor', 
              'conditions.0.operator' => '=', 
              'conditions.0.name' => $c->stash->{user}->name, 
              'conditions.0.args.0' => $c->stash->{user}->id, 
              'conditions.1.field' => 'status', 
              'conditions.1.operator' => '=', 
              'conditions.1.args' => $STATUS_OPEN },
    );
}

sub accepted : Chained('/user/load') PathPart('edits/accepted') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    $self->_edits($c, sub {
        return $c->model('Edit')->find({
            editor => $c->stash->{user}->id,
            status => $STATUS_APPLIED,
            autoedit => 0
        }, shift, shift);
    });
    $c->stash(
        refine_url_args => 
            { auto_edit_filter => 0, order=> 'desc', negation=> 0, 
              combinator=>'and', 
              'conditions.0.field' => 'editor', 
              'conditions.0.operator' => '=', 
              'conditions.0.name' => $c->stash->{user}->name, 
              'conditions.0.args.0' => $c->stash->{user}->id, 
              'conditions.1.field' => 'status', 
              'conditions.1.operator' => '=', 
              'conditions.1.args' => $STATUS_APPLIED },
    );
}

sub failed : Chained('/user/load') PathPart('edits/failed') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    $self->_edits($c, sub {
        return $c->model('Edit')->find({
            editor => $c->stash->{user}->id,
            status => [ $STATUS_FAILEDDEP, $STATUS_FAILEDPREREQ,
                        $STATUS_ERROR, $STATUS_NOVOTES ]
        }, shift, shift);
    });
    $c->stash(
        refine_url_args => 
            { auto_edit_filter => '', order=> 'desc', negation=> 0, 
              combinator=>'and', 
              'conditions.0.field' => 'editor', 
              'conditions.0.operator' => '=', 
              'conditions.0.name' => $c->stash->{user}->name, 
              'conditions.0.args.0' => $c->stash->{user}->id, 
              'conditions.1.field' => 'status', 
              'conditions.1.operator' => '=', 
              'conditions.1.args' => 
                  [ $STATUS_FAILEDDEP, $STATUS_FAILEDPREREQ, 
                    $STATUS_ERROR, $STATUS_NOVOTES ] },
    );
}

sub rejected : Chained('/user/load') PathPart('edits/rejected') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    $self->_edits($c, sub {
        return $c->model('Edit')->find({
            editor => $c->stash->{user}->id,
            status => [ $STATUS_FAILEDVOTE ]
        }, shift, shift);
    });
    $c->stash(
        refine_url_args => 
            { auto_edit_filter => '', order=> 'desc', negation=> 0, 
              combinator=>'and', 
              'conditions.0.field' => 'editor', 
              'conditions.0.operator' => '=', 
              'conditions.0.name' => $c->stash->{user}->name, 
              'conditions.0.args.0' => $c->stash->{user}->id, 
              'conditions.1.field' => 'status', 
              'conditions.1.operator' => '=', 
              'conditions.1.args' => $STATUS_FAILEDVOTE },
    );
}

sub autoedits : Chained('/user/load') PathPart('edits/autoedits') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    $self->_edits($c, sub {
        return $c->model('Edit')->find({
            editor => $c->stash->{user}->id,
            autoedit => 1
        }, shift, shift);
    });
    $c->stash(
        refine_url_args => 
            { auto_edit_filter => 1, order=> 'desc', negation=> 0, 
              combinator=>'and', 
              'conditions.0.field' => 'editor', 
              'conditions.0.operator' => '=', 
              'conditions.0.name' => $c->stash->{user}->name, 
              'conditions.0.args.0' => $c->stash->{user}->id },
    );
}

sub all : Chained('/user/load') PathPart('edits') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    $self->_edits($c, sub {
        return $c->model('Edit')->find({
            editor => $c->stash->{user}->id
        }, shift, shift);
    });
    $c->stash(
        refine_url_args => 
            { auto_edit_filter => '', order=> 'desc', negation=> 0, 
              combinator=>'and', 
              'conditions.0.field' => 'editor', 
              'conditions.0.operator' => '=', 
              'conditions.0.name' => $c->stash->{user}->name, 
              'conditions.0.args.0' => $c->stash->{user}->id },
    );
}

sub votes : Chained('/user/load') PathPart('votes') RequireAuth HiddenOnSlaves {
    my ($self, $c) = @_;
    my $edits = $self->_edits($c, sub {
        return $c->model('Edit')->find_by_voter($c->stash->{user}->id, shift, shift);
    });
    $c->stash( voter => $c->stash->{user} );
}

no Moose;
__PACKAGE__->meta->make_immutable;

1;
