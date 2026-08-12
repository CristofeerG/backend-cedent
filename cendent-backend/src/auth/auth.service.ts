import { Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { UsuariosService } from '../usuarios/usuarios.service';
import { LoginDto } from './dto/login.dto';
import { JwtPayload } from './interfaces/jwt-payload.interface';

@Injectable()
export class AuthService {
  constructor(
    private readonly usuariosService: UsuariosService,
    private readonly jwtService: JwtService,
  ) {}

  async login(dto: LoginDto) {
    const usuario = await this.usuariosService.buscarPorNomUsuario(dto.nom_usuario);

    if (!usuario) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    if (usuario.sucursales?.estado === false) {
      throw new UnauthorizedException('Sucursal inactiva');
    }

    const passwordValida = await bcrypt.compare(dto.password, usuario.password_hash);
    if (!passwordValida) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    const payload: JwtPayload = {
      sub: usuario.id_usuario,
      rol: usuario.rol,
      id_sucursal: usuario.id_sucursal,
    };

    return {
      access_token: this.jwtService.sign(payload),
      id_usuario: usuario.id_usuario,
      nom_usuario: usuario.nom_usuario,
      rol: usuario.rol,
      id_sucursal: usuario.id_sucursal,
      nom_sucursal: usuario.sucursales?.nom_sucursal ?? '',
    };
  }
}
