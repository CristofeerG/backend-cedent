// =============================================================================
//  lib/services/socket_service.dart
//  Singleton que mantiene la conexión Socket.IO con el backend NestJS.
//
//  Eventos escuchados:
//    alerta_caducidad — lotes próximos a vencer (notificaciones.gateway.ts)
//    alerta_stock     — productos bajo stock mínimo (notificaciones.gateway.ts)
// =============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

// Modelo de notificación (exportado para que los widgets puedan tiparlo)
class Notificacion {
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  // 'vencimiento' | 'stock' | 'transferencia' | 'kit'
  final String tipo;
  const Notificacion({
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    required this.tipo,
  });
}

/// Lote de notificaciones de un mismo tipo.
///
/// Los eventos del gateway (`alerta_stock`, `alerta_caducidad`) son fotografías
/// del estado completo de la sucursal, no avisos incrementales: cada uno trae
/// *todos* los productos bajo mínimo o *todos* los lotes por vencer en ese
/// momento. Por eso el lote viaja entero y quien lo recibe debe reemplazar lo
/// que ya tenga de ese tipo en lugar de acumularlo.
///
/// Antes el servicio emitía una `Notificacion` suelta por producto y la
/// pantalla las iba añadiendo. Bastaba una reconexión —el cliente vuelve a
/// pedir el snapshot al reconectar— para que la lista se duplicara: 202
/// productos bajo mínimo se mostraban como 404. Emitiendo el lote completo la
/// operación es idempotente: recibir dos veces el mismo estado deja el mismo
/// resultado.
///
/// Un lote con `items` vacío es información válida, no ausencia de datos:
/// significa que ya no hay alertas de ese tipo y hay que limpiar las anteriores.
class LoteNotificaciones {
  /// 'stock' | 'vencimiento'
  final String tipo;
  final List<Notificacion> items;
  const LoteNotificaciones({required this.tipo, required this.items});
}

/// Estado de la conexión con el backend, para que la interfaz pueda decir la
/// verdad sobre si está recibiendo alertas o no.
enum EstadoConexion {
  /// Todavía no se ha llamado a [SocketService.conectar].
  inactivo,

  /// Intentando conectar o reconectar. No llegan alertas.
  conectando,

  /// Conectado y recibiendo.
  conectado,
}

class SocketService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  sio.Socket? _socket;
  final _controller = StreamController<LoteNotificaciones>.broadcast();

  Stream<LoteNotificaciones> get stream => _controller.stream;

  /// Estado observable de la conexión.
  ///
  /// La píldora del encabezado mostraba "En línea" como texto fijo: daba igual
  /// que el socket estuviera muerto, siempre se veía verde. Con la conexión
  /// caída y las tarjetas del dashboard funcionando (van por HTTP, que abre una
  /// conexión nueva en cada petición) no había forma de distinguir "no hay
  /// alertas" de "no me estoy enterando de las alertas".
  final ValueNotifier<EstadoConexion> estado =
      ValueNotifier(EstadoConexion.inactivo);

  /// id_sucursal del usuario conectado, usado para descartar cualquier alerta
  /// ajena que llegara por error. El aislamiento real lo hace el backend con
  /// salas por sucursal; esto es sólo una segunda barrera.
  int? _idSucursal;

  /// Se invoca en cada (re)conexión, no sólo en la primera: el backend sólo
  /// emite alertas cuando se le pide o a medianoche, así que tras recuperar la
  /// conexión hay que volver a pedir el estado o la lista se queda congelada.
  void Function()? _onConnected;

  bool get conectado => _socket?.connected ?? false;

  // ── Conexión ───────────────────────────────────────────────────────────────
  void conectar(String token, {int? idSucursal, void Function()? onConnected}) {
    desconectar(); // cierra conexión previa si la hay
    _idSucursal = idSucursal;
    _onConnected = onConnected;
    estado.value = EstadoConexion.conectando;
    _socket = sio.io(
      'http://localhost:3000',
      sio.OptionBuilder()
          // websocket primero y polling como respaldo. Con la lista limitada a
          // ['websocket'] no había plan B: si el upgrade fallaba (un proxy, una
          // extensión, una red que filtra WS) el cliente se quedaba sin
          // notificaciones para toda la sesión y sin decir nada.
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          // Obligatorio: sin esto el socket se queda con el token del usuario
          // anterior tras un cambio de sesión.
          //
          // `socket_io_client` guarda los Manager en un mapa global cacheado por
          // 'esquema://host:puerto' que vive lo que dure el proceso, y
          // `Manager.socket()` devuelve el Socket ya existente del namespace
          // *ignorando las opciones nuevas*. Como `auth` sólo se lee en el
          // constructor de Socket, al reconectar tras cerrar sesión se seguía
          // mandando el token del usuario anterior: el gateway lo validaba
          // (es un JWT legítimo) y metía al cliente en la sala de la sucursal
          // equivocada, así que las alertas de la sucursal nueva nunca
          // llegaban. Recargar con F5 lo arreglaba porque rehacía ese mapa.
          //
          // Con esta bandera `_lookup` construye Manager y Socket nuevos en
          // cada conexión. Tampoco acumula: el Manager creado por esta vía no
          // se inserta en el mapa global.
          .enableForceNewConnection()
          // El token va por `auth` y por cabecera: con transporte websocket
          // puro las cabeceras extra no siempre sobreviven al handshake, y el
          // gateway rechaza la conexión si no encuentra el token.
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableReconnection()
          // Reintentar indefinidamente. Antes eran 10 intentos cada 3 s: a los
          // 30 s el cliente se rendía para siempre, así que cualquier reinicio
          // del backend que tardara más de medio minuto dejaba la pestaña sin
          // alertas hasta recargar la página.
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .build(),
    );

    // Los handlers se registran antes de `connect()` para no depender de que la
    // conexión tarde más que el resto de este método.
    _socket!.onConnect((_) {
      estado.value = EstadoConexion.conectado;
      _log('conectado');
      _onConnected?.call();
    });
    _socket!.onDisconnect((motivo) {
      estado.value = EstadoConexion.conectando;
      _log('desconectado ($motivo)');
    });
    // Sin estos tres, un handshake rechazado (token vencido, gateway caído) era
    // completamente silencioso: ni error en consola ni cambio en la interfaz.
    _socket!.onConnectError((e) => _log('error de conexión: $e'));
    _socket!.onError((e) => _log('error: $e'));
    _socket!.onReconnectAttempt((n) => _log('reintentando conexión ($n)'));

    _socket!.on('alerta_caducidad', _onCaducidad);
    _socket!.on('alerta_stock', _onStock);

    _socket!.connect();
  }

  /// Reconecta si la conexión se perdió. La llama la pantalla al recuperar el
  /// foco: si el equipo estuvo suspendido, el socket puede estar muerto sin que
  /// el temporizador de reconexión haya llegado a dispararse.
  void reconectarSiHaceFalta() {
    final s = _socket;
    if (s == null || s.connected) return;
    _log('reconexión forzada al recuperar el foco');
    s.connect();
  }

  void _log(String mensaje) => debugPrint('[socket] $mensaje');

  // ── Handlers ───────────────────────────────────────────────────────────────

  /// Descarta payloads de otra sucursal. El backend ya emite sólo a la sala
  /// correspondiente, así que esto no debería filtrar nada; está para que un
  /// fallo del lado servidor no vuelva a mezclar las notificaciones.
  bool _esDeOtraSucursal(dynamic data) {
    if (_idSucursal == null || data is! Map) return false;
    final id = data['id_sucursal'];
    return id is num && id.toInt() != _idSucursal;
  }

  void _onCaducidad(dynamic data) {
    if (_esDeOtraSucursal(data)) return;
    final ahora = DateTime.now();
    final lotes = _asList(data is Map ? data['lotes'] : null);
    _emit(LoteNotificaciones(
      tipo: 'vencimiento',
      items: lotes.map((lote) {
        final prod = (lote['nombre_producto'] as String?) ?? '?';
        final dias = lote['dias_restantes'];
        return Notificacion(
          titulo: 'Próximo a vencer',
          mensaje: '$prod — $dias días restantes',
          fecha: ahora,
          tipo: 'vencimiento',
        );
      }).toList(),
    ));
  }

  void _onStock(dynamic data) {
    if (_esDeOtraSucursal(data)) return;
    final ahora = DateTime.now();
    final productos = _asList(data is Map ? data['productos'] : null);
    _emit(LoteNotificaciones(
      tipo: 'stock',
      items: productos.map((p) {
        final prod = (p['nombre_producto'] as String?) ?? '?';
        final total = p['stock_total'];
        final min = p['stock_min'];
        return Notificacion(
          titulo: 'Stock bajo mínimo',
          mensaje: '$prod — $total/$min unidades',
          fecha: ahora,
          tipo: 'stock',
        );
      }).toList(),
    ));
  }

  void _emit(LoteNotificaciones lote) {
    if (!_controller.isClosed) _controller.add(lote);
  }

  List _asList(dynamic v) => v is List ? v : [];

  // ── Desconexión ────────────────────────────────────────────────────────────
  void desconectar() {
    _idSucursal = null;
    _onConnected = null;
    _socket?.off('alerta_caducidad');
    _socket?.off('alerta_stock');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    estado.value = EstadoConexion.inactivo;
  }
}
