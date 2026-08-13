import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CrearKitDto } from './dto/crear-kit.dto';
import { ActualizarKitDto } from './dto/actualizar-kit.dto';

@Injectable()
export class KitsService {
  constructor(private readonly prisma: PrismaService) {}

  obtenerTodos() {
    return this.prisma.kits.findMany({
      include: {
        detalle_kit: {
          include: { productos: true },
        },
      },
    });
  }

  buscarPorNombre(nombre: string) {
    return this.prisma.kits.findMany({
      where: { nombre_procedimiento: { contains: nombre, mode: 'insensitive' } },
      include: {
        detalle_kit: {
          include: { productos: true },
        },
      },
      orderBy: { nombre_procedimiento: 'asc' },
    });
  }

  async obtenerPorId(idKit: number) {
    const kit = await this.prisma.kits.findUnique({
      where: { id_kit: idKit },
      include: {
        detalle_kit: {
          include: { productos: true },
        },
      },
    });
    if (!kit) throw new NotFoundException(`Kit con id ${idKit} no encontrado`);
    return kit;
  }

  async crear(dto: CrearKitDto) {
    for (const item of dto.detalle) {
      if (!item.es_variable && (item.id_producto === null || item.id_producto === undefined)) {
        throw new BadRequestException(
          'Los ítems fijos (es_variable: false) deben tener id_producto',
        );
      }
    }

    return this.prisma.$transaction(async (tx) => {
      const kit = await tx.kits.create({
        data: { nombre_procedimiento: dto.nombre_procedimiento },
      });

      await tx.detalle_kit.createMany({
        data: dto.detalle.map((item) => ({
          id_kit: kit.id_kit,
          id_producto: item.id_producto ?? null,
          cantidad_estandar: item.cantidad_estandar,
          es_variable: item.es_variable ?? false,
        })),
      });

      return tx.kits.findUnique({
        where: { id_kit: kit.id_kit },
        include: { detalle_kit: { include: { productos: true } } },
      });
    });
  }

  async actualizar(idKit: number, dto: ActualizarKitDto) {
    await this.obtenerPorId(idKit);

    return this.prisma.$transaction(async (tx) => {
      if (dto.detalle !== undefined) {
        for (const item of dto.detalle) {
          if (!item.es_variable && (item.id_producto === null || item.id_producto === undefined)) {
            throw new BadRequestException(
              'Los ítems fijos (es_variable: false) deben tener id_producto',
            );
          }
        }
        await tx.detalle_kit.deleteMany({ where: { id_kit: idKit } });
        await tx.detalle_kit.createMany({
          data: dto.detalle.map((item) => ({
            id_kit: idKit,
            id_producto: item.id_producto ?? null,
            cantidad_estandar: item.cantidad_estandar,
            es_variable: item.es_variable ?? false,
          })),
        });
      }

      if (dto.nombre_procedimiento !== undefined) {
        await tx.kits.update({
          where: { id_kit: idKit },
          data: { nombre_procedimiento: dto.nombre_procedimiento },
        });
      }

      return tx.kits.findUnique({
        where: { id_kit: idKit },
        include: { detalle_kit: { include: { productos: true } } },
      });
    });
  }

  async eliminar(idKit: number) {
    await this.obtenerPorId(idKit);

    // 1. Verificar si el kit tiene historial de movimientos
    //    Si tiene, no se puede eliminar para preservar la auditoría
    const movimientos = await this.prisma.movimientos.count({
      where: { id_kit: idKit },
    });

    if (movimientos > 0) {
      throw new ConflictException(
        `El kit tiene ${movimientos} movimiento(s) registrado(s) y no puede eliminarse. ` +
        'Desactívelo en su lugar para preservar el historial.',
      );
    }

    // 2. Si no tiene movimientos, eliminar en transacción:
    //    primero los detalles del kit, luego el kit
    return this.prisma.$transaction(async (tx) => {
      await tx.detalle_kit.deleteMany({ where: { id_kit: idKit } });
      return tx.kits.delete({ where: { id_kit: idKit } });
    });
  }
}
