import { Injectable } from '@nestjs/common';
import { AppException } from '../../common/errors/app-exception.js';
import { ErrorCode } from '../../common/errors/error-codes.js';
import { zodErrorToDetails } from '../../common/validation/zod-validation.pipe.js';
import type { Prisma } from '../../generated/prisma/client.js';
import { PrismaService } from '../../prisma/prisma.service.js';
import { stockOf } from '../gifts/gift-catalogue.js';
import { GiftsService } from '../gifts/gifts.service.js';
import { LiveGiftsService } from '../live/live-gifts.service.js';
import { isUuid } from '../live/live.schemas.js';
import { Notifier } from '../notifications/notifier.js';
import { CommentsService, type CommentDto } from '../posts/comments.service.js';
import { visiblePostWhere } from '../posts/post-views.js';
import { UsersService, violatedUniqueIndex } from '../users/users.service.js';
import { WalletService } from '../wallet/wallet.service.js';
import { isContentGiftRecipient } from './content-gift-rules.js';
import { contentGiftSendSchema } from './content-gifts.schemas.js';

type Tx = Prisma.TransactionClient;

/** `ContentGiftResult` (v1.127-social, D372): the gift line, the post's gift cherries, the sender's coins and bag. */
export interface ContentGiftResultDto {
  /** The gift line «فلان أرسل … ×N» (a comment of kind GIFT). */
  comment: CommentDto;
  /** The cherries the post's author earned from every gift on this post so far. */
  giftCherries: number;
  coins: number;
  bagQuantity: number;
}

/** What a send checks of the post (outside and again inside the send's transaction). */
interface PostFacts {
  readonly id: string;
  readonly authorId: string;
  readonly commentsEnabled: boolean;
  readonly whoCanComment: string;
}

/**
 * «هدية الدعم» (v1.127-social, D372, CONVENTIONS §10.164): a catalogue gift sent on a post or reel to its author, a
 * host or a content creator. The live gift pipeline without a room ({@link LiveGiftsService.sendDirect}, place
 * CONTENT): the same prices, quantities and bag, the coins in one conditional debit (`CONTENT_GIFT`), the author's
 * cherries and charm and the sender's support as from a live gift, the sender's family points for coins. In the same
 * transaction the gift line (a comment of kind GIFT), the post's comment count and gift cherries, and the author's
 * notification `CONTENT_GIFT_RECEIVED` (one unread row per post). A retry with the same `clientId` is never charged.
 */
@Injectable()
export class ContentGiftsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gifts: GiftsService,
    private readonly liveGifts: LiveGiftsService,
    private readonly comments: CommentsService,
    private readonly users: UsersService,
    private readonly wallet: WalletService,
    private readonly notifier: Notifier,
  ) {}

  /**
   * `POST /posts/{postId}/gifts`. Order (§10.164.2): 404 (a post the caller cannot see: deleted, removed, not
   * published, an author who is not ACTIVE or a block either way), 400 the body, a retry with the same `clientId` → the
   * first send (`created` false; another post's or place's send with it → 409 `IDEMPOTENCY_CONFLICT`), 409
   * `CONTENT_GIFT_RECIPIENT_UNAVAILABLE` (`own_content`, `not_creator`), 403 `AUTH_FORBIDDEN` (the caller may not
   * comment there), then the gift pipeline: 409 `GIFT_UNAVAILABLE` (also a lucky gift or a quip), the rate limit, 409
   * `INSUFFICIENT_COINS` / `GIFT_BAG_INSUFFICIENT`.
   */
  async send(
    callerId: string,
    postId: string,
    body: unknown,
  ): Promise<{ created: boolean; result: ContentGiftResultDto }> {
    if (!isUuid(postId)) throw new AppException(ErrorCode.NOT_FOUND);
    const id = postId.toLowerCase();
    const first = await this.prisma.post.findFirst({
      where: { AND: [{ id }, visiblePostWhere(callerId)] },
      select: { id: true, authorId: true, commentsEnabled: true, whoCanComment: true },
    });
    if (!first) throw new AppException(ErrorCode.NOT_FOUND);
    const parsed = contentGiftSendSchema(this.gifts.quantities).safeParse(body ?? {}, { reportInput: true });
    if (!parsed.success) throw AppException.validation(zodErrorToDetails(parsed.error));
    const input = parsed.data;
    const clientId = input.clientId.toLowerCase();
    const replay = await this.replay(callerId, clientId, id);
    if (replay) return { created: false, result: replay };
    await this.check(this.prisma, callerId, first);

    let sent;
    try {
      sent = await this.liveGifts.sendDirect(
        callerId,
        first.authorId,
        { giftCode: input.giftCode, quantity: input.quantity, source: input.source, clientId },
        { edgeCountry: undefined },
        {
          before: async (tx) => {
            if (!(await this.users.lockActiveById(tx, callerId)))
              throw new AppException(ErrorCode.AUTH_UNAUTHENTICATED);
            // The post row is locked for the send (its counters); a change since the first check is refused here.
            await tx.$queryRaw`SELECT 1 FROM posts WHERE id = ${id}::uuid FOR UPDATE`;
            const post = await tx.post.findFirst({
              where: { AND: [{ id }, visiblePostWhere(callerId)] },
              select: { id: true, authorId: true, commentsEnabled: true, whoCanComment: true },
            });
            if (!post || post.authorId !== first.authorId) throw new AppException(ErrorCode.NOT_FOUND);
            await this.check(tx, callerId, post);
            return post.id;
          },
          after: async (tx, gift) => {
            const comment = await tx.comment.create({
              data: {
                postId: id,
                authorId: callerId,
                kind: 'GIFT',
                giftId: gift.giftId,
                text: '',
                createdAt: gift.at,
              },
              select: { id: true },
            });
            const post = await tx.post.update({
              where: { id },
              data: { commentCount: { increment: 1 }, giftCherries: { increment: gift.cherries } },
              select: { giftCherries: true },
            });
            await this.notifier.notify(tx, {
              type: 'CONTENT_GIFT_RECEIVED',
              recipientId: first.authorId,
              actorId: callerId,
              postId: id,
            });
            return { commentId: comment.id, giftCherries: post.giftCherries };
          },
        },
        'CONTENT',
      );
    } catch (err) {
      if ((violatedUniqueIndex(err) ?? '').includes('live_gifts_client_once')) {
        const raced = await this.replay(callerId, clientId, id);
        if (raced) return { created: false, result: raced };
      }
      throw err;
    }
    return {
      created: true,
      result: {
        comment: await this.comments.view(callerId, sent.extra.commentId),
        giftCherries: Number(sent.extra.giftCherries),
        coins: sent.coins,
        bagQuantity: sent.bagQuantity,
      },
    };
  }

  /** 409 for the caller's own post or an author who is not a host or a creator; 403 when the caller may not comment. */
  private async check(db: Tx, callerId: string, post: PostFacts): Promise<void> {
    if (post.authorId === callerId)
      throw new AppException(ErrorCode.CONTENT_GIFT_RECIPIENT_UNAVAILABLE, undefined, [
        { field: 'post', issue: 'own_content' },
      ]);
    if (!(await isContentGiftRecipient(db, post.authorId)))
      throw new AppException(ErrorCode.CONTENT_GIFT_RECIPIENT_UNAVAILABLE, undefined, [
        { field: 'post', issue: 'not_creator' },
      ]);
    // The gift line is a comment: the post's comment settings apply (§11.5).
    if (!post.commentsEnabled || post.whoCanComment === 'NOBODY')
      throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    if (post.whoCanComment === 'FOLLOWERS') {
      const follows = await db.follow.count({ where: { followerId: callerId, followeeId: post.authorId } });
      if (follows === 0) throw new AppException(ErrorCode.AUTH_FORBIDDEN);
    }
  }

  /**
   * The first send with this `clientId`: its gift line and the values now (null: none). A send with it elsewhere (a
   * live, a conversation, another post) → 409 `IDEMPOTENCY_CONFLICT`.
   */
  private async replay(
    callerId: string,
    clientId: string,
    postId: string,
  ): Promise<ContentGiftResultDto | null> {
    const row = await this.prisma.liveGift.findUnique({
      where: { senderId_clientId: { senderId: callerId, clientId } },
      select: { postId: true, giftCode: true, comment: { select: { id: true } } },
    });
    if (!row) return null;
    if (row.postId !== postId || !row.comment) throw new AppException(ErrorCode.IDEMPOTENCY_CONFLICT);
    const post = await this.prisma.post.findUniqueOrThrow({
      where: { id: postId },
      select: { giftCherries: true },
    });
    return {
      comment: await this.comments.view(callerId, row.comment.id),
      giftCherries: Number(post.giftCherries),
      coins: (await this.wallet.mine(callerId)).coins,
      bagQuantity: await stockOf(this.prisma, callerId, row.giftCode),
    };
  }
}
