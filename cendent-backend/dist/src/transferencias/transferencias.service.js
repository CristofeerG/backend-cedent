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
    async enviarTransferencia(dto) {
        return this.prisma.$transaction(async (tx) => {
            for (const item of dto.lotes) {
                const lote = await tx.lotes.findFirst({
                    where: { id_lote: item.id_lote, id_sucursal: dto.id_sucursal_origen },
                });
                if (!lote) {
                    throw new common_1.BadRequestException(`Lote ${item.id_lote} no existe en la sucursal origen ${dto.id_sucursal_origen}`);
                }
                const stockDisponible = Number(lote.stock_actual);
                if (stockDisponible < item.cantidad) {
                    throw new common_1.BadRequestException(`Stock insuficiente en lote ${item.id_lote}. ` +
                        `Disponible: ${stockDisponible}, solicitado: ${item.cantidad}`);
                }
                await tx.lotes.update({
                    where: { id_lote: item.id_lote },
                    data: { stock_actual: stockDisponible - item.cantidad },
                });
            }
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
    async recibirTransferencia(dto) {
        return this.prisma.$transaction(async (tx) => {
            const transferencia = await tx.transferencias.findUnique({
                where: { id_transferencia: dto.id_transferencia },
                include: {
                    detalle_transferencia: { include: { lotes: true } },
                },
            });
            if (!transferencia) {
                throw new common_1.NotFoundException(`Transferencia con id ${dto.id_transferencia} no encontrada`);
            }
            if (transferencia.estado !== 'EN_TRANSITO') {
                throw new common_1.BadRequestException(`La transferencia ya fue procesada con estado "${transferencia.estado}"`);
            }
            await tx.transferencias.update({
                where: { id_transferencia: dto.id_transferencia },
                data: {
                    estado: 'RECIBIDA',
                    fecha_recepcion: new Date(),
                    id_usuario_recibe: dto.id_usuario_recibe,
                },
            });
            const lotesCreados = [];
            for (const detalle of transferencia.detalle_transferencia) {
                const loteOriginal = detalle.lotes;
                if (!loteOriginal)
                    continue;
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
};
exports.TransferenciasService = TransferenciasService;
exports.TransferenciasService = TransferenciasService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], TransferenciasService);
//# sourceMappingURL=transferencias.service.js.map