"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransferenciasService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
function generarCodigoTrz() {
    const hoy = new Date();
    const fechaStr = hoy.toISOString().slice(0, 10).replace(/-/g, '');
    const aleatorio = Math.random().toString(36).substring(2, 7).toUpperCase();
    return `TRZ-${fechaStr}-${aleatorio}`;
}
let TransferenciasService = class TransferenciasService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
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
    async obtenerPorId(idTransferencia) {
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
            throw new common_1.NotFoundException(`Transferencia con id ${idTransferencia} no encontrada`);
        return transferencia;
    }
    async enviarTransferencia(dto, idSucursalOrigen, idUsuarioEnvia) {
        return this.prisma.$transaction(async (tx) => {
            const sucursalDestino = await tx.sucursales.findFirst({
                where: {
                    nom_sucursal: { contains: dto.nombre_sucursal_destino, mode: 'insensitive' },
                },
            });
            if (!sucursalDestino) {
                throw new common_1.NotFoundException(`Sucursal destino no encontrada: "${dto.nombre_sucursal_destino}"`);
            }
            const idSucursalDestino = sucursalDestino.id_sucursal;
            const descontesPorProducto = [];
            for (const item of dto.productos) {
                const producto = await tx.productos.findFirst({
                    where: { nombre_mat: { contains: item.nombre_producto, mode: 'insensitive' } },
                });
                if (!producto) {
                    throw new common_1.NotFoundException(`Producto no encontrado: "${item.nombre_producto}"`);
                }
                const lotesDisponibles = await tx.lotes.findMany({
                    where: {
                        id_producto: producto.id_producto,
                        id_sucursal: idSucursalOrigen,
                        stock_actual: { gt: 0 },
                    },
                    orderBy: { fecha_venc: 'asc' },
                });
                const stockTotal = lotesDisponibles.reduce((suma, l) => suma + Number(l.stock_actual), 0);
                if (stockTotal < item.cantidad) {
                    throw new common_1.BadRequestException(`Stock insuficiente para "${producto.nombre_mat}". ` +
                        `Disponible: ${stockTotal}, solicitado: ${item.cantidad}`);
                }
                const lotesDescontados = [];
                let restante = item.cantidad;
                for (const lote of lotesDisponibles) {
                    if (restante <= 0)
                        break;
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
            const transferencia = await tx.transferencias.create({
                data: {
                    codigo_trz: generarCodigoTrz(),
                    id_sucursal_origen: idSucursalOrigen,
                    id_sucursal_destino: idSucursalDestino,
                    id_usuario_envia: idUsuarioEnvia,
                    estado: 'EN_TRANSITO',
                },
            });
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
    async recibirTransferencia(dto, idUsuarioRecibe) {
        return this.prisma.$transaction(async (tx) => {
            const transferencia = await tx.transferencias.findUnique({
                where: { codigo_trz: dto.codigo_trz },
                include: {
                    detalle_transferencia: { include: { lotes: true } },
                },
            });
            if (!transferencia) {
                throw new common_1.NotFoundException(`Transferencia con código "${dto.codigo_trz}" no encontrada`);
            }
            if (transferencia.estado !== 'EN_TRANSITO') {
                throw new common_1.BadRequestException(`La transferencia ya fue procesada con estado "${transferencia.estado}"`);
            }
            await tx.transferencias.update({
                where: { codigo_trz: dto.codigo_trz },
                data: {
                    estado: 'RECIBIDA',
                    fecha_recepcion: new Date(),
                    id_usuario_recibe: idUsuarioRecibe,
                },
            });
            const lotesCreados = [];
            for (const detalle of transferencia.detalle_transferencia) {
                const loteOriginal = detalle.lotes;
                if (!loteOriginal)
                    continue;
                const cantidadRecibida = Number(detalle.cantidad);
                const loteExistente = await tx.lotes.findFirst({
                    where: {
                        id_producto: loteOriginal.id_producto,
                        id_sucursal: transferencia.id_sucursal_destino,
                        fecha_venc: loteOriginal.fecha_venc,
                    },
                });
                let loteResultante;
                if (loteExistente) {
                    loteResultante = await tx.lotes.update({
                        where: { id_lote: loteExistente.id_lote },
                        data: { stock_actual: Number(loteExistente.stock_actual) + cantidadRecibida },
                    });
                }
                else {
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
};
exports.TransferenciasService = TransferenciasService;
exports.TransferenciasService = TransferenciasService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], TransferenciasService);
//# sourceMappingURL=transferencias.service.js.map