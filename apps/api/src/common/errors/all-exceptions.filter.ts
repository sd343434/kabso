import { Catch, Logger, type ArgumentsHost, type ExceptionFilter } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { getRequestId } from '../request-id/request-id.js';
import { mapException, toEnvelope } from './error-mapping.js';

const logger = new Logger('ExceptionFilter');

/** Writes the contract error envelope for any exception (shared by the filter and Express). */
export function sendError(exception: unknown, req: Request, res: Response): void {
  const mapped = mapException(exception);
  const requestId = getRequestId(req);
  if (mapped.unexpected) {
    logger.error({ err: exception, requestId, method: req.method, path: req.path }, 'Unhandled exception');
  }
  if (res.headersSent) return;
  for (const [name, value] of Object.entries(mapped.headers ?? {})) res.setHeader(name, value);
  res.status(mapped.status).json(toEnvelope(mapped, requestId));
}

@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    sendError(exception, http.getRequest<Request>(), http.getResponse<Response>());
  }
}

/** Express error middleware for failures raised before Nest routing (e.g. body parsing). */
export function expressErrorHandler(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  sendError(err, req, res);
}
