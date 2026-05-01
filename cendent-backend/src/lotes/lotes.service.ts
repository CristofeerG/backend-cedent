import { Injectable, NotFoundException } from '@nestjs/common';
import { generarCodigoLote } from '../common/codigo-lote.util';
import { PrismaService } from '../prisma/prisma.service';
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

  obtenerPorProducto(idProducto: number) {
    return this.prisma.lotes.findMany({
      where: { id_producto: idProducto },
      orderBy: { fecha_venc: 'asc' },
    });
  }
}
