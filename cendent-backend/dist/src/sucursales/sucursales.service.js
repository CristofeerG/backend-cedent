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
exports.SucursalesService = void 0;
const common_1 = require("@nestjs/common");
const prisma_service_1 = require("../prisma/prisma.service");
let SucursalesService = class SucursalesService {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    obtenerTodas() {
        return this.prisma.sucursales.findMany({
            orderBy: { nom_sucursal: 'asc' },
        });
    }
    async obtenerPorId(idSucursal) {
        const sucursal = await this.prisma.sucursales.findUnique({
            where: { id_sucursal: idSucursal },
        });
        if (!sucursal)
            throw new common_1.NotFoundException(`Sucursal con id ${idSucursal} no encontrada`);
        return sucursal;
    }
    buscarPorNombre(nombre) {
        return this.prisma.sucursales.findMany({
            where: { nom_sucursal: { contains: nombre, mode: 'insensitive' } },
            orderBy: { nom_sucursal: 'asc' },
        });
    }
    crear(dto) {
        return this.prisma.sucursales.create({
            data: {
                nom_sucursal: dto.nomSucursal,
                ubicacion: dto.ubicacion ?? null,
                estado: dto.estado ?? true,
            },
        });
    }
    async actualizar(id, dto) {
        const suc = await this.prisma.sucursales.findUnique({ where: { id_sucursal: id } });
        if (!suc)
            throw new common_1.NotFoundException(`Sucursal ${id} no encontrada`);
        const data = {};
        if (dto.nomSucursal !== undefined)
            data.nom_sucursal = dto.nomSucursal;
        if (dto.ubicacion !== undefined)
            data.ubicacion = dto.ubicacion || null;
        return this.prisma.sucursales.update({ where: { id_sucursal: id }, data });
    }
    async eliminar(id) {
        const suc = await this.prisma.sucursales.findUnique({ where: { id_sucursal: id } });
        if (!suc)
            throw new common_1.NotFoundException(`Sucursal ${id} no encontrada`);
        await this.prisma.sucursales.update({
            where: { id_sucursal: id },
            data: { estado: false },
        });
        return { message: `Sucursal ${id} eliminada` };
    }
};
exports.SucursalesService = SucursalesService;
exports.SucursalesService = SucursalesService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService])
], SucursalesService);
//# sourceMappingURL=sucursales.service.js.map