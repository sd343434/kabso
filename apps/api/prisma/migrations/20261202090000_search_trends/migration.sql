-- v1.29-live (D147): search trends — normalized search terms with hourly counts of different
-- searchers (no user id stored), and the owner's blocked words for trends. CONVENTIONS §11.11.
-- No GRANT (default privileges, 20261016130000_per_database_runtime_group).

-- CreateTable
CREATE TABLE "search_terms" (
    "id" UUID NOT NULL,
    "term" VARCHAR(64) NOT NULL,
    "first_seen_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "hidden_at" TIMESTAMPTZ(3),

    CONSTRAINT "search_terms_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "search_terms_term_length" CHECK (char_length("term") BETWEEN 2 AND 64)
);

CREATE TABLE "search_term_counts" (
    "term_id" UUID NOT NULL,
    "hour" TIMESTAMPTZ(3) NOT NULL,
    "searchers" INTEGER NOT NULL,

    CONSTRAINT "search_term_counts_pkey" PRIMARY KEY ("term_id","hour"),
    CONSTRAINT "search_term_counts_positive" CHECK ("searchers" > 0)
);

CREATE TABLE "search_blocked_words" (
    "word" VARCHAR(60) NOT NULL,
    "created_at" TIMESTAMPTZ(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "search_blocked_words_pkey" PRIMARY KEY ("word")
);

-- CreateIndex
CREATE UNIQUE INDEX "search_terms_term_key" ON "search_terms"("term");
CREATE INDEX "search_term_counts_hour_idx" ON "search_term_counts"("hour");

-- AddForeignKey
ALTER TABLE "search_term_counts" ADD CONSTRAINT "search_term_counts_term_id_fkey" FOREIGN KEY ("term_id") REFERENCES "search_terms"("id") ON DELETE CASCADE ON UPDATE CASCADE;
