import { Module } from '@nestjs/common';
import { CountriesModule } from '../countries/countries.module.js';
import { MediaModule } from '../media/media.module.js';
import { UsersController } from './users.controller.js';
import { UsersService } from './users.service.js';

@Module({
  imports: [MediaModule, CountriesModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
