-- D121: the following list (`GET /users/{username}/following`) reads a user's follows newest
-- first; the followers list already has `follows_followee_id_created_at_idx`.
CREATE INDEX "follows_follower_id_created_at_idx" ON "follows"("follower_id", "created_at" DESC);
