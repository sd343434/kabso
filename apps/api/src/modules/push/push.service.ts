import { Inject, Injectable, Logger } from '@nestjs/common';
import { PUSH_SENDER, type PushChannel, type PushSender } from './push-sender.js';
import type { PushLocale } from './push-texts.js';
import { PushTokensService } from './push-tokens.service.js';

/** One push to some accounts; the text may depend on each recipient's language. */
export interface PushDelivery {
  readonly userIds: readonly string[];
  readonly channel: PushChannel;
  readonly tag: string;
  readonly data: Readonly<Record<string, string>>;
  /** The title and body in `locale`, or null to send nothing in that language. */
  text(locale: PushLocale): { title: string; body: string } | null;
}

/**
 * v1.30-live (D152, CONVENTIONS §11.12): sends a push to the live Android sessions of some
 * accounts, one multicast per language, and deletes the tokens Firebase reports invalid. Logs
 * counts only — never a token, title or body.
 */
@Injectable()
export class PushService {
  private readonly logger = new Logger('Push');

  constructor(
    @Inject(PUSH_SENDER) private readonly sender: PushSender,
    private readonly tokens: PushTokensService,
  ) {}

  /** False when this server has no Firebase key: callers skip their work. */
  get enabled(): boolean {
    return this.sender.enabled;
  }

  /** Returns how many devices accepted it. */
  async deliver(delivery: PushDelivery): Promise<number> {
    if (!this.sender.enabled || delivery.userIds.length === 0) return 0;
    const targets = await this.tokens.targets(delivery.userIds);
    if (targets.length === 0) return 0;
    const byLocale = new Map<PushLocale, string[]>();
    for (const t of targets) byLocale.set(t.locale, [...(byLocale.get(t.locale) ?? []), t.token]);
    let sent = 0;
    for (const [locale, tokens] of byLocale) {
      const text = delivery.text(locale);
      if (!text) continue;
      const res = await this.sender.send({
        tokens,
        channel: delivery.channel,
        title: text.title,
        body: text.body,
        tag: delivery.tag,
        data: delivery.data,
      });
      sent += res.sent;
      const removed = await this.tokens.removeTokens(res.invalidTokens);
      this.logger.debug(
        { channel: delivery.channel, devices: tokens.length, sent: res.sent, failed: res.failed, removed },
        'Push sent',
      );
    }
    return sent;
  }
}
