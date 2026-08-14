"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ResultadoPrediccionDto = exports.DemandaProductoDto = exports.ResultadoEntrenamientoDto = exports.PrediccionProductoDto = void 0;
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
    prediccion_semanal;
}
exports.DemandaProductoDto = DemandaProductoDto;
class ResultadoPrediccionDto {
    id_sucursal;
    total_productos_analizados;
    predicciones;
}
exports.ResultadoPrediccionDto = ResultadoPrediccionDto;
//# sourceMappingURL=resultado-entrenamiento.dto.js.map