-- v1.56-live (D213, CONVENTIONS §10.86): the STREAMER live mode (the host's phone screen with a small
-- round front-camera bubble). A value added to an existing type goes in a migration of its own (a value
-- added by ALTER TYPE … ADD VALUE cannot be used in the same transaction).
ALTER TYPE "live_room_mode" ADD VALUE 'STREAMER';
