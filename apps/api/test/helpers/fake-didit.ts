/**
 * D227: an in-memory Didit for the tests (no network, no real key). It implements the `DiditApi` port the API uses
 * (`DIDIT_API_FACTORY` is overridden with {@link FakeDidit.factory}): sessions with Didit's documented shapes and its
 * idempotency (an unfinished session of the same `vendor_data` and workflow is returned again), decisions the test
 * sets, the application's workflows, and a key that is accepted or refused. {@link FakeDidit.webhook} builds a
 * `status.updated` delivery signed like Didit (`X-Signature-V2` over the canonical JSON, `X-Timestamp`).
 */
import { randomBytes, randomUUID } from 'node:crypto';
import {
  DiditKeyRejectedError,
  DiditRequestError,
  DiditUnreachableError,
  type DiditApi,
  type DiditDecision,
  type DiditSession,
  type DiditWorkflow,
} from '../../src/modules/kyc/didit-api.js';
import { signWebhookV2 } from '../../src/modules/kyc/kyc.rules.js';

export interface FakeSession {
  readonly sessionId: string;
  readonly sessionNumber: number;
  readonly vendorData: string;
  readonly workflowId: string;
  readonly callback: string;
  readonly language: string | null;
  readonly metadata: Record<string, string>;
  status: string;
  decision: Record<string, unknown> | null;
}

/** Made-up credentials built at run time (nothing for a secret scanner to match). */
export function fakeKey(prefix: string): string {
  return `${prefix}_${randomBytes(12).toString('hex')}`;
}

export class FakeDidit {
  readonly sessions = new Map<string, FakeSession>();
  readonly calls: { op: string; key: string }[] = [];
  readonly workflows: DiditWorkflow[] = [];
  /** The keys Didit accepts. */
  readonly keys = new Set<string>();
  /** Next calls fail as if Didit were down. */
  down = false;
  private number = 1000;

  addWorkflow(w: Partial<DiditWorkflow> = {}): string {
    const id = w.id ?? randomUUID();
    this.workflows.push({
      id,
      label: w.label ?? 'KYC',
      status: w.status ?? 'published',
      archived: w.archived ?? false,
      features: w.features ?? 'OCR + LIVENESS + FACE_MATCH',
    });
    return id;
  }

  readonly factory = (apiKey: string): DiditApi => this.client(apiKey);

  client(apiKey: string): DiditApi {
    const guard = (op: string) => {
      this.calls.push({ op, key: apiKey });
      if (this.down) throw new DiditUnreachableError('down');
      if (!this.keys.has(apiKey)) throw new DiditKeyRejectedError('HTTP 403');
    };
    return {
      createSession: async (input): Promise<DiditSession> => {
        guard('createSession');
        if (!this.workflows.some((w) => w.id === input.workflowId)) {
          throw new DiditRequestError('HTTP 400', 400);
        }
        const open = [...this.sessions.values()].find(
          (s) =>
            s.vendorData === input.vendorData &&
            s.workflowId === input.workflowId &&
            ['Not Started', 'In Progress', 'Resubmitted', 'Awaiting User'].includes(s.status),
        );
        const s: FakeSession = open ?? {
          sessionId: randomUUID(),
          sessionNumber: ++this.number,
          vendorData: input.vendorData,
          workflowId: input.workflowId,
          callback: input.callback,
          language: input.language,
          metadata: input.metadata,
          status: 'Not Started',
          decision: null,
        };
        this.sessions.set(s.sessionId, s);
        const token = randomBytes(6).toString('base64url');
        return {
          sessionId: s.sessionId,
          sessionNumber: s.sessionNumber,
          url: `https://verify.didit.me/${input.language ? `${input.language}/` : ''}session/${token}`,
          status: s.status,
          workflowId: s.workflowId,
        };
      },
      decision: async (sessionId): Promise<DiditDecision> => {
        guard('decision');
        const s = this.sessions.get(sessionId);
        if (!s) throw new DiditRequestError('HTTP 404', 404);
        return {
          status: s.status,
          body: {
            session_id: s.sessionId,
            session_number: s.sessionNumber,
            status: s.status,
            ...(s.decision ?? {}),
          },
        };
      },
      workflows: async (): Promise<DiditWorkflow[]> => {
        guard('workflows');
        return [...this.workflows];
      },
    };
  }

  /** The session the person (vendor_data) started last. */
  sessionOf(userId: string): FakeSession {
    const list = [...this.sessions.values()].filter((s) => s.vendorData === userId);
    const s = list.at(-1);
    if (!s) throw new Error(`no Didit session for ${userId}`);
    return s;
  }

  /** Sets a session's result as Didit's decision (v3 plural arrays). */
  decide(
    sessionId: string,
    status: 'Approved' | 'Declined' | 'In Review' | 'In Progress' | 'Abandoned' | 'Expired',
    person: {
      firstName?: string;
      lastName?: string;
      dateOfBirth?: string | null;
      issuingState?: string;
      documentNumber?: string;
      warnings?: string[];
    } = {},
  ): FakeSession {
    const s = this.sessions.get(sessionId);
    if (!s) throw new Error(`no session ${sessionId}`);
    s.status = status;
    const warnings = (person.warnings ?? []).map((risk) => ({
      risk,
      feature: 'LIVENESS',
      additional_data: null,
      log_type: 'error',
      short_description: risk,
      long_description: risk,
    }));
    s.decision =
      status === 'In Progress'
        ? null
        : {
            session_id: s.sessionId,
            session_number: s.sessionNumber,
            status,
            workflow_id: s.workflowId,
            features: ['ID_VERIFICATION', 'LIVENESS', 'FACE_MATCH'],
            vendor_data: s.vendorData,
            id_verifications: [
              {
                node_id: 'id_verification_1',
                status,
                document_type: 'Identity Card',
                document_number: person.documentNumber ?? 'SAMPLE-DOC-12345',
                first_name: person.firstName ?? 'Jane',
                last_name: person.lastName ?? 'Doe',
                date_of_birth: person.dateOfBirth === undefined ? '1990-01-01' : person.dateOfBirth,
                issuing_state: person.issuingState ?? 'SAU',
                portrait_image: 'https://media.didit.example/portrait.jpg?sig=1',
                front_image: 'https://media.didit.example/front.jpg?sig=1',
                back_image: 'https://media.didit.example/back.jpg?sig=1',
                address: 'NOT TO BE STORED 12',
                warnings: [],
              },
            ],
            liveness_checks: [
              {
                node_id: 'liveness_1',
                status,
                method: 'PASSIVE',
                score: 95.4,
                reference_image: 'https://media.didit.example/live.jpg?sig=1',
                warnings,
              },
            ],
            face_matches: [{ node_id: 'face_match_1', status, score: 96.1, warnings: [] }],
            reviews: [],
          };
    return s;
  }

  /** A `status.updated` delivery for the session as Didit signs it (or with a wrong secret / an old timestamp). */
  webhook(
    session: FakeSession,
    secret: string,
    opts: { eventId?: string; at?: number; createdAt?: number; tamper?: boolean } = {},
  ): { body: string; headers: Record<string, string>; eventId: string } {
    const at = Math.floor((opts.at ?? Date.now()) / 1000);
    const eventId = opts.eventId ?? randomUUID();
    const payload = {
      event_id: eventId,
      webhook_type: 'status.updated',
      timestamp: at,
      created_at: opts.createdAt ?? at,
      application_id: '11111111-2222-3333-4444-555555555555',
      environment: 'live',
      session_id: session.sessionId,
      status: session.status,
      workflow_id: session.workflowId,
      workflow_version: 1,
      vendor_data: session.vendorData,
      metadata: session.metadata,
      ...(session.decision ? { decision: session.decision } : {}),
    };
    const signature = signWebhookV2(secret, payload);
    const body = JSON.stringify(opts.tamper ? { ...payload, status: 'Approved' } : payload);
    return {
      body,
      eventId,
      headers: {
        'Content-Type': 'application/json',
        'X-Timestamp': String(at),
        'X-Signature-V2': signature,
      },
    };
  }
}
