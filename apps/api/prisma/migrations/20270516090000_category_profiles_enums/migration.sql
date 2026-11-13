-- v1.138-social (D386, owner 2026-11-12: a profile page per account category), CONVENTIONS §10.175. The new enum values go
-- first, in a migration of their own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in
-- the same transaction; the split of 20270209090000_profile_cover_enums).

-- Account categories (§10.47, §10.175.1): 13 more, after the 11 of D175 («نعم وأضف أي فئة مقترحة»).
ALTER TYPE "account_category" ADD VALUE 'QURAN_RECITER';
ALTER TYPE "account_category" ADD VALUE 'STORYTELLER';
ALTER TYPE "account_category" ADD VALUE 'WRITER';
ALTER TYPE "account_category" ADD VALUE 'JOURNALIST';
ALTER TYPE "account_category" ADD VALUE 'PHOTOGRAPHER';
ALTER TYPE "account_category" ADD VALUE 'ACTOR';
ALTER TYPE "account_category" ADD VALUE 'COMEDIAN';
ALTER TYPE "account_category" ADD VALUE 'CALLIGRAPHER';
ALTER TYPE "account_category" ADD VALUE 'DESIGNER';
ALTER TYPE "account_category" ADD VALUE 'CHEF';
ALTER TYPE "account_category" ADD VALUE 'TEACHER';
ALTER TYPE "account_category" ADD VALUE 'DJ';
ALTER TYPE "account_category" ADD VALUE 'TRAVELER';

-- Notifications (§10.175.5, §11.10): (system) the team verified the category / reviewed it otherwise.
ALTER TYPE "notification_type" ADD VALUE 'CATEGORY_VERIFIED';
ALTER TYPE "notification_type" ADD VALUE 'CATEGORY_REVIEWED';
