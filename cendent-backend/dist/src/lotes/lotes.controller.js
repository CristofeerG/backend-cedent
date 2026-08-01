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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.LotesController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const roles_guard_1 = require("../auth/guards/roles.guard");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const actualizar_lote_dto_1 = require("./dto/actualizar-lote.dto");
const crear_lote_dto_1 = require("./dto/crear-lote.dto");
const lotes_service_1 = require("./lotes.service");
let LotesController = class LotesController {
    lotesService;
    constructor(lotesService) {
        this.lotesService = lotesService;
    }
    registrarLote(dto, req) {
        return this.lotesService.registrarLote(dto, req.user.id_sucursal);
    }
    obtenerPorProducto(idProducto) {
        return this.lotesService.obtenerPorProducto(idProducto);
    }
    darDeBaja(id, req) {
        return this.lotesService.darDeBaja(id, req.user.id_sucursal);
    }
    actualizar(id, dto) {
        return this.lotesService.actualizar(id, dto);
    }
};
exports.LotesController = LotesController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Registrar un nuevo lote para un producto existente; codigo_lote e id_sucursal se generan automáticamente' }),
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_lote_dto_1.CrearLoteDto, Object]),
    __metadata("design:returntype", void 0)
], LotesController.prototype, "registrarLote", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar lotes de un producto ordenados por fecha de vencimiento' }),
    (0, common_1.Get)('producto/:id_producto'),
    __param(0, (0, common_1.Param)('id_producto', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], LotesController.prototype, "obtenerPorProducto", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Dar de baja un lote (requiere stock en 0) — solo administrador' }),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Patch)(':id/baja'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, Object]),
    __metadata("design:returntype", void 0)
], LotesController.prototype, "darDeBaja", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar stock, costo o fecha de vencimiento de un lote — solo administrador' }),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, actualizar_lote_dto_1.ActualizarLoteDto]),
    __metadata("design:returntype", void 0)
], LotesController.prototype, "actualizar", null);
exports.LotesController = LotesController = __decorate([
    (0, swagger_1.ApiTags)('Lotes'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('lotes'),
    __metadata("design:paramtypes", [lotes_service_1.LotesService])
], LotesController);
//# sourceMappingURL=lotes.controller.js.map