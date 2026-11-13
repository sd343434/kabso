/**
 * Contract conformance against docs/contracts/openapi.yaml (KL-037).
 *
 * `expectContract(res, operationId)` asserts that the response status is documented for the
 * operation and that the body validates against the documented schema (JSON Schema 2020-12 via
 * Ajv, formats included). It additionally rejects properties the schema does not declare
 * (resolving `$ref`, `allOf` and `oneOf`), so a response cannot leak extra fields such as an
 * email. A 2xx without a documented body (204) must have an empty body.
 */
import { readFileSync } from 'node:fs';
import { Ajv2020, type ValidateFunction } from 'ajv/dist/2020.js';
import addFormatsModule from 'ajv-formats';
import type request from 'supertest';
import { expect } from 'vitest';
import { parse } from 'yaml';

type Json = Record<string, unknown>;

const OPENAPI_PATH = new URL('../../../../docs/contracts/openapi.yaml', import.meta.url);
export const openapi = parse(readFileSync(OPENAPI_PATH, 'utf8')) as Json;

const DOC_ID = 'https://kabso.local/openapi.json';
// ajv-formats is CommonJS; its default export arrives wrapped under ESM interop.
const addFormats = ((addFormatsModule as unknown as { default?: unknown }).default ?? addFormatsModule) as (
  ajv: Ajv2020,
) => Ajv2020;
// strict: false — OpenAPI keywords such as `example`/`examples` are annotations here.
const ajv = new Ajv2020({ strict: false, allErrors: true });
addFormats(ajv);
ajv.addSchema({ ...openapi, $id: DOC_ID });

const HTTP_METHODS = ['get', 'put', 'post', 'delete', 'patch'] as const;

export interface Operation {
  readonly method: (typeof HTTP_METHODS)[number];
  readonly path: string;
  readonly operationId: string;
  readonly spec: Json;
}

export function operations(): Operation[] {
  const result: Operation[] = [];
  for (const [path, item] of Object.entries(openapi.paths as Record<string, Json>)) {
    for (const method of HTTP_METHODS) {
      const spec = item[method] as Json | undefined;
      if (spec) result.push({ method, path, operationId: String(spec.operationId), spec });
    }
  }
  return result;
}

function pointerOf(path: string): string {
  return path.replace(/~/g, '~0').replace(/\//g, '~1');
}

function get(ref: string): Json {
  if (!ref.startsWith('#/')) throw new Error(`unsupported $ref ${ref}`);
  let node: unknown = openapi;
  for (const raw of ref.slice(2).split('/')) {
    const key = raw.replace(/~1/g, '/').replace(/~0/g, '~');
    node = (node as Json)[key];
  }
  if (node === undefined) throw new Error(`unresolved $ref ${ref}`);
  return node as Json;
}

function resolve(node: Json): Json {
  let current = node;
  while (typeof current.$ref === 'string') current = get(current.$ref);
  return current;
}

const validators = new Map<string, ValidateFunction>();

function validatorFor(pointer: string): ValidateFunction {
  let validate = validators.get(pointer);
  if (!validate) {
    validate = ajv.compile({ $ref: `${DOC_ID}#${pointer}` });
    validators.set(pointer, validate);
  }
  return validate;
}

/** Undeclared properties anywhere in `data` (paths), given the schema at `node`. */
function undeclared(node: Json, data: unknown, path: string): string[] {
  const schema = resolve(node);
  if (Array.isArray(schema.oneOf)) {
    if (data === null) return [];
    const branches = (schema.oneOf as Json[]).map(resolve);
    const objectBranches = branches.filter((b) => b.type === 'object' || b.properties || b.allOf);
    // Several object branches (e.g. SearchPage items): check against the one whose required
    // properties the data has (the validator already proved exactly one branch matches).
    const objectBranch =
      objectBranches.length > 1 && data !== null && typeof data === 'object'
        ? (objectBranches.find((b) =>
            ((b.required as string[] | undefined) ?? []).every((k) => k in (data as Json)),
          ) ?? objectBranches[0])
        : objectBranches[0];
    return objectBranch ? undeclared(objectBranch, data, path) : [];
  }
  if (Array.isArray(data)) {
    const items = schema.items as Json | undefined;
    return items ? data.flatMap((item, i) => undeclared(items, item, `${path}[${i}]`)) : [];
  }
  if (data === null || typeof data !== 'object') return [];
  let properties: Record<string, Json> = { ...((schema.properties as Record<string, Json>) ?? {}) };
  if (Array.isArray(schema.allOf)) {
    for (const part of schema.allOf as Json[]) {
      properties = { ...properties, ...((resolve(part).properties as Record<string, Json>) ?? {}) };
    }
  }
  if (Object.keys(properties).length === 0) return []; // free-form object (e.g. health checks)
  return Object.entries(data as Json).flatMap(([key, value]) =>
    key in properties ? undeclared(properties[key]!, value, `${path}.${key}`) : [`${path}.${key}`],
  );
}

export function findOperation(operationId: string): Operation {
  const op = operations().find((o) => o.operationId === operationId);
  if (!op) throw new Error(`operationId ${operationId} is not in openapi.yaml`);
  return op;
}

/** Asserts that `res` is a documented response of `operationId` and matches its schema. */
export function expectContract(res: request.Response, operationId: string): void {
  const op = findOperation(operationId);
  const responses = op.spec.responses as Record<string, Json>;
  const status = String(res.status);
  expect(Object.keys(responses), `${operationId}: status ${status} is not documented`).toContain(status);
  const response = resolve(responses[status]!);
  const content = response.content as Record<string, Json> | undefined;
  if (!content) {
    expect(res.text ?? '', `${operationId}: ${status} must have no body`).toBe('');
    return;
  }
  const responsePointer =
    typeof responses[status]!.$ref === 'string'
      ? `${responses[status]!.$ref.slice(1)}/content/application~1json/schema`
      : `/paths/${pointerOf(op.path)}/${op.method}/responses/${status}/content/application~1json/schema`;
  const validate = validatorFor(responsePointer);
  const ok = validate(res.body);
  expect(
    ok ? [] : (validate.errors ?? []).map((e) => `${e.instancePath} ${e.message}`),
    `${operationId} ${status} body: ${JSON.stringify(res.body)}`,
  ).toEqual([]);
  const schema = content['application/json']!.schema as Json;
  expect(undeclared(schema, res.body, '$'), `${operationId}: undeclared properties`).toEqual([]);
  expect(res.headers['content-type']).toMatch(/^application\/json/);
}
