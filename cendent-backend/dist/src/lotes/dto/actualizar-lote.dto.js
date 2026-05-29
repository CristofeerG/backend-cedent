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
exports.ActualizarLoteDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
class ActualizarLoteDto {
    stock_actual;
    costo_unit;
    fecha_venc;
}
exports.ActualizarLoteDto = ActualizarLoteDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Stock actual del lote', example: 50 }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], ActualizarLoteDto.prototype, "stock_actual", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Costo unitario; enviar null para limpiar', example: 12.5, nullable: true }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Object)
], ActualizarLoteDto.prototype, "costo_unit", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ description: 'Fecha de vencimiento en formato ISO', example: '2027-06-30' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], ActualizarLoteDto.prototype, "fecha_venc", void 0);
//# sourceMappingURL=actualizar-lote.dto.js.map