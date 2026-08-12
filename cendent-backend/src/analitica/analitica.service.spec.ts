import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { AnaliticaService } from './analitica.service';
import { PrismaService } from '../prisma/prisma.service';

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

function movimientoFalso(overrides: Partial<{ fecha_hora: Date; id_producto: number; cantidad: number }> = {}) {
  return {
    id_movimiento: 1,
    id_lote: 1,
    id_kit: null,
    id_usuario: 1,
    cantidad: overrides.cantidad ?? 2,
    fecha_hora: overrides.fecha_hora ?? new Date('2024-01-01'),
    tipo_mov: 'EGRESO_KIT',
    lotes: {
      id_lote: 1,
      id_producto: overrides.id_producto ?? 1,
      id_sucursal: 1,
      productos: { nombre_mat: 'Producto Test' },
    },
  };
}

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

  describe('predecirDemanda', () => {
    it('retorna el resultado cacheado si existe sin llamar a entrenar', async () => {
      const cacheFalso = {
        id: 1,
        id_sucursal: 1,
        resultado: {
          id_sucursal: 1,
          total_productos_analizados: 3,
          predicciones: [],
        },
        generado_en: new Date('2024-06-01'),
      };

      prismaMock.predicciones_cache.findUnique.mockResolvedValue(cacheFalso);
      const spyGenerarYGuardar = jest.spyOn(service, 'generarYGuardar');

      const resultado = await service.predecirDemanda(1);

      expect(resultado).not.toBeNull();
      expect(resultado!.id_sucursal).toBe(1);
      expect(resultado!.generado_en).toEqual(cacheFalso.generado_en);
      expect(spyGenerarYGuardar).not.toHaveBeenCalled();
    });

    it('retorna null cuando no hay caché y lanza entrenamiento en background', async () => {
      prismaMock.predicciones_cache.findUnique.mockResolvedValue(null);
      const spyGenerarYGuardar = jest
        .spyOn(service, 'generarYGuardar')
        .mockResolvedValue({} as any);

      const resultado = await service.predecirDemanda(1);

      expect(resultado).toBeNull();

      // Esperar a que el callback de setImmediate se ejecute
      await new Promise<void>((resolve) => setImmediate(resolve));

      expect(spyGenerarYGuardar).toHaveBeenCalledWith(1);
    });
  });

  describe('prepararYEntrenar', () => {
    it('omite productos que tienen menos de 14 puntos históricos y retorna total_productos_entrenados = 0', async () => {
      // 5 movimientos todos en la misma fecha → 1 único punto en la serie temporal
      const movimientosEscasos = Array.from({ length: 5 }, () =>
        movimientoFalso({ fecha_hora: new Date('2024-03-01') }),
      );

      prismaMock.movimientos.findMany.mockResolvedValue(movimientosEscasos);

      const resultado = await service.prepararYEntrenar(1);

      expect(resultado.total_productos_entrenados).toBe(0);
      expect(resultado.predicciones).toHaveLength(0);
    });

    it('retorna id_sucursal correcto en el resultado', async () => {
      prismaMock.movimientos.findMany.mockResolvedValue([]);

      const resultado = await service.prepararYEntrenar(7);

      expect(resultado.id_sucursal).toBe(7);
    });
  });
});

// Para ejecutar: npx jest --testPathPattern=analitica.service.spec.ts
