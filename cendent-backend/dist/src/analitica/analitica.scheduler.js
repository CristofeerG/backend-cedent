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
var AnaliticaScheduler_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.AnaliticaScheduler = void 0;
const common_1 = require("@nestjs/common");
const schedule_1 = require("@nestjs/schedule");
const prisma_service_1 = require("../prisma/prisma.service");
const analitica_service_1 = require("./analitica.service");
let AnaliticaScheduler = AnaliticaScheduler_1 = class AnaliticaScheduler {
    analiticaService;
    prisma;
    logger = new common_1.Logger(AnaliticaScheduler_1.name);
    constructor(analiticaService, prisma) {
        this.analiticaService = analiticaService;
        this.prisma = prisma;
    }
    async generarTodasLasPredicciones() {
        this.logger.log('Cron 07:00 — generando predicciones para todas las sucursales activas...');
        const sucursales = await this.prisma.sucursales.findMany({
            where: { estado: true },
            select: { id_sucursal: true },
        });
        for (const { id_sucursal } of sucursales) {
            try {
                await this.analiticaService.generarYGuardar(id_sucursal);
            }
            catch (err) {
                this.logger.error(`Error generando predicción para sucursal ${id_sucursal}: ${err.message}`);
            }
        }
        this.logger.log(`Predicciones generadas para ${sucursales.length} sucursal(es).`);
    }
};
exports.AnaliticaScheduler = AnaliticaScheduler;
__decorate([
    (0, schedule_1.Cron)('0 7 * * *'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], AnaliticaScheduler.prototype, "generarTodasLasPredicciones", null);
exports.AnaliticaScheduler = AnaliticaScheduler = AnaliticaScheduler_1 = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [analitica_service_1.AnaliticaService,
        prisma_service_1.PrismaService])
], AnaliticaScheduler);
//# sourceMappingURL=analitica.scheduler.js.map