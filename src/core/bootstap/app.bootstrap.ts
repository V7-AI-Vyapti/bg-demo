import { INestApplication } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export function bootstrapApp(app: INestApplication): void {
    const config = app.get(ConfigService);
    const apiPrefix = config.get<string>('app.apiPrefix');
    if (apiPrefix) {
        app.setGlobalPrefix(apiPrefix);
    }
    const origin = config.get<string[] | undefined>('cors.origin');
    const credentials = config.get<boolean | undefined>('cors.credentials');
    app.enableCors({
        origin: origin ?? true,
        credentials: credentials ?? false,
    });
    app.enableShutdownHooks();
}
