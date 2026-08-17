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
var NotificacionesGateway_1;
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotificacionesGateway = void 0;
const common_1 = require("@nestjs/common");
const jwt_1 = require("@nestjs/jwt");
const websockets_1 = require("@nestjs/websockets");
const socket_io_1 = require("socket.io");
function salaSucursal(idSucursal) {
    return `sucursal:${idSucursal}`;
}
let NotificacionesGateway = NotificacionesGateway_1 = class NotificacionesGateway {
    jwtService;
    logger = new common_1.Logger(NotificacionesGateway_1.name);
    servidor;
    constructor(jwtService) {
        this.jwtService = jwtService;
    }
    handleConnection(cliente) {
        const token = this.extraerToken(cliente);
        if (!token) {
            this.logger.warn(`Socket ${cliente.id} sin token: conexión rechazada.`);
            cliente.disconnect(true);
            return;
        }
        let payload;
        try {
            payload = this.jwtService.verify(token);
        }
        catch {
            this.logger.warn(`Socket ${cliente.id} con token inválido: conexión rechazada.`);
            cliente.disconnect(true);
            return;
        }
        if (payload.id_sucursal == null) {
            this.logger.warn(`Socket ${cliente.id} de usuario sin sucursal: conexión rechazada.`);
            cliente.disconnect(true);
            return;
        }
        cliente.join(salaSucursal(payload.id_sucursal));
        this.logger.log(`Socket ${cliente.id} (usuario ${payload.sub}) unido a ${salaSucursal(payload.id_sucursal)}.`);
    }
    extraerToken(cliente) {
        const auth = cliente.handshake.auth;
        const desdeAuth = typeof auth?.token === 'string' ? auth.token : null;
        const cabecera = cliente.handshake.headers?.authorization;
        const desdeCabecera = typeof cabecera === 'string' ? cabecera : null;
        const query = cliente.handshake.query?.token;
        const desdeQuery = typeof query === 'string' ? query : null;
        const bruto = desdeAuth ?? desdeCabecera ?? desdeQuery;
        if (!bruto)
            return null;
        return bruto.startsWith('Bearer ') ? bruto.slice('Bearer '.length) : bruto;
    }
    emitirAlertaCaducidad(idSucursal, lotes) {
        this.servidor.to(salaSucursal(idSucursal)).emit('alerta_caducidad', {
            id_sucursal: idSucursal,
            total: lotes.length,
            lotes,
        });
    }
    emitirAlertaStock(idSucursal, productos) {
        this.servidor.to(salaSucursal(idSucursal)).emit('alerta_stock', {
            id_sucursal: idSucursal,
            total: productos.length,
            productos,
        });
    }
};
exports.NotificacionesGateway = NotificacionesGateway;
__decorate([
    (0, websockets_1.WebSocketServer)(),
    __metadata("design:type", socket_io_1.Server)
], NotificacionesGateway.prototype, "servidor", void 0);
exports.NotificacionesGateway = NotificacionesGateway = NotificacionesGateway_1 = __decorate([
    (0, websockets_1.WebSocketGateway)({ cors: { origin: '*' } }),
    __metadata("design:paramtypes", [jwt_1.JwtService])
], NotificacionesGateway);
//# sourceMappingURL=notificaciones.gateway.js.map