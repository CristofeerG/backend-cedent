import { NotificacionesService } from './notificaciones.service';
export declare class NotificacionesController {
    private readonly notificacionesService;
    constructor(notificacionesService: NotificacionesService);
    revisarAhora(): Promise<{
        alertasCaducidad: import("./notificaciones.gateway").AlertaCaducidadPayload[];
        alertasStock: import("./notificaciones.gateway").AlertaStockPayload[];
    }>;
}
