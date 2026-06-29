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
exports.ActualizarKitDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
const crear_kit_dto_1 = require("./crear-kit.dto");
class ActualizarKitDto {
    nombre_procedimiento;
    detalle;
}
exports.ActualizarKitDto = ActualizarKitDto;
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ example: 'Restauración (mediana y pequeña)' }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.IsNotEmpty)(),
    __metadata("design:type", String)
], ActualizarKitDto.prototype, "nombre_procedimiento", void 0);
__decorate([
    (0, swagger_1.ApiPropertyOptional)({ type: [crear_kit_dto_1.DetalleKitDto] }),
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => crear_kit_dto_1.DetalleKitDto),
    __metadata("design:type", Array)
], ActualizarKitDto.prototype, "detalle", void 0);
//# sourceMappingURL=actualizar-kit.dto.js.map