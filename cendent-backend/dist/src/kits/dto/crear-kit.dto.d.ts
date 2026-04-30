export declare class DetalleKitDto {
    id_producto: number;
    cantidad_estandar: number;
}
export declare class CrearKitDto {
    nombre_procedimiento: string;
    detalle: DetalleKitDto[];
}
