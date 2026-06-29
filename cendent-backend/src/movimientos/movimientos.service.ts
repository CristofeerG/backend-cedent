import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { movimientos } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SustitucionDto } from './dto/despachar-kit.dto';

@Injectable()
export class MovimientosService {
  constructor(private readonly prisma: PrismaService) {}

  obtenerTodos(idSucursal?: number, idProducto?: number) {
    const lotesWhere: Record<string, unknown> = {};
    if (idSucursal) lotesWhere['id_sucursal'] = idSucursal;
    if (idProducto) lotesWhere['id_producto'] = idProducto;
    const hasFilter = Object.keys(lotesWhere).length > 0;

    return this.prisma.movimientos.findMany({
      where: hasFilter ? { lotes: lotesWhere } : undefined,
      include: {
        lotes: { include: { productos: true, sucursales: true } },
        usuarios: true,
        kits: true,
      },
      orderBy: { fecha_hora: 'desc' },
      take: idProducto ? 10 : 200,
    });
  }

  async despacharKit(
    idKit: number,
    idUsuario: number,
    idSucursal: number,
    sustituciones: SustitucionDto[],
  ) {
    return this.prisma.$transaction(async (tx) => {
      const detalles = await tx.detalle_kit.findMany({
        where: { id_kit: idKit },
        include: { productos: true },
      });

      if (!detalles.length) {
        throw new NotFoundException(`Kit con id ${idKit} no encontrado o sin productos`);
      }

      const mapaDetalles = new Map(detalles.map((d) => [d.id_detalle, d]));
      const mapaSust = new Map(sustituciones.map((s) => [s.id_detalle, s.id_producto]));

      for (const s of sustituciones) {
        if (!mapaDetalles.has(s.id_detalle))
          throw new BadRequestException(`id_detalle ${s.id_detalle} no pertenece al kit ${idKit}`);
      }

      for (const s of sustituciones) {
        if (!mapaDetalles.get(s.id_detalle)!.es_variable)
          throw new BadRequestException(`id_detalle ${s.id_detalle} es un ítem fijo y no admite sustitución`);
      }

      for (const detalle of detalles) {
        if (detalle.es_variable && !mapaSust.has(detalle.id_detalle) && detalle.id_producto === null)
          throw new BadRequestException(
            `El ítem variable id_detalle ${detalle.id_detalle} no tiene producto genérico ni sustitución proporcionada`,
          );
      }

      // Build name map for substituted products (needed for lotes_usados metadata)
      const substIds = [...new Set(sustituciones.map((s) => s.id_producto))];
      const substProds = substIds.length > 0
        ? await tx.productos.findMany({
            where: { id_producto: { in: substIds } },
            select: { id_producto: true, nombre_mat: true },
          })
        : [];
      const substProdMap = new Map(substProds.map((p) => [p.id_producto, p.nombre_mat ?? '']));

      const movimientosGenerados: movimientos[] = [];
      const lotesUsados: { nombre_producto: string; num_lote: string | null; fecha_vencimiento: Date; stock_restante: number }[] = [];

      for (const detalle of detalles) {
        const cantidadNecesaria = Number(detalle.cantidad_estandar);
        const idProductoAUsar = mapaSust.has(detalle.id_detalle)
          ? mapaSust.get(detalle.id_detalle)!
          : detalle.id_producto!;

        const nombreProducto = mapaSust.has(detalle.id_detalle)
          ? substProdMap.get(idProductoAUsar) ?? `Producto ${idProductoAUsar}`
          : detalle.productos?.nombre_mat ?? `Producto ${idProductoAUsar}`;

        const lotes = await tx.lotes.findMany({
          where: { id_producto: idProductoAUsar, id_sucursal: idSucursal, stock_actual: { gt: 0 } },
          orderBy: { fecha_venc: 'asc' },
        });

        const stockTotal = lotes.reduce((a, l) => a + Number(l.stock_actual), 0);
        if (stockTotal < cantidadNecesaria) {
          const nombre = detalle.productos?.nombre_mat ?? `id_producto ${idProductoAUsar}`;
          throw new BadRequestException(
            `Stock insuficiente para "${nombre}". Disponible: ${stockTotal}, requerido: ${cantidadNecesaria}`,
          );
        }

        let restante = cantidadNecesaria;
        let primerLote = true;
        for (const lote of lotes) {
          if (restante <= 0) break;
          const stockLote = Number(lote.stock_actual);
          const descontado = Math.min(stockLote, restante);
          const stockRestante = stockLote - descontado;
          await tx.lotes.update({ where: { id_lote: lote.id_lote }, data: { stock_actual: stockRestante } });
          movimientosGenerados.push(
            await tx.movimientos.create({
              data: { id_usuario: idUsuario, id_lote: lote.id_lote, id_kit: idKit, cantidad: descontado, tipo_mov: 'EGRESO_KIT' },
            }),
          );
          if (primerLote) {
            lotesUsados.push({
              nombre_producto: nombreProducto,
              num_lote: lote.codigo_lote ?? null,
              fecha_vencimiento: lote.fecha_venc,
              stock_restante: stockRestante,
            });
            primerLote = false;
          }
          restante -= descontado;
        }
      }

      return { movimientos: movimientosGenerados, lotes_usados: lotesUsados };
    });
  }

  async consumirProducto(
    idProducto: number,
    cantidad: number,
    idUsuario: number,
    idSucursal: number,
  ) {
    return this.prisma.$transaction(async (tx) => {
      const producto = await tx.productos.findUnique({
        where: { id_producto: idProducto },
        select: { nombre_mat: true },
      });
      if (!producto) throw new NotFoundException(`Producto con id ${idProducto} no encontrado`);

      const lotes = await tx.lotes.findMany({
        where: { id_producto: idProducto, id_sucursal: idSucursal, stock_actual: { gt: 0 } },
        orderBy: { fecha_venc: 'asc' },
      });

      const stockTotal = lotes.reduce((a, l) => a + Number(l.stock_actual), 0);
      if (stockTotal < cantidad)
        throw new BadRequestException(
          `Stock insuficiente para "${producto.nombre_mat}". Disponible: ${stockTotal}, requerido: ${cantidad}`,
        );

      const movimientosGenerados: movimientos[] = [];
      let restante = cantidad;
      let loteUsado: { num_lote: string | null; fecha_vencimiento: Date; stock_restante: number } | null = null;

      for (const lote of lotes) {
        if (restante <= 0) break;
        const stockLote = Number(lote.stock_actual);
        const descontado = Math.min(stockLote, restante);
        const stockRestante = stockLote - descontado;
        await tx.lotes.update({ where: { id_lote: lote.id_lote }, data: { stock_actual: stockRestante } });
        movimientosGenerados.push(
          await tx.movimientos.create({
            data: { id_usuario: idUsuario, id_lote: lote.id_lote, id_kit: null, cantidad: descontado, tipo_mov: 'EGRESO_DIRECTO' },
          }),
        );
        if (loteUsado === null) {
          loteUsado = {
            num_lote: lote.codigo_lote ?? null,
            fecha_vencimiento: lote.fecha_venc,
            stock_restante: stockRestante,
          };
        }
        restante -= descontado;
      }

      return { movimientos: movimientosGenerados, lote_usado: loteUsado };
    });
  }
}
