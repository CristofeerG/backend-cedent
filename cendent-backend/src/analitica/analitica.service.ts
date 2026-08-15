import { Injectable, Logger } from '@nestjs/common';
import * as brain from 'brain.js';
import { PrismaService } from '../prisma/prisma.service';
import {
  ConsumoRealDto,
  DemandaProductoDto,
  PrediccionProductoDto,
  ResultadoEntrenamientoDto,
  ResultadoPrediccionDto,
} from './dto/resultado-entrenamiento.dto';

const ITERACIONES = 500;
const UMBRAL_ERROR = 0.01;
const MIN_PUNTOS_SERIE = 14;
const HORIZONTE_DIAS = 30;
// Factor de amortiguamiento para el forecast recursivo del LSTM.
// En el paso i, el valor normalizado predicho se "jala" hacia el promedio
// histórico con peso (1 - F^i), evitando la divergencia acumulada.
// Con F = 0.9 la primera semana quedaba casi sin amortiguar (peso 0.9^0..0.9^6
// = 1.00..0.53), así que el pico crudo del LSTM se colaba entero en S+1 y
// producía un escalón irreal frente a S+2..S+4. Con 0.75 el anclaje al
// promedio histórico entra desde el día 2 (1.00..0.18) y la curva sale plana.
const FACTOR_AMORTIGUACION = 0.75;
// Productos sin ningún egreso en los últimos VENTANA_ACTIVIDAD_DIAS días se
// omiten de la predicción: el LSTM, entrenado en histórico antiguo, generaría
// consumo positivo para productos que en la práctica están inactivos.
const VENTANA_ACTIVIDAD_DIAS = 45;
// Movimientos que descuentan stock de la sucursal. La predicción y el consumo
// real deben usar exactamente esta lista, o los dos lados del gráfico del
// dashboard cubrirían universos distintos.
const TIPOS_EGRESO = ['EGRESO_KIT', 'EGRESO_DIRECTO', 'SALIDA_TRANSFERENCIA'];
// Ventana del comparativo de consumo real del dashboard: 4 semanas.
const SEMANAS_CONSUMO_REAL = 4;

@Injectable()
export class AnaliticaService {
  private readonly logger = new Logger(AnaliticaService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ─── helpers compartidos ────────────────────────────────────────────────────

  private async obtenerEgresosPorSucursal(idSucursal: number) {
    return this.prisma.movimientos.findMany({
      where: {
        tipo_mov: { in: TIPOS_EGRESO },
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

  /**
   * Consumo real de las últimas 4 semanas, agregado por semana, más el conjunto
   * de productos que lo generaron.
   *
   * El dashboard usaba GET /movimientos para esto, pero ese endpoint corta en
   * los últimos 200 registros (~21 días de operación actual): la semana más
   * antigua de la ventana llegaba casi vacía, el total real quedaba subvaluado
   * y los productos activos solo en esos días perdidos no entraban al filtro de
   * la proyección. Aquí se consulta por rango de fecha, así que la ventana está
   * completa sin importar el volumen de movimientos.
   */
  async obtenerConsumoReal(idSucursal: number): Promise<ConsumoRealDto> {
    const diasVentana = SEMANAS_CONSUMO_REAL * 7;

    // Inicio a medianoche: los buckets semanales quedan alineados a días
    // completos y no se desplazan según la hora en que se consulte.
    const inicio = new Date();
    inicio.setHours(0, 0, 0, 0);
    inicio.setDate(inicio.getDate() - diasVentana);

    const egresos = await this.prisma.movimientos.findMany({
      where: {
        tipo_mov: { in: TIPOS_EGRESO },
        fecha_hora: { gte: inicio },
        lotes: { id_sucursal: idSucursal },
      },
      select: {
        cantidad: true,
        fecha_hora: true,
        lotes: { select: { id_producto: true } },
      },
    });

    const semanas = new Array<number>(SEMANAS_CONSUMO_REAL).fill(0);
    const productosActivos = new Set<number>();

    for (const mov of egresos) {
      if (!mov.fecha_hora) continue;
      const dias = (mov.fecha_hora.getTime() - inicio.getTime()) / 86_400_000;
      const semana = Math.floor(dias / 7);
      // Descarta fechas fuera de rango (p. ej. un fecha_hora futuro por error
      // de captura) para que no distorsionen ni el total ni la última barra.
      if (semana < 0 || semana >= SEMANAS_CONSUMO_REAL) continue;

      semanas[semana] += Number(mov.cantidad);
      if (mov.lotes?.id_producto != null) {
        productosActivos.add(mov.lotes.id_producto);
      }
    }

    const redondear = (v: number) => Math.round(v * 100) / 100;

    return {
      id_sucursal: idSucursal,
      dias_ventana: diasVentana,
      semanas: semanas.map(redondear),
      total: redondear(semanas.reduce((s, v) => s + v, 0)),
      productos_activos: Array.from(productosActivos).sort((a, b) => a - b),
    };
  }

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

      // Compuerta de actividad: si el último egreso real supera VENTANA_ACTIVIDAD_DIAS,
      // el producto está inactivo → omitirlo evita que el LSTM prediga consumo basado
      // en historial antiguo, lo que inflaría el total artificialmente.
      const ultimaFechaConConsumo = fechas[fechas.length - 1];
      const diasInactividad =
        (Date.now() - new Date(ultimaFechaConConsumo).getTime()) / 86_400_000;
      if (diasInactividad > VENTANA_ACTIVIDAD_DIAS) continue;

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

      // Promedio histórico normalizado: ancla del amortiguamiento
      const promSmooth = serieSmooth.reduce((a, b) => a + b, 0) / serieSmooth.length;

      // Clamp [0, 1.2] + damped trend: a medida que avanza el horizonte el
      // valor se acerca al promedio histórico, frenando la divergencia recursiva.
      const forecastDamped = forecastNorm.map((v, i) => {
        const clamped = Math.min(Math.max(v, 0), 1.2);
        const peso = Math.pow(FACTOR_AMORTIGUACION, i);
        return clamped * peso + promSmooth * (1 - peso);
      });

      const consumoPredicho30Dias = Math.round(
        forecastDamped.reduce((suma, v) => suma + v * max, 0) * 100,
      ) / 100;

      // Desglose semanal del forecast denormalizado.
      // Semanas 1–3 = exactamente 7 días (índices 0-6, 7-13, 14-20).
      // Semana 4    = días 22–30 (9 días): los 2 sobrantes del horizonte de
      // 30 d se acumulan en el último bloque para que el gráfico siempre tenga
      // exactamente 4 columnas sin un bloque parcial que distorsione la escala.
      const prediccionSemanal = [0, 1, 2, 3].map((sem) => {
        const inicio = sem * 7;
        const fin = sem === 3 ? HORIZONTE_DIAS : inicio + 7;
        return (
          Math.round(
            forecastDamped
              .slice(inicio, fin)
              .reduce((s, v) => s + v * max, 0) * 100,
          ) / 100
        );
      });

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
        prediccion_semanal: prediccionSemanal,
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
