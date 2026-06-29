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
exports.TransferenciasController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const roles_guard_1 = require("../auth/guards/roles.guard");
const enviar_transferencia_dto_1 = require("./dto/enviar-transferencia.dto");
const recibir_transferencia_dto_1 = require("./dto/recibir-transferencia.dto");
const transferencias_service_1 = require("./transferencias.service");
let TransferenciasController = class TransferenciasController {
    transferenciasService;
    constructor(transferenciasService) {
        this.transferenciasService = transferenciasService;
    }
    obtenerTodas(req) {
        return this.transferenciasService.obtenerTodas(req.user.id_sucursal);
    }
    obtenerPorId(id) {
        return this.transferenciasService.obtenerPorId(id);
    }
    enviarTransferencia(dto, req) {
        return this.transferenciasService.enviarTransferencia(dto, req.user.id_sucursal, req.user.id_usuario);
    }
    cancelarTransferencia(id) {
        return this.transferenciasService.cancelarTransferencia(id);
    }
    recibirTransferencia(dto, req) {
        return this.transferenciasService.recibirTransferencia(dto, req.user.id_usuario);
    }
};
exports.TransferenciasController = TransferenciasController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar todas las transferencias de la sucursal del usuario' }),
    (0, common_1.Get)(),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "obtenerTodas", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Obtener una transferencia por ID' }),
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "obtenerPorId", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Crear transferencia por nombre de producto con FIFO; sucursal origen y usuario se extraen del JWT' }),
    (0, common_1.Post)('enviar'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [enviar_transferencia_dto_1.EnviarTransferenciaDto, Object]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "enviarTransferencia", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Cancelar una transferencia EN_TRANSITO y restaurar stock en origen' }),
    (0, common_1.Patch)(':id/cancelar'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "cancelarTransferencia", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Registrar la recepción de una transferencia; usuario recibe se extrae del JWT' }),
    (0, common_1.Post)('recibir'),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [recibir_transferencia_dto_1.RecibirTransferenciaDto, Object]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "recibirTransferencia", null);
exports.TransferenciasController = TransferenciasController = __decorate([
    (0, swagger_1.ApiTags)('Transferencias'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador', 'auxiliar'),
    (0, common_1.Controller)('transferencias'),
    __metadata("design:paramtypes", [transferencias_service_1.TransferenciasService])
], TransferenciasController);
//# sourceMappingURL=transferencias.controller.js.map