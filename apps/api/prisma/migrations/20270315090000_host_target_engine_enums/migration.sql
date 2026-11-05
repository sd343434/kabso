-- v1.71-live (D281, owner, CONVENTIONS §10.62.2): the smart daily host targets pay a share of the platform profit in
-- LOCKED task cherries («كرز مقفل مثل المهام»), through the cherry ledger with a reason of their own. The new value
-- goes in a migration of its own (a value added by ALTER TYPE … ADD VALUE cannot be used in the same transaction).
ALTER TYPE "cherry_ledger_reason" ADD VALUE 'HOST_TARGET_REWARD';
