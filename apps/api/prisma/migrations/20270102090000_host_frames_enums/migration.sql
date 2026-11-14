-- v1.55-social (D186, owner 2026-10-30): the active-host avatar frames. The new enum value goes in a
-- migration of its own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction).

-- Bag (CONVENTIONS §10.22, §10.49): an item the server gives while the user is an active agency host and
-- takes back when they are not (never sent, never expires while kept).
ALTER TYPE "bag_item_source" ADD VALUE 'HOST_ACTIVE';
