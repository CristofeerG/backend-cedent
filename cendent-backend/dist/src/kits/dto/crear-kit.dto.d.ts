export declare class DetalleKitDto {
    id_producto?: number | null;
    cantidad_estandar: number;
    es_variable?: boolean;
}
export declare class CrearKitDto {
    nombre_procedimiento: string;
    detalle: DetalleKitDto[];
}
