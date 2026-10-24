-- CP-015 (D98): the host's live cover, reused by every live. `live_hosts.cover_media_id` is the
-- host's `LIVE_COVER` asset (one host per asset) and `live_hosts.cover_url` its public 640 px square
-- URL; a live started later copies the URL into `live_rooms.cover_url`. Replacing or removing the
-- cover deletes the old asset in the API, so the reference never dangles (NO ACTION). The runtime
-- role gets DML through the default privileges (20261016120000_runtime_role_grants), so this
-- migration contains no GRANT.

-- AlterTable
ALTER TABLE "live_hosts" ADD COLUMN     "cover_media_id" UUID,
ADD COLUMN     "cover_url" VARCHAR(2048);

-- CreateIndex
CREATE UNIQUE INDEX "live_hosts_cover_media_id_key" ON "live_hosts"("cover_media_id");

-- AddForeignKey
ALTER TABLE "live_hosts" ADD CONSTRAINT "live_hosts_cover_media_id_fkey" FOREIGN KEY ("cover_media_id") REFERENCES "media_assets"("id") ON DELETE NO ACTION ON UPDATE CASCADE;

-- Checks (CONVENTIONS §10.13, §11.1).
ALTER TABLE "live_hosts" ADD CONSTRAINT "live_hosts_cover_pair" CHECK ((cover_media_id IS NULL) = (cover_url IS NULL));
ALTER TABLE "media_assets" DROP CONSTRAINT "media_assets_kind_known";
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_kind_known" CHECK (kind IN ('POST_IMAGE', 'STORY_IMAGE', 'LIVE_COVER'));
