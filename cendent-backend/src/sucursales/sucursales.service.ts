import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SucursalesService {
  constructor(private readonly prisma: PrismaService) {}

  obtenerTodas() {
    return this.prisma.sucursales.findMany({
      orderBy: { nom_sucursal: 'asc' },
    });
  }

  async obtenerPorId(idSucursal: number) {
    const sucursal = await this.prisma.sucursales.findUnique({
      where: { id_sucursal: idSucursal },
    });
    if (!sucursal)
      throw new NotFoundException(`Sucursal con id ${idSucursal} no encontrada`);
    return sucursal;
  }

  buscarPorNombre(nombre: string) {
    return this.prisma.sucursales.findMany({
      where: { nom_sucursal: { contains: nombre, mode: 'insensitive' } },
      orderBy: { nom_sucursal: 'asc' },
    });
  }
}
