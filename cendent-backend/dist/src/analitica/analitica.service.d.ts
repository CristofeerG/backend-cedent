import { PrismaService } from '../prisma/prisma.service';
import { ConsumoRealDto, ResultadoEntrenamientoDto, ResultadoPrediccionDto } from './dto/resultado-entrenamiento.dto';
export declare class AnaliticaService {
    private readonly prisma;
    private readonly logger;
    constructor(prisma: PrismaService);
    private obtenerEgresosPorSucursal;
    private agruparConsumosPorFecha;
    private suavizarSerie;
    private crearYEntrenarLSTM;
    private cederEventLoop;
    private obtenerStockActual;
    obtenerConsumoReal(idSucursal: number): Promise<ConsumoRealDto>;
    prepararYEntrenar(idSucursal: number): Promise<ResultadoEntrenamientoDto>;
    private generarPrediccion;
    generarYGuardar(idSucursal: number): Promise<ResultadoPrediccionDto & {
        generado_en: Date;
    }>;
    predecirDemanda(idSucursal: number): Promise<(ResultadoPrediccionDto & {
        generado_en?: Date;
    }) | null>;
}
