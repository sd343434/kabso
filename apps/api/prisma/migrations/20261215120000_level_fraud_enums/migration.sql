-- v1.46-levels (owner D169, 2026-10-30): levels never go down except by an admin deduction marked
-- as fraud (CONVENTIONS §10.43). The new history reason goes in a migration of its own (a value
-- added by ALTER TYPE … ADD VALUE cannot be used in the same transaction).
ALTER TYPE "level_transition_reason" ADD VALUE 'FRAUD';
