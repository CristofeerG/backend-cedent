import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { AnaliticaService } from './analitica.service';

@Injectable()
export class AnaliticaScheduler {
  private readonly logger = new Logger(AnaliticaScheduler.name);

  constructor(
    private readonly analiticaService: AnaliticaService,
    private readonly prisma: PrismaService,
  ) {}

  @Cron('0 7 * * *')
  async generarTodasLasPredicciones() {
    this.logger.log('Cron 07:00 — generando predicciones para todas las sucursales activas...');

    const sucursales = await this.prisma.sucursales.findMany({
      where: { estado: true },
      select: { id_sucursal: true },
    });

    for (const { id_sucursal } of sucursales) {
      try {
        await this.analiticaService.generarYGuardar(id_sucursal);
      } catch (err) {
        this.logger.error(`Error generando predicción para sucursal ${id_sucursal}: ${(err as Error).message}`);
      }
    }

    this.logger.log(`Predicciones generadas para ${sucursales.length} sucursal(es).`);
  }
}
