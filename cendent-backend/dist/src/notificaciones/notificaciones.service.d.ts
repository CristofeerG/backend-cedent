import { PrismaService } from '../prisma/prisma.service';
import { AlertaCaducidadPayload, AlertaStockPayload, NotificacionesGateway } from './notificaciones.gateway';
export declare class NotificacionesService {
    private readonly prisma;
    private readonly gateway;
    private readonly logger;
    constructor(prisma: PrismaService, gateway: NotificacionesGateway);
    revisarInventario(): Promise<{
        id_sucursal: number;
        alertasCaducidad: AlertaCaducidadPayload[];
        alertasStock: AlertaStockPayload[];
    }[]>;
    revisarSucursal(idSucursal: number): Promise<{
        id_sucursal: number;
        alertasCaducidad: AlertaCaducidadPayload[];
        alertasStock: AlertaStockPayload[];
    }>;
    private consultarLotesPorCaducar;
    private consultarProductosBajoStock;
}
