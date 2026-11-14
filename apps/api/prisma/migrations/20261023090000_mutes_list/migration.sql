-- CP-007 (D89): the caller's muted accounts, newest first (GET /me/mutes).
CREATE INDEX "user_mutes_muter_created_idx" ON "user_mutes"("muter_id", "created_at" DESC);
