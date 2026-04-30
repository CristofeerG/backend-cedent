export declare class ItemLoteDto {
    id_lote: number;
    cantidad: number;
}
export declare class EnviarTransferenciaDto {
    id_sucursal_origen: number;
    id_sucursal_destino: number;
    id_usuario_envia: number;
    lotes: ItemLoteDto[];
}
