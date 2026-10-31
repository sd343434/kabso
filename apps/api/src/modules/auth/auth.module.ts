import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { UsersModule } from '../users/users.module.js';
import { AccessTokenGuard } from './access-token.guard.js';
import { AccessTokenService } from './access-token.service.js';
import { AuthController } from './auth.controller.js';
import { AuthService } from './auth.service.js';
import { ARGON2_BACKEND, nodeArgon2Backend, PasswordHasher } from './password-hasher.service.js';
import { RegistrationService } from './registration.service.js';
import { SessionsService } from './sessions.service.js';
import { VerificationTokensService } from './verification-tokens.service.js';

@Module({
  // Secrets and algorithms are passed explicitly per call in AccessTokenService.
  imports: [JwtModule.register({}), UsersModule],
  controllers: [AuthController],
  providers: [
    AuthService,
    AccessTokenService,
    AccessTokenGuard,
    PasswordHasher,
    { provide: ARGON2_BACKEND, useValue: nodeArgon2Backend },
    SessionsService,
    RegistrationService,
    VerificationTokensService,
  ],
  exports: [AccessTokenGuard, AccessTokenService, SessionsService, PasswordHasher],
})
export class AuthModule {}
