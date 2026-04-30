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
exports.EnviarTransferenciaDto = exports.ItemLoteDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class ItemLoteDto {
    id_lote;
    cantidad;
}
exports.ItemLoteDto = ItemLoteDto;
__decorate([
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], ItemLoteDto.prototype, "id_lote", void 0);
__decorate([
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], ItemLoteDto.prototype, "cantidad", void 0);
class EnviarTransferenciaDto {
    id_sucursal_origen;
    id_sucursal_destino;
    id_usuario_envia;
    lotes;
}
exports.EnviarTransferenciaDto = EnviarTransferenciaDto;
__decorate([
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], EnviarTransferenciaDto.prototype, "id_sucursal_origen", void 0);
__decorate([
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], EnviarTransferenciaDto.prototype, "id_sucursal_destino", void 0);
__decorate([
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.IsPositive)(),
    __metadata("design:type", Number)
], EnviarTransferenciaDto.prototype, "id_usuario_envia", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => ItemLoteDto),
    __metadata("design:type", Array)
], EnviarTransferenciaDto.prototype, "lotes", void 0);
//# sourceMappingURL=enviar-transferencia.dto.js.map