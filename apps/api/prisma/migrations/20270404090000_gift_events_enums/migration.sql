-- v1.97-social (D303, owner 2026-11-07: «فعاليات الهدايا» — an event of its own gifts with several boards and prize
-- bundles paid automatically at the end; CONVENTIONS §10.114). Its own migration: a new enum value cannot be used in the
-- transaction that adds it (20270404090100 uses them in CHECKs).
ALTER TYPE "event_metric" ADD VALUE IF NOT EXISTS 'EVENT_GIFTS';
ALTER TYPE "bag_item_source" ADD VALUE IF NOT EXISTS 'EVENT';
ALTER TYPE "cherry_ledger_reason" ADD VALUE IF NOT EXISTS 'EVENT_PRIZE';
ALTER TYPE "notification_type" ADD VALUE IF NOT EXISTS 'EVENT_PRIZE_WON';
