-- v1.61-social (D192, owner 2026-10-31): the public website kabsolive.com (CONVENTIONS §10.55, CP-035). The value
-- added to an existing type goes in a migration of its own (a value added by ALTER TYPE … ADD VALUE cannot be used
-- in the same transaction): the admin permission that edits the website's settings.
ALTER TYPE "admin_permission" ADD VALUE 'SITE_SETTINGS';
