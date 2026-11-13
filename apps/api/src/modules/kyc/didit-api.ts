import { DIDIT_API_BASE_URL } from './kyc.rules.js';

/**
 * v1.80-kyc (D227): the few Didit API calls identity checks make, behind one port so tests replace them (no network
 * and no key in tests: they override {@link DIDIT_API_FACTORY}). The key can change at run time (the OWNER enters it in
 * the panel), so the module provides a factory: one client per key.
 *
 * Shapes from docs.didit.me (2026-11-01): `POST /v3/session/` → 201 `{session_id, session_number, session_token, url,
 * status, workflow_id, …}`; `GET /v3/session/{id}/decision/` → `{status, session_number, id_verifications[], …}`;
 * `GET /v3/workflows/` → `{results: [{uuid, workflow_id, workflow_label, status, is_archived, features, …}]}` (also a
 * plain array is accepted); a bad key → 401/403 `{"detail": …}`.
 */
export const DIDIT_API_FACTORY = Symbol('DIDIT_API_FACTORY');
export type DiditApiFactory = (apiKey: string) => DiditApi;

/** Didit could not be reached or answered 5xx / 429 (the request may be repeated later). */
export class DiditUnreachableError extends Error {}
/** Didit refused the key (401 / 403). */
export class DiditKeyRejectedError extends Error {}
/** Didit refused the request (another 4xx; e.g. no credits, unknown workflow, unknown session). */
export class DiditRequestError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}

export interface DiditSession {
  readonly sessionId: string;
  readonly sessionNumber: number | null;
  readonly url: string;
  readonly status: string;
  readonly workflowId: string | null;
}

export interface DiditDecision {
  readonly status: string;
  /** The whole decision object (features as plural arrays). Read with `factsOf` / `mediaOf`; never stored. */
  readonly body: Record<string, unknown>;
}

export interface DiditWorkflow {
  readonly id: string;
  readonly label: string | null;
  readonly status: string | null;
  readonly archived: boolean;
  readonly features: string | null;
}

export interface DiditApi {
  createSession(input: {
    workflowId: string;
    vendorData: string;
    callback: string;
    language: 'ar' | 'en' | null;
    metadata: Record<string, string>;
  }): Promise<DiditSession>;
  decision(sessionId: string): Promise<DiditDecision>;
  workflows(): Promise<DiditWorkflow[]>;
}

/** One step's time limit (Didit documents 5 s for webhooks; API calls get a little more). */
export const DIDIT_TIMEOUT_MS = 10_000;

type Json = Record<string, unknown>;

/** The production client: `fetch` against {@link DIDIT_API_BASE_URL} with the `x-api-key` header. */
export function createDiditApi(apiKey: string, baseUrl: string = DIDIT_API_BASE_URL): DiditApi {
  const call = async (method: 'GET' | 'POST', path: string, body?: Json): Promise<Json | unknown[]> => {
    let res: Response;
    try {
      res = await fetch(`${baseUrl.replace(/\/+$/, '')}${path}`, {
        method,
        headers: {
          'x-api-key': apiKey,
          Accept: 'application/json',
          ...(body ? { 'Content-Type': 'application/json' } : {}),
        },
        ...(body ? { body: JSON.stringify(body) } : {}),
        redirect: 'error',
        signal: AbortSignal.timeout(DIDIT_TIMEOUT_MS),
      });
    } catch (err) {
      throw new DiditUnreachableError(`Didit unreachable: ${(err as Error).name}`);
    }
    const textBody = await res.text().catch(() => '');
    if (res.status === 401 || res.status === 403) throw new DiditKeyRejectedError(`Didit HTTP ${res.status}`);
    if (res.status === 429 || res.status >= 500) throw new DiditUnreachableError(`Didit HTTP ${res.status}`);
    if (res.status < 200 || res.status >= 300)
      throw new DiditRequestError(`Didit HTTP ${res.status}`, res.status);
    try {
      return JSON.parse(textBody) as Json | unknown[];
    } catch {
      throw new DiditUnreachableError('Didit answered something that is not JSON');
    }
  };
  const str = (v: unknown): string | null => (typeof v === 'string' && v !== '' ? v : null);
  return {
    async createSession(input) {
      const body: Json = {
        workflow_id: input.workflowId,
        vendor_data: input.vendorData,
        callback: input.callback,
        metadata: input.metadata,
      };
      if (input.language) body.language = input.language;
      const r = (await call('POST', '/v3/session/', body)) as Json;
      const sessionId = str(r.session_id);
      const url = str(r.url);
      if (!sessionId || !url) throw new DiditUnreachableError('Didit session without session_id / url');
      return {
        sessionId,
        sessionNumber: typeof r.session_number === 'number' ? r.session_number : null,
        url,
        status: str(r.status) ?? 'Not Started',
        workflowId: str(r.workflow_id),
      };
    },
    async decision(sessionId) {
      const r = (await call('GET', `/v3/session/${encodeURIComponent(sessionId)}/decision/`)) as Json;
      return { status: str(r.status) ?? '', body: r };
    },
    async workflows() {
      const r = await call('GET', '/v3/workflows/');
      const list = Array.isArray(r) ? r : Array.isArray(r.results) ? r.results : [];
      return list.flatMap((w) => {
        const o = w as Json;
        const id = str(o.workflow_id) ?? str(o.uuid);
        if (!id) return [];
        return [
          {
            id,
            label: str(o.workflow_label),
            status: str(o.status),
            archived: o.is_archived === true,
            features: str(o.features),
          },
        ];
      });
    },
  };
}
