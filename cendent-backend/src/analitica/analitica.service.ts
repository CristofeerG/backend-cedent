import { Injectable, Logger } from '@nestjs/common';
import * as brain from 'brain.js';
import { PrismaService } from '../prisma/prisma.service';
import {
  DemandaProductoDto,
  PrediccionProductoDto,
  ResultadoEntrenamientoDto,
  ResultadoPrediccionDto,
} from './dto/resultado-entrenamiento.dto';

const ITERACIONES = 500;
const UMBRAL_ERROR = 0.01;
const MIN_PUNTOS_SERIE = 14;
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

  private suavizarSerie(serie: number[]): number[] {
    return serie.map((_, i) => {
      const inicio = Math.max(0, i - 1);
      const fin = Math.min(serie.length - 1, i + 1);
      const ventana = serie.slice(inicio, fin + 1);
      return ventana.reduce((s, v) => s + v, 0) / ventana.length;
    });
  }

  private crearYEntrenarLSTM(serieNormalizada: number[]) {
    const red = new (brain.recurrent.LSTMTimeStep as any)({
      inputSize: 1,
      hiddenLayers: [10, 5],
      outputSize: 1,
    });

    const serieSmooth = this.suavizarSerie(serieNormalizada);

    const resultado = red.train([serieSmooth], {
      iterations: ITERACIONES,
      errorThresh: UMBRAL_ERROR,
      log: false,
    });

    return { red, serieSmooth, errorEntrenamiento: resultado.error as number };
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
      // Rellenar días sin consumo con 0 y ordenar cronológicamente
      const fechas = Array.from(mapaFecha.keys()).sort();
      if (fechas.length >= 2) {
        const cursor = new Date(fechas[0]);
        const ultima = new Date(fechas[fechas.length - 1]);
        while (cursor <= ultima) {
          const key = cursor.toISOString().slice(0, 10);
          if (!mapaFecha.has(key)) mapaFecha.set(key, 0);
          cursor.setDate(cursor.getDate() + 1);
        }
      }
      const fechasOrdenadas = Array.from(mapaFecha.keys()).sort();
      const serie = fechasOrdenadas.map((f) => mapaFecha.get(f)!);

      if (serie.length < MIN_PUNTOS_SERIE) continue;

      const max = Math.max(...serie);
      if (max === 0) continue;

      const serieNorm = serie.map((v) => v / max);
      const { red, serieSmooth, errorEntrenamiento } = this.crearYEntrenarLSTM(serieNorm);

      const prediccionNorm: number = red.run(serieSmooth);

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

  private async generarPrediccion(idSucursal: number): Promise<ResultadoPrediccionDto> {
    this.logger.log(`Generando predicción de demanda (${HORIZONTE_DIAS}d) para sucursal ${idSucursal}...`);

    const egresos = await this.obtenerEgresosPorSucursal(idSucursal);
    const { mapaConsumos, nombreProducto } = this.agruparConsumosPorFecha(egresos);

    const idsProductos = Array.from(mapaConsumos.keys());
    const stockPorProducto = await this.obtenerStockActual(idSucursal, idsProductos);

    const predicciones: DemandaProductoDto[] = [];

    for (const [idProducto, mapaFecha] of mapaConsumos.entries()) {
      // Rellenar días sin consumo con 0 y ordenar cronológicamente
      const fechas = Array.from(mapaFecha.keys()).sort();
      if (fechas.length >= 2) {
        const cursor = new Date(fechas[0]);
        const ultima = new Date(fechas[fechas.length - 1]);
        while (cursor <= ultima) {
          const key = cursor.toISOString().slice(0, 10);
          if (!mapaFecha.has(key)) mapaFecha.set(key, 0);
          cursor.setDate(cursor.getDate() + 1);
        }
      }
      const fechasOrdenadas = Array.from(mapaFecha.keys()).sort();
      const serie = fechasOrdenadas.map((f) => mapaFecha.get(f)!);

      if (serie.length < MIN_PUNTOS_SERIE) continue;

      const max = Math.max(...serie);
      if (max === 0) continue;

      const serieNorm = serie.map((v) => v / max);
      const { red, serieSmooth } = this.crearYEntrenarLSTM(serieNorm);

      // Proyectar los próximos HORIZONTE_DIAS valores normalizados
      const forecastNorm: number[] = red.forecast(serieSmooth, HORIZONTE_DIAS);
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

    predicciones.sort((a, b) => a.dias_para_quiebre - b.dias_para_quiebre);

    this.logger.log(`Predicción finalizada: ${predicciones.length} producto(s) para sucursal ${idSucursal}.`);

    return {
      id_sucursal: idSucursal,
      total_productos_analizados: predicciones.length,
      predicciones,
    };
  }

  async generarYGuardar(idSucursal: number): Promise<ResultadoPrediccionDto & { generado_en: Date }> {
    const resultado = await this.generarPrediccion(idSucursal);
    const registro = await this.prisma.predicciones_cache.upsert({
      where: { id_sucursal: idSucursal },
      create: { id_sucursal: idSucursal, resultado: resultado as any },
      update: { resultado: resultado as any },
    });
    return { ...resultado, generado_en: registro.generado_en };
  }

  async predecirDemanda(idSucursal: number): Promise<(ResultadoPrediccionDto & { generado_en?: Date }) | null> {
    const cached = await this.prisma.predicciones_cache.findUnique({
      where: { id_sucursal: idSucursal },
    });
    if (cached) {
      return { ...(cached.resultado as any), generado_en: cached.generado_en };
    }
    // Sin caché: lanzar entrenamiento en background y responder null inmediatamente
    setImmediate(() => {
      this.generarYGuardar(idSucursal).catch(e =>
        this.logger.error(`Background training failed for sucursal ${idSucursal}: ${e.message}`),
      );
    });
    return null;
  }
}
