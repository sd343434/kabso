# CP-036 — Account deletion «حذف الحساب»

**Status: OWNER DECISION (2026-10-31, via the coordinator) — built in D193 (contract v1.62-social, CONVENTIONS §10.56).**
Default rules marked *proposal* below are built so each can change in one place.

## 1. Owner decisions

| Topic | Decision (owner) |
|-------|------------------|
| Where | A «حذف الحساب» button inside the app (Settings › Account), as Apple 5.1.1(v) and Google Play require. |
| Grace | 30 days during which the person can cancel; then the account is deleted or anonymised for good. |
| Flow | Explanation (what is deleted, the 30 days, coins and cherries forfeited) → re-authentication → typed confirmation → the request. |
| During grace | Signed out everywhere; hidden from others at once (search, profile, lists, live). Signing in shows «طلب حذف قيد التنفيذ — إلغاء الحذف؟»; cancelling restores everything. Email notices at request and cancellation. |
| Blockers | An active recharge agent or host agency (team handles first), a pending cherry withdrawal, a negative balance. |
| Kept | Financial and audit ledgers needed for accounting and fraud, pseudonymised (no PII); others see «مستخدم محذوف». |
| Usernames | The base username freed after a quarantine; `coinNNNN` / `hostNN` never reused. |
| Without the app | Email to info@kabsolive.com for now; a web page later. |

## 2. Default rules (proposals)

| | Rule built | Where to change it |
|-|------------|--------------------|
| a | **Tombstone in place:** the user row keeps its random id (no PII left) instead of moving the ledgers to a new id. Pair tables have ordering CHECKs (`cp_couples`, `dm_conversations`) and the ledgers are append-only, so re-keying would rewrite history; the id alone identifies no one. | `purgeAccountIn` (`users/account-deletion.ts`) |
| b | **Re-authentication = the password** (every account has one; a forgotten one is reset by email, allowed during the grace). No login OTP exists yet. | `AccountDeletionService.request` |
| c | **Confirmation word** «حذف» or `DELETE` (either language). | `DELETION_CONFIRMATION_WORDS` |
| d | **Username quarantine 90 days**, stored as a SHA-256 only. | `ACCOUNT_DELETION_USERNAME_QUARANTINE_DAYS` |
| e | **Cherry-withdrawal payout details** kept as their last 4 characters (bank reconciliation). | `purgeAccountIn` |
| f | Content is hard-deleted at the purge (posts, reels, stories with their reports); reports **about the person** stay. Moderators act during the 30 days if needed. | `purgeAccountIn` |
| g | A family leader hands over to the longest-serving deputy (else member); alone → disbanded. The CP couple ends. | `leaveFamilyIn` |
| h | Blockers: a recharge agent not suspended or with stock; an agency not suspended or with hosts; a pending withdrawal or cherry sale; a negative coin or cherry balance. | `deletionBlockersIn` |

## 3. Open questions for the owner / legal

- Retention period of the kept ledgers and of IP addresses in the audit log (PP-08).
- Legal hold: should content under an open report survive the purge?
- The English UI shows the tombstone's stored display name «مستخدم محذوف» where a client renders `displayName`
  directly (only gift histories carry `senderDeleted` for a localized label).
