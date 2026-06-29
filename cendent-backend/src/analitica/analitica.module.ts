import { Module } from '@nestjs/common';
import { AnaliticaController } from './analitica.controller';
import { AnaliticaScheduler } from './analitica.scheduler';
import { AnaliticaService } from './analitica.service';

@Module({
  controllers: [AnaliticaController],
  providers: [AnaliticaService, AnaliticaScheduler],
})
export class AnaliticaModule {}
