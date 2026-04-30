import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ActualizarProductoDto } from './dto/actualizar-producto.dto';
import { CrearProductoDto } from './dto/crear-producto.dto';

@Injectable()
export class ProductosService {
  constructor(private readonly prisma: PrismaService) {}

  obtenerTodos() {
    return this.prisma.productos.findMany({
      orderBy: { nombre_mat: 'asc' },
    });
  }

  async obtenerPorId(idProducto: number) {
    const producto = await this.prisma.productos.findUnique({
      where: { id_producto: idProducto },
      include: { lotes: true },
    });
    if (!producto)
      throw new NotFoundException(`Producto con id ${idProducto} no encontrado`);
    return producto;
  }

  async obtenerInventario(idSucursal?: number) {
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);

    const productos = await this.prisma.productos.findMany({
      include: {
        lotes: {
          where: {
            fecha_venc: { gte: hoy },
            ...(idSucursal ? { id_sucursal: idSucursal } : {}),
          },
        },
      },
      orderBy: { nombre_mat: 'asc' },
    });

    return productos.map(({ lotes, ...datosProducto }) => ({
      ...datosProducto,
      stock_total: lotes.reduce(
        (suma, lote) => suma + Number(lote.stock_actual),
        0,
      ),
    }));
  }

  crear(dto: CrearProductoDto) {
    return this.prisma.productos.create({ data: dto });
  }

  async actualizar(idProducto: number, dto: ActualizarProductoDto) {
    await this.obtenerPorId(idProducto);
    return this.prisma.productos.update({
      where: { id_producto: idProducto },
      data: dto,
    });
  }

  async eliminar(idProducto: number) {
    await this.obtenerPorId(idProducto);
    return this.prisma.productos.delete({ where: { id_producto: idProducto } });
  }
}
