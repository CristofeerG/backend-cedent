import { WebSocketGateway, WebSocketServer } from '@nestjs/websockets';
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

@WebSocketGateway({ cors: { origin: '*' } })
export class NotificacionesGateway {
  @WebSocketServer()
  servidor: Server;

  emitirAlertaCaducidad(lotes: AlertaCaducidadPayload[]) {
    this.servidor.emit('alerta_caducidad', {
      total: lotes.length,
      lotes,
    });
  }

  emitirAlertaStock(productos: AlertaStockPayload[]) {
    this.servidor.emit('alerta_stock', {
      total: productos.length,
      productos,
    });
  }
}
