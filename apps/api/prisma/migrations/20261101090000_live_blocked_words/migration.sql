-- CP-016 B (D99): the host's blocked words, masked in the chat of every live of that host.
-- At most 100 words of 1–30 code points (the API normalizes them; char_length counts code
-- points). The runtime role gets DML through the default privileges
-- (20261016120000_runtime_role_grants), so this migration contains no GRANT.

-- AlterTable
ALTER TABLE "live_hosts" ADD COLUMN     "blocked_words" VARCHAR(30)[] DEFAULT ARRAY[]::VARCHAR(30)[];

-- Checks (CONVENTIONS §10.14).
ALTER TABLE "live_hosts" ADD CONSTRAINT "live_hosts_blocked_words_max" CHECK (cardinality(blocked_words) <= 100);
