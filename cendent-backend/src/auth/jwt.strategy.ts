import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { UsuariosService } from '../usuarios/usuarios.service';
import { JwtPayload } from './interfaces/jwt-payload.interface';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly usuariosService: UsuariosService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: process.env.JWT_SECRET as string,
    });
  }

  async validate(payload: JwtPayload) {
    // Verifica que el usuario del token aún exista en la base de datos
    const usuario = await this.usuariosService.obtenerPorId(payload.sub);
    if (!usuario) throw new UnauthorizedException('Token inválido o usuario eliminado');

    return { id_usuario: payload.sub, rol: payload.rol, id_sucursal: payload.id_sucursal };
  }
}
