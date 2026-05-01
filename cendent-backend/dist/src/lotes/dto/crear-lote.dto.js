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
exports.CrearLoteDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class CrearLoteDto {
    id_producto;
    stock_inicial;
    fecha_venc;
    costo_unit;
}
exports.CrearLoteDto = CrearLoteDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del producto al que pertenece el lote', example: 12 }),
    (0, class_validator_1.IsInt)(),
    (0, class_transformer_1.Type)(() => Number),
    __metadata("design:type", Number)
], CrearLoteDto.prototype, "id_producto", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Stock inicial del lote', example: 50 }),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_transformer_1.Type)(() => Number),
    __metadata("design:type", Number)
], CrearLoteDto.prototype, "stock_inicial", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'Fecha de vencimiento (ISO 8601)', example: '2027-12-31' }),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CrearLoteDto.prototype, "fecha_venc", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Costo unitario', example: 8.75 }),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    __metadata("design:type", Number)
], CrearLoteDto.prototype, "costo_unit", void 0);
//# sourceMappingURL=crear-lote.dto.js.map