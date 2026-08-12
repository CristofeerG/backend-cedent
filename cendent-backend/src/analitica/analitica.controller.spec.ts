import { Test, TestingModule } from '@nestjs/testing';
import { AnaliticaController } from './analitica.controller';
import { AnaliticaService } from './analitica.service';

// Mock completo de los guards para que no requieran sus dependencias
// (JwtAuthGuard, RolesGuard) en el test unitario del controller.
jest.mock('../auth/jwt-auth.guard', () => ({
  JwtAuthGuard: class {
    canActivate() { return true; }
  },
}));
jest.mock('../auth/guards/roles.guard', () => ({
  RolesGuard: class {
    canActivate() { return true; }
  },
}));

describe('AnaliticaController', () => {
  let controller: AnaliticaController;
  let serviceMock: { prepararYEntrenar: jest.Mock; predecirDemanda: jest.Mock };

  beforeEach(async () => {
    serviceMock = {
      prepararYEntrenar: jest.fn(),
      predecirDemanda: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [AnaliticaController],
      providers: [{ provide: AnaliticaService, useValue: serviceMock }],
    }).compile();

    controller = module.get<AnaliticaController>(AnaliticaController);
  });

  afterEach(() => jest.clearAllMocks());

  it('GET entrenar/:id_sucursal llama a prepararYEntrenar con el id correcto', async () => {
    const resultadoEsperado = {
      id_sucursal: 1,
      total_productos_entrenados: 5,
      iteraciones: 500,
      predicciones: [],
    };
    serviceMock.prepararYEntrenar.mockResolvedValue(resultadoEsperado);

    const resultado = await controller.entrenar(1);

    expect(serviceMock.prepararYEntrenar).toHaveBeenCalledWith(1);
    expect(resultado).toEqual(resultadoEsperado);
  });

  it('GET prediccion/:id_sucursal llama a predecirDemanda con el id correcto', async () => {
    serviceMock.predecirDemanda.mockResolvedValue(null);

    await controller.prediccion(2);

    expect(serviceMock.predecirDemanda).toHaveBeenCalledWith(2);
  });

  it('entrenar retorna null si el service retorna null (sin caché aún)', async () => {
    serviceMock.prepararYEntrenar.mockResolvedValue(null);

    const resultado = await controller.entrenar(1);

    expect(resultado).toBeNull();
  });

  it('prediccion retorna el objeto cacheado cuando existe', async () => {
    const cacheado = { total_productos_analizados: 10, predicciones: [] };
    serviceMock.predecirDemanda.mockResolvedValue(cacheado);

    const resultado = await controller.prediccion(1);

    expect(resultado).toEqual(cacheado);
  });

  it('ParseIntPipe convierte el parámetro a number antes de llegar al service', async () => {
    serviceMock.prepararYEntrenar.mockResolvedValue({});

    await controller.entrenar(3);

    const argRecibido = serviceMock.prepararYEntrenar.mock.calls[0][0];
    expect(typeof argRecibido).toBe('number');
    expect(argRecibido).toBe(3);
  });
});
