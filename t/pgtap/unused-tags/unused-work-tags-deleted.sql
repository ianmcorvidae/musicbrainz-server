SET search_path = 'musicbrainz', 'public';

--------------------------------------------------------------------------------
BEGIN;
SELECT no_plan();

INSERT INTO work_name (id, name) VALUES (1, 'Work');
INSERT INTO work (id, gid, name)
  VALUES (1, '82ac9811-db47-4c05-9792-83cf4208afd0', 1),
         (2, '9baea67a-8d86-422d-b653-b0f6d0a93c7c', 1);

INSERT INTO tag (id, name) VALUES (2, 'Unused tag'), (4, 'Used tag'), (5, 'Shared tag');
INSERT INTO work_tag (work, tag, count) VALUES
  (1, 2, 1), (1, 4, 1), (1, 5, 1), (2, 5, 1);

DELETE FROM work_tag WHERE tag = 2;

-- Deleting but the re-adding should not garbage collect
DELETE FROM work_tag WHERE tag = 4;
INSERT INTO work_tag (work, tag, count) VALUES (1, 4, 1);

DELETE FROM work_tag WHERE tag = 5 AND work = 1;

SELECT set_eq(
  'SELECT id FROM tag', '{2, 4, 5}'::INT[],
  'Tag exists before commit'
);

-- Simulate the commit
SET CONSTRAINTS ALL IMMEDIATE;

SELECT set_eq(
  'SELECT id FROM tag', '{4, 5}'::INT[],
  'Tag collected after commit'
);

SELECT finish();
ROLLBACK;
