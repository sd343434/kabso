import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { MediaModule } from '../media/media.module.js';
import { UsersModule } from '../users/users.module.js';
import { AccountDeletionController } from './account-deletion.controller.js';
import { AccountDeletionService, AccountDeletionSweeper } from './account-deletion.service.js';
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
  imports: [JwtModule.register({}), UsersModule, MediaModule],
  controllers: [AuthController, AccountDeletionController],
  providers: [
    AuthService,
    AccessTokenService,
    AccessTokenGuard,
    PasswordHasher,
    { provide: ARGON2_BACKEND, useValue: nodeArgon2Backend },
    SessionsService,
    RegistrationService,
    VerificationTokensService,
    // v1.62-social (D193): account deletion.
    AccountDeletionService,
    AccountDeletionSweeper,
  ],
  // v1.72-social (D208): AuthService for the admin panel's reset link and verification resend.
  exports: [AccessTokenGuard, AccessTokenService, SessionsService, PasswordHasher, AuthService],
})
export class AuthModule {}
