import { NotificacionesService } from './notificaciones.service';
export declare class NotificacionesController {
    private readonly notificacionesService;
    constructor(notificacionesService: NotificacionesService);
    revisarAhora(req: {
        user?: {
            id_sucursal?: number | null;
        };
    }): Promise<{
        id_sucursal: number;
        alertasCaducidad: import("./notificaciones.gateway").AlertaCaducidadPayload[];
        alertasStock: import("./notificaciones.gateway").AlertaStockPayload[];
    }>;
}
