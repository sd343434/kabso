-- v1.110-social (D345, CONVENTIONS §10.144): the wallet ledger reasons of coins bought in a store (Google Play / the App
-- Store) and taken back after a store refund. Their own migration: a new enum value cannot be used in the transaction
-- that adds it.
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'STORE_IAP';
ALTER TYPE "wallet_ledger_reason" ADD VALUE IF NOT EXISTS 'STORE_IAP_REVERSAL';
