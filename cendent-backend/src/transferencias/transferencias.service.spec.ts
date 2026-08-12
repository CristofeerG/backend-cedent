import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { TransferenciasService, generarCodigoTrz } from './transferencias.service';
import { PrismaService } from '../prisma/prisma.service';

function crearPrismaMock() {
  const tx = {
    sucursales: { findFirst: jest.fn() },
    productos: { findFirst: jest.fn() },
    lotes: { findMany: jest.fn(), update: jest.fn() },
    transferencias: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    detalle_transferencia: { create: jest.fn() },
    movimientos: { create: jest.fn() },
  };

  const prisma = {
    $transaction: jest.fn().mockImplementation(async (cb: (tx: any) => any) => cb(tx)),
    transferencias: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    lotes: { update: jest.fn() },
    _tx: tx,
  };

  return { prisma, tx };
}

describe('TransferenciasService', () => {
  let service: TransferenciasService;
  let { prisma, tx } = crearPrismaMock();

  beforeEach(async () => {
    ({ prisma, tx } = crearPrismaMock());

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TransferenciasService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();

    service = module.get<TransferenciasService>(TransferenciasService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('generarCodigoTrz', () => {
    it('produce el formato TRZ-AAAAMMDD-XXXXX', () => {
      const INTENTOS = 20;
      const regex = /^TRZ-\d{8}-[A-Z0-9]{1,10}$/;

      for (let i = 0; i < INTENTOS; i++) {
        const codigo = generarCodigoTrz();
        expect(codigo).toMatch(regex);
      }
    });

    it('incluye la fecha del día actual en el código', () => {
      const hoy = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      const codigo = generarCodigoTrz();
      expect(codigo).toContain(`TRZ-${hoy}-`);
    });
  });

  describe('enviarTransferencia', () => {
    it('lanza BadRequestException cuando el origen y destino son la misma sucursal', async () => {
      tx.sucursales.findFirst.mockResolvedValue({ id_sucursal: 5, nom_sucursal: 'Central' });

      await expect(
        service.enviarTransferencia(
          { nombre_sucursal_destino: 'Central', productos: [{ nombre_producto: 'X', cantidad: 1 }] },
          5,
          1,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('lanza BadRequestException cuando el stock del lote es insuficiente', async () => {
      tx.sucursales.findFirst.mockResolvedValue({ id_sucursal: 99, nom_sucursal: 'Norte' });
      tx.productos.findFirst.mockResolvedValue({ id_producto: 1, nombre_mat: 'Guante' });
      tx.lotes.findMany.mockResolvedValue([
        { id_lote: 1, stock_actual: 0 },
      ]);

      await expect(
        service.enviarTransferencia(
          { nombre_sucursal_destino: 'Norte', productos: [{ nombre_producto: 'Guante', cantidad: 10 }] },
          1,
          1,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('lanza NotFoundException cuando la sucursal destino no existe', async () => {
      tx.sucursales.findFirst.mockResolvedValue(null);

      await expect(
        service.enviarTransferencia(
          { nombre_sucursal_destino: 'Inexistente', productos: [] },
          1,
          1,
        ),
      ).rejects.toThrow(NotFoundException);
    });
  });
});

// Para ejecutar: npx jest --testPathPattern=transferencias.service.spec.ts
