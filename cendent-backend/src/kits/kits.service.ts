import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CrearKitDto } from './dto/crear-kit.dto';

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
    return this.prisma.$transaction(async (tx) => {
      const kit = await tx.kits.create({
        data: { nombre_procedimiento: dto.nombre_procedimiento },
      });

      await tx.detalle_kit.createMany({
        data: dto.detalle.map((item) => ({
          id_kit: kit.id_kit,
          id_producto: item.id_producto,
          cantidad_estandar: item.cantidad_estandar,
        })),
      });

      return tx.kits.findUnique({
        where: { id_kit: kit.id_kit },
        include: { detalle_kit: { include: { productos: true } } },
      });
    });
  }

  async eliminar(idKit: number) {
    await this.obtenerPorId(idKit);
    return this.prisma.kits.delete({ where: { id_kit: idKit } });
  }
}
