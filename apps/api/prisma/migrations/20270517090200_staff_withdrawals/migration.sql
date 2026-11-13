-- v1.139-social (D387, owner 2026-11-12, CONVENTIONS §10.176.9): «الموظفين الذين لديهم كرز يسحب من خلالنا فقط» — a
-- staff account's cherries leave only through a withdrawal request to the company, which only the OWNER sees and
-- decides. The flag is set when the request is made (any panel role held then) and never changes. Existing rows are
-- false (made before the rule). A plain column with a constant default: no table rewrite.
ALTER TABLE "cherry_withdrawals" ADD COLUMN "staff_request" BOOLEAN NOT NULL DEFAULT false;
