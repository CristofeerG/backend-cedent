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
exports.MovimientosService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let MovimientosService = class MovimientosService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    obtenerTodos(idSucursal) {
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
    async despacharKit(idKit, idUsuario, idSucursal) {
        return this.prisma.$transaction(async (tx) => {
            const detalles = await tx.detalle_kit.findMany({
                where: { id_kit: idKit },
                include: { productos: true },
            });
            if (!detalles.length) {
                throw new common_1.NotFoundException(`Kit con id ${idKit} no encontrado o sin productos`);
            }
            const movimientosGenerados = [];
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
                const stockTotal = lotesDisponibles.reduce((acumulado, lote) => acumulado + Number(lote.stock_actual), 0);
                if (stockTotal < cantidadNecesaria) {
                    throw new common_1.BadRequestException(`Stock insuficiente para "${nombreProducto}". ` +
                        `Disponible: ${stockTotal}, requerido: ${cantidadNecesaria}`);
                }
                let restante = cantidadNecesaria;
                for (const lote of lotesDisponibles) {
                    if (restante <= 0)
                        break;
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
};
exports.MovimientosService = MovimientosService;
exports.MovimientosService = MovimientosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], MovimientosService);
//# sourceMappingURL=movimientos.service.js.map