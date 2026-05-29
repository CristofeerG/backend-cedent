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
exports.CrearKitDto = exports.DetalleKitDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class DetalleKitDto {
    id_producto;
    cantidad_estandar;
    es_variable;
}
exports.DetalleKitDto = DetalleKitDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'ID del producto. Puede ser null solo cuando es_variable es true',
        nullable: true,
        example: 5,
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Object)
], DetalleKitDto.prototype, "id_producto", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ example: 1 }),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], DetalleKitDto.prototype, "cantidad_estandar", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'true = el odontólogo elige el producto concreto en el despacho',
        default: false,
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], DetalleKitDto.prototype, "es_variable", void 0);
class CrearKitDto {
    nombre_procedimiento;
    detalle;
}
exports.CrearKitDto = CrearKitDto;
__decorate([
    (0, swagger_1.ApiProperty)({ example: 'Restauración (mediana y pequeña)' }),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], CrearKitDto.prototype, "nombre_procedimiento", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ type: [DetalleKitDto] }),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => DetalleKitDto),
    __metadata("design:type", Array)
], CrearKitDto.prototype, "detalle", void 0);
//# sourceMappingURL=crear-kit.dto.js.map