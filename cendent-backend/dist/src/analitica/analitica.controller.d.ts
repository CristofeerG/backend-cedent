import { AnaliticaService } from './analitica.service';
export declare class AnaliticaController {
    private readonly analiticaService;
    constructor(analiticaService: AnaliticaService);
    entrenar(idSucursal: number): Promise<import("./dto/resultado-entrenamiento.dto").ResultadoEntrenamientoDto>;
    prediccion(idSucursal: number): Promise<(import("./dto/resultado-entrenamiento.dto").ResultadoPrediccionDto & {
        generado_en?: Date;
    }) | null>;
    consumoReal(idSucursal: number): Promise<import("./dto/resultado-entrenamiento.dto").ConsumoRealDto>;
    refrescar(idSucursal: number): Promise<import("./dto/resultado-entrenamiento.dto").ResultadoPrediccionDto & {
        generado_en: Date;
    }>;
}
