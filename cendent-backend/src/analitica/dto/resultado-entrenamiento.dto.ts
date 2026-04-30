export class PrediccionProductoDto {
  id_producto: number;
  nombre_producto: string;
  puntos_historicos: number;
  prediccion_siguiente: number;
  error_entrenamiento: number;
}

export class ResultadoEntrenamientoDto {
  id_sucursal: number;
  total_productos_entrenados: number;
  iteraciones: number;
  predicciones: PrediccionProductoDto[];
}

export class DemandaProductoDto {
  id_producto: number;
  nombre_mat: string;
  stock_total: number;
  consumo_predicho_30_dias: number;
  dias_para_quiebre: number;
  sugerencia_compra: number;
}

export class ResultadoPrediccionDto {
  id_sucursal: number;
  total_productos_analizados: number;
  predicciones: DemandaProductoDto[];
}
