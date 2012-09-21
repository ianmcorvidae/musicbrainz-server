package t::MusicBrainz::Server::Edit::Release::EditReleaseLabel;
use Test::Routine;
use Test::More;
use Test::Fatal;

with 't::Edit';
with 't::Context';

BEGIN { use MusicBrainz::Server::Edit::Release::EditReleaseLabel }

use MusicBrainz::Server::Constants qw( $EDIT_RELEASE_EDITRELEASELABEL );
use MusicBrainz::Server::Test qw( accept_edit reject_edit );

test all => sub {

my $test = shift;
my $c = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+edit_release_label');

my $rl = $c->model('ReleaseLabel')->get_by_id(1);

my $edit = create_edit($c, $rl);
isa_ok($edit, 'MusicBrainz::Server::Edit::Release::EditReleaseLabel');

my ($edits) = $c->model('Edit')->find({ release => 1 }, 10, 0);
is(scalar @$edits, 1);
is($edits->[0]->id, $edit->id);

my $release = $c->model('Release')->get_by_id(1);
is($release->edits_pending, 1);

$rl = $c->model('ReleaseLabel')->get_by_id(1);
is($rl->label_id, 1);
is($rl->catalog_number, 'ABC-123');

reject_edit($c, $edit);

$rl = $c->model('ReleaseLabel')->get_by_id(1);
is($rl->label_id, 1);
is($rl->catalog_number, 'ABC-123');

$release = $c->model('Release')->get_by_id($rl->release_id);
is($release->edits_pending, 0);

$edit = create_edit($c, $rl);
accept_edit($c, $edit);

$rl = $c->model('ReleaseLabel')->get_by_id(1);
is($rl->label_id, 2);
is($rl->catalog_number, 'FOO');

$release = $c->model('Release')->get_by_id($rl->release_id);
is($release->edits_pending, 0);

};

test 'Editing the label can fail as a conflict' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_release_label');

    my $rl = $c->model('ReleaseLabel')->get_by_id(1);
    my $edit1 = _create_edit($c, $rl, label => $c->model('Label')->get_by_id(2));
    my $edit2 = _create_edit($c, $rl, label => undef);

    ok !exception { $edit1->accept };
    ok  exception { $edit2->accept };
};

test 'Editing the catalog number can fail as a conflict' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_release_label');

    my $rl = $c->model('ReleaseLabel')->get_by_id(1);
    my $edit1 = _create_edit($c, $rl, catalog_number => 'Woof!');
    my $edit2 = _create_edit($c, $rl, catalog_number => 'Meow!');

    ok !exception { $edit1->accept };
    ok  exception { $edit2->accept };
};

test 'Parallel edits that dont conflict merge' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_release_label');

    my $expected_label_id = 2;
    my $expected_cat_no = 'Woof!';

    {
        my $rl = $c->model('ReleaseLabel')->get_by_id(1);
        my $edit1 = _create_edit($c, $rl, catalog_number => $expected_cat_no);
        my $edit2 = _create_edit(
            $c, $rl,
            label => $c->model('Label')->get_by_id($expected_label_id)
        );

        ok !exception { $edit1->accept };
        ok !exception { $edit2->accept };
    }

    my $rl = $c->model('ReleaseLabel')->get_by_id(1);
    is($rl->label_id, 2);
    is($rl->catalog_number, 'Woof!');
};

test 'Editing a non-existant release label fails' => sub {
    my $test = shift;
    my $c = $test->c;

    my $model = $c->model('ReleaseLabel');
    MusicBrainz::Server::Test->prepare_test_database($c, '+edit_release_label');

    my $rl = $model->get_by_id(1);
    my $edit = _create_edit($c, $rl, label => $c->model('Label')->get_by_id(2));

    $model->delete(1);

    isa_ok exception { $edit->accept }, 'MusicBrainz::Server::Edit::Exceptions::FailedDependency';
};


sub create_edit {
    my ($c, $rl) = @_;
    return _create_edit(
        $c, $rl,
        label => $c->model('Label')->get_by_id(2),
        catalog_number => 'FOO',
    );
}


sub _create_edit {
    my ($c, $rl, %args) = @_;
    return $c->model('Edit')->create(
        edit_type => $EDIT_RELEASE_EDITRELEASELABEL,
        editor_id => 1,
        release_label => $rl,
        %args
    );
}

1;
