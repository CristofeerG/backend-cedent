import { Test, TestingModule } from '@nestjs/testing';
import { Logger } from '@nestjs/common';
import { AnaliticaScheduler } from './analitica.scheduler';
import { AnaliticaService } from './analitica.service';
import { PrismaService } from '../prisma/prisma.service';

describe('AnaliticaScheduler', () => {
  let scheduler: AnaliticaScheduler;
  let serviceMock: { generarYGuardar: jest.Mock };
  let prismaMock: { sucursales: { findMany: jest.Mock } };

  beforeEach(async () => {
    serviceMock = { generarYGuardar: jest.fn() };
    prismaMock = { sucursales: { findMany: jest.fn() } };

    jest.spyOn(Logger.prototype, 'log').mockImplementation(() => {});
    jest.spyOn(Logger.prototype, 'error').mockImplementation(() => {});

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AnaliticaScheduler,
        { provide: AnaliticaService, useValue: serviceMock },
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    scheduler = module.get<AnaliticaScheduler>(AnaliticaScheduler);
  });

  afterEach(() => jest.clearAllMocks());

  it('llama a generarYGuardar para cada sucursal activa', async () => {
    prismaMock.sucursales.findMany.mockResolvedValue([
      { id_sucursal: 1 },
      { id_sucursal: 2 },
    ]);
    serviceMock.generarYGuardar.mockResolvedValue({});

    await scheduler.generarTodasLasPredicciones();

    expect(serviceMock.generarYGuardar).toHaveBeenCalledTimes(2);
    expect(serviceMock.generarYGuardar).toHaveBeenCalledWith(1);
    expect(serviceMock.generarYGuardar).toHaveBeenCalledWith(2);
  });

  it('no falla si no hay sucursales activas', async () => {
    prismaMock.sucursales.findMany.mockResolvedValue([]);

    await expect(
      scheduler.generarTodasLasPredicciones(),
    ).resolves.not.toThrow();

    expect(serviceMock.generarYGuardar).not.toHaveBeenCalled();
  });

  it('continúa con otras sucursales aunque una falle', async () => {
    prismaMock.sucursales.findMany.mockResolvedValue([
      { id_sucursal: 1 },
      { id_sucursal: 2 },
    ]);
    serviceMock.generarYGuardar
      .mockRejectedValueOnce(new Error('Error en sucursal 1'))
      .mockResolvedValueOnce({});

    await expect(
      scheduler.generarTodasLasPredicciones(),
    ).resolves.not.toThrow();

    expect(serviceMock.generarYGuardar).toHaveBeenCalledTimes(2);
    expect(serviceMock.generarYGuardar).toHaveBeenCalledWith(1);
    expect(serviceMock.generarYGuardar).toHaveBeenCalledWith(2);
  });

  it('registra en el log el inicio del proceso cron', async () => {
    prismaMock.sucursales.findMany.mockResolvedValue([{ id_sucursal: 1 }]);
    serviceMock.generarYGuardar.mockResolvedValue({});

    await scheduler.generarTodasLasPredicciones();

    const logCalls = (Logger.prototype.log as jest.Mock).mock.calls;
    const inicioRegistrado = logCalls.some(([msg]: any[]) =>
      typeof msg === 'string' && msg.includes('07:00'),
    );
    expect(inicioRegistrado).toBe(true);
  });

  it('registra en el log cuántas sucursales fueron procesadas al finalizar', async () => {
    prismaMock.sucursales.findMany.mockResolvedValue([
      { id_sucursal: 1 },
      { id_sucursal: 2 },
    ]);
    serviceMock.generarYGuardar.mockResolvedValue({});

    await scheduler.generarTodasLasPredicciones();

    const logCalls = (Logger.prototype.log as jest.Mock).mock.calls;
    const finalizacionRegistrada = logCalls.some(([msg]: any[]) =>
      typeof msg === 'string' && msg.includes('2'),
    );
    expect(finalizacionRegistrada).toBe(true);
  });

  it('registra el error en el log cuando generarYGuardar falla para una sucursal', async () => {
    prismaMock.sucursales.findMany.mockResolvedValue([{ id_sucursal: 3 }]);
    serviceMock.generarYGuardar.mockRejectedValue(new Error('BD timeout'));

    await expect(
      scheduler.generarTodasLasPredicciones(),
    ).resolves.not.toThrow();

    const errorCalls = (Logger.prototype.error as jest.Mock).mock.calls;
    const errorRegistrado = errorCalls.some(([msg]: any[]) =>
      typeof msg === 'string' &&
      msg.includes('3') &&
      msg.includes('BD timeout'),
    );
    expect(errorRegistrado).toBe(true);
  });
});
