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
var NotificacionesService_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificacionesService = void 0;
const common_1 = require("@nestjs/common");
const schedule_1 = require("@nestjs/schedule");
const prisma_service_1 = require("../prisma/prisma.service");
const notificaciones_gateway_1 = require("./notificaciones.gateway");
const DIAS_ALERTA_CADUCIDAD = 30;
let NotificacionesService = NotificacionesService_1 = class NotificacionesService {
    prisma;
    gateway;
    logger = new common_1.Logger(NotificacionesService_1.name);
    constructor(prisma, gateway) {
        this.prisma = prisma;
        this.gateway = gateway;
    }
    async revisarInventario() {
        this.logger.log('Iniciando revisión automática de inventario...');
        const sucursales = await this.prisma.sucursales.findMany({
            where: { estado: true },
            select: { id_sucursal: true },
            orderBy: { id_sucursal: 'asc' },
        });
        const resultados = await Promise.all(sucursales.map((s) => this.revisarSucursal(s.id_sucursal)));
        this.logger.log(`Revisión de inventario finalizada (${sucursales.length} sucursal(es)).`);
        return resultados;
    }
    async revisarSucursal(idSucursal) {
        const hoy = new Date();
        hoy.setHours(0, 0, 0, 0);
        const limiteCaducidad = new Date(hoy);
        limiteCaducidad.setDate(limiteCaducidad.getDate() + DIAS_ALERTA_CADUCIDAD);
        const [alertasCaducidad, alertasStock] = await Promise.all([
            this.consultarLotesPorCaducar(idSucursal, hoy, limiteCaducidad),
            this.consultarProductosBajoStock(idSucursal, hoy),
        ]);
        if (alertasCaducidad.length > 0) {
            this.gateway.emitirAlertaCaducidad(idSucursal, alertasCaducidad);
            this.logger.warn(`[sucursal ${idSucursal}] Alerta caducidad: ${alertasCaducidad.length} lote(s) próximos a vencer`);
        }
        if (alertasStock.length > 0) {
            this.gateway.emitirAlertaStock(idSucursal, alertasStock);
            this.logger.warn(`[sucursal ${idSucursal}] Alerta stock: ${alertasStock.length} producto(s) bajo mínimo`);
        }
        return { id_sucursal: idSucursal, alertasCaducidad, alertasStock };
    }
    async consultarLotesPorCaducar(idSucursal, hoy, limite) {
        const lotes = await this.prisma.lotes.findMany({
            where: {
                id_sucursal: idSucursal,
                fecha_venc: { gte: hoy, lte: limite },
                stock_actual: { gt: 0 },
            },
            include: {
                productos: { select: { nombre_mat: true } },
                sucursales: { select: { nom_sucursal: true } },
            },
            orderBy: { fecha_venc: 'asc' },
        });
        return lotes.map((lote) => {
            const diasRestantes = Math.ceil((lote.fecha_venc.getTime() - hoy.getTime()) / (1000 * 60 * 60 * 24));
            return {
                id_lote: lote.id_lote,
                codigo_lote: lote.codigo_lote,
                nombre_producto: lote.productos?.nombre_mat ?? `id_producto ${lote.id_producto}`,
                nombre_sucursal: lote.sucursales?.nom_sucursal ?? `id_sucursal ${lote.id_sucursal}`,
                stock_actual: Number(lote.stock_actual),
                fecha_venc: lote.fecha_venc,
                dias_restantes: diasRestantes,
            };
        });
    }
    async consultarProductosBajoStock(idSucursal, hoy) {
        const productos = await this.prisma.productos.findMany({
            where: {
                stock_min: { gt: 0 },
                lotes: { some: { id_sucursal: idSucursal } },
            },
            include: {
                lotes: {
                    where: { id_sucursal: idSucursal, fecha_venc: { gte: hoy } },
                    select: { stock_actual: true },
                },
            },
        });
        const productosBajoStock = [];
        for (const producto of productos) {
            const stockTotal = producto.lotes.reduce((suma, lote) => suma + Number(lote.stock_actual), 0);
            const stockMin = Number(producto.stock_min);
            if (stockTotal <= stockMin) {
                productosBajoStock.push({
                    id_producto: producto.id_producto,
                    nombre_producto: producto.nombre_mat,
                    stock_total: stockTotal,
                    stock_min: stockMin,
                });
            }
        }
        return productosBajoStock;
    }
};
exports.NotificacionesService = NotificacionesService;
__decorate([
    (0, schedule_1.Cron)(schedule_1.CronExpression.EVERY_DAY_AT_MIDNIGHT),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], NotificacionesService.prototype, "revisarInventario", null);
exports.NotificacionesService = NotificacionesService = NotificacionesService_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        notificaciones_gateway_1.NotificacionesGateway])
], NotificacionesService);
//# sourceMappingURL=notificaciones.service.js.map