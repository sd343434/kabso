-- v1.64-live (D260, CONVENTIONS §10.96; owner 2026-11-04): staff presence in lives — a panel staff member's shift
-- «في المناوبة», every LIVE room assigned to one staff member on shift (spread by load, reported lives first), and
-- the staff watching a live visibly (listed with the «فريق كابسو» badge, never counted as viewers). The runtime
-- role gets DML through the default privileges (20261016130000_per_database_runtime_group): no GRANT here.

CREATE TABLE "admin_shifts" (
    "user_id" UUID NOT NULL,
    "on_shift" BOOLEAN NOT NULL DEFAULT false,
    "since" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(3) NOT NULL,

    CONSTRAINT "admin_shifts_pkey" PRIMARY KEY ("user_id")
);
CREATE INDEX "admin_shifts_on_idx" ON "admin_shifts"("on_shift") WHERE on_shift;
ALTER TABLE "admin_shifts" ADD CONSTRAINT "admin_shifts_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "live_room_assignments" (
    "room_id" UUID NOT NULL,
    "admin_id" UUID NOT NULL,
    "assigned_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_assignments_pkey" PRIMARY KEY ("room_id")
);
CREATE INDEX "live_room_assignments_admin_idx" ON "live_room_assignments"("admin_id");
ALTER TABLE "live_room_assignments" ADD CONSTRAINT "live_room_assignments_room_id_fkey"
  FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_room_assignments" ADD CONSTRAINT "live_room_assignments_admin_id_fkey"
  FOREIGN KEY ("admin_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "live_room_staff_watchers" (
    "room_id" UUID NOT NULL,
    "identity" VARCHAR(80) NOT NULL,
    "admin_id" UUID NOT NULL,
    "joined_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_staff_watchers_pkey" PRIMARY KEY ("room_id", "identity")
);
CREATE INDEX "live_room_staff_watchers_admin_idx" ON "live_room_staff_watchers"("admin_id");
ALTER TABLE "live_room_staff_watchers" ADD CONSTRAINT "live_room_staff_watchers_room_id_fkey"
  FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_room_staff_watchers" ADD CONSTRAINT "live_room_staff_watchers_admin_id_fkey"
  FOREIGN KEY ("admin_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "live_room_staff_watchers" ADD CONSTRAINT "live_room_staff_watchers_identity_shape"
  CHECK (identity LIKE 'team:%');
