-- v1.44-live (D199, CONVENTIONS §10.62): the PK Setting page. A value added to an existing type goes in a
-- migration of its own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction):
-- CONNECTED (the hosts are connected and wait for either of them to start — «PK auto-start» off) and
-- CANCELLED (a connected PK that never started: void, never counted).
ALTER TYPE "pk_match_status" ADD VALUE 'CONNECTED' BEFORE 'BATTLE';
ALTER TYPE "pk_end_reason" ADD VALUE 'CANCELLED';
