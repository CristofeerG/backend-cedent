import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { movimientos } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MovimientosService {
  constructor(private readonly prisma: PrismaService) {}

  obtenerTodos(idSucursal?: number) {
    return this.prisma.movimientos.findMany({
      where: idSucursal ? { lotes: { id_sucursal: idSucursal } } : undefined,
      include: {
        lotes: { include: { productos: true, sucursales: true } },
        usuarios: true,
        kits: true,
      },
      orderBy: { fecha_hora: 'desc' },
    });
  }

  async despacharKit(idKit: number, idUsuario: number, idSucursal: number) {
    return this.prisma.$transaction(async (tx) => {
      const detalles = await tx.detalle_kit.findMany({
        where: { id_kit: idKit },
        include: { productos: true },
      });

      if (!detalles.length) {
        throw new NotFoundException(
          `Kit con id ${idKit} no encontrado o sin productos`,
        );
      }

      const movimientosGenerados: movimientos[] = [];

      for (const detalle of detalles) {
        const cantidadNecesaria = Number(detalle.cantidad_estandar);
        const nombreProducto = detalle.productos?.nombre_mat ?? `id ${detalle.id_producto}`;

        const lotesDisponibles = await tx.lotes.findMany({
          where: {
            id_producto: detalle.id_producto,
            id_sucursal: idSucursal,
            stock_actual: { gt: 0 },
          },
          orderBy: { fecha_venc: 'asc' },
        });

        const stockTotal = lotesDisponibles.reduce(
          (acumulado, lote) => acumulado + Number(lote.stock_actual),
          0,
        );

        if (stockTotal < cantidadNecesaria) {
          throw new BadRequestException(
            `Stock insuficiente para "${nombreProducto}". ` +
              `Disponible: ${stockTotal}, requerido: ${cantidadNecesaria}`,
          );
        }

        let restante = cantidadNecesaria;

        for (const lote of lotesDisponibles) {
          if (restante <= 0) break;

          const stockLote = Number(lote.stock_actual);
          const cantidadDescontada = Math.min(stockLote, restante);

          await tx.lotes.update({
            where: { id_lote: lote.id_lote },
            data: { stock_actual: stockLote - cantidadDescontada },
          });

          const movimiento = await tx.movimientos.create({
            data: {
              id_usuario: idUsuario,
              id_lote: lote.id_lote,
              id_kit: idKit,
              cantidad: cantidadDescontada,
              tipo_mov: 'EGRESO_KIT',
            },
          });

          movimientosGenerados.push(movimiento);
          restante -= cantidadDescontada;
        }
      }

      return movimientosGenerados;
    });
  }
}
