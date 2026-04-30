import { Server } from 'socket.io';
export interface AlertaCaducidadPayload {
    id_lote: number;
    codigo_lote: string | null;
    nombre_producto: string;
    nombre_sucursal: string;
    stock_actual: number;
    fecha_venc: Date;
    dias_restantes: number;
}
export interface AlertaStockPayload {
    id_producto: number;
    nombre_producto: string;
    stock_total: number;
    stock_min: number;
}
export declare class NotificacionesGateway {
    servidor: Server;
    emitirAlertaCaducidad(lotes: AlertaCaducidadPayload[]): void;
    emitirAlertaStock(productos: AlertaStockPayload[]): void;
}
