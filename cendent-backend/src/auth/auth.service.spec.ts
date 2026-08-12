import { Test, TestingModule } from '@nestjs/testing';
import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import { UsuariosService } from '../usuarios/usuarios.service';

jest.mock('bcrypt');
const bcryptMock = bcrypt as jest.Mocked<typeof bcrypt>;

const USUARIO_BASE = {
  id_usuario: 1,
  nom_usuario: 'admin',
  password_hash: '$2b$10$hashedpassword',
  rol: 'administrador',
  id_sucursal: 1,
  sucursales: {
    id_sucursal: 1,
    nom_sucursal: 'Central',
    ubicacion: null,
    estado: true,
  },
};

describe('AuthService', () => {
  let service: AuthService;
  let usuariosService: jest.Mocked<Pick<UsuariosService, 'buscarPorNomUsuario'>>;
  let jwtService: jest.Mocked<Pick<JwtService, 'sign'>>;

  beforeEach(async () => {
    const mockUsuariosService = { buscarPorNomUsuario: jest.fn() };
    const mockJwtService = { sign: jest.fn().mockReturnValue('token-falso') };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsuariosService, useValue: mockUsuariosService },
        { provide: JwtService, useValue: mockJwtService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    usuariosService = module.get(UsuariosService);
    jwtService = module.get(JwtService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('login exitoso', () => {
    it('retorna access_token cuando las credenciales son correctas', async () => {
      (usuariosService.buscarPorNomUsuario as jest.Mock).mockResolvedValue(USUARIO_BASE);
      bcryptMock.compare.mockResolvedValue(true as never);

      const result = await service.login({ nom_usuario: 'admin', password: '1234' });

      expect(result).toHaveProperty('access_token');
      expect(result.access_token).toBe('token-falso');
      expect(result.nom_usuario).toBe('admin');
      expect(jwtService.sign).toHaveBeenCalledTimes(1);
    });
  });

  describe('login fallido', () => {
    it('lanza UnauthorizedException cuando el usuario no existe', async () => {
      (usuariosService.buscarPorNomUsuario as jest.Mock).mockResolvedValue(null);

      await expect(
        service.login({ nom_usuario: 'noexiste', password: '1234' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('lanza UnauthorizedException cuando la contraseña es incorrecta', async () => {
      (usuariosService.buscarPorNomUsuario as jest.Mock).mockResolvedValue(USUARIO_BASE);
      bcryptMock.compare.mockResolvedValue(false as never);

      await expect(
        service.login({ nom_usuario: 'admin', password: 'incorrecta' }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('lanza UnauthorizedException cuando la sucursal del usuario está desactivada', async () => {
      const usuarioSucursalInactiva = {
        ...USUARIO_BASE,
        sucursales: { ...USUARIO_BASE.sucursales, estado: false },
      };
      (usuariosService.buscarPorNomUsuario as jest.Mock).mockResolvedValue(usuarioSucursalInactiva);

      await expect(
        service.login({ nom_usuario: 'admin', password: '1234' }),
      ).rejects.toThrow(UnauthorizedException);
    });
  });
});

// Para ejecutar: npx jest --testPathPattern=auth.service.spec.ts
