-- v1.94-social (D297, owner «مهام خاصة بصناع المحتوى، وقيمتها كمهام المضيف», CONVENTIONS §10.110): the Task Center's
-- audience for creator-programme members (`creator_members`), beside EVERYONE and HOSTS. Its own migration: a new enum
-- value cannot be used in the transaction that adds it (20270331090100 seeds the CREATORS tasks).
ALTER TYPE "program_audience" ADD VALUE IF NOT EXISTS 'CREATORS';
