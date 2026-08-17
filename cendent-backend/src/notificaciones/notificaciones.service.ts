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

  /**
   * Barrido diario: revisa cada sucursal activa por separado.
   *
   * Antes esto lanzaba una sola consulta global y un único broadcast, así que
   * todas las sucursales recibían las alertas de todas. Peor aún, el stock se
   * sumaba cruzando sucursales: las existencias de una tapaban el faltante de
   * la otra y la alerta de stock mínimo nunca se disparaba.
   */
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async revisarInventario() {
    this.logger.log('Iniciando revisión automática de inventario...');

    const sucursales = await this.prisma.sucursales.findMany({
      where: { estado: true },
      select: { id_sucursal: true },
      orderBy: { id_sucursal: 'asc' },
    });

    const resultados = await Promise.all(
      sucursales.map((s) => this.revisarSucursal(s.id_sucursal)),
    );

    this.logger.log(`Revisión de inventario finalizada (${sucursales.length} sucursal(es)).`);
    return resultados;
  }

  /**
   * Revisa una sucursal y notifica únicamente a los clientes de esa sucursal.
   */
  async revisarSucursal(idSucursal: number) {
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    const limiteCaducidad = new Date(hoy);
    limiteCaducidad.setDate(limiteCaducidad.getDate() + DIAS_ALERTA_CADUCIDAD);

    // Ambas consultas en paralelo para mayor eficiencia
    const [alertasCaducidad, alertasStock] = await Promise.all([
      this.consultarLotesPorCaducar(idSucursal, hoy, limiteCaducidad),
      this.consultarProductosBajoStock(idSucursal, hoy),
    ]);

    if (alertasCaducidad.length > 0) {
      this.gateway.emitirAlertaCaducidad(idSucursal, alertasCaducidad);
      this.logger.warn(
        `[sucursal ${idSucursal}] Alerta caducidad: ${alertasCaducidad.length} lote(s) próximos a vencer`,
      );
    }

    if (alertasStock.length > 0) {
      this.gateway.emitirAlertaStock(idSucursal, alertasStock);
      this.logger.warn(
        `[sucursal ${idSucursal}] Alerta stock: ${alertasStock.length} producto(s) bajo mínimo`,
      );
    }

    return { id_sucursal: idSucursal, alertasCaducidad, alertasStock };
  }

  private async consultarLotesPorCaducar(
    idSucursal: number,
    hoy: Date,
    limite: Date,
  ): Promise<AlertaCaducidadPayload[]> {
    const lotes = await this.prisma.lotes.findMany({
      where: {
        id_sucursal: idSucursal,
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

  private async consultarProductosBajoStock(
    idSucursal: number,
    hoy: Date,
  ): Promise<AlertaStockPayload[]> {
    // Sólo productos que la sucursal realmente maneja y que tienen stock_min
    // definido (> 0).
    //
    // El `some` no es opcional: `productos` es el catálogo global, así que sin
    // él se evaluaban los 353 productos con mínimo y los que la sucursal nunca
    // ha manejado salían con stockTotal = 0, cumpliendo `0 <= stock_min` y
    // disparando alerta. Una sucursal con 16 productos recibía 353 avisos de
    // reposición. Un producto que la sucursal no maneja no está agotado: no
    // forma parte de su inventario. Mismo criterio que usa
    // ProductosService.obtenerInventario.
    const productos = await this.prisma.productos.findMany({
      where: {
        stock_min: { gt: 0 },
        lotes: { some: { id_sucursal: idSucursal } },
      },
      include: {
        lotes: {
          // El filtro por sucursal va aquí, en los lotes: `productos` es un
          // catálogo global y sin esto la suma cruzaba sucursales.
          where: { id_sucursal: idSucursal, fecha_venc: { gte: hoy } },
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
