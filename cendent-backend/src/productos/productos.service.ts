import { Injectable, NotFoundException } from '@nestjs/common';
import { generarCodigoLote } from '../common/codigo-lote.util';
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

  buscarPorNombre(nombre: string) {
    return this.prisma.productos.findMany({
      where: { nombre_mat: { contains: nombre, mode: 'insensitive' } },
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

  async crear(dto: CrearProductoDto, idSucursal: number) {
    const { stock_inicial, fecha_venc, costo_unit, ...datosProducto } = dto;
    const crearLote = stock_inicial !== undefined && fecha_venc !== undefined;

    return this.prisma.$transaction(async (tx) => {
      const producto = await tx.productos.create({ data: datosProducto });

      if (crearLote) {
        const codigoLote = generarCodigoLote(producto.subcategoria, producto.id_producto);

        await tx.lotes.create({
          data: {
            id_producto: producto.id_producto,
            id_sucursal: idSucursal,
            codigo_lote: codigoLote,
            stock_actual: stock_inicial!,
            fecha_venc: new Date(fecha_venc!),
            costo_unit: costo_unit ?? null,
          },
        });
      }

      return tx.productos.findUnique({
        where: { id_producto: producto.id_producto },
        include: { lotes: true },
      });
    });
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
