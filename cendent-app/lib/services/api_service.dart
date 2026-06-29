import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  static const String _base = 'http://localhost:3000';
  final _auth = AuthService();

  // Caché compartida entre todas las instancias; TTL de 60 segundos.
  static final _cache = <String, ({dynamic data, DateTime ts})>{};
  static const _cacheTtl = Duration(seconds: 60);

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _get(String path, {Duration timeout = const Duration(seconds: 15)}) async {
    try {
      final res = await http
          .get(Uri.parse('$_base$path'), headers: await _headers())
          .timeout(timeout);
      if (res.statusCode == 401) {
        await _auth.logout();
        return null;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _getCached(String path, {Duration timeout = const Duration(seconds: 15)}) async {
    final cached = _cache[path];
    if (cached != null && DateTime.now().difference(cached.ts) < _cacheTtl) {
      return cached.data;
    }
    final data = await _get(path, timeout: timeout);
    if (data != null) _cache[path] = (data: data, ts: DateTime.now());
    return data;
  }

  void invalidateCache() => _cache.clear();

  Future<({bool ok, String? errorMsg, dynamic data})> _postWithData(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$_base$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        await _auth.logout();
        return (ok: false, errorMsg: 'Sesión expirada', data: null);
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        dynamic responseData;
        try { responseData = jsonDecode(res.body); } catch (_) { responseData = null; }
        return (ok: true, errorMsg: null, data: responseData);
      }
      try {
        final errData = jsonDecode(res.body);
        final msg = errData['message'];
        return (ok: false, errorMsg: msg is String ? msg : 'Error del servidor', data: null);
      } catch (_) {
        return (ok: false, errorMsg: 'Error del servidor (${res.statusCode})', data: null);
      }
    } catch (_) {
      return (ok: false, errorMsg: 'No se pudo conectar con el servidor', data: null);
    }
  }

  Future<({bool ok, String? errorMsg})> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$_base$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        await _auth.logout();
        return (ok: false, errorMsg: 'Sesión expirada');
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (ok: true, errorMsg: null);
      }
      try {
        final data = jsonDecode(res.body);
        final msg = data['message'];
        return (ok: false, errorMsg: msg is String ? msg : 'Error del servidor');
      } catch (_) {
        return (ok: false, errorMsg: 'Error del servidor (${res.statusCode})');
      }
    } catch (_) {
      return (ok: false, errorMsg: 'No se pudo conectar con el servidor');
    }
  }

  Future<({bool ok, String? errorMsg})> _patch(String path, Map<String, dynamic> body) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base$path'),
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        await _auth.logout();
        return (ok: false, errorMsg: 'Sesión expirada');
      }
      if (res.statusCode == 403) {
        return (ok: false, errorMsg: 'No tienes permisos para esta acción');
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (ok: true, errorMsg: null);
      }
      try {
        final data = jsonDecode(res.body);
        final msg = data['message'];
        return (ok: false, errorMsg: msg is String ? msg : 'Error del servidor');
      } catch (_) {
        return (ok: false, errorMsg: 'Error del servidor (${res.statusCode})');
      }
    } catch (_) {
      return (ok: false, errorMsg: 'No se pudo conectar con el servidor');
    }
  }

  // ─── Endpoints ──────────────────────────────────────────────────────────────

  /// GET /productos/inventario?id_sucursal=X
  Future<List<dynamic>?> getInventario(int idSucursal) async {
    final data = await _getCached('/productos/inventario?id_sucursal=$idSucursal');
    return data is List ? data : null;
  }

  /// GET /movimientos?id_sucursal=X[&id_producto=Y]
  /// Si se pasa idProducto devuelve los últimos 10 movimientos de ese producto.
  Future<List<dynamic>?> getMovimientos(int idSucursal, {int? idProducto}) async {
    final path = idProducto != null
        ? '/movimientos?id_sucursal=$idSucursal&id_producto=$idProducto'
        : '/movimientos?id_sucursal=$idSucursal';
    final data = await _getCached(path);
    return data is List ? data : null;
  }

  /// GET /lotes/producto/:idProducto
  Future<List<dynamic>?> getLotesProducto(int idProducto) async {
    final data = await _getCached('/lotes/producto/$idProducto');
    return data is List ? data : null;
  }

  /// GET /transferencias
  Future<List<dynamic>?> getTransferencias() async {
    final data = await _getCached('/transferencias');
    return data is List ? data : null;
  }

  /// POST /transferencias/enviar
  Future<({bool ok, String? errorMsg})> crearTransferencia({
    required String nombreSucursalDestino,
    required List<Map<String, dynamic>> productos,
  }) async {
    return _post('/transferencias/enviar', {
      'nombre_sucursal_destino': nombreSucursalDestino,
      'productos': productos,
    });
  }

  /// PATCH /transferencias/:id/cancelar
  Future<({bool ok, String? errorMsg})> cancelarTransferencia(int idTransferencia) async {
    return _patch('/transferencias/$idTransferencia/cancelar', {});
  }

  /// POST /transferencias/recibir
  Future<({bool ok, String? errorMsg})> recibirTransferencia(String codigoTrz) async {
    return _post('/transferencias/recibir', {'codigo_trz': codigoTrz});
  }

  /// POST /productos — solo administrador; id_sucursal viene del JWT
  Future<({bool ok, String? errorMsg})> crearProducto({
    required String nombre,
    String? categoria,
    String? subcategoria,
    required String unidadMedida,
    int stockMin = 0,
    int? stockInicial,
    String? fechaVenc,
    double? costoUnit,
  }) async {
    return _post('/productos', {
      'nombre_mat': nombre,
      if (categoria != null) 'categoria': categoria,
      if (subcategoria != null) 'subcategoria': subcategoria,
      'unidad_medida': unidadMedida,
      'stock_min': stockMin,
      if (stockInicial != null) 'stock_inicial': stockInicial,
      if (fechaVenc != null) 'fecha_venc': fechaVenc,
      if (costoUnit != null) 'costo_unit': costoUnit,
    });
  }

  /// POST /lotes — id_sucursal viene del JWT, no va en el body
  Future<({bool ok, String? errorMsg})> crearLote({
    required int idProducto,
    required int stockInicial,
    required String fechaVenc,
    double? costoUnit,
  }) async {
    return _post('/lotes', {
      'id_producto': idProducto,
      'stock_inicial': stockInicial,
      'fecha_venc': fechaVenc,
      if (costoUnit != null) 'costo_unit': costoUnit,
    });
  }

  /// PATCH /lotes/:id — solo administrador
  Future<({bool ok, String? errorMsg})> actualizarLote({
    required int idLote,
    required int stockActual,
    required String fechaVenc,
    double? costoUnit,
  }) async {
    return _patch('/lotes/$idLote', {
      'stock_actual': stockActual,
      'fecha_venc': fechaVenc,
      if (costoUnit != null) 'costo_unit': costoUnit,
    });
  }

  /// PATCH /productos/:id — solo administrador
  Future<({bool ok, String? errorMsg})> actualizarProducto({
    required int idProducto,
    required String nombre,
    String? categoria,
    String? subcategoria,
    required String unidadMedida,
    required int stockMin,
  }) async {
    return _patch('/productos/$idProducto', {
      'nombre_mat': nombre,
      if (categoria != null) 'categoria': categoria,
      if (subcategoria != null) 'subcategoria': subcategoria,
      'unidad_medida': unidadMedida,
      'stock_min': stockMin,
    });
  }

  // ─── Kits ─────────────────────────────────────────────────────────────────

  Future<({bool ok, String? errorMsg})> _delete(String path) async {
    try {
      final res = await http
          .delete(Uri.parse('$_base$path'), headers: await _headers())
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 401) {
        await _auth.logout();
        return (ok: false, errorMsg: 'Sesión expirada');
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (ok: true, errorMsg: null);
      }
      try {
        final data = jsonDecode(res.body);
        final msg = data['message'];
        return (ok: false, errorMsg: msg is String ? msg : 'Error del servidor');
      } catch (_) {
        return (ok: false, errorMsg: 'Error del servidor (${res.statusCode})');
      }
    } catch (_) {
      return (ok: false, errorMsg: 'No se pudo conectar con el servidor');
    }
  }

  /// GET /kits
  Future<List<dynamic>?> getKits() async {
    final data = await _getCached('/kits');
    return data is List ? data : null;
  }

  /// POST /kits
  Future<({bool ok, String? errorMsg})> crearKit({
    required String nombreProcedimiento,
    required List<Map<String, dynamic>> detalle,
  }) async {
    return _post('/kits', {
      'nombre_procedimiento': nombreProcedimiento,
      'detalle': detalle,
    });
  }

  /// PATCH /kits/:id
  Future<({bool ok, String? errorMsg})> actualizarKit({
    required int idKit,
    String? nombreProcedimiento,
    List<Map<String, dynamic>>? detalle,
  }) => _patch('/kits/$idKit', {
    if (nombreProcedimiento != null) 'nombre_procedimiento': nombreProcedimiento,
    if (detalle != null) 'detalle': detalle,
  });

  /// DELETE /kits/:id
  Future<({bool ok, String? errorMsg})> eliminarKit(int idKit) async {
    return _delete('/kits/$idKit');
  }

  /// POST /movimientos/despachar-kit — retorna lotes_usados en data
  Future<({bool ok, String? errorMsg, dynamic data})> despacharKit(
    int idKit, {
    List<Map<String, dynamic>> sustituciones = const [],
  }) async {
    return _postWithData('/movimientos/despachar-kit', {
      'id_kit': idKit,
      'sustituciones': sustituciones,
    });
  }

  /// POST /movimientos/consumir — retorna lote_usado en data
  Future<({bool ok, String? errorMsg, dynamic data})> consumirProducto({
    required int idProducto,
    required int cantidad,
  }) async {
    return _postWithData('/movimientos/consumir', {
      'id_producto': idProducto,
      'cantidad': cantidad,
    });
  }

  /// GET /sucursales/buscar?nombre=X — búsqueda parcial, insensible a mayúsculas
  Future<List<dynamic>?> buscarSucursal(String nombre) async {
    final encoded = Uri.encodeComponent(nombre);
    final data = await _get('/sucursales/buscar?nombre=$encoded');
    return data is List ? data : null;
  }

  /// GET /usuarios — solo administrador
  Future<List<dynamic>?> getUsuarios() async {
    final data = await _get('/usuarios');
    return data is List ? data : null;
  }

  /// POST /usuarios — crear nuevo usuario
  Future<({bool ok, String? errorMsg})> crearUsuario({
    required String nomUsuario,
    required String password,
    required String rol,
    int? idSucursal,
  }) async {
    return _post('/usuarios', {
      'nom_usuario': nomUsuario,
      'password': password,
      'rol': rol,
      if (idSucursal != null) 'id_sucursal': idSucursal,
    });
  }

  /// PATCH /usuarios/:id — editar usuario (password opcional)
  Future<({bool ok, String? errorMsg})> editarUsuario(
    int id, {
    String? nomUsuario,
    String? password,
    String? rol,
    int? idSucursal,
  }) async {
    return _patch('/usuarios/$id', {
      if (nomUsuario != null) 'nom_usuario': nomUsuario,
      if (password != null && password.isNotEmpty) 'password': password,
      if (rol != null) 'rol': rol,
      if (idSucursal != null) 'id_sucursal': idSucursal,
    });
  }

  /// DELETE /usuarios/:id — eliminar usuario
  Future<({bool ok, String? errorMsg})> eliminarUsuario(int id) async {
    return _delete('/usuarios/$id');
  }

  /// GET /analitica/prediccion/:idSucursal — sirve desde caché; sin espera larga
  Future<Map<String, dynamic>?> getPrediccion(int idSucursal) async {
    final data = await _get('/analitica/prediccion/$idSucursal');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  /// GET /analitica/entrenar/:idSucursal
  Future<Map<String, dynamic>?> entrenar(int idSucursal) async {
    final data = await _get('/analitica/entrenar/$idSucursal');
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }
}
