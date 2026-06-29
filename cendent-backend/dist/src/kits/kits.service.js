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
exports.KitsService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let KitsService = class KitsService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    obtenerTodos() {
        return this.prisma.kits.findMany({
            include: {
                detalle_kit: {
                    include: { productos: true },
                },
            },
        });
    }
    buscarPorNombre(nombre) {
        return this.prisma.kits.findMany({
            where: { nombre_procedimiento: { contains: nombre, mode: 'insensitive' } },
            include: {
                detalle_kit: {
                    include: { productos: true },
                },
            },
            orderBy: { nombre_procedimiento: 'asc' },
        });
    }
    async obtenerPorId(idKit) {
        const kit = await this.prisma.kits.findUnique({
            where: { id_kit: idKit },
            include: {
                detalle_kit: {
                    include: { productos: true },
                },
            },
        });
        if (!kit)
            throw new common_1.NotFoundException(`Kit con id ${idKit} no encontrado`);
        return kit;
    }
    async crear(dto) {
        for (const item of dto.detalle) {
            if (!item.es_variable && (item.id_producto === null || item.id_producto === undefined)) {
                throw new common_1.BadRequestException('Los ítems fijos (es_variable: false) deben tener id_producto');
            }
        }
        return this.prisma.$transaction(async (tx) => {
            const kit = await tx.kits.create({
                data: { nombre_procedimiento: dto.nombre_procedimiento },
            });
            await tx.detalle_kit.createMany({
                data: dto.detalle.map((item) => ({
                    id_kit: kit.id_kit,
                    id_producto: item.id_producto ?? null,
                    cantidad_estandar: item.cantidad_estandar,
                    es_variable: item.es_variable ?? false,
                })),
            });
            return tx.kits.findUnique({
                where: { id_kit: kit.id_kit },
                include: { detalle_kit: { include: { productos: true } } },
            });
        });
    }
    async actualizar(idKit, dto) {
        await this.obtenerPorId(idKit);
        return this.prisma.$transaction(async (tx) => {
            if (dto.detalle !== undefined) {
                for (const item of dto.detalle) {
                    if (!item.es_variable && (item.id_producto === null || item.id_producto === undefined)) {
                        throw new common_1.BadRequestException('Los ítems fijos (es_variable: false) deben tener id_producto');
                    }
                }
                await tx.detalle_kit.deleteMany({ where: { id_kit: idKit } });
                await tx.detalle_kit.createMany({
                    data: dto.detalle.map((item) => ({
                        id_kit: idKit,
                        id_producto: item.id_producto ?? null,
                        cantidad_estandar: item.cantidad_estandar,
                        es_variable: item.es_variable ?? false,
                    })),
                });
            }
            if (dto.nombre_procedimiento !== undefined) {
                await tx.kits.update({
                    where: { id_kit: idKit },
                    data: { nombre_procedimiento: dto.nombre_procedimiento },
                });
            }
            return tx.kits.findUnique({
                where: { id_kit: idKit },
                include: { detalle_kit: { include: { productos: true } } },
            });
        });
    }
    async eliminar(idKit) {
        await this.obtenerPorId(idKit);
        return this.prisma.kits.delete({ where: { id_kit: idKit } });
    }
};
exports.KitsService = KitsService;
exports.KitsService = KitsService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], KitsService);
//# sourceMappingURL=kits.service.js.map