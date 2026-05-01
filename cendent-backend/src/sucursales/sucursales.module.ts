import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { SucursalesController } from './sucursales.controller';
import { SucursalesService } from './sucursales.service';

@Module({
  imports: [PrismaModule],
  controllers: [SucursalesController],
  providers: [SucursalesService],
})
export class SucursalesModule {}
