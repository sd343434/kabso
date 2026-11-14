-- v1.47-live (D212, CONVENTIONS §10.69): the PODCAST live mode (audio only, the host and up to 3
-- speakers, listeners raise a hand). A value added to an existing type goes in a migration of its own
-- (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction).
ALTER TYPE "live_room_mode" ADD VALUE 'PODCAST';
