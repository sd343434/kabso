/**
 * Development seed: creates (or updates) a verified demo user and an admin user.
 * Refuses to run when NODE_ENV=production. Passwords come from SEED_DEMO_PASSWORD /
 * SEED_ADMIN_PASSWORD or are generated randomly and printed once — none are committed.
 *
 *   pnpm db:seed
 */
import 'dotenv/config';
import { randomBytes } from 'node:crypto';
import { PrismaPg } from '@prisma/adapter-pg';
import * as argon2 from 'argon2';
import { PrismaClient, type UserRole } from '../src/generated/prisma/client.js';
import { ARGON2_OPTIONS } from '../src/modules/auth/password-hasher.service.js';
import { grantFreeItemsIn } from '../src/modules/bag/bag-grants.js';

if (process.env.NODE_ENV === 'production') {
  process.stderr.write('Refusing to seed: NODE_ENV=production.\n');
  process.exit(1);
}

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  process.stderr.write('DATABASE_URL is not set (copy apps/api/.env.example to apps/api/.env).\n');
  process.exit(1);
}

const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: databaseUrl }) });

interface SeedUser {
  email: string;
  username: string;
  displayName: string;
  role: UserRole;
  passwordEnv: string;
}

const USERS: SeedUser[] = [
  {
    email: 'demo@kabso.local',
    username: 'demo_user',
    displayName: 'Demo User',
    role: 'USER',
    passwordEnv: 'SEED_DEMO_PASSWORD',
  },
  {
    email: 'admin@kabso.local',
    username: 'kabso_admin',
    displayName: 'Kabso Admin',
    role: 'ADMIN',
    passwordEnv: 'SEED_ADMIN_PASSWORD',
  },
];

async function main(): Promise<void> {
  for (const seed of USERS) {
    const provided = process.env[seed.passwordEnv];
    const password = provided && provided.length >= 8 ? provided : randomBytes(12).toString('base64url');
    const passwordHash = await argon2.hash(password, ARGON2_OPTIONS);
    const now = new Date();
    const user = await prisma.user.upsert({
      where: { email: seed.email },
      update: { passwordHash, role: seed.role, status: 'ACTIVE' },
      create: {
        email: seed.email,
        passwordHash,
        role: seed.role,
        emailVerifiedAt: now,
        profile: { create: { username: seed.username, displayName: seed.displayName, locale: 'ar' } },
        settings: { create: {} },
      },
    });
    // CP-019 (D107): the free bag items, as at signup (nothing changes for items already owned).
    await grantFreeItemsIn(prisma, user.id, 'FREE_SIGNUP');
    const source = provided ? `from ${seed.passwordEnv}` : 'generated';
    process.stdout.write(
      `seeded ${seed.role.padEnd(5)} ${seed.email} / @${seed.username} (password ${source}: ${
        provided ? '<hidden>' : password
      })\n`,
    );
  }
}

main()
  .catch((err: unknown) => {
    process.stderr.write(`Seed failed: ${(err as Error).stack ?? String(err)}\n`);
    process.exitCode = 1;
  })
  .finally(() => {
    void prisma.$disconnect();
  });
