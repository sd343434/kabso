-- AlterTable
ALTER TABLE "pending_registrations" ADD COLUMN     "total_attempts" INTEGER NOT NULL DEFAULT 0;

-- Hand-written CHECK (contract v1.2.3, SEC-026): at most 10 code checks per pending registration
-- across resends.
ALTER TABLE "pending_registrations" ADD CONSTRAINT "pending_registrations_total_attempts_range"
    CHECK ("total_attempts" BETWEEN 0 AND 10);
