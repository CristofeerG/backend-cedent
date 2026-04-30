"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const node_crypto_1 = require("node:crypto");
if (!globalThis.crypto) {
    globalThis.crypto = node_crypto_1.webcrypto;
}
const common_1 = require("@nestjs/common");
const core_1 = require("@nestjs/core");
const swagger_1 = require("@nestjs/swagger");
const app_module_1 = require("./app.module");
async function bootstrap() {
    const app = await core_1.NestFactory.create(app_module_1.AppModule);
    app.useGlobalPipes(new common_1.ValidationPipe({ whitelist: true, transform: true }));
    app.enableCors();
    const configSwagger = new swagger_1.DocumentBuilder()
        .setTitle('API CENDENT')
        .setDescription('Sistema de Gestión Logística y Analítica Predictiva')
        .setVersion('1.0')
        .addBearerAuth()
        .build();
    const documento = swagger_1.SwaggerModule.createDocument(app, configSwagger);
    swagger_1.SwaggerModule.setup('api/docs', app, documento);
    await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
//# sourceMappingURL=main.js.map