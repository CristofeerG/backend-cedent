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
exports.LotesService = void 0;
const common_1 = require("@nestjs/common");
const codigo_lote_util_1 = require("../common/codigo-lote.util");
const prisma_service_1 = require("../prisma/prisma.service");
let LotesService = class LotesService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async registrarLote(dto, idSucursal) {
        const producto = await this.prisma.productos.findUnique({
            where: { id_producto: dto.id_producto },
            select: { id_producto: true, subcategoria: true },
        });
        if (!producto) {
            throw new common_1.NotFoundException(`Producto con id ${dto.id_producto} no encontrado`);
        }
        const codigoLote = (0, codigo_lote_util_1.generarCodigoLote)(producto.subcategoria, producto.id_producto);
        return this.prisma.lotes.create({
            data: {
                id_producto: dto.id_producto,
                id_sucursal: idSucursal,
                codigo_lote: codigoLote,
                stock_actual: dto.stock_inicial,
                fecha_venc: new Date(dto.fecha_venc),
                costo_unit: dto.costo_unit ?? null,
            },
        });
    }
    obtenerPorProducto(idProducto) {
        return this.prisma.lotes.findMany({
            where: { id_producto: idProducto },
            orderBy: { fecha_venc: 'asc' },
        });
    }
};
exports.LotesService = LotesService;
exports.LotesService = LotesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], LotesService);
//# sourceMappingURL=lotes.service.js.map