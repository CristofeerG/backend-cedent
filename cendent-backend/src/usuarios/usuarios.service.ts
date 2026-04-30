import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';

const RONDAS_HASH = 10;

@Injectable()
export class UsuariosService {
  constructor(private readonly prisma: PrismaService) {}

  async crearUsuario(dto: CrearUsuarioDto) {
    const existe = await this.prisma.usuarios.findUnique({
      where: { nom_usuario: dto.nom_usuario },
    });
    if (existe) {
      throw new ConflictException(`El usuario "${dto.nom_usuario}" ya existe`);
    }

    const passwordHash = await bcrypt.hash(dto.password, RONDAS_HASH);

    const { password, ...datosRegistro } = dto;
    const nuevoUsuario = await this.prisma.usuarios.create({
      data: { ...datosRegistro, password_hash: passwordHash },
    });

    const { password_hash, ...usuarioSinHash } = nuevoUsuario;
    return usuarioSinHash;
  }

  async buscarPorNomUsuario(nomUsuario: string) {
    return this.prisma.usuarios.findUnique({
      where: { nom_usuario: nomUsuario },
      include: { sucursales: true },
    });
  }

  async obtenerTodos() {
    const usuarios = await this.prisma.usuarios.findMany({
      select: {
        id_usuario: true,
        nom_usuario: true,
        rol: true,
        id_sucursal: true,
        sucursales: { select: { nom_sucursal: true } },
      },
    });
    return usuarios;
  }

  async obtenerPorId(idUsuario: number) {
    const usuario = await this.prisma.usuarios.findUnique({
      where: { id_usuario: idUsuario },
      select: {
        id_usuario: true,
        nom_usuario: true,
        rol: true,
        id_sucursal: true,
        sucursales: { select: { nom_sucursal: true } },
      },
    });
    if (!usuario) throw new NotFoundException(`Usuario con id ${idUsuario} no encontrado`);
    return usuario;
  }
}
