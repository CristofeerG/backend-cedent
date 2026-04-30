import { PrismaService } from '../prisma/prisma.service';
import { ResultadoEntrenamientoDto, ResultadoPrediccionDto } from './dto/resultado-entrenamiento.dto';
export declare class AnaliticaService {
    private readonly prisma;
    private readonly logger;
    constructor(prisma: PrismaService);
    private obtenerEgresosPorSucursal;
    private agruparConsumosPorFecha;
    private crearYEntrenarLSTM;
    private obtenerStockActual;
    prepararYEntrenar(idSucursal: number): Promise<ResultadoEntrenamientoDto>;
    predecirDemanda(idSucursal: number): Promise<ResultadoPrediccionDto>;
}
