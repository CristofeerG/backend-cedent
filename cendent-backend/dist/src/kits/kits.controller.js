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
exports.KitsController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const actualizar_kit_dto_1 = require("./dto/actualizar-kit.dto");
const crear_kit_dto_1 = require("./dto/crear-kit.dto");
const kits_service_1 = require("./kits.service");
let KitsController = class KitsController {
    kitsService;
    constructor(kitsService) {
        this.kitsService = kitsService;
    }
    buscarPorNombre(nombre) {
        if (!nombre?.trim())
            throw new common_1.BadRequestException('El parámetro nombre es requerido');
        return this.kitsService.buscarPorNombre(nombre.trim());
    }
    obtenerTodos() {
        return this.kitsService.obtenerTodos();
    }
    obtenerPorId(id) {
        return this.kitsService.obtenerPorId(id);
    }
    crear(dto) {
        return this.kitsService.crear(dto);
    }
    actualizar(id, dto) {
        return this.kitsService.actualizar(id, dto);
    }
    eliminar(id) {
        return this.kitsService.eliminar(id);
    }
};
exports.KitsController = KitsController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Buscar kits por nombre de procedimiento (búsqueda parcial, insensible a mayúsculas)' }),
    (0, swagger_1.ApiQuery)({ name: 'nombre', required: true, type: String }),
    (0, common_1.Get)('buscar'),
    __param(0, (0, common_1.Query)('nombre')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], KitsController.prototype, "buscarPorNombre", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar todos los kits de procedimientos' }),
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], KitsController.prototype, "obtenerTodos", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Obtener un kit con su detalle de materiales por ID' }),
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], KitsController.prototype, "obtenerPorId", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Crear un nuevo kit de procedimiento' }),
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_kit_dto_1.CrearKitDto]),
    __metadata("design:returntype", void 0)
], KitsController.prototype, "crear", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar nombre y/o detalle de un kit existente' }),
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, actualizar_kit_dto_1.ActualizarKitDto]),
    __metadata("design:returntype", void 0)
], KitsController.prototype, "actualizar", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Eliminar un kit y su detalle de materiales' }),
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], KitsController.prototype, "eliminar", null);
exports.KitsController = KitsController = __decorate([
    (0, swagger_1.ApiTags)('Kits'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('kits'),
    __metadata("design:paramtypes", [kits_service_1.KitsService])
], KitsController);
//# sourceMappingURL=kits.controller.js.map