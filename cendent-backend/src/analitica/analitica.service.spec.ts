import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import * as brain from 'brain.js';
import { AnaliticaService } from './analitica.service';
import { PrismaService } from '../prisma/prisma.service';

// ─── Helpers ────────────────────────────────────────────────────────────────

function crearPrismaMock() {
  return {
    movimientos: { findMany: jest.fn() },
    lotes: { findMany: jest.fn() },
    predicciones_cache: {
      findUnique: jest.fn(),
      upsert: jest.fn(),
    },
  };
}

/**
 * Genera N movimientos para un producto, cada uno en una fecha consecutiva
 * distinta, comenzando en 2024-01-01.
 * Si se pasan `cantidades`, se ciclan; si no, se usa (i % 5) + 1.
 */
function generarMovimientos(
  n: number,
  idProducto = 1,
  cantidades?: number[],
): any[] {
  // Base reciente: el último movimiento cae hace ~5 días para pasar la
  // compuerta de VENTANA_ACTIVIDAD_DIAS (60d) independientemente de cuándo
  // se ejecute el test.
  const base = new Date(Date.now() - (n + 5) * 86_400_000);
  return Array.from({ length: n }, (_, i) => {
    const fecha = new Date(base);
    fecha.setDate(base.getDate() + i);
    return {
      id_movimiento: i + 1,
      id_lote: idProducto * 100 + i,
      id_kit: null,
      id_usuario: 1,
      cantidad: cantidades ? cantidades[i % cantidades.length] : (i % 5) + 1,
      fecha_hora: fecha,
      tipo_mov: 'EGRESO_KIT',
      lotes: {
        id_lote: idProducto * 100 + i,
        id_producto: idProducto,
        id_sucursal: 1,
        productos: { nombre_mat: `Producto ${idProducto}` },
      },
    };
  });
}

// ─── Suite principal ─────────────────────────────────────────────────────────

describe('AnaliticaService', () => {
  let service: AnaliticaService;
  let prismaMock: ReturnType<typeof crearPrismaMock>;

  beforeEach(async () => {
    prismaMock = crearPrismaMock();
    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => {});

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AnaliticaService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = module.get<AnaliticaService>(AnaliticaService);
  });

  afterEach(() => jest.clearAllMocks());

  // ── BLOQUE 1: predecirDemanda (caché) ──────────────────────────────────────

  describe('predecirDemanda', () => {
    it('retorna el resultado cacheado si ya existe en BD', async () => {
      const cacheFalso = {
        id: 1,
        id_sucursal: 1,
        resultado: {
          id_sucursal: 1,
          total_productos_analizados: 5,
          predicciones: [],
        },
        generado_en: new Date('2024-06-01'),
      };
      prismaMock.predicciones_cache.findUnique.mockResolvedValue(cacheFalso);
      const spyGenerarYGuardar = jest.spyOn(service, 'generarYGuardar');

      const resultado = await service.predecirDemanda(1);

      expect(resultado).not.toBeNull();
      expect(resultado!.total_productos_analizados).toBe(5);
      expect(resultado!.generado_en).toEqual(cacheFalso.generado_en);
      expect(spyGenerarYGuardar).not.toHaveBeenCalled();
    });

    it('retorna null y lanza entrenamiento en background si no hay caché', async () => {
      prismaMock.predicciones_cache.findUnique.mockResolvedValue(null);
      const spyImmediate = jest.spyOn(global, 'setImmediate');
      const spyGenerarYGuardar = jest
        .spyOn(service, 'generarYGuardar')
        .mockResolvedValue({} as any);

      const resultado = await service.predecirDemanda(1);

      expect(resultado).toBeNull();
      expect(spyImmediate).toHaveBeenCalled();

      // Vaciar la cola de setImmediate para que el callback se ejecute
      await new Promise<void>((resolve) => setImmediate(resolve));

      expect(spyGenerarYGuardar).toHaveBeenCalledWith(1);
    });
  });

  // ── BLOQUE 2: prepararYEntrenar ─────────────────────────────────────────────

  describe('prepararYEntrenar', () => {
    it('omite productos con menos de 14 puntos históricos', async () => {
      // 5 movimientos en la misma fecha → serie de 1 único punto
      const movs = Array.from({ length: 5 }, () => ({
        id_movimiento: 1,
        id_lote: 1,
        id_kit: null,
        id_usuario: 1,
        cantidad: 3,
        fecha_hora: new Date('2024-03-01T08:00:00Z'),
        tipo_mov: 'EGRESO_KIT',
        lotes: {
          id_lote: 1,
          id_producto: 1,
          id_sucursal: 1,
          productos: { nombre_mat: 'Test' },
        },
      }));
      prismaMock.movimientos.findMany.mockResolvedValue(movs);

      const resultado = await service.prepararYEntrenar(1);

      expect(resultado.total_productos_entrenados).toBe(0);
      expect(resultado.predicciones).toHaveLength(0);
    });

    it('omite productos cuya serie tiene max === 0', async () => {
      // 20 movimientos en 20 fechas distintas pero cantidad = 0
      const movs = generarMovimientos(20, 1, Array(20).fill(0));
      prismaMock.movimientos.findMany.mockResolvedValue(movs);

      const resultado = await service.prepararYEntrenar(1);

      expect(resultado.total_productos_entrenados).toBe(0);
    });

    it('entrena correctamente con serie de 20 puntos válidos y retorna predicción', async () => {
      const cantidades = [2, 3, 1, 4, 2, 5, 3, 2, 4, 1, 3, 2, 4, 3, 1, 5, 2, 3, 4, 2];
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);

      const resultado = await service.prepararYEntrenar(1);

      expect(resultado.total_productos_entrenados).toBe(1);
      expect(resultado.predicciones[0].prediccion_siguiente).toBeGreaterThan(0);
      expect(resultado.predicciones[0].error_entrenamiento).toBeGreaterThanOrEqual(0);
      expect(resultado.predicciones[0].error_entrenamiento).toBeLessThanOrEqual(1);
      expect(resultado.predicciones[0].puntos_historicos).toBe(20);
    }, 30_000);

    it('entrena con múltiples productos y retorna uno por cada producto válido', async () => {
      const cantidades = [2, 3, 1, 4, 2, 5, 3, 2, 4, 1, 3, 2, 4, 3, 1, 5, 2, 3, 4, 2];
      const movsProd1 = generarMovimientos(20, 1, cantidades);
      const movsProd2 = generarMovimientos(20, 2, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue([...movsProd1, ...movsProd2]);

      const resultado = await service.prepararYEntrenar(1);

      expect(resultado.total_productos_entrenados).toBe(2);
    }, 60_000);
  });

  // ── BLOQUE 3: suavizarSerie (probado vía resultado) ─────────────────────────

  describe('suavizarSerie (vía prepararYEntrenar)', () => {
    it('la serie suavizada no tiene valores negativos', async () => {
      // Serie alternante 0–5 → el suavizado produce valores >= 0
      const cantidades = [0, 5, 0, 5, 0, 5, 0, 5, 0, 5, 0, 5, 0, 5, 0, 5, 0, 5, 0, 5];
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);

      const resultado = await service.prepararYEntrenar(1);

      // La serie tiene max > 0, debe entrenar
      expect(resultado.total_productos_entrenados).toBe(1);
      expect(resultado.predicciones[0].prediccion_siguiente).toBeGreaterThanOrEqual(0);
    }, 30_000);

    it('la serie con un solo pico no produce NaN', async () => {
      const cantidades = [1, 1, 1, 1, 1, 10, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);

      const resultado = await service.prepararYEntrenar(1);

      expect(resultado.total_productos_entrenados).toBe(1);
      expect(resultado.predicciones[0].prediccion_siguiente).not.toBeNaN();
    }, 30_000);
  });

  // ── BLOQUE 4: generarYGuardar ───────────────────────────────────────────────

  describe('generarYGuardar', () => {
    const cantidades = [2, 3, 1, 4, 2, 5, 3, 2, 4, 1, 3, 2, 4, 3, 1, 5, 2, 3, 4, 2];

    function mockUpsert(fecha = new Date('2024-06-01')) {
      prismaMock.predicciones_cache.upsert.mockResolvedValue({
        id: 1,
        id_sucursal: 1,
        resultado: {},
        generado_en: fecha,
      });
    }

    it('llama a prisma.predicciones_cache.upsert exactamente una vez', async () => {
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);
      prismaMock.lotes.findMany.mockResolvedValue([]);
      mockUpsert();

      await service.generarYGuardar(1);

      expect(prismaMock.predicciones_cache.upsert).toHaveBeenCalledTimes(1);
    }, 30_000);

    it('el resultado incluye la propiedad generado_en', async () => {
      const fechaEsperada = new Date('2024-06-15T12:00:00Z');
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);
      prismaMock.lotes.findMany.mockResolvedValue([]);
      mockUpsert(fechaEsperada);

      const resultado = await service.generarYGuardar(1);

      expect(resultado.generado_en).toEqual(fechaEsperada);
    }, 30_000);

    it('dias_para_quiebre === 0 cuando el stock es 0', async () => {
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);
      prismaMock.lotes.findMany.mockResolvedValue([]); // sin stock
      mockUpsert();

      const resultado = await service.generarYGuardar(1);

      expect(resultado.predicciones).toHaveLength(1);
      expect(resultado.predicciones[0].dias_para_quiebre).toBe(0);
    }, 30_000);

    it('sugerencia_compra === 0 cuando el stock supera el consumo predicho', async () => {
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);
      // Stock enorme → consumo predicho (max ~150 u/30d) nunca lo supera
      prismaMock.lotes.findMany.mockResolvedValue([
        { id_producto: 1, stock_actual: 9999 },
      ]);
      mockUpsert();

      const resultado = await service.generarYGuardar(1);

      expect(resultado.predicciones[0].sugerencia_compra).toBe(0);
    }, 30_000);

    it('asigna dias_para_quiebre = 9999 cuando el stock existe pero el consumo predicho es prácticamente cero', async () => {
      const movs = generarMovimientos(20, 1, cantidades);
      prismaMock.movimientos.findMany.mockResolvedValue(movs);
      // Stock presente → entra al branch promedioDiario <= 0 → 9999
      prismaMock.lotes.findMany.mockResolvedValue([
        { id_producto: 1, stock_actual: 10 },
      ]);
      mockUpsert();

      // Forzar que crearYEntrenarLSTM retorne un modelo cuyo forecast es todo ceros
      // Y serieSmooth también cero → promSmooth = 0 → damping no introduce consumo
      // → consumoPredicho30Dias = 0 → promedioDiario = 0 → diasParaQuiebre = 9999
      (service as any).crearYEntrenarLSTM = jest.fn().mockReturnValue({
        red: {
          forecast: jest.fn().mockReturnValue(Array(30).fill(0)),
          run: jest.fn().mockReturnValue(0),
        },
        serieSmooth: Array(20).fill(0),
        errorEntrenamiento: 0.001,
      });

      const resultado = await service.generarYGuardar(1);

      expect(resultado.predicciones).toHaveLength(1);
      expect(resultado.predicciones[0].dias_para_quiebre).toBe(9999);
    });
  });
});

// ─── BLOQUE 5: Brain.js LSTM — integración ligera ───────────────────────────
// Usa la librería real (sin mock). Verifica que el modelo funciona
// correctamente en el entorno del proyecto.

describe('Brain.js LSTMTimeStep', () => {
  const OPTS = { iterations: 100, errorThresh: 0.05, log: false };

  const SERIE_14 = [
    0.1, 0.2, 0.3, 0.2, 0.4, 0.3, 0.5, 0.4,
    0.3, 0.5, 0.4, 0.6, 0.5, 0.7,
  ];

  function crearRed() {
    return new (brain.recurrent.LSTMTimeStep as any)({
      inputSize: 1,
      hiddenLayers: [10, 5],
      outputSize: 1,
    });
  }

  it('LSTMTimeStep entrena sin errores con serie normalizada de 14 puntos', () => {
    const red = crearRed();
    red.train([SERIE_14], OPTS);

    const prediccion: number = red.run(SERIE_14);

    expect(typeof prediccion).toBe('number');
    expect(prediccion).toBeGreaterThanOrEqual(0);
    expect(prediccion).toBeLessThanOrEqual(1);

    const forecast7: number[] = red.forecast(SERIE_14, 7);
    expect(forecast7).toHaveLength(7);
  }, 30_000);

  it('LSTMTimeStep.forecast retorna array con la longitud solicitada', () => {
    const red = crearRed();
    const serie20 = Array.from({ length: 20 }, (_, i) => ((i % 5) + 1) / 5);
    red.train([serie20], OPTS);

    const f4: number[] = red.forecast(serie20, 4);
    const f30: number[] = red.forecast(serie20, 30);

    expect(f4).toHaveLength(4);
    expect(f30).toHaveLength(30);
  }, 30_000);

  it('el error de entrenamiento queda por debajo de 0.5 con serie creciente simple', () => {
    const red = crearRed();
    const serieSimple = [
      0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45,
      0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.82,
      0.84, 0.86, 0.88, 0.90,
    ];

    const resultado = red.train([serieSimple], OPTS);

    expect(resultado.error).toBeLessThan(0.5);
  }, 30_000);
});
