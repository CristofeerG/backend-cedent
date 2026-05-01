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
exports.ProductosService = void 0;
const common_1 = require("@nestjs/common");
const codigo_lote_util_1 = require("../common/codigo-lote.util");
const prisma_service_1 = require("../prisma/prisma.service");
let ProductosService = class ProductosService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    obtenerTodos() {
        return this.prisma.productos.findMany({
            orderBy: { nombre_mat: 'asc' },
        });
    }
    buscarPorNombre(nombre) {
        return this.prisma.productos.findMany({
            where: { nombre_mat: { contains: nombre, mode: 'insensitive' } },
            orderBy: { nombre_mat: 'asc' },
        });
    }
    async obtenerPorId(idProducto) {
        const producto = await this.prisma.productos.findUnique({
            where: { id_producto: idProducto },
            include: { lotes: true },
        });
        if (!producto)
            throw new common_1.NotFoundException(`Producto con id ${idProducto} no encontrado`);
        return producto;
    }
    async obtenerInventario(idSucursal) {
        const hoy = new Date();
        hoy.setHours(0, 0, 0, 0);
        const productos = await this.prisma.productos.findMany({
            include: {
                lotes: {
                    where: {
                        fecha_venc: { gte: hoy },
                        ...(idSucursal ? { id_sucursal: idSucursal } : {}),
                    },
                },
            },
            orderBy: { nombre_mat: 'asc' },
        });
        return productos.map(({ lotes, ...datosProducto }) => ({
            ...datosProducto,
            stock_total: lotes.reduce((suma, lote) => suma + Number(lote.stock_actual), 0),
        }));
    }
    async crear(dto, idSucursal) {
        const { stock_inicial, fecha_venc, costo_unit, ...datosProducto } = dto;
        const crearLote = stock_inicial !== undefined && fecha_venc !== undefined;
        return this.prisma.$transaction(async (tx) => {
            const producto = await tx.productos.create({ data: datosProducto });
            if (crearLote) {
                const codigoLote = (0, codigo_lote_util_1.generarCodigoLote)(producto.subcategoria, producto.id_producto);
                await tx.lotes.create({
                    data: {
                        id_producto: producto.id_producto,
                        id_sucursal: idSucursal,
                        codigo_lote: codigoLote,
                        stock_actual: stock_inicial,
                        fecha_venc: new Date(fecha_venc),
                        costo_unit: costo_unit ?? null,
                    },
                });
            }
            return tx.productos.findUnique({
                where: { id_producto: producto.id_producto },
                include: { lotes: true },
            });
        });
    }
    async actualizar(idProducto, dto) {
        await this.obtenerPorId(idProducto);
        return this.prisma.productos.update({
            where: { id_producto: idProducto },
            data: dto,
        });
    }
    async eliminar(idProducto) {
        await this.obtenerPorId(idProducto);
        return this.prisma.productos.delete({ where: { id_producto: idProducto } });
    }
};
exports.ProductosService = ProductosService;
exports.ProductosService = ProductosService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], ProductosService);
//# sourceMappingURL=productos.service.js.map