import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import {
  AlertaCaducidadPayload,
  AlertaStockPayload,
  NotificacionesGateway,
} from './notificaciones.gateway';

const DIAS_ALERTA_CADUCIDAD = 30;

@Injectable()
export class NotificacionesService {
  private readonly logger = new Logger(NotificacionesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: NotificacionesGateway,
  ) {}

  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async revisarInventario() {
    this.logger.log('Iniciando revisión automática de inventario...');

    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    const limiteCaducidad = new Date(hoy);
    limiteCaducidad.setDate(limiteCaducidad.getDate() + DIAS_ALERTA_CADUCIDAD);

    // Ambas consultas en paralelo para mayor eficiencia
    const [alertasCaducidad, alertasStock] = await Promise.all([
      this.consultarLotesPorCaducar(hoy, limiteCaducidad),
      this.consultarProductosBajoStock(hoy),
    ]);

    if (alertasCaducidad.length > 0) {
      this.gateway.emitirAlertaCaducidad(alertasCaducidad);
      this.logger.warn(`Alerta caducidad emitida: ${alertasCaducidad.length} lote(s) próximos a vencer`);
    }

    if (alertasStock.length > 0) {
      this.gateway.emitirAlertaStock(alertasStock);
      this.logger.warn(`Alerta stock emitida: ${alertasStock.length} producto(s) bajo mínimo`);
    }

    this.logger.log('Revisión de inventario finalizada.');
    return { alertasCaducidad, alertasStock };
  }

  private async consultarLotesPorCaducar(
    hoy: Date,
    limite: Date,
  ): Promise<AlertaCaducidadPayload[]> {
    const lotes = await this.prisma.lotes.findMany({
      where: {
        fecha_venc: { gte: hoy, lte: limite },
        stock_actual: { gt: 0 },
      },
      include: {
        productos: { select: { nombre_mat: true } },
        sucursales: { select: { nom_sucursal: true } },
      },
      orderBy: { fecha_venc: 'asc' },
    });

    return lotes.map((lote) => {
      const diasRestantes = Math.ceil(
        (lote.fecha_venc.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24),
      );
      return {
        id_lote: lote.id_lote,
        codigo_lote: lote.codigo_lote,
        nombre_producto: lote.productos?.nombre_mat ?? `id_producto ${lote.id_producto}`,
        nombre_sucursal: lote.sucursales?.nom_sucursal ?? `id_sucursal ${lote.id_sucursal}`,
        stock_actual: Number(lote.stock_actual),
        fecha_venc: lote.fecha_venc,
        dias_restantes: diasRestantes,
      };
    });
  }

  private async consultarProductosBajoStock(hoy: Date): Promise<AlertaStockPayload[]> {
    // Trae sólo productos que tienen stock_min definido (> 0)
    const productos = await this.prisma.productos.findMany({
      where: { stock_min: { gt: 0 } },
      include: {
        lotes: {
          where: { fecha_venc: { gte: hoy } },
          select: { stock_actual: true },
        },
      },
    });

    const productosBajoStock: AlertaStockPayload[] = [];

    for (const producto of productos) {
      const stockTotal = producto.lotes.reduce(
        (suma, lote) => suma + Number(lote.stock_actual),
        0,
      );
      const stockMin = Number(producto.stock_min);

      if (stockTotal <= stockMin) {
        productosBajoStock.push({
          id_producto: producto.id_producto,
          nombre_producto: producto.nombre_mat,
          stock_total: stockTotal,
          stock_min: stockMin,
        });
      }
    }

    return productosBajoStock;
  }
}
