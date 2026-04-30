import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { lotes } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { EnviarTransferenciaDto } from './dto/enviar-transferencia.dto';
import { RecibirTransferenciaDto } from './dto/recibir-transferencia.dto';

function generarCodigoTrz(): string {
  const hoy = new Date();
  const fechaStr = hoy.toISOString().slice(0, 10).replace(/-/g, '');
  const aleatorio = Math.random().toString(36).substring(2, 7).toUpperCase();
  return `TRZ-${fechaStr}-${aleatorio}`;
}

@Injectable()
export class TransferenciasService {
  constructor(private readonly prisma: PrismaService) {}

  obtenerTodas() {
    return this.prisma.transferencias.findMany({
      include: {
        detalle_transferencia: { include: { lotes: { include: { productos: true } } } },
        sucursales_transferencias_id_sucursal_origenTosucursales: true,
        sucursales_transferencias_id_sucursal_destinoTosucursales: true,
        usuarios_transferencias_id_usuario_enviaTousuarios: { select: { nom_usuario: true } },
        usuarios_transferencias_id_usuario_recibeTousuarios: { select: { nom_usuario: true } },
      },
      orderBy: { fecha_envio: 'desc' },
    });
  }

  async obtenerPorId(idTransferencia: number) {
    const transferencia = await this.prisma.transferencias.findUnique({
      where: { id_transferencia: idTransferencia },
      include: {
        detalle_transferencia: { include: { lotes: { include: { productos: true } } } },
        sucursales_transferencias_id_sucursal_origenTosucursales: true,
        sucursales_transferencias_id_sucursal_destinoTosucursales: true,
        usuarios_transferencias_id_usuario_enviaTousuarios: { select: { nom_usuario: true } },
        usuarios_transferencias_id_usuario_recibeTousuarios: { select: { nom_usuario: true } },
      },
    });
    if (!transferencia)
      throw new NotFoundException(`Transferencia con id ${idTransferencia} no encontrada`);
    return transferencia;
  }

  async enviarTransferencia(dto: EnviarTransferenciaDto) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Validar stock y descontar en sucursal origen
      for (const item of dto.lotes) {
        const lote = await tx.lotes.findFirst({
          where: { id_lote: item.id_lote, id_sucursal: dto.id_sucursal_origen },
        });

        if (!lote) {
          throw new BadRequestException(
            `Lote ${item.id_lote} no existe en la sucursal origen ${dto.id_sucursal_origen}`,
          );
        }

        const stockDisponible = Number(lote.stock_actual);
        if (stockDisponible < item.cantidad) {
          throw new BadRequestException(
            `Stock insuficiente en lote ${item.id_lote}. ` +
              `Disponible: ${stockDisponible}, solicitado: ${item.cantidad}`,
          );
        }

        await tx.lotes.update({
          where: { id_lote: item.id_lote },
          data: { stock_actual: stockDisponible - item.cantidad },
        });
      }

      // 2. Crear registro de transferencia
      const codigoTrz = generarCodigoTrz();
      const transferencia = await tx.transferencias.create({
        data: {
          codigo_trz: codigoTrz,
          id_sucursal_origen: dto.id_sucursal_origen,
          id_sucursal_destino: dto.id_sucursal_destino,
          id_usuario_envia: dto.id_usuario_envia,
          estado: 'EN_TRANSITO',
        },
      });

      // 3. Insertar detalle y registrar salidas en movimientos
      for (const item of dto.lotes) {
        await tx.detalle_transferencia.create({
          data: {
            id_transferencia: transferencia.id_transferencia,
            id_lote: item.id_lote,
            cantidad: item.cantidad,
          },
        });

        await tx.movimientos.create({
          data: {
            id_usuario: dto.id_usuario_envia,
            id_lote: item.id_lote,
            id_kit: null,
            cantidad: item.cantidad,
            tipo_mov: 'SALIDA_TRANSFERENCIA',
          },
        });
      }

      return transferencia;
    });
  }

  async recibirTransferencia(dto: RecibirTransferenciaDto) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Obtener y validar la transferencia
      const transferencia = await tx.transferencias.findUnique({
        where: { id_transferencia: dto.id_transferencia },
        include: {
          detalle_transferencia: { include: { lotes: true } },
        },
      });

      if (!transferencia) {
        throw new NotFoundException(
          `Transferencia con id ${dto.id_transferencia} no encontrada`,
        );
      }

      if (transferencia.estado !== 'EN_TRANSITO') {
        throw new BadRequestException(
          `La transferencia ya fue procesada con estado "${transferencia.estado}"`,
        );
      }

      // 2. Cambiar estado y registrar recepción
      await tx.transferencias.update({
        where: { id_transferencia: dto.id_transferencia },
        data: {
          estado: 'RECIBIDA',
          fecha_recepcion: new Date(),
          id_usuario_recibe: dto.id_usuario_recibe,
        },
      });

      // 3. Crear nuevos lotes en sucursal destino y registrar ingresos
      const lotesCreados: lotes[] = [];

      for (const detalle of transferencia.detalle_transferencia) {
        const loteOriginal = detalle.lotes;

        if (!loteOriginal) continue;

        const codigoLoteNuevo = `REC-${transferencia.id_transferencia}-${loteOriginal.id_lote}`;

        const nuevoLote = await tx.lotes.create({
          data: {
            id_producto: loteOriginal.id_producto,
            id_sucursal: transferencia.id_sucursal_destino,
            codigo_lote: codigoLoteNuevo,
            stock_actual: Number(detalle.cantidad),
            costo_unit: loteOriginal.costo_unit ? Number(loteOriginal.costo_unit) : null,
            fecha_venc: loteOriginal.fecha_venc,
          },
        });

        await tx.movimientos.create({
          data: {
            id_usuario: dto.id_usuario_recibe,
            id_lote: nuevoLote.id_lote,
            id_kit: null,
            cantidad: Number(detalle.cantidad),
            tipo_mov: 'INGRESO_TRANSFERENCIA',
          },
        });

        lotesCreados.push(nuevoLote);
      }

      return {
        mensaje: 'Transferencia recibida correctamente',
        codigo_trz: transferencia.codigo_trz,
        lotes_creados: lotesCreados,
      };
    });
  }
}
