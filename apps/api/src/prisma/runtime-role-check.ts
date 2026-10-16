/**
 * Boot-time least-privilege check for the API's database connection (SEC-011 / KL-013, KL-013b).
 *
 * The API must connect as the DML-only runtime login (docs/DEPLOYMENT.md §5.1): a member of this
 * database's NOLOGIN group `kabso_runtime_<database>` and of nothing else, never the migration/
 * owner role, a superuser or any role that can run DDL. Every role the login can reach through
 * membership (also `SET`-only memberships with `INHERIT FALSE`) is evaluated, because any of them
 * is one `SET ROLE` away. In production a violation stops the boot (fail closed); elsewhere it is
 * logged as a warning so old single-role dev setups keep working while they are migrated.
 */

/** Prefix of the per-database runtime group; the full name is `<prefix><current_database()>`. */
export const RUNTIME_GROUP_PREFIX = 'kabso_runtime_';

/** What the connected role can do, as reported by PostgreSQL's catalogs. */
export interface RuntimeRoleFacts {
  readonly user: string;
  /** The runtime group expected for this database (`kabso_runtime_<database>`). */
  readonly runtimeGroup: string;
  /** Whether the role is a member of {@link runtimeGroup}. */
  readonly inRuntimeGroup: boolean;
  /** Roles reachable through membership other than the role itself and {@link runtimeGroup}. */
  readonly unexpectedRoles: readonly string[];
  // Role attributes, true when the role itself OR any role it can reach has them.
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
  /** Whether the role may create temporary tables in the current database. */
  readonly databaseTemp: boolean;
  /** Tables on which the role holds TRUNCATE, REFERENCES or TRIGGER. */
  readonly ddlLikeTablePrivileges: readonly string[];
  /** UPDATE / DELETE on append-only tables (`audit_logs`), e.g. `public.audit_logs (UPDATE)`. */
  readonly appendOnlyViolations: readonly string[];
  /** Whether the role holds any privilege on Prisma's `_prisma_migrations`. */
  readonly migrationHistoryAccess: boolean;
  /** Objects on which the role (or a role it reaches) holds a privilege WITH GRANT OPTION. */
  readonly grantOptions: readonly string[];
  /** Other databases the role (or a role it reaches) owns, holds privileges in or owns objects in. */
  readonly otherDatabases: readonly string[];
}

const SYSTEM_SCHEMA_FILTER = `n.nspname NOT IN ('pg_catalog', 'information_schema')
       AND n.nspname NOT LIKE 'pg\\_toast%'
       AND n.nspname NOT LIKE 'pg\\_temp\\_%'`;

/** Tables the runtime role may only INSERT into and SELECT from. */
const APPEND_ONLY_TABLES = ['public.audit_logs'];

/**
 * The catalog query, for the role named by the SQL expression `roleSql` (default `current_user`,
 * which is what the API runs; tests pass a quoted role name to inspect another role). It only
 * reads catalogs every role may read, so it never needs extra grants.
 */
export function runtimeRoleFactsSql(roleSql = 'current_user'): string {
  const appendOnly = APPEND_ONLY_TABLES.map((t) => `'${t}'`).join(', ');
  return `
WITH me AS (
  SELECT r.oid, r.rolname FROM pg_roles r WHERE r.rolname = ${roleSql}
), reach AS (
  SELECT r.* FROM pg_roles r, me WHERE pg_has_role(me.oid, r.oid, 'MEMBER')
), grp AS (
  SELECT ('${RUNTIME_GROUP_PREFIX}' || current_database())::text AS name
)
SELECT
  me.rolname::text AS "user",
  grp.name AS "runtimeGroup",
  EXISTS (SELECT 1 FROM reach WHERE reach.rolname = grp.name) AS "inRuntimeGroup",
  ARRAY(
    SELECT reach.rolname::text FROM reach
     WHERE reach.oid <> me.oid AND reach.rolname <> grp.name
     ORDER BY 1
  ) AS "unexpectedRoles",
  coalesce((SELECT bool_or(rolsuper) FROM reach), false) AS "superuser",
  coalesce((SELECT bool_or(rolcreaterole) FROM reach), false) AS "createRole",
  coalesce((SELECT bool_or(rolcreatedb) FROM reach), false) AS "createDb",
  coalesce((SELECT bool_or(rolreplication) FROM reach), false) AS "replication",
  coalesce((SELECT bool_or(rolbypassrls) FROM reach), false) AS "bypassRls",
  ARRAY(
    SELECT n.nspname::text FROM pg_namespace n
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND n.nspowner IN (SELECT oid FROM reach)
     ORDER BY 1
  ) AS "ownedSchemas",
  ARRAY(
    SELECT n.nspname || '.' || c.relname FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND c.relkind IN ('r', 'p', 'v', 'm', 'S', 'f')
       AND c.relowner IN (SELECT oid FROM reach)
     ORDER BY 1
  ) AS "ownedRelations",
  ARRAY(
    SELECT n.nspname::text FROM pg_namespace n
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND has_schema_privilege(me.oid, n.oid, 'CREATE')
     ORDER BY 1
  ) AS "creatableSchemas",
  has_database_privilege(me.oid, current_database(), 'CREATE') AS "databaseCreate",
  has_database_privilege(me.oid, current_database(), 'TEMPORARY') AS "databaseTemp",
  ARRAY(
    SELECT n.nspname || '.' || c.relname FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
     WHERE ${SYSTEM_SCHEMA_FILTER}
       AND c.relkind IN ('r', 'p')
       AND has_table_privilege(me.oid, c.oid, 'TRUNCATE, REFERENCES, TRIGGER')
     ORDER BY 1
  ) AS "ddlLikeTablePrivileges",
  ARRAY(
    SELECT t.name || ' (' || p.priv || ')'
      FROM unnest(ARRAY[${appendOnly}]::text[]) AS t(name)
      CROSS JOIN unnest(ARRAY['UPDATE', 'DELETE']) AS p(priv)
     WHERE to_regclass(t.name) IS NOT NULL
       AND CASE p.priv
             WHEN 'UPDATE' THEN has_any_column_privilege(me.oid, to_regclass(t.name), 'UPDATE')
             ELSE has_table_privilege(me.oid, to_regclass(t.name), 'DELETE')
           END
     ORDER BY 1
  ) AS "appendOnlyViolations",
  coalesce(
    has_any_column_privilege(me.oid, to_regclass('public._prisma_migrations'), 'SELECT, INSERT, UPDATE, REFERENCES')
      OR has_table_privilege(me.oid, to_regclass('public._prisma_migrations'), 'DELETE, TRUNCATE, TRIGGER'),
    false
  ) AS "migrationHistoryAccess",
  ARRAY(
    SELECT DISTINCT o.obj FROM (
      SELECT 'table ' || n.nspname || '.' || c.relname AS obj, c.relacl AS acl
        FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE ${SYSTEM_SCHEMA_FILTER}
      UNION ALL
      SELECT 'schema ' || n.nspname, n.nspacl FROM pg_namespace n WHERE ${SYSTEM_SCHEMA_FILTER}
      UNION ALL
      SELECT 'function ' || n.nspname || '.' || p.proname, p.proacl
        FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
       WHERE ${SYSTEM_SCHEMA_FILTER}
      UNION ALL
      SELECT 'database ' || d.datname, d.datacl FROM pg_database d WHERE d.datname = current_database()
    ) o
    CROSS JOIN LATERAL aclexplode(o.acl) a
     WHERE a.is_grantable AND a.grantee IN (SELECT oid FROM reach)
     ORDER BY 1
  ) AS "grantOptions",
  ARRAY(
    SELECT d.datname::text FROM pg_database d
     WHERE d.datname <> current_database()
       AND (
         d.datdba IN (SELECT oid FROM reach)
         OR EXISTS (SELECT 1 FROM aclexplode(d.datacl) a WHERE a.grantee IN (SELECT oid FROM reach))
         OR EXISTS (
           SELECT 1 FROM pg_shdepend s
            WHERE s.dbid = d.oid
              AND s.refclassid = 'pg_authid'::regclass
              AND s.refobjid IN (SELECT oid FROM reach)
         )
       )
     ORDER BY 1
  ) AS "otherDatabases"
FROM me, grp`;
}

/** The query the API runs at boot, for `current_user`. */
export const RUNTIME_ROLE_FACTS_SQL = runtimeRoleFactsSql();

function list(items: readonly string[], max = 5): string {
  const shown = items.slice(0, max).join(', ');
  return items.length > max ? `${shown}, … (${items.length} total)` : shown;
}

/** Every reason the role is not a least-privilege runtime role; empty when it is. */
export function assessRuntimeRole(facts: RuntimeRoleFacts): string[] {
  const problems: string[] = [];
  const reach = facts.unexpectedRoles.length > 0 ? ' (directly or through role membership)' : '';
  if (facts.superuser) problems.push(`is a superuser${reach}`);
  if (facts.createRole) problems.push(`has CREATEROLE${reach}`);
  if (facts.createDb) problems.push(`has CREATEDB${reach}`);
  if (facts.replication) problems.push(`has REPLICATION${reach}`);
  if (facts.bypassRls) problems.push(`has BYPASSRLS${reach}`);
  if (facts.unexpectedRoles.length > 0) {
    problems.push(
      `is a member of ${list(facts.unexpectedRoles)} (only ${facts.runtimeGroup} is allowed; ` +
        'any reachable role is one SET ROLE away)',
    );
  }
  if (!facts.inRuntimeGroup) problems.push(`is not a member of ${facts.runtimeGroup}`);
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
  if (facts.databaseTemp) problems.push('may create TEMPORARY tables in the database');
  if (facts.ddlLikeTablePrivileges.length > 0) {
    problems.push(`holds TRUNCATE/REFERENCES/TRIGGER on ${list(facts.ddlLikeTablePrivileges)}`);
  }
  if (facts.appendOnlyViolations.length > 0) {
    problems.push(`may change append-only rows: ${list(facts.appendOnlyViolations)}`);
  }
  if (facts.migrationHistoryAccess) problems.push('holds privileges on _prisma_migrations');
  if (facts.grantOptions.length > 0) {
    problems.push(`holds grant options on ${list(facts.grantOptions)}`);
  }
  if (facts.otherDatabases.length > 0) {
    problems.push(
      `owns, or holds privileges in, other database(s) ${list(facts.otherDatabases)} ` +
        '(use one runtime login per database)',
    );
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
        `${problems.join('; ')}. Point DATABASE_URL at the DML-only runtime login (member of ` +
        `${RUNTIME_GROUP_PREFIX}<database> only) and keep the migration role in ` +
        'MIGRATION_DATABASE_URL for `prisma migrate deploy` only (SEC-011, docs/DEPLOYMENT.md §5.1).',
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
