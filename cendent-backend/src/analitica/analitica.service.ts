import { Injectable, Logger } from '@nestjs/common';
import * as brain from 'brain.js';
import { PrismaService } from '../prisma/prisma.service';
import {
  DemandaProductoDto,
  PrediccionProductoDto,
  ResultadoEntrenamientoDto,
  ResultadoPrediccionDto,
} from './dto/resultado-entrenamiento.dto';

const ITERACIONES = 100;
const UMBRAL_ERROR = 0.025;
const MIN_PUNTOS_SERIE = 3;
const HORIZONTE_DIAS = 30;

@Injectable()
export class AnaliticaService {
  private readonly logger = new Logger(AnaliticaService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── helpers compartidos ────────────────────────────────────────────────────

  private async obtenerEgresosPorSucursal(idSucursal: number) {
    return this.prisma.movimientos.findMany({
      where: {
        tipo_mov: { in: ['EGRESO_KIT', 'EGRESO_DIRECTO', 'SALIDA_TRANSFERENCIA'] },
        lotes: { id_sucursal: idSucursal },
      },
      include: {
        lotes: {
          include: { productos: { select: { nombre_mat: true } } },
        },
      },
      orderBy: { fecha_hora: 'asc' },
    });
  }

  private agruparConsumosPorFecha(egresos: Awaited<ReturnType<typeof this.obtenerEgresosPorSucursal>>) {
    const mapaConsumos = new Map<number, Map<string, number>>();
    const nombreProducto = new Map<number, string>();

    for (const mov of egresos) {
      if (!mov.lotes || mov.lotes.id_producto === null) continue;

      const idProducto = mov.lotes.id_producto;
      const fecha = (mov.fecha_hora ?? new Date()).toISOString().slice(0, 10);
      const cantidad = Number(mov.cantidad);

      if (!mapaConsumos.has(idProducto)) {
        mapaConsumos.set(idProducto, new Map());
        nombreProducto.set(
          idProducto,
          mov.lotes.productos?.nombre_mat ?? `producto_${idProducto}`,
        );
      }

      const mapaFecha = mapaConsumos.get(idProducto)!;
      mapaFecha.set(fecha, (mapaFecha.get(fecha) ?? 0) + cantidad);
    }

    return { mapaConsumos, nombreProducto };
  }

  private crearYEntrenarLSTM(serieNormalizada: number[]) {
    const red = new (brain.recurrent.LSTMTimeStep as any)({
      inputSize: 1,
      hiddenLayers: [10, 5],
      outputSize: 1,
    });

    const resultado = red.train([serieNormalizada], {
      iterations: ITERACIONES,
      errorThresh: UMBRAL_ERROR,
      log: false,
    });

    return { red, errorEntrenamiento: resultado.error as number };
  }

  private async obtenerStockActual(idSucursal: number, idsProductos: number[]): Promise<Map<number, number>> {
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    const lotes = await this.prisma.lotes.findMany({
      where: {
        id_sucursal: idSucursal,
        id_producto: { in: idsProductos },
        fecha_venc: { gte: hoy },
        stock_actual: { gt: 0 },
      },
      select: { id_producto: true, stock_actual: true },
    });

    const stockPorProducto = new Map<number, number>();
    for (const lote of lotes) {
      if (lote.id_producto === null) continue;
      const acum = stockPorProducto.get(lote.id_producto) ?? 0;
      stockPorProducto.set(lote.id_producto, acum + Number(lote.stock_actual));
    }

    return stockPorProducto;
  }

  // ─── endpoints ──────────────────────────────────────────────────────────────

  async prepararYEntrenar(idSucursal: number): Promise<ResultadoEntrenamientoDto> {
    this.logger.log(`Iniciando entrenamiento LSTM para sucursal ${idSucursal}...`);

    const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
    const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);

    const predicciones: PrediccionProductoDto[] = [];

    for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
      const serie = Array.from(mapaFecha.values());
      if (serie.length < MIN_PUNTOS_SERIE) continue;

      const max = Math.max(...serie);
      if (max === 0) continue;

      const serieNorm = serie.map((v) => v / max);
      const { red, errorEntrenamiento } = this.crearYEntrenarLSTM(serieNorm);

      const prediccionNorm: number = red.run(serieNorm);

      predicciones.push({
        id_producto: idProducto,
        nombre_producto: nombreProducto.get(idProducto) ?? `producto_${idProducto}`,
        puntos_historicos: serie.length,
        prediccion_siguiente: Math.round(prediccionNorm * max * 100) / 100,
        error_entrenamiento: Math.round(errorEntrenamiento * 10000) / 10000,
      });
    }

    this.logger.log(`Entrenamiento finalizado: ${predicciones.length} producto(s) para sucursal ${idSucursal}.`);

    return {
      id_sucursal: idSucursal,
      total_productos_entrenados: predicciones.length,
      iteraciones: ITERACIONES,
      predicciones,
    };
  }

  async predecirDemanda(idSucursal: number): Promise<ResultadoPrediccionDto> {
    this.logger.log(`Iniciando predicción de demanda (${HORIZONTE_DIAS}d) para sucursal ${idSucursal}...`);

    const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
    const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);

    const idsProductos = Array.from(mapaConsumos.keys());
    const stockPorProducto = await this.obtenerStockActual(idSucursal, idsProductos);

    const predicciones: DemandaProductoDto[] = [];

    for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
      const serie = Array.from(mapaFecha.values());
      if (serie.length < MIN_PUNTOS_SERIE) continue;

      const max = Math.max(...serie);
      if (max === 0) continue;

      const serieNorm = serie.map((v) => v / max);
      const { red } = this.crearYEntrenarLSTM(serieNorm);

      // Proyectar los próximos HORIZONTE_DIAS valores normalizados
      const forecastNorm: number[] = red.forecast(serieNorm, HORIZONTE_DIAS);
      const consumoPredicho30Dias = Math.round(
        forecastNorm.reduce((suma, v) => suma + v * max, 0) * 100,
      ) / 100;

      const stockTotal = stockPorProducto.get(idProducto) ?? 0;
      const promedioDiario = consumoPredicho30Dias / HORIZONTE_DIAS;

      const diasParaQuiebre =
        stockTotal === 0
          ? 0
          : promedioDiario > 0
            ? Math.floor(stockTotal / promedioDiario)
            : 9999;

      const sugerenciaCompra = Math.max(0, Math.round((consumoPredicho30Dias - stockTotal) * 100) / 100);

      predicciones.push({
        id_producto: idProducto,
        nombre_mat: nombreProducto.get(idProducto) ?? `producto_${idProducto}`,
        stock_total: Math.round(stockTotal * 100) / 100,
        consumo_predicho_30_dias: consumoPredicho30Dias,
        dias_para_quiebre: diasParaQuiebre,
        sugerencia_compra: sugerenciaCompra,
      });
    }

    // Ordenar por urgencia: primero los de menor días para quiebre
    predicciones.sort((a, b) => a.dias_para_quiebre - b.dias_para_quiebre);

    this.logger.log(`Predicción finalizada: ${predicciones.length} producto(s) analizados para sucursal ${idSucursal}.`);

    return {
      id_sucursal: idSucursal,
      total_productos_analizados: predicciones.length,
      predicciones,
    };
  }
}
