-- v1.76-live (D286, owner: «عندما يقوم المشرف بالعمل يتم تفعيل زر مناوبة», CONVENTIONS §10.96.14): the automatic shift.
-- Staff work (entering a live as staff, a staff tool, «بثوثي») switches «في المناوبة» on; a shift switched on that
-- way goes off again after STAFF_SHIFT_IDLE_OFF_SECONDS without staff work (a shift switched on by hand never does).
--  - `started_via`: how the shift was last switched — `panel` or `app` (by hand) or `auto` (staff work);
--  - `last_activity_at`: the last staff work seen (written at most once a minute), null before any.
-- The runtime role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.
ALTER TABLE "admin_shifts"
  ADD COLUMN "started_via" VARCHAR(8) NOT NULL DEFAULT 'panel',
  ADD COLUMN "last_activity_at" TIMESTAMPTZ(3);
ALTER TABLE "admin_shifts"
  ADD CONSTRAINT "admin_shifts_started_via_values" CHECK ("started_via" IN ('panel', 'app', 'auto'));
CREATE INDEX "admin_shifts_auto_idx" ON "admin_shifts"("last_activity_at")
  WHERE on_shift AND started_via = 'auto';

-- D286 fix (found by the D286 e2e): a timed NO_LIVE / SUSPEND from the app's staff tools (D273, `via = 'app'`) failed
-- the restriction's shape CHECK, which knew only the panel and the CLI. The app is a third admin channel (§10.96.6).
ALTER TABLE "account_restrictions" DROP CONSTRAINT "account_restrictions_shape";
ALTER TABLE "account_restrictions" ADD CONSTRAINT "account_restrictions_shape" CHECK (
  ends_at > starts_at
  AND via IN ('panel', 'cli', 'app')
  AND length(btrim(reason)) > 0
  AND (lifted_at IS NOT NULL OR lift_reason IS NULL));
