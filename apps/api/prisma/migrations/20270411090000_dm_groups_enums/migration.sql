-- v1.104-social (D339, 2026-11-09): group messages «رسائل جماعية» can be reported. The new enum value goes first, in a
-- migration of its own (PostgreSQL does not allow a value added by ALTER TYPE … ADD VALUE to be used in the same
-- transaction; the same split as 20261210090000_direct_messages_enums).

-- Reports (CONVENTIONS §11.7, §10.133): a group conversation, kept as a snapshot.
ALTER TYPE "report_target_type" ADD VALUE 'DM_GROUP';
