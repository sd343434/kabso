import { createParamDecorator, type ExecutionContext } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import type { AppRequest, AuthContext } from '../../common/http/request-context.js';

/** Injects the {@link AuthContext} set by the access-token guard. */
export const CurrentAuth = createParamDecorator((_: unknown, ctx: ExecutionContext): AuthContext => {
  const req = ctx.switchToHttp().getRequest<AppRequest>();
  if (!req.auth) throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
  return req.auth;
});
