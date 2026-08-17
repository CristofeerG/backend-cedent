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
exports.ConsumoRealDto = exports.ResultadoPrediccionDto = exports.DemandaProductoDto = exports.ResultadoEntrenamientoDto = exports.PrediccionProductoDto = void 0;
const swagger_1 = require("@nestjs/swagger");
class PrediccionProductoDto {
    id_producto;
    nombre_producto;
    puntos_historicos;
    prediccion_siguiente;
    error_entrenamiento;
}
exports.PrediccionProductoDto = PrediccionProductoDto;
class ResultadoEntrenamientoDto {
    id_sucursal;
    total_productos_entrenados;
    iteraciones;
    predicciones;
}
exports.ResultadoEntrenamientoDto = ResultadoEntrenamientoDto;
class DemandaProductoDto {
    id_producto;
    nombre_mat;
    stock_total;
    consumo_predicho_30_dias;
    dias_para_quiebre;
    sugerencia_compra;
    error_entrenamiento;
    prediccion_semanal;
}
exports.DemandaProductoDto = DemandaProductoDto;
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 0.0087,
        description: 'Pérdida final de entrenamiento del LSTM para este producto (MSE sobre ' +
            'la serie normalizada y suavizada). Más bajo = mejor ajuste del modelo ' +
            'a su historial de consumo.',
    }),
    __metadata("design:type", Number)
], DemandaProductoDto.prototype, "error_entrenamiento", void 0);
class ResultadoPrediccionDto {
    id_sucursal;
    total_productos_analizados;
    error_entrenamiento_promedio;
    predicciones;
}
exports.ResultadoPrediccionDto = ResultadoPrediccionDto;
__decorate([
    (0, swagger_1.ApiProperty)({
        example: 0.0142,
        description: 'Promedio de la pérdida final de entrenamiento del LSTM (MSE) sobre ' +
            'todos los productos analizados de la sucursal. Más bajo = mejor ' +
            'ajuste global del modelo. Vale 0 cuando no se entrenó ningún producto.',
    }),
    __metadata("design:type", Number)
], ResultadoPrediccionDto.prototype, "error_entrenamiento_promedio", void 0);
class ConsumoRealDto {
    id_sucursal;
    dias_ventana;
    semanas;
    total;
    productos_activos;
}
exports.ConsumoRealDto = ConsumoRealDto;
//# sourceMappingURL=resultado-entrenamiento.dto.js.map