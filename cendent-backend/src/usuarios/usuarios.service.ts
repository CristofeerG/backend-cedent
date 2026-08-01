import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { CrearUsuarioDto } from './dto/crear-usuario.dto';
import { EditarUsuarioDto } from './dto/editar-usuario.dto';

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

  async editarUsuario(idUsuario: number, dto: EditarUsuarioDto) {
    const usuario = await this.prisma.usuarios.findUnique({
      where: { id_usuario: idUsuario },
    });
    if (!usuario) throw new NotFoundException(`Usuario ${idUsuario} no encontrado`);

    const data: Record<string, unknown> = {};
    if (dto.nom_usuario !== undefined) data.nom_usuario = dto.nom_usuario;
    if (dto.rol !== undefined) data.rol = dto.rol;
    if (dto.id_sucursal !== undefined) data.id_sucursal = dto.id_sucursal;
    if (dto.password !== undefined) {
      data.password_hash = await bcrypt.hash(dto.password, RONDAS_HASH);
    }

    return this.prisma.usuarios.update({
      where: { id_usuario: idUsuario },
      data,
      select: {
        id_usuario: true,
        nom_usuario: true,
        rol: true,
        id_sucursal: true,
        sucursales: { select: { nom_sucursal: true } },
      },
    });
  }

  async eliminarUsuario(idUsuario: number) {
    const usuario = await this.prisma.usuarios.findUnique({
      where: { id_usuario: idUsuario },
    });
    if (!usuario) throw new NotFoundException(`Usuario ${idUsuario} no encontrado`);

    await this.prisma.$transaction([
      this.prisma.movimientos.updateMany({
        where: { id_usuario: idUsuario },
        data: { id_usuario: null },
      }),
      this.prisma.transferencias.updateMany({
        where: { id_usuario_envia: idUsuario },
        data: { id_usuario_envia: null },
      }),
      this.prisma.transferencias.updateMany({
        where: { id_usuario_recibe: idUsuario },
        data: { id_usuario_recibe: null },
      }),
      this.prisma.usuarios.delete({ where: { id_usuario: idUsuario } }),
    ]);

    return { message: `Usuario ${idUsuario} eliminado` };
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
