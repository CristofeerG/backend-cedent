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

  async enviarTransferencia(
    dto: EnviarTransferenciaDto,
    idSucursalOrigen: number,
    idUsuarioEnvia: number,
  ) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Resolver sucursal destino por nombre
      const sucursalDestino = await tx.sucursales.findFirst({
        where: {
          nom_sucursal: { contains: dto.nombre_sucursal_destino, mode: 'insensitive' },
        },
      });

      if (!sucursalDestino) {
        throw new NotFoundException(
          `Sucursal destino no encontrada: "${dto.nombre_sucursal_destino}"`,
        );
      }

      const idSucursalDestino = sucursalDestino.id_sucursal;

      // 2. Por cada producto: buscar, validar stock FIFO y preparar descuentos
      type LoteDescontado = { id_lote: number; cantidadDescontada: number };
      const descontesPorProducto: Array<{
        nombreProducto: string;
        lotes: LoteDescontado[];
      }> = [];

      for (const item of dto.productos) {
        // 2a. Buscar producto por nombre
        const producto = await tx.productos.findFirst({
          where: { nombre_mat: { contains: item.nombre_producto, mode: 'insensitive' } },
        });

        if (!producto) {
          throw new NotFoundException(
            `Producto no encontrado: "${item.nombre_producto}"`,
          );
        }

        // 2b. Obtener lotes disponibles en origen con FIFO
        const lotesDisponibles = await tx.lotes.findMany({
          where: {
            id_producto: producto.id_producto,
            id_sucursal: idSucursalOrigen,
            stock_actual: { gt: 0 },
          },
          orderBy: { fecha_venc: 'asc' },
        });

        // 2c. Verificar stock total suficiente
        const stockTotal = lotesDisponibles.reduce(
          (suma, l) => suma + Number(l.stock_actual),
          0,
        );

        if (stockTotal < item.cantidad) {
          throw new BadRequestException(
            `Stock insuficiente para "${producto.nombre_mat}". ` +
              `Disponible: ${stockTotal}, solicitado: ${item.cantidad}`,
          );
        }

        // 2d. Distribuir descuento FIFO entre lotes
        const lotesDescontados: LoteDescontado[] = [];
        let restante = item.cantidad;

        for (const lote of lotesDisponibles) {
          if (restante <= 0) break;
          const descontar = Math.min(Number(lote.stock_actual), restante);

          await tx.lotes.update({
            where: { id_lote: lote.id_lote },
            data: { stock_actual: Number(lote.stock_actual) - descontar },
          });

          lotesDescontados.push({ id_lote: lote.id_lote, cantidadDescontada: descontar });
          restante -= descontar;
        }

        descontesPorProducto.push({
          nombreProducto: producto.nombre_mat,
          lotes: lotesDescontados,
        });
      }

      // 3. Crear registro de transferencia
      const transferencia = await tx.transferencias.create({
        data: {
          codigo_trz: generarCodigoTrz(),
          id_sucursal_origen: idSucursalOrigen,
          id_sucursal_destino: idSucursalDestino,
          id_usuario_envia: idUsuarioEnvia,
          estado: 'EN_TRANSITO',
        },
      });

      // 4. Insertar detalle y movimientos por cada lote consumido
      for (const grupo of descontesPorProducto) {
        for (const loteDesc of grupo.lotes) {
          await tx.detalle_transferencia.create({
            data: {
              id_transferencia: transferencia.id_transferencia,
              id_lote: loteDesc.id_lote,
              cantidad: loteDesc.cantidadDescontada,
            },
          });

          await tx.movimientos.create({
            data: {
              id_usuario: idUsuarioEnvia,
              id_lote: loteDesc.id_lote,
              id_kit: null,
              cantidad: loteDesc.cantidadDescontada,
              tipo_mov: 'SALIDA_TRANSFERENCIA',
            },
          });
        }
      }

      return transferencia;
    });
  }

  async recibirTransferencia(dto: RecibirTransferenciaDto, idUsuarioRecibe: number) {
    return this.prisma.$transaction(async (tx) => {
      // 1. Obtener y validar la transferencia
      const transferencia = await tx.transferencias.findUnique({
        where: { codigo_trz: dto.codigo_trz },
        include: {
          detalle_transferencia: { include: { lotes: true } },
        },
      });

      if (!transferencia) {
        throw new NotFoundException(
          `Transferencia con código "${dto.codigo_trz}" no encontrada`,
        );
      }

      if (transferencia.estado !== 'EN_TRANSITO') {
        throw new BadRequestException(
          `La transferencia ya fue procesada con estado "${transferencia.estado}"`,
        );
      }

      // 2. Cambiar estado y registrar recepción
      await tx.transferencias.update({
        where: { codigo_trz: dto.codigo_trz },
        data: {
          estado: 'RECIBIDA',
          fecha_recepcion: new Date(),
          id_usuario_recibe: idUsuarioRecibe,
        },
      });

      // 3. Consolidar lotes en sucursal destino y registrar ingresos
      const lotesCreados: lotes[] = [];

      for (const detalle of transferencia.detalle_transferencia) {
        const loteOriginal = detalle.lotes;
        if (!loteOriginal) continue;

        const cantidadRecibida = Number(detalle.cantidad);

        // Buscar lote existente en destino con mismo producto y misma fecha_venc
        const loteExistente = await tx.lotes.findFirst({
          where: {
            id_producto: loteOriginal.id_producto,
            id_sucursal: transferencia.id_sucursal_destino,
            fecha_venc: loteOriginal.fecha_venc,
          },
        });

        let loteResultante: lotes;

        if (loteExistente) {
          // Acumular stock en el lote existente
          loteResultante = await tx.lotes.update({
            where: { id_lote: loteExistente.id_lote },
            data: { stock_actual: Number(loteExistente.stock_actual) + cantidadRecibida },
          });
        } else {
          // Crear lote nuevo en destino
          loteResultante = await tx.lotes.create({
            data: {
              id_producto: loteOriginal.id_producto,
              id_sucursal: transferencia.id_sucursal_destino,
              codigo_lote: `REC-${transferencia.id_transferencia}-${loteOriginal.id_lote}`,
              stock_actual: cantidadRecibida,
              costo_unit: loteOriginal.costo_unit ? Number(loteOriginal.costo_unit) : null,
              fecha_venc: loteOriginal.fecha_venc,
            },
          });
        }

        await tx.movimientos.create({
          data: {
            id_usuario: idUsuarioRecibe,
            id_lote: loteResultante.id_lote,
            id_kit: null,
            cantidad: cantidadRecibida,
            tipo_mov: 'INGRESO_TRANSFERENCIA',
          },
        });

        lotesCreados.push(loteResultante);
      }

      return {
        mensaje: 'Transferencia recibida correctamente',
        codigo_trz: transferencia.codigo_trz,
        lotes_creados: lotesCreados,
      };
    });
  }
}
