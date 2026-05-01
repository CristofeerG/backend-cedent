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
Object.defineProperty(exports, "__esModule", { value: true });
exports.EnviarTransferenciaDto = exports.ItemProductoTransferenciaDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class ItemProductoTransferenciaDto {
    nombre_producto;
    cantidad;
}
exports.ItemProductoTransferenciaDto = ItemProductoTransferenciaDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Nombre (parcial) del producto a transferir', example: 'Alginato' }),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], ItemProductoTransferenciaDto.prototype, "nombre_producto", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Cantidad total a transferir', example: 10 }),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(1),
    __metadata("design:type", Number)
], ItemProductoTransferenciaDto.prototype, "cantidad", void 0);
class EnviarTransferenciaDto {
    nombre_sucursal_destino;
    productos;
}
exports.EnviarTransferenciaDto = EnviarTransferenciaDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Nombre (parcial) de la sucursal destino', example: 'Norte' }),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], EnviarTransferenciaDto.prototype, "nombre_sucursal_destino", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ type: [ItemProductoTransferenciaDto] }),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => ItemProductoTransferenciaDto),
    __metadata("design:type", Array)
], EnviarTransferenciaDto.prototype, "productos", void 0);
//# sourceMappingURL=enviar-transferencia.dto.js.map