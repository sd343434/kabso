import { Module } from '@nestjs/common';
import { CountriesService } from './countries.service.js';

/**
 * `countries` (contract v1.4, CONVENTIONS §11.7): the vendored ISO 3166-1 list with CLDR 48 names.
 * No dependencies; `users` and `live` use it to validate and localize. `GET /countries` is served
 * by the profiles module (it needs the caller's stored locale).
 */
@Module({
  providers: [CountriesService],
  exports: [CountriesService],
})
export class CountriesModule {}
