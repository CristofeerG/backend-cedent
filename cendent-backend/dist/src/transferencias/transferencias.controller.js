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
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const enviar_transferencia_dto_1 = require("./dto/enviar-transferencia.dto");
const recibir_transferencia_dto_1 = require("./dto/recibir-transferencia.dto");
const transferencias_service_1 = require("./transferencias.service");
let TransferenciasController = class TransferenciasController {
    transferenciasService;
    constructor(transferenciasService) {
        this.transferenciasService = transferenciasService;
    }
    obtenerTodas() {
        return this.transferenciasService.obtenerTodas();
    }
    obtenerPorId(id) {
        return this.transferenciasService.obtenerPorId(id);
    }
    enviarTransferencia(dto) {
        return this.transferenciasService.enviarTransferencia(dto);
    }
    recibirTransferencia(dto) {
        return this.transferenciasService.recibirTransferencia(dto);
    }
};
exports.TransferenciasController = TransferenciasController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar todas las transferencias' }),
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
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
    (0, swagger_1.ApiOperation)({ summary: 'Crear una transferencia de stock entre sucursales (descuenta origen)' }),
    (0, common_1.Post)('enviar'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [enviar_transferencia_dto_1.EnviarTransferenciaDto]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "enviarTransferencia", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Registrar la recepción de una transferencia (acredita destino)' }),
    (0, common_1.Post)('recibir'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [recibir_transferencia_dto_1.RecibirTransferenciaDto]),
    __metadata("design:returntype", void 0)
], TransferenciasController.prototype, "recibirTransferencia", null);
exports.TransferenciasController = TransferenciasController = __decorate([
    (0, swagger_1.ApiTags)('Transferencias'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('transferencias'),
    __metadata("design:paramtypes", [transferencias_service_1.TransferenciasService])
], TransferenciasController);
//# sourceMappingURL=transferencias.controller.js.map