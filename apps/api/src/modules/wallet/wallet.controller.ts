import { Controller, Get } from '@nestjs/common';
import type { AuthContext } from '../../common/http/request-context.js';
import { CurrentAuth } from '../auth/current-auth.decorator.js';
import { WalletService, type WalletDto } from './wallet.service.js';

/** The caller's coins (contract v1.19-live draft, CP-017, CONVENTIONS §10.19). */
@Controller('wallet')
export class WalletController {
  constructor(private readonly wallet: WalletService) {}

  /** Per-user default rate limit (§7). */
  @Get('me')
  mine(@CurrentAuth() auth: AuthContext): Promise<WalletDto> {
    return this.wallet.mine(auth.userId);
  }
}
