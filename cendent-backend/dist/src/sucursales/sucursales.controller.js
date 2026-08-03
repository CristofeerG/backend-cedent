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
exports.SucursalesController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const roles_guard_1 = require("../auth/guards/roles.guard");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const crear_sucursal_dto_1 = require("./dto/crear-sucursal.dto");
const editar_sucursal_dto_1 = require("./dto/editar-sucursal.dto");
const sucursales_service_1 = require("./sucursales.service");
let SucursalesController = class SucursalesController {
    sucursalesService;
    constructor(sucursalesService) {
        this.sucursalesService = sucursalesService;
    }
    crear(dto) {
        return this.sucursalesService.crear(dto);
    }
    buscarPorNombre(nombre) {
        if (!nombre?.trim())
            throw new common_1.BadRequestException('El parámetro nombre es requerido');
        return this.sucursalesService.buscarPorNombre(nombre.trim());
    }
    obtenerTodas() {
        return this.sucursalesService.obtenerTodas();
    }
    obtenerPorId(id) {
        return this.sucursalesService.obtenerPorId(id);
    }
    actualizar(id, dto) {
        return this.sucursalesService.actualizar(id, dto);
    }
    eliminar(id) {
        return this.sucursalesService.eliminar(id);
    }
};
exports.SucursalesController = SucursalesController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Crear una nueva sucursal — solo administrador' }),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_sucursal_dto_1.CrearSucursalDto]),
    __metadata("design:returntype", void 0)
], SucursalesController.prototype, "crear", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Buscar sucursales por nombre (búsqueda parcial, insensible a mayúsculas)' }),
    (0, swagger_1.ApiQuery)({ name: 'nombre', required: true, type: String }),
    (0, common_1.Get)('buscar'),
    __param(0, (0, common_1.Query)('nombre')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], SucursalesController.prototype, "buscarPorNombre", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar todas las sucursales' }),
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SucursalesController.prototype, "obtenerTodas", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Obtener una sucursal por ID' }),
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], SucursalesController.prototype, "obtenerPorId", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Editar nombre o ubicación de una sucursal — solo administrador' }),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, editar_sucursal_dto_1.EditarSucursalDto]),
    __metadata("design:returntype", void 0)
], SucursalesController.prototype, "actualizar", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Desactivar (eliminar) una sucursal — solo administrador' }),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard, roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], SucursalesController.prototype, "eliminar", null);
exports.SucursalesController = SucursalesController = __decorate([
    (0, swagger_1.ApiTags)('Sucursales'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('sucursales'),
    __metadata("design:paramtypes", [sucursales_service_1.SucursalesService])
], SucursalesController);
//# sourceMappingURL=sucursales.controller.js.map