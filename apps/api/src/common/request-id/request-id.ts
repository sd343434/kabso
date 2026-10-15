import { randomUUID } from 'node:crypto';
import type { NextFunction, Request, Response } from 'express';

export const REQUEST_ID_HEADER = 'X-Request-Id';

/** CONVENTIONS §1: inbound ids are reused only if ≤ 64 chars of `[A-Za-z0-9._-]`. */
const VALID_REQUEST_ID = /^[A-Za-z0-9._-]{1,64}$/;

type RequestWithId = Request & { id?: string };

export function resolveRequestId(inbound: unknown): string {
  return typeof inbound === 'string' && VALID_REQUEST_ID.test(inbound) ? inbound : randomUUID();
}

/** Assigns `req.id` and echoes `X-Request-Id` on every response. Must run first. */
export function requestIdMiddleware(req: Request, res: Response, next: NextFunction): void {
  const id = resolveRequestId(req.headers['x-request-id']);
  (req as RequestWithId).id = id;
  res.setHeader(REQUEST_ID_HEADER, id);
  next();
}

export function getRequestId(req: Request): string {
  const existing = (req as RequestWithId).id;
  return typeof existing === 'string' ? existing : resolveRequestId(undefined);
}
