import { ExecutionContext, ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';
import { RolesGuard } from './roles.guard';

function crearContexto(user: object | null, roles: string[] | undefined): ExecutionContext {
  const reflector = { getAllAndOverride: jest.fn().mockReturnValue(roles) } as unknown as Reflector;
  const guard = new RolesGuard(reflector);

  const ctx = {
    getHandler: jest.fn(),
    getClass: jest.fn(),
    switchToHttp: jest.fn().mockReturnValue({
      getRequest: jest.fn().mockReturnValue({ user }),
    }),
  } as unknown as ExecutionContext;

  return ctx;
}

describe('RolesGuard', () => {
  let reflector: jest.Mocked<Reflector>;
  let guard: RolesGuard;

  beforeEach(() => {
    reflector = { getAllAndOverride: jest.fn() } as unknown as jest.Mocked<Reflector>;
    guard = new RolesGuard(reflector);
  });

  afterEach(() => jest.clearAllMocks());

  describe('permite acceso', () => {
    it('retorna true cuando el rol del usuario coincide con el rol requerido', () => {
      reflector.getAllAndOverride.mockReturnValue(['administrador']);
      const ctx = {
        getHandler: jest.fn(),
        getClass: jest.fn(),
        switchToHttp: jest.fn().mockReturnValue({
          getRequest: jest.fn().mockReturnValue({ user: { rol: 'administrador' } }),
        }),
      } as unknown as ExecutionContext;

      expect(guard.canActivate(ctx)).toBe(true);
    });

    it('retorna true cuando no hay roles definidos en la ruta (ruta pública)', () => {
      reflector.getAllAndOverride.mockReturnValue(undefined);
      const ctx = {
        getHandler: jest.fn(),
        getClass: jest.fn(),
        switchToHttp: jest.fn().mockReturnValue({
          getRequest: jest.fn().mockReturnValue({ user: { rol: 'medico' } }),
        }),
      } as unknown as ExecutionContext;

      expect(guard.canActivate(ctx)).toBe(true);
    });

    it('retorna true cuando la lista de roles requeridos está vacía', () => {
      reflector.getAllAndOverride.mockReturnValue([]);
      const ctx = {
        getHandler: jest.fn(),
        getClass: jest.fn(),
        switchToHttp: jest.fn().mockReturnValue({
          getRequest: jest.fn().mockReturnValue({ user: { rol: 'medico' } }),
        }),
      } as unknown as ExecutionContext;

      expect(guard.canActivate(ctx)).toBe(true);
    });
  });

  describe('deniega acceso', () => {
    it('lanza ForbiddenException cuando el rol del usuario no está en los roles permitidos', () => {
      reflector.getAllAndOverride.mockReturnValue(['administrador']);
      const ctx = {
        getHandler: jest.fn(),
        getClass: jest.fn(),
        switchToHttp: jest.fn().mockReturnValue({
          getRequest: jest.fn().mockReturnValue({ user: { rol: 'medico' } }),
        }),
      } as unknown as ExecutionContext;

      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });

    it('lanza ForbiddenException cuando no hay usuario en la request', () => {
      reflector.getAllAndOverride.mockReturnValue(['administrador']);
      const ctx = {
        getHandler: jest.fn(),
        getClass: jest.fn(),
        switchToHttp: jest.fn().mockReturnValue({
          getRequest: jest.fn().mockReturnValue({ user: null }),
        }),
      } as unknown as ExecutionContext;

      expect(() => guard.canActivate(ctx)).toThrow(ForbiddenException);
    });
  });
});

// Para ejecutar: npx jest --testPathPattern=roles.guard.spec.ts
