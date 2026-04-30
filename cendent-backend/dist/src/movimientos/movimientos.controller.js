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
exports.MovimientosController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const despachar_kit_dto_1 = require("./dto/despachar-kit.dto");
const movimientos_service_1 = require("./movimientos.service");
let MovimientosController = class MovimientosController {
    movimientosService;
    constructor(movimientosService) {
        this.movimientosService = movimientosService;
    }
    obtenerTodos(idSucursal) {
        const sucursal = idSucursal ? parseInt(idSucursal, 10) : undefined;
        return this.movimientosService.obtenerTodos(sucursal);
    }
    despacharKit(dto) {
        return this.movimientosService.despacharKit(dto.id_kit, dto.id_usuario, dto.id_sucursal);
    }
};
exports.MovimientosController = MovimientosController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar todos los movimientos, opcionalmente filtrados por sucursal' }),
    (0, swagger_1.ApiQuery)({ name: 'id_sucursal', required: false, type: Number }),
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('id_sucursal')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], MovimientosController.prototype, "obtenerTodos", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Despachar un kit descontando stock por FIFO' }),
    (0, common_1.Post)('despachar-kit'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [despachar_kit_dto_1.DespacharKitDto]),
    __metadata("design:returntype", void 0)
], MovimientosController.prototype, "despacharKit", null);
exports.MovimientosController = MovimientosController = __decorate([
    (0, swagger_1.ApiTags)('Movimientos'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.Controller)('movimientos'),
    __metadata("design:paramtypes", [movimientos_service_1.MovimientosService])
], MovimientosController);
//# sourceMappingURL=movimientos.controller.js.map