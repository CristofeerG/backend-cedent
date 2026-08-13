import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { generarCodigoLote } from '../common/codigo-lote.util';
import { PrismaService } from '../prisma/prisma.service';
import { ActualizarLoteDto } from './dto/actualizar-lote.dto';
import { CrearLoteDto } from './dto/crear-lote.dto';

@Injectable()
export class LotesService {
  constructor(private readonly prisma: PrismaService) {}

  async registrarLote(dto: CrearLoteDto, idSucursal: number) {
    const producto = await this.prisma.productos.findUnique({
      where: { id_producto: dto.id_producto },
      select: { id_producto: true, subcategoria: true },
    });

    if (!producto) {
      throw new NotFoundException(`Producto con id ${dto.id_producto} no encontrado`);
    }

    const codigoLote = generarCodigoLote(producto.subcategoria, producto.id_producto);

    return this.prisma.lotes.create({
      data: {
        id_producto: dto.id_producto,
        id_sucursal: idSucursal,
        codigo_lote: codigoLote,
        stock_actual: dto.stock_inicial,
        fecha_venc: new Date(dto.fecha_venc),
        costo_unit: dto.costo_unit ?? null,
      },
    });
  }

  obtenerPorProducto(idProducto: number, idSucursal: number) {
    return this.prisma.lotes.findMany({
      where: {
        id_producto: idProducto,
        id_sucursal: idSucursal,
      },
      orderBy: { fecha_venc: 'asc' },
    });
  }

  async darDeBaja(idLote: number, idSucursal: number) {
    const lote = await this.prisma.lotes.findUnique({ where: { id_lote: idLote } });
    if (!lote) throw new NotFoundException(`Lote con id ${idLote} no encontrado`);
    if (lote.id_sucursal !== idSucursal) {
      throw new ForbiddenException('No tienes permiso para modificar este lote');
    }
    if (Number(lote.stock_actual) > 0) {
      throw new ConflictException(
        'El lote tiene stock disponible; retira o ajusta el stock antes de darlo de baja',
      );
    }
    return this.prisma.lotes.update({
      where: { id_lote: idLote },
      data: { stock_actual: 0 },
    });
  }

  async actualizar(idLote: number, dto: ActualizarLoteDto) {
    const lote = await this.prisma.lotes.findUnique({ where: { id_lote: idLote } });
    if (!lote) throw new NotFoundException(`Lote con id ${idLote} no encontrado`);

    return this.prisma.lotes.update({
      where: { id_lote: idLote },
      data: {
        ...(dto.stock_actual !== undefined && { stock_actual: dto.stock_actual }),
        ...(dto.costo_unit !== undefined && { costo_unit: dto.costo_unit }),
        ...(dto.fecha_venc !== undefined && { fecha_venc: new Date(dto.fecha_venc) }),
      },
    });
  }
}
