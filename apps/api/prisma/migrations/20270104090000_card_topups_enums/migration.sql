-- v1.59-social (D190, owner 2026-10-31): card top-ups on the Kabso website through Stripe (CONVENTIONS §10.53,
-- CP-033). The values added to an existing type go in a migration of their own (a value added by ALTER TYPE …
-- ADD VALUE cannot be used in the same transaction): coins bought on the website (credit), coins taken back
-- after a refund, an early-fraud warning or a dispute (debit; the balance may go below 0), and coins given back
-- when a dispute is won (credit).
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CARD_TOPUP';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CARD_TOPUP_REVERSAL';
ALTER TYPE "wallet_ledger_reason" ADD VALUE 'CARD_TOPUP_RESTORE';
