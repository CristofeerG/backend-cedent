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
exports.AnaliticaController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const roles_guard_1 = require("../auth/guards/roles.guard");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const analitica_service_1 = require("./analitica.service");
let AnaliticaController = class AnaliticaController {
    analiticaService;
    constructor(analiticaService) {
        this.analiticaService = analiticaService;
    }
    entrenar(idSucursal) {
        return this.analiticaService.prepararYEntrenar(idSucursal);
    }
    prediccion(idSucursal) {
        return this.analiticaService.predecirDemanda(idSucursal);
    }
    refrescar(idSucursal) {
        return this.analiticaService.generarYGuardar(idSucursal);
    }
};
exports.AnaliticaController = AnaliticaController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Entrenar modelo LSTM con historial de egresos de la sucursal' }),
    (0, common_1.Get)('entrenar/:id_sucursal'),
    __param(0, (0, common_1.Param)('id_sucursal', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], AnaliticaController.prototype, "entrenar", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Predecir demanda a 30 días y calcular sugerencias de compra por sucursal' }),
    (0, common_1.Get)('prediccion/:id_sucursal'),
    __param(0, (0, common_1.Param)('id_sucursal', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], AnaliticaController.prototype, "prediccion", null);
__decorate([
    (0, swagger_1.ApiOperation)({
        summary: 'Forzar reentrenamiento LSTM y actualizar caché de predicción',
        description: 'Lanza generarYGuardar() sincrónicamente. Con 350+ productos puede tardar varios minutos. ' +
            'Retorna ResultadoPrediccionDto + generado_en con la fecha de actualización.',
    }),
    (0, common_1.Post)('refrescar/:id_sucursal'),
    __param(0, (0, common_1.Param)('id_sucursal', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], AnaliticaController.prototype, "refrescar", null);
exports.AnaliticaController = AnaliticaController = __decorate([
    (0, swagger_1.ApiTags)('Analítica'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador', 'auxiliar'),
    (0, common_1.Controller)('analitica'),
    __metadata("design:paramtypes", [analitica_service_1.AnaliticaService])
], AnaliticaController);
//# sourceMappingURL=analitica.controller.js.map