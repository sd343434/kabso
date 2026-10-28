import { Logger, Module } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from '../../config/app-config.js';
import {
  CredentialsError,
  FirebasePushSender,
  createFirebaseMessaging,
  loadServiceAccount,
} from './firebase-push-sender.js';
import { PushController } from './push.controller.js';
import { DisabledPushSender, PUSH_SENDER, type PushSender } from './push-sender.js';
import { PushService } from './push.service.js';
import { PushThrottle } from './push-throttle.js';
import { PushTokensService } from './push-tokens.service.js';

/**
 * The push sender for this server (D152): Firebase when FIREBASE_CREDENTIALS_FILE names a readable
 * service-account key, otherwise off — with one log line that says why (never the key).
 */
export async function createPushSender(config: AppConfig, logger = new Logger('Push')): Promise<PushSender> {
  const path = config.push.credentialsFile;
  if (path === null) {
    logger.log('Push notifications are off: FIREBASE_CREDENTIALS_FILE is not set');
    return new DisabledPushSender();
  }
  try {
    const account = await loadServiceAccount(path);
    const messaging = await createFirebaseMessaging(account);
    logger.log({ projectId: account.projectId }, 'Push notifications are on (Firebase Cloud Messaging)');
    return new FirebasePushSender(messaging, (codes) => logger.warn({ codes }, 'Some pushes failed'));
  } catch (err) {
    const reason = err instanceof CredentialsError ? err.problem : 'firebase_start_failed';
    logger.warn(
      { reason },
      'Push notifications are off: the Firebase key at FIREBASE_CREDENTIALS_FILE cannot be used',
    );
    return new DisabledPushSender();
  }
}

/**
 * v1.30-live (D152, CONVENTIONS §11.12): push notifications. Owns `device_tokens`; the
 * notifications module's dispatcher (general pushes) and the families module (chat pushes) send
 * through {@link PushService}.
 */
@Module({
  controllers: [PushController],
  providers: [
    {
      provide: PUSH_SENDER,
      inject: [APP_CONFIG],
      useFactory: (config: AppConfig) => createPushSender(config),
    },
    PushTokensService,
    PushService,
    PushThrottle,
  ],
  exports: [PushService, PushTokensService, PushThrottle],
})
export class PushModule {}
