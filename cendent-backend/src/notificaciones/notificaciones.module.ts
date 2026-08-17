import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { NotificacionesController } from './notificaciones.controller';
import { NotificacionesGateway } from './notificaciones.gateway';
import { NotificacionesService } from './notificaciones.service';

@Module({
  // El gateway verifica el JWT del socket por su cuenta: la conexión WebSocket
  // no pasa por JwtAuthGuard, que sólo cubre peticiones HTTP.
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET,
      signOptions: { expiresIn: (process.env.JWT_EXPIRES_IN ?? '8h') as any },
    }),
  ],
  controllers: [NotificacionesController],
  providers: [NotificacionesGateway, NotificacionesService],
  exports: [NotificacionesGateway],
})
export class NotificacionesModule {}
