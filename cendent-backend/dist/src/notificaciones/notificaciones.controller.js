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
exports.NotificacionesController = void 0;
const common_1 = require("@nestjs/common");
const swagger_1 = require("@nestjs/swagger");
const jwt_auth_guard_1 = require("../auth/jwt-auth.guard");
const notificaciones_service_1 = require("./notificaciones.service");
let NotificacionesController = class NotificacionesController {
    notificacionesService;
    constructor(notificacionesService) {
        this.notificacionesService = notificacionesService;
    }
    revisarAhora(req) {
        const idSucursal = req.user?.id_sucursal;
        if (idSucursal == null) {
            throw new common_1.BadRequestException('El usuario no tiene una sucursal asignada.');
        }
        return this.notificacionesService.revisarSucursal(idSucursal);
    }
};
exports.NotificacionesController = NotificacionesController;
__decorate([
    (0, swagger_1.ApiOperation)({
        summary: 'Forzar revisión inmediata de caducidades y stock mínimo de la propia sucursal',
        description: 'La sucursal se toma del token, no del cliente. Antes este endpoint ' +
            'revisaba todo el inventario y notificaba a todos los usuarios ' +
            'conectados, así que un refresco desde una sucursal alertaba a las demás.',
    }),
    (0, common_1.Post)('revisar'),
    __param(0, (0, common_1.Req)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object]),
    __metadata("design:returntype", void 0)
], NotificacionesController.prototype, "revisarAhora", null);
exports.NotificacionesController = NotificacionesController = __decorate([
    (0, swagger_1.ApiTags)('Notificaciones'),
    (0, swagger_1.ApiBearerAuth)(),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    (0, common_1.Controller)('notificaciones'),
    __metadata("design:paramtypes", [notificaciones_service_1.NotificacionesService])
], NotificacionesController);
//# sourceMappingURL=notificaciones.controller.js.map