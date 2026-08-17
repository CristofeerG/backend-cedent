import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  OnGatewayConnection,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';

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

/** Nombre de la sala de Socket.IO que agrupa a los clientes de una sucursal. */
function salaSucursal(idSucursal: number): string {
  return `sucursal:${idSucursal}`;
}

@WebSocketGateway({ cors: { origin: '*' } })
export class NotificacionesGateway implements OnGatewayConnection {
  private readonly logger = new Logger(NotificacionesGateway.name);

  @WebSocketServer()
  servidor: Server;

  constructor(private readonly jwtService: JwtService) {}

  /**
   * Autentica el socket y lo mete en la sala de su sucursal.
   *
   * El id_sucursal sale del JWT y nunca de lo que declare el cliente: si el
   * cliente pudiera elegir su sala, el aislamiento entre sucursales sería
   * decorativo — bastaría con pedir la ajena. Un socket sin token válido se
   * desconecta, porque antes cualquiera que alcanzara el puerto recibía las
   * alertas de inventario de todas las sucursales sin siquiera iniciar sesión.
   */
  handleConnection(cliente: Socket) {
    const token = this.extraerToken(cliente);
    if (!token) {
      this.logger.warn(`Socket ${cliente.id} sin token: conexión rechazada.`);
      cliente.disconnect(true);
      return;
    }

    let payload: JwtPayload;
    try {
      payload = this.jwtService.verify<JwtPayload>(token);
    } catch {
      this.logger.warn(`Socket ${cliente.id} con token inválido: conexión rechazada.`);
      cliente.disconnect(true);
      return;
    }

    if (payload.id_sucursal == null) {
      this.logger.warn(`Socket ${cliente.id} de usuario sin sucursal: conexión rechazada.`);
      cliente.disconnect(true);
      return;
    }

    // Sin sala global: un administrador recibe sólo su propia sucursal, igual
    // que el resto de módulos (analítica, inventario, movimientos).
    cliente.join(salaSucursal(payload.id_sucursal));
    this.logger.log(
      `Socket ${cliente.id} (usuario ${payload.sub}) unido a ${salaSucursal(payload.id_sucursal)}.`,
    );
  }

  /**
   * El token puede llegar por `auth`, por cabecera o por query.
   * Socket.IO no unifica esto entre plataformas y el cliente Flutter usa
   * cabeceras, así que se aceptan las tres formas para no depender del
   * transporte que negocie cada cliente.
   */
  private extraerToken(cliente: Socket): string | null {
    const auth = cliente.handshake.auth as Record<string, unknown> | undefined;
    const desdeAuth = typeof auth?.token === 'string' ? auth.token : null;

    const cabecera = cliente.handshake.headers?.authorization;
    const desdeCabecera = typeof cabecera === 'string' ? cabecera : null;

    const query = cliente.handshake.query?.token;
    const desdeQuery = typeof query === 'string' ? query : null;

    const bruto = desdeAuth ?? desdeCabecera ?? desdeQuery;
    if (!bruto) return null;

    return bruto.startsWith('Bearer ') ? bruto.slice('Bearer '.length) : bruto;
  }

  emitirAlertaCaducidad(idSucursal: number, lotes: AlertaCaducidadPayload[]) {
    this.servidor.to(salaSucursal(idSucursal)).emit('alerta_caducidad', {
      id_sucursal: idSucursal,
      total: lotes.length,
      lotes,
    });
  }

  emitirAlertaStock(idSucursal: number, productos: AlertaStockPayload[]) {
    this.servidor.to(salaSucursal(idSucursal)).emit('alerta_stock', {
      id_sucursal: idSucursal,
      total: productos.length,
      productos,
    });
  }
}
