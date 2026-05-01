import { Module } from '@nestjs/common';
import { ScheduleModule } from '@nestjs/schedule';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { AnaliticaModule } from './analitica/analitica.module';
import { AuthModule } from './auth/auth.module';
import { KitsModule } from './kits/kits.module';
import { LotesModule } from './lotes/lotes.module';
import { MovimientosModule } from './movimientos/movimientos.module';
import { NotificacionesModule } from './notificaciones/notificaciones.module';
import { PrismaModule } from './prisma/prisma.module';
import { ProductosModule } from './productos/productos.module';
import { SucursalesModule } from './sucursales/sucursales.module';
import { TransferenciasModule } from './transferencias/transferencias.module';
import { UsuariosModule } from './usuarios/usuarios.module';

@Module({
  imports: [
    ScheduleModule.forRoot(),
    PrismaModule,
    AuthModule,
    UsuariosModule,
    ProductosModule,
    KitsModule,
    LotesModule,
    MovimientosModule,
    SucursalesModule,
    TransferenciasModule,
    NotificacionesModule,
    AnaliticaModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
