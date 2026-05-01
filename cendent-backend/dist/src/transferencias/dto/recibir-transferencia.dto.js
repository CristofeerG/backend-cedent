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
exports.RecibirTransferenciaDto = void 0;
const swagger_1 = require("@nestjs/swagger");
const class_validator_1 = require("class-validator");
class RecibirTransferenciaDto {
    codigo_trz;
}
exports.RecibirTransferenciaDto = RecibirTransferenciaDto;
__decorate([
    (0, swagger_1.ApiProperty)({
        description: 'Código de trazabilidad generado al enviar la transferencia',
        example: 'TRZ-20260429-FUB7D',
    }),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(/^TRZ-\d{8}-[A-Z0-9]+$/, {
        message: 'codigo_trz debe tener el formato TRZ-YYYYMMDD-XXXXX',
    }),
    __metadata("design:type", String)
], RecibirTransferenciaDto.prototype, "codigo_trz", void 0);
//# sourceMappingURL=recibir-transferencia.dto.js.map