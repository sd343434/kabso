-- CP-016 part D (D101): the room level is the host's charm level (CONVENTIONS §10.18). Every 10
-- counted taps of a viewer in a live give the host 1 charm point through the CP-005 ledger, as
-- source `LIVE_TAPS`. The 10 000 counted taps a viewer may give in a live (§10.10) bound them:
-- no table of its own.

ALTER TYPE "points_source_type" ADD VALUE 'LIVE_TAPS';
