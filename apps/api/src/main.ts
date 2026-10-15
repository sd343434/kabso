import 'reflect-metadata';
import 'dotenv/config';
import { createApp } from './app.setup.js';
import { ConfigValidationError, loadConfig, type AppConfig } from './config/app-config.js';

async function bootstrap(): Promise<void> {
  let config: AppConfig;
  try {
    config = loadConfig(process.env);
  } catch (err) {
    if (err instanceof ConfigValidationError) {
      // Fail fast with an actionable message (values are never printed).
      process.stderr.write(`${err.message}\n`);
      process.exit(1);
    }
    throw err;
  }

  const app = await createApp(config);
  await app.listen(config.port, '0.0.0.0');
}

bootstrap().catch((err: unknown) => {
  process.stderr.write(`Fatal: failed to start Kabso API: ${(err as Error).stack ?? String(err)}\n`);
  process.exit(1);
});
