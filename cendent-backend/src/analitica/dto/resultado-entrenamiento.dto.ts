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
  /**
   * Consumo predicho desglosado en 4 semanas (unidades).
   * Índices: [0] días 1-7, [1] días 8-14, [2] días 15-21, [3] días 22-30.
   * La semana 4 acumula 9 días (los 2 sobrantes del horizonte de 30 d se
   * suman ahí para mantener exactamente 4 columnas en el gráfico).
   */
  prediccion_semanal: number[];
}

export class ResultadoPrediccionDto {
  id_sucursal: number;
  total_productos_analizados: number;
  predicciones: DemandaProductoDto[];
}
