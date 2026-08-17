// Regresión del bug "tras cambiar de sesión no llegan las notificaciones".
//
// `socket_io_client` cachea los Manager en un mapa global por
// 'esquema://host:puerto' que dura lo que el proceso, y `Manager.socket()`
// devuelve el Socket ya existente del namespace ignorando las opciones nuevas.
// Como `auth` sólo se lee en el constructor de Socket, el segundo login se
// conectaba con el token del usuario anterior y acababa en la sala de la
// sucursal equivocada.
//
// La prueba construye dos sockets contra la misma URL con tokens distintos,
// igual que hace SocketService al cerrar y volver a abrir sesión. Sin
// `enableForceNewConnection()` el segundo `io()` devuelve el mismo objeto con
// el token viejo y ambas expectativas fallan.

import 'package:flutter_test/flutter_test.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

sio.Socket crearSocket(String token) {
  return sio.io(
    'http://localhost:3000',
    sio.OptionBuilder()
        .setTransports(['websocket', 'polling'])
        .disableAutoConnect()
        .enableForceNewConnection()
        .setAuth({'token': token})
        .build(),
  );
}

void main() {
  test('cada conexión usa el token actual, no el de la sesión anterior', () {
    final primero = crearSocket('token-sucursal-1');
    final segundo = crearSocket('token-sucursal-3');

    expect(identical(primero, segundo), isFalse,
        reason: 'el segundo login reutilizó el socket cacheado del primero');
    expect(segundo.auth['token'], 'token-sucursal-3',
        reason: 'el socket nuevo arrastró el token del usuario anterior');
    expect(primero.auth['token'], 'token-sucursal-1');

    primero.dispose();
    segundo.dispose();
  });
}
