import { webcrypto } from 'node:crypto';
// Polyfill necesario para @nestjs/schedule en Node.js < 19
if (!globalThis.crypto) {
  (globalThis as any).crypto = webcrypto;
}

import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.enableCors();

  const configSwagger = new DocumentBuilder()
    .setTitle('API CEDENT')
    .setDescription('Sistema de Gestión Logística y Analítica Predictiva')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const documento = SwaggerModule.createDocument(app, configSwagger);
  SwaggerModule.setup('api/docs', app, documento);

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
