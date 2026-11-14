-- v1.58-social (D189, owner 2026-10-30): host agents «وكيل مضيفين» get perks like the recharge agents (CONVENTIONS
-- §10.52, CP-032). The value added to an existing type goes in a migration of its own (a value added by ALTER TYPE
-- … ADD VALUE cannot be used in the same transaction): the host agent's special username `hostNN`.
ALTER TYPE "special_username_source" ADD VALUE 'HOST_AGENT';
