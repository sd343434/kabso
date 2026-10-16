/**
 * Boot-time least-privilege check for the API's database connection (SEC-011 / KL-013).
 *
 * The API must connect as the DML-only runtime role (docs/DEPLOYMENT.md §5.1), never as the
 * migration/owner role, a superuser or any role that can run DDL. In production a violation stops
 * the boot (fail closed); elsewhere it is logged as a warning so old single-role dev setups keep
 * working while they are migrated.
 */

/** What the connected role can do, as reported by PostgreSQL's catalogs. */
export interface RuntimeRoleFacts {
  readonly user: string;
  readonly superuser: boolean;
  readonly createRole: boolean;
  readonly createDb: boolean;
  readonly replication: boolean;
  readonly bypassRls: boolean;
  /** Non-system schemas the role owns (directly or through role membership). */
  readonly ownedSchemas: readonly string[];
  /** Relations in non-system schemas the role owns (directly or through role membership). */
  readonly ownedRelations: readonly string[];
  /** Non-system schemas in which the role may CREATE objects. */
  readonly creatableSchemas: readonly string[];
  /** Whether the role may create schemas in the current database. */
  readonly databaseCreate: boolean;
  /** Tables on which the role holds TRUNCATE, REFERENCES or TRIGGER. */
  readonly ddlLikeTablePrivileges: readonly string[];
}

const SYSTEM_SCHEMA_FILTER = `n.nspname NOT IN ('pg_catalog', 'information_schema')
       AND n.nspname NOT LIKE 'pg\\_toast%'
       AND n.nspname NOT LIKE 'pg\\_temp\\_%'`;

/** One catalog query; readable by every role, so it never needs extra grants. */
export const RUNTIME_ROLE_FACTS_SQL = `
SELECT
  r.rolname::text AS "user",
  r.rolsuper AS "superuser",
  r.rolcreaterole AS "createRole",
  r.rolcreatedb AS "createDb",
  r.rolreplication AS "replication",
  r.rolbypassrls AS "bypassRls",
  ARRAY(
    SELECT n.nspname::text FROM pg_namespace n
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND pg_has_role(current_user, n.nspowner, 'MEMBER')
     ORDER BY 1
  ) AS "ownedSchemas",
  ARRAY(
    SELECT n.nspname || '.' || c.relname FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
       AND pg_has_role(current_user, c.relowner, 'MEMBER')
     ORDER BY 1
  ) AS "ownedRelations",
  ARRAY(
    SELECT n.nspname::text FROM pg_namespace n
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND has_schema_privilege(n.oid, 'CREATE')
     ORDER BY 1
  ) AS "creatableSchemas",
  has_database_privilege(current_database(), 'CREATE') AS "databaseCreate",
  ARRAY(
    SELECT n.nspname || '.' || c.relname FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND c.relkind IN ('r', 'p')
       AND has_table_privilege(c.oid, 'TRUNCATE, REFERENCES, TRIGGER')
     ORDER BY 1
  ) AS "ddlLikeTablePrivileges"
FROM pg_roles r
WHERE r.rolname = current_user`;

function list(items: readonly string[], max = 5): string {
  const shown = items.slice(0, max).join(', ');
  return items.length > max ? `${shown}, … (${items.length} total)` : shown;
}

/** Every reason the role is not a least-privilege runtime role; empty when it is. */
export function assessRuntimeRole(facts: RuntimeRoleFacts): string[] {
  const problems: string[] = [];
  if (facts.superuser) problems.push('is a superuser');
  if (facts.createRole) problems.push('has CREATEROLE');
  if (facts.createDb) problems.push('has CREATEDB');
  if (facts.replication) problems.push('has REPLICATION');
  if (facts.bypassRls) problems.push('has BYPASSRLS');
  if (facts.ownedSchemas.length > 0) {
    problems.push(`owns schema(s) ${list(facts.ownedSchemas)} (looks like the migration/owner role)`);
  }
  if (facts.ownedRelations.length > 0) {
    problems.push(`owns ${list(facts.ownedRelations)} (looks like the migration/owner role)`);
  }
  if (facts.creatableSchemas.length > 0) {
    problems.push(`may CREATE objects in schema(s) ${list(facts.creatableSchemas)}`);
  }
  if (facts.databaseCreate) problems.push('may CREATE schemas in the database');
  if (facts.ddlLikeTablePrivileges.length > 0) {
    problems.push(`holds TRUNCATE/REFERENCES/TRIGGER on ${list(facts.ddlLikeTablePrivileges)}`);
  }
  return problems;
}

export class UnsafeDatabaseRoleError extends Error {
  constructor(
    readonly user: string,
    readonly problems: readonly string[],
  ) {
    super(
      `DATABASE_URL connects as "${user}", which is not a least-privilege runtime role: ` +
        `${problems.join('; ')}. Point DATABASE_URL at the DML-only runtime role (member of ` +
        'kabso_runtime) and keep the migration role in MIGRATION_DATABASE_URL for ' +
        '`prisma migrate deploy` only (SEC-011, docs/DEPLOYMENT.md §5.1).',
    );
    this.name = 'UnsafeDatabaseRoleError';
  }
}

export interface RuntimeRoleCheckLogger {
  warn(message: string): void;
  fatal(message: string): void;
}

/** Runs {@link RUNTIME_ROLE_FACTS_SQL} through the given executor. */
export type FactsQuery = (sql: string) => Promise<readonly RuntimeRoleFacts[]>;

/**
 * Inspects the connected role. With `enforce` (production) any problem — or a failure to inspect
 * the role at all — throws {@link UnsafeDatabaseRoleError}; otherwise problems are logged as a
 * warning and the boot continues.
 */
export async function checkRuntimeRole(
  query: FactsQuery,
  options: { readonly enforce: boolean; readonly logger: RuntimeRoleCheckLogger },
): Promise<readonly string[]> {
  const rows = await query(RUNTIME_ROLE_FACTS_SQL);
  const facts = rows[0];
  if (!facts) {
    const problems = ['the connected role was not found in pg_roles'];
    if (options.enforce) {
      options.logger.fatal(`db.runtime_role_check failed: ${problems[0]}`);
      throw new UnsafeDatabaseRoleError('(unknown)', problems);
    }
    options.logger.warn(`db.runtime_role_check: ${problems[0]}`);
    return problems;
  }
  const problems = assessRuntimeRole(facts);
  if (problems.length === 0) return problems;
  const error = new UnsafeDatabaseRoleError(facts.user, problems);
  if (options.enforce) {
    options.logger.fatal(`db.runtime_role_check failed — refusing to start. ${error.message}`);
    throw error;
  }
  options.logger.warn(`db.runtime_role_check (not enforced outside production): ${error.message}`);
  return problems;
}
