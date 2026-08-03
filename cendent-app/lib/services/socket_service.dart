// =============================================================================
//  lib/services/socket_service.dart
//  Singleton que mantiene la conexión Socket.IO con el backend NestJS.
//
//  Eventos escuchados:
//    alerta_caducidad — lotes próximos a vencer (notificaciones.gateway.ts)
//    alerta_stock     — productos bajo stock mínimo (notificaciones.gateway.ts)
// =============================================================================

import 'dart:async';
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

class SocketService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  sio.Socket? _socket;
  final _controller = StreamController<Notificacion>.broadcast();

  Stream<Notificacion> get stream => _controller.stream;

  // ── Conexión ───────────────────────────────────────────────────────────────
  void conectar(String token, {void Function()? onConnected}) {
    desconectar(); // cierra conexión previa si la hay
    _socket = sio.io(
      'http://localhost:3000',
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(3000)
          .build(),
    );
    _socket!.connect();
    if (onConnected != null) {
      _socket!.onConnect((_) => onConnected());
    }
    _socket!.on('alerta_caducidad', _onCaducidad);
    _socket!.on('alerta_stock', _onStock);
  }

  // ── Handlers ───────────────────────────────────────────────────────────────
  void _onCaducidad(dynamic data) {
    final lotes = _asList(data is Map ? data['lotes'] : null);
    for (final lote in lotes) {
      final prod = (lote['nombre_producto'] as String?) ?? '?';
      final dias = lote['dias_restantes'];
      _emit(Notificacion(
        titulo: 'Próximo a vencer',
        mensaje: '$prod — $dias días restantes',
        fecha: DateTime.now(),
        tipo: 'vencimiento',
      ));
    }
  }

  void _onStock(dynamic data) {
    final productos = _asList(data is Map ? data['productos'] : null);
    for (final p in productos) {
      final prod = (p['nombre_producto'] as String?) ?? '?';
      final total = p['stock_total'];
      final min = p['stock_min'];
      _emit(Notificacion(
        titulo: 'Stock bajo mínimo',
        mensaje: '$prod — $total/$min unidades',
        fecha: DateTime.now(),
        tipo: 'stock',
      ));
    }
  }

  void _emit(Notificacion n) {
    if (!_controller.isClosed) _controller.add(n);
  }

  List _asList(dynamic v) => v is List ? v : [];

  // ── Desconexión ────────────────────────────────────────────────────────────
  void desconectar() {
    _socket?.off('alerta_caducidad');
    _socket?.off('alerta_stock');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
