export declare class ItemProductoTransferenciaDto {
    nombre_producto: string;
    cantidad: number;
}
export declare class EnviarTransferenciaDto {
    nombre_sucursal_destino: string;
    productos: ItemProductoTransferenciaDto[];
}
