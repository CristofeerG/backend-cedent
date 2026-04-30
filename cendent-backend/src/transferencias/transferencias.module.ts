import { Module } from '@nestjs/common';
import { TransferenciasController } from './transferencias.controller';
import { TransferenciasService } from './transferencias.service';

@Module({
  controllers: [TransferenciasController],
  providers: [TransferenciasService],
})
export class TransferenciasModule {}
