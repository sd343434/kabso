import { Body, Controller, Get, Headers, HttpCode, Param, Post, Query, Res } from '@nestjs/common';
import type { Response } from 'express';
import type { AuthContext } from '../../common/http/request-context.js';
import { byUserId, RateLimit } from '../../common/rate-limit/rate-limit.decorator.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import type { PageDto } from '../posts/post-views.js';
import {
  RechargeOrdersService,
  type RechargeOrderDto,
  type RechargeOrderMessageDto,
  type RechargeQuoteDto,
} from './recharge-orders.service.js';

const CREATE = {
  bucket: 'recharge:order',
  rule: 'rechargeOrderUser',
  key: byUserId,
  replacesDefault: true,
} as const;
const ACTION = {
  bucket: 'recharge:order_action',
  rule: 'rechargeOrderActionUser',
  key: byUserId,
  replacesDefault: true,
} as const;

function sendImage(res: Response, bytes: Buffer): void {
  res.setHeader('Content-Type', 'image/webp');
  res.setHeader('Cache-Control', 'private, no-store');
  res.setHeader('Content-Disposition', 'inline');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.status(200).end(bytes);
}

/** Recharge orders «طلبات الشحن» (contract v1.69-social draft, D204, CONVENTIONS §10.64), tag `recharge`. */
@Controller('recharge-orders')
export class RechargeOrdersController {
  constructor(private readonly orders: RechargeOrdersService) {}

  @Get('quote')
  quote(@Query() query: unknown): Promise<RechargeQuoteDto> {
    return this.orders.quote(query);
  }

  /** 201 created now, 200 the same Idempotency-Key again. */
  @Post()
  @RateLimit(CREATE)
  async create(
    @CurrentAuth() auth: AuthContext,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: unknown,
    @Res({ passthrough: true }) res: Response,
  ): Promise<RechargeOrderDto> {
    const { created, result } = await this.orders.create(auth.userId, key, body);
    res.status(created ? 201 : 200);
    return result;
  }

  @Get()
  list(@CurrentAuth() auth: AuthContext, @Query() query: unknown): Promise<PageDto<RechargeOrderDto>> {
    return this.orders.list(auth.userId, query);
  }

  @Get(':orderId')
  get(@CurrentAuth() auth: AuthContext, @Param('orderId') id: string): Promise<RechargeOrderDto> {
    return this.orders.get(auth.userId, id);
  }

  @Get(':orderId/messages')
  messages(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Query() query: unknown,
  ): Promise<PageDto<RechargeOrderMessageDto>> {
    return this.orders.messages(auth.userId, id, query);
  }

  @Post(':orderId/messages')
  @HttpCode(201)
  @RateLimit(ACTION)
  postMessage(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Body() body: unknown,
  ): Promise<RechargeOrderMessageDto> {
    return this.orders.postMessage(auth.userId, id, body);
  }

  @Get(':orderId/messages/:messageId/image')
  async image(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Param('messageId') messageId: string,
    @Res() res: Response,
  ): Promise<void> {
    sendImage(res, await this.orders.image(auth.userId, id, messageId));
  }

  @Post(':orderId/payment-details')
  @HttpCode(200)
  @RateLimit(ACTION)
  details(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Body() body: unknown,
  ): Promise<RechargeOrderDto> {
    return this.orders.sendDetails(auth.userId, id, body);
  }

  @Post(':orderId/notice-ack')
  @HttpCode(200)
  @RateLimit(ACTION)
  ack(@CurrentAuth() auth: AuthContext, @Param('orderId') id: string): Promise<RechargeOrderDto> {
    return this.orders.ackNotice(auth.userId, id);
  }

  @Post(':orderId/paid')
  @HttpCode(200)
  @RateLimit(ACTION)
  paid(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Body() body: unknown,
  ): Promise<RechargeOrderDto> {
    return this.orders.markPaid(auth.userId, id, body);
  }

  @Post(':orderId/confirm')
  @HttpCode(200)
  @RateLimit(ACTION)
  confirm(@CurrentAuth() auth: AuthContext, @Param('orderId') id: string): Promise<RechargeOrderDto> {
    return this.orders.confirm(auth.userId, id);
  }

  @Post(':orderId/dispute')
  @HttpCode(200)
  @RateLimit(ACTION)
  dispute(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Body() body: unknown,
  ): Promise<RechargeOrderDto> {
    return this.orders.dispute(auth.userId, id, body);
  }

  @Post(':orderId/cancel')
  @HttpCode(200)
  @RateLimit(ACTION)
  cancel(
    @CurrentAuth() auth: AuthContext,
    @Param('orderId') id: string,
    @Body() body: unknown,
  ): Promise<RechargeOrderDto> {
    return this.orders.cancel(auth.userId, id, body);
  }
}
