-- v1.101-social (D325, owner 2026-11-09: events v2 «الفعاليات» — one events system; CONVENTIONS §10.127). Its own
-- migration: a new enum value cannot be used in the transaction that adds it (20270409090100 uses them in CHECKs).
-- Who an event is for: its own type now (the Task Center keeps `program_audience`), adding agencies (owners and member
-- hosts of an open agency) and CP couples.
CREATE TYPE "event_audience" AS ENUM ('EVERYONE', 'HOSTS', 'CREATORS', 'AGENCIES', 'CP');
-- The start notification of an event, to its audience (target the event).
ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'EVENT_STARTED';
