#!/usr/bin/env node
// Kabso Live — compute a PostgreSQL SCRAM-SHA-256 password verifier (SEC-011 / KL-013b).
//
// Outside development, infra/postgres/bootstrap-roles.sql only accepts verifiers, never clear-text
// passwords, so the clear text never travels in a SQL statement that the server could log. The
// password is read from STDIN (never argv, which other users can see in `ps`):
//
//   read -rs PW && printf '%s' "$PW" | node infra/postgres/scram-verifier.mjs; unset PW
//
// Prints `SCRAM-SHA-256$<iterations>:<salt>$<StoredKey>:<ServerKey>` (RFC 5802 / RFC 7677, the
// format PostgreSQL stores in pg_authid). Put that value into KABSO_DB_*_PASSWORD for the
// bootstrap and keep the clear text only in the connection URL secret.
//
// The password is used as-is (no SASLprep); use ASCII passwords, e.g. `openssl rand -base64 32`.
import { createHash, createHmac, pbkdf2Sync, randomBytes } from 'node:crypto';
import { readFileSync } from 'node:fs';

/** Clear-text values that appear in this repository (dev/CI defaults); never valid elsewhere. */
export const KNOWN_DEV_PASSWORDS = [
  'kabso_dev_password',
  'kabso_app_dev_password',
  'kabso_app_test_dev_password',
  'kabso_migrator_dev_password',
  'ci_test_password_not_secret',
  'ci_app_password_not_secret',
  'ci_migrator_password_not_secret',
];

export function scramVerifier(password, { iterations = 4096, salt = randomBytes(16) } = {}) {
  const salted = pbkdf2Sync(Buffer.from(password, 'utf8'), salt, iterations, 32, 'sha256');
  const clientKey = createHmac('sha256', salted).update('Client Key').digest();
  const storedKey = createHash('sha256').update(clientKey).digest();
  const serverKey = createHmac('sha256', salted).update('Server Key').digest();
  return (
    `SCRAM-SHA-256$${iterations}:${salt.toString('base64')}` +
    `$${storedKey.toString('base64')}:${serverKey.toString('base64')}`
  );
}

function main() {
  let password = readFileSync(0, 'utf8');
  if (password.endsWith('\n')) password = password.slice(0, -1);
  if (password.endsWith('\r')) password = password.slice(0, -1);
  if (password.length < 12) {
    process.stderr.write('scram-verifier: the password must be at least 12 characters\n');
    process.exit(1);
  }
  if (KNOWN_DEV_PASSWORDS.includes(password)) {
    process.stderr.write('scram-verifier: refusing a development default password\n');
    process.exit(1);
  }
  process.stdout.write(`${scramVerifier(password)}\n`);
}

if (import.meta.url === `file://${process.argv[1]}`) main();
