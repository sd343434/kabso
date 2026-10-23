-- CP-011 (D94): multi-guest video (MULTI) and audio (AUDIO) rooms with seats. The room's seat
-- count, theme and seat version; seats that are LOCKED or TAKEN (an EMPTY seat has no row); seat
-- requests and invitations (one PENDING per room and user); room moderators. The runtime role
-- gets DML through the default privileges (20261016120000_runtime_role_grants).
-- CreateEnum
CREATE TYPE "live_seat_offer_status" AS ENUM ('PENDING', 'ACCEPTED', 'DECLINED', 'CANCELLED', 'EXPIRED', 'REPLACED');

-- AlterEnum
ALTER TYPE "live_room_mode" ADD VALUE 'AUDIO';

-- AlterTable
ALTER TABLE "live_rooms" ADD COLUMN     "seat_count" SMALLINT,
ADD COLUMN     "seats_version" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "theme" VARCHAR(32) NOT NULL DEFAULT 'classic';

-- CreateTable
CREATE TABLE "live_room_seats" (
    "room_id" UUID NOT NULL,
    "seat_index" SMALLINT NOT NULL,
    "locked" BOOLEAN NOT NULL DEFAULT false,
    "user_id" UUID,
    "muted_by_host" BOOLEAN NOT NULL DEFAULT false,
    "updated_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_seats_pkey" PRIMARY KEY ("room_id","seat_index")
);

-- CreateTable
CREATE TABLE "live_seat_requests" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "seat_index" SMALLINT,
    "status" "live_seat_offer_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "handled_at" TIMESTAMPTZ(3),

    CONSTRAINT "live_seat_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_seat_invites" (
    "id" UUID NOT NULL,
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "seat_index" SMALLINT,
    "invited_by_id" UUID NOT NULL,
    "status" "live_seat_offer_status" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMPTZ(3) NOT NULL,
    "handled_at" TIMESTAMPTZ(3),

    CONSTRAINT "live_seat_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "live_room_moderators" (
    "room_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "added_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "live_room_moderators_pkey" PRIMARY KEY ("room_id","user_id")
);

-- CreateIndex
CREATE INDEX "live_room_seats_user_idx" ON "live_room_seats"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "live_room_seats_one_per_user" ON "live_room_seats"("room_id", "user_id");

-- CreateIndex
CREATE INDEX "live_seat_requests_pending_idx" ON "live_seat_requests"("room_id", "created_at", "id") WHERE (status = 'PENDING'::live_seat_offer_status);

-- CreateIndex
CREATE INDEX "live_seat_requests_user_idx" ON "live_seat_requests"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "live_seat_requests_one_pending" ON "live_seat_requests"("room_id", "user_id") WHERE (status = 'PENDING'::live_seat_offer_status);

-- CreateIndex
CREATE INDEX "live_seat_invites_pending_expiry_idx" ON "live_seat_invites"("expires_at") WHERE (status = 'PENDING'::live_seat_offer_status);

-- CreateIndex
CREATE INDEX "live_seat_invites_user_idx" ON "live_seat_invites"("user_id");

-- CreateIndex
CREATE INDEX "live_seat_invites_invited_by_idx" ON "live_seat_invites"("invited_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "live_seat_invites_one_pending" ON "live_seat_invites"("room_id", "user_id") WHERE (status = 'PENDING'::live_seat_offer_status);

-- CreateIndex
CREATE INDEX "live_room_moderators_user_idx" ON "live_room_moderators"("user_id");

-- AddForeignKey
ALTER TABLE "live_room_seats" ADD CONSTRAINT "live_room_seats_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_seats" ADD CONSTRAINT "live_room_seats_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_seat_requests" ADD CONSTRAINT "live_seat_requests_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_seat_requests" ADD CONSTRAINT "live_seat_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_invited_by_id_fkey" FOREIGN KEY ("invited_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_moderators" ADD CONSTRAINT "live_room_moderators_room_id_fkey" FOREIGN KEY ("room_id") REFERENCES "live_rooms"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "live_room_moderators" ADD CONSTRAINT "live_room_moderators_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- The seat count matches the mode (host tile included): SOLO and PK have none, MULTI 4/6/9/12,
-- AUDIO 5/9/13. `mode::text` because the new enum value cannot be used as a literal in the
-- transaction that adds it.
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_seat_count_mode" CHECK (
  (mode::text IN ('SOLO', 'PK') AND seat_count IS NULL)
  OR (mode::text = 'MULTI' AND seat_count IN (4, 6, 9, 12))
  OR (mode::text = 'AUDIO' AND seat_count IN (5, 9, 13)));
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_theme_format" CHECK (theme ~ '^[a-z0-9-]{2,32}$');
ALTER TABLE "live_rooms" ADD CONSTRAINT "live_rooms_seats_version_nonneg" CHECK (seats_version >= 0);

-- Seats 1 … 12 (the host is 0); a row is either LOCKED (no user) or TAKEN (a user, maybe muted).
ALTER TABLE "live_room_seats" ADD CONSTRAINT "live_room_seats_index" CHECK (seat_index BETWEEN 1 AND 12);
ALTER TABLE "live_room_seats" ADD CONSTRAINT "live_room_seats_locked_or_taken" CHECK (
  (locked AND user_id IS NULL AND NOT muted_by_host) OR (NOT locked AND user_id IS NOT NULL));

ALTER TABLE "live_seat_requests" ADD CONSTRAINT "live_seat_requests_index" CHECK (seat_index IS NULL OR seat_index BETWEEN 1 AND 12);
ALTER TABLE "live_seat_requests" ADD CONSTRAINT "live_seat_requests_status" CHECK (status::text <> 'REPLACED');
ALTER TABLE "live_seat_requests" ADD CONSTRAINT "live_seat_requests_handled" CHECK ((status::text = 'PENDING') = (handled_at IS NULL));
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_index" CHECK (seat_index IS NULL OR seat_index BETWEEN 1 AND 12);
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_handled" CHECK ((status::text = 'PENDING') = (handled_at IS NULL));
ALTER TABLE "live_seat_invites" ADD CONSTRAINT "live_seat_invites_expiry" CHECK (expires_at > created_at);
