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

/**
 * Consumo real agregado de las últimas 4 semanas.
 *
 * Existe para que el gráfico del dashboard compare peras con peras: las barras
 * de consumo real y las de proyección LSTM deben cubrir la misma ventana
 * temporal, el mismo conjunto de tipos de movimiento y el mismo universo de
 * productos. Calcularlo en el cliente a partir de GET /movimientos no lo
 * garantizaba: ese endpoint corta en los últimos 200 registros (~21 días), lo
 * que dejaba la semana más antigua casi vacía y subvaluaba el total.
 */
export class ConsumoRealDto {
  id_sucursal: number;
  /** Tamaño de la ventana analizada (28 días = 4 semanas). */
  dias_ventana: number;
  /**
   * Consumo por semana, de la más antigua a la más reciente.
   * Índices: [0] S-3, [1] S-2, [2] S-1, [3] semana actual.
   */
  semanas: number[];
  /** Suma de `semanas`. */
  total: number;
  /**
   * id_producto con al menos un egreso en la ventana. El dashboard filtra la
   * proyección a este conjunto para que ambos lados del gráfico cubran los
   * mismos productos.
   */
  productos_activos: number[];
}
