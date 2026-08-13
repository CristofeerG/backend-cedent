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
exports.ProductosController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const roles_decorator_1 = require("../auth/decorators/roles.decorator");
const roles_guard_1 = require("../auth/guards/roles.guard");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const actualizar_producto_dto_1 = require("./dto/actualizar-producto.dto");
const crear_producto_dto_1 = require("./dto/crear-producto.dto");
const productos_service_1 = require("./productos.service");
let ProductosController = class ProductosController {
    productosService;
    constructor(productosService) {
        this.productosService = productosService;
    }
    obtenerInventario(req) {
        const idSucursal = req.user.rol === 'administrador'
            ? undefined
            : req.user.id_sucursal;
        return this.productosService.obtenerInventario(idSucursal);
    }
    buscarPorNombre(nombre) {
        if (!nombre?.trim())
            throw new common_1.BadRequestException('El parámetro nombre es requerido');
        return this.productosService.buscarPorNombre(nombre.trim());
    }
    obtenerTodos() {
        return this.productosService.obtenerTodos();
    }
    obtenerPorId(id) {
        return this.productosService.obtenerPorId(id);
    }
    crear(dto, req) {
        return this.productosService.crear(dto, req.user.id_sucursal);
    }
    actualizar(id, dto) {
        return this.productosService.actualizar(id, dto);
    }
    eliminar(id) {
        return this.productosService.eliminar(id);
    }
};
exports.ProductosController = ProductosController;
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Obtener inventario consolidado con stock total por producto vigente (filtrado por sucursal del JWT; administrador ve todas)' }),
    (0, common_1.Get)('inventario'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "obtenerInventario", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Buscar productos por nombre (búsqueda parcial, insensible a mayúsculas)' }),
    (0, swagger_1.ApiQuery)({ name: 'nombre', required: true, type: String }),
    (0, common_1.Get)('buscar'),
    __param(0, (0, common_1.Query)('nombre')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "buscarPorNombre", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Listar todos los productos del catálogo' }),
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "obtenerTodos", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Obtener un producto por ID' }),
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "obtenerPorId", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Crear producto — solo administrador' }),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __param(1, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [crear_producto_dto_1.CrearProductoDto, Object]),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "crear", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Actualizar datos de un producto — solo administrador' }),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Patch)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number, actualizar_producto_dto_1.ActualizarProductoDto]),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "actualizar", null);
__decorate([
    (0, swagger_1.ApiOperation)({ summary: 'Eliminar un producto — solo administrador' }),
    (0, common_1.UseGuards)(roles_guard_1.RolesGuard),
    (0, roles_decorator_1.Roles)('administrador'),
    (0, common_1.Delete)(':id'),
    __param(0, (0, common_1.Param)('id', common_1.ParseIntPipe)),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Number]),
    __metadata("design:returntype", void 0)
], ProductosController.prototype, "eliminar", null);
exports.ProductosController = ProductosController = __decorate([
    (0, swagger_1.ApiTags)('Productos'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('productos'),
    __metadata("design:paramtypes", [productos_service_1.ProductosService])
], ProductosController);
//# sourceMappingURL=productos.controller.js.map