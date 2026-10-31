-- v1.66-social (D198, owner: Kabso Live is a GLOBAL app — privacy compliance, CONVENTIONS §10.61, CP-040). The value
-- added to an existing type goes in a migration of its own (ALTER TYPE … ADD VALUE cannot be used in the same
-- transaction): the system notification «بياناتك جاهزة للتنزيل».
ALTER TYPE "notification_type" ADD VALUE 'DATA_EXPORT_READY';
