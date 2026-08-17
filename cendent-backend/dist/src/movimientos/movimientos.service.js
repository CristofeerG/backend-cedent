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
    obtenerTodos(idSucursal, idProducto) {
        const lotesWhere = {};
        if (idSucursal)
            lotesWhere['id_sucursal'] = idSucursal;
        if (idProducto)
            lotesWhere['id_producto'] = idProducto;
        const hasFilter = Object.keys(lotesWhere).length > 0;
        return this.prisma.movimientos.findMany({
            where: hasFilter ? { lotes: lotesWhere } : undefined,
            include: {
                lotes: {
                    include: {
                        productos: true,
                        sucursales: true,
                    },
                },
                transferencias: {
                    include: {
                        sucursales_transferencias_id_sucursal_origenTosucursales: {
                            select: { nom_sucursal: true },
                        },
                        sucursales_transferencias_id_sucursal_destinoTosucursales: {
                            select: { nom_sucursal: true },
                        },
                    },
                },
                usuarios: true,
                kits: true,
            },
            orderBy: { fecha_hora: 'desc' },
            take: idProducto ? 10 : 200,
        });
    }
    async despacharKit(idKit, idUsuario, idSucursal, sustituciones) {
        return this.prisma.$transaction(async (tx) => {
            const detalles = await tx.detalle_kit.findMany({
                where: { id_kit: idKit },
                include: { productos: true },
            });
            if (!detalles.length) {
                throw new common_1.NotFoundException(`Kit con id ${idKit} no encontrado o sin productos`);
            }
            const mapaDetalles = new Map(detalles.map((d) => [d.id_detalle, d]));
            const mapaSust = new Map(sustituciones.map((s) => [s.id_detalle, s.id_producto]));
            for (const s of sustituciones) {
                if (!mapaDetalles.has(s.id_detalle))
                    throw new common_1.BadRequestException(`id_detalle ${s.id_detalle} no pertenece al kit ${idKit}`);
            }
            for (const s of sustituciones) {
                if (!mapaDetalles.get(s.id_detalle).es_variable)
                    throw new common_1.BadRequestException(`id_detalle ${s.id_detalle} es un ítem fijo y no admite sustitución`);
            }
            for (const detalle of detalles) {
                if (detalle.es_variable && !mapaSust.has(detalle.id_detalle) && detalle.id_producto === null)
                    throw new common_1.BadRequestException(`El ítem variable id_detalle ${detalle.id_detalle} no tiene producto genérico ni sustitución proporcionada`);
            }
            const substIds = [...new Set(sustituciones.map((s) => s.id_producto))];
            const substProds = substIds.length > 0
                ? await tx.productos.findMany({
                    where: { id_producto: { in: substIds } },
                    select: { id_producto: true, nombre_mat: true },
                })
                : [];
            const substProdMap = new Map(substProds.map((p) => [p.id_producto, p.nombre_mat ?? '']));
            const movimientosGenerados = [];
            const lotesUsados = [];
            for (const detalle of detalles) {
                const cantidadNecesaria = Number(detalle.cantidad_estandar);
                const idProductoAUsar = mapaSust.has(detalle.id_detalle)
                    ? mapaSust.get(detalle.id_detalle)
                    : detalle.id_producto;
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
                    throw new common_1.BadRequestException(`Stock insuficiente para "${nombre}". Disponible: ${stockTotal}, requerido: ${cantidadNecesaria}`);
                }
                let restante = cantidadNecesaria;
                let primerLote = true;
                for (const lote of lotes) {
                    if (restante <= 0)
                        break;
                    const stockLote = Number(lote.stock_actual);
                    const descontado = Math.min(stockLote, restante);
                    const stockRestante = stockLote - descontado;
                    await tx.lotes.update({ where: { id_lote: lote.id_lote }, data: { stock_actual: stockRestante } });
                    movimientosGenerados.push(await tx.movimientos.create({
                        data: { id_usuario: idUsuario, id_lote: lote.id_lote, id_kit: idKit, cantidad: descontado, tipo_mov: 'EGRESO_KIT' },
                    }));
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
    async consumirProducto(idProducto, cantidad, idUsuario, idSucursal) {
        return this.prisma.$transaction(async (tx) => {
            const producto = await tx.productos.findUnique({
                where: { id_producto: idProducto },
                select: { nombre_mat: true },
            });
            if (!producto)
                throw new common_1.NotFoundException(`Producto con id ${idProducto} no encontrado`);
            const lotes = await tx.lotes.findMany({
                where: { id_producto: idProducto, id_sucursal: idSucursal, stock_actual: { gt: 0 } },
                orderBy: { fecha_venc: 'asc' },
            });
            const stockTotal = lotes.reduce((a, l) => a + Number(l.stock_actual), 0);
            if (stockTotal < cantidad)
                throw new common_1.BadRequestException(`Stock insuficiente para "${producto.nombre_mat}". Disponible: ${stockTotal}, requerido: ${cantidad}`);
            const movimientosGenerados = [];
            let restante = cantidad;
            let loteUsado = null;
            for (const lote of lotes) {
                if (restante <= 0)
                    break;
                const stockLote = Number(lote.stock_actual);
                const descontado = Math.min(stockLote, restante);
                const stockRestante = stockLote - descontado;
                await tx.lotes.update({ where: { id_lote: lote.id_lote }, data: { stock_actual: stockRestante } });
                movimientosGenerados.push(await tx.movimientos.create({
                    data: { id_usuario: idUsuario, id_lote: lote.id_lote, id_kit: null, cantidad: descontado, tipo_mov: 'EGRESO_DIRECTO' },
                }));
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
};
exports.MovimientosService = MovimientosService;
exports.MovimientosService = MovimientosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], MovimientosService);
//# sourceMappingURL=movimientos.service.js.map