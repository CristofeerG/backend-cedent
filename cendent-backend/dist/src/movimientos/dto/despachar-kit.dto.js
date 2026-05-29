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
exports.DespacharKitDto = exports.SustitucionDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class SustitucionDto {
    id_detalle;
    id_producto;
}
exports.SustitucionDto = SustitucionDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'id_detalle del ítem variable dentro del kit', example: 3 }),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], SustitucionDto.prototype, "id_detalle", void 0);
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del producto concreto elegido por el odontólogo', example: 12 }),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], SustitucionDto.prototype, "id_producto", void 0);
class DespacharKitDto {
    id_kit;
    sustituciones;
}
exports.DespacharKitDto = DespacharKitDto;
__decorate([
    (0, swagger_1.ApiProperty)({ description: 'ID del kit a despachar', example: 1 }),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], DespacharKitDto.prototype, "id_kit", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({
        description: 'Producto elegido para cada ítem variable del kit',
        type: [SustitucionDto],
    }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => SustitucionDto),
    __metadata("design:type", Array)
], DespacharKitDto.prototype, "sustituciones", void 0);
//# sourceMappingURL=despachar-kit.dto.js.map