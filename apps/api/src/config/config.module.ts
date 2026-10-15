import { Global, Module, type DynamicModule } from '@nestjs/common';
import { APP_CONFIG, type AppConfig } from './app-config.js';

/**
 * Provides the validated {@link AppConfig} under the {@link APP_CONFIG} token. The config is
 * loaded (and validated) once by the caller — `main.ts` from `process.env`, tests from an
 * explicit object — so no module reads `process.env` directly.
 */
@Global()
@Module({})
export class ConfigModule {
  static forRoot(config: AppConfig): DynamicModule {
    return {
      module: ConfigModule,
      providers: [{ provide: APP_CONFIG, useValue: config }],
      exports: [APP_CONFIG],
    };
  }
}
