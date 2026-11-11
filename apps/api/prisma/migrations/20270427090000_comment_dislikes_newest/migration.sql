-- v1.122-social (D364, CONVENTIONS §10.158): the comments sheet's «الأحدث» order and the comment dislike.
-- One new table, which the schema's default privileges give the runtime role (20261016120000_runtime_role_grants),
-- and one partial index for `listComments?sort=NEWEST` (the existing `comments_top_idx` leads with the like count).
-- No data change.

-- A person's dislike of a comment. The number is never returned (private); a like and a dislike by the same person
-- exclude each other (the API removes one when it writes the other, under the comment's row lock).
CREATE TABLE "comment_dislikes" (
    "comment_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "comment_dislikes_pkey" PRIMARY KEY ("comment_id","user_id")
);
CREATE INDEX "comment_dislikes_user_id_idx" ON "comment_dislikes"("user_id");
ALTER TABLE "comment_dislikes" ADD CONSTRAINT "comment_dislikes_comment_id_fkey"
  FOREIGN KEY ("comment_id") REFERENCES "comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "comment_dislikes" ADD CONSTRAINT "comment_dislikes_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Live top-level comments of a post, newest first (the pinned one is read apart and excluded by `pinned_at IS NULL`).
CREATE INDEX "comments_newest_idx" ON "comments"("post_id", "created_at" DESC, "id" DESC)
  WHERE (parent_id IS NULL AND deleted_at IS NULL);
