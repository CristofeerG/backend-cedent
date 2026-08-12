// =============================================================================
//  lib/screens/home_screen.dart — Dashboard CENDENT
//  Datos reales desde la API. Paleta azul · Material 3 · responsive.
// =============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../utils/cendent_colors.dart';
import 'inventario_screen.dart';
import 'kits_screen.dart';
import 'login_screen.dart';
import 'movimientos_screen.dart';
import 'analitica_screen.dart';
import 'transferencias_screen.dart';
import 'usuarios_screen.dart';

// ─── Modelos ──────────────────────────────────────────────────────────────────
enum MovType { egresoKit, egresoDirecto, ingreso, transferencia }

class Movement {
  final String date;
  final String product;
  final String sku;
  final MovType type;
  final double qty;
  final String user;
  final String initials;
  const Movement(this.date, this.product, this.sku, this.type, this.qty, this.user, this.initials);
}

class RiskItem {
  final String name;
  final int daysToBreak;
  final String detail;
  final double fill;
  const RiskItem(this.name, this.daysToBreak, this.detail, this.fill);
}

class ForecastBar {
  final String label;
  final int value;
  final double height;
  final bool projected;
  const ForecastBar(this.label, this.value, this.height, this.projected);
}

class _KpiData {
  final int totalProductos;
  final int lotesVencer;
  final int lotesBajoMinimo;
  final int transferenciasPendientes;
  final String ultimoMovNombre;
  final String ultimoMovDetalle;
  const _KpiData({
    required this.totalProductos,
    required this.lotesVencer,
    required this.lotesBajoMinimo,
    required this.transferenciasPendientes,
    required this.ultimoMovNombre,
    required this.ultimoMovDetalle,
  });
}

// ─── Navegación sidebar ───────────────────────────────────────────────────────
class _NavEntry {
  final IconData icon;
  final String label;
  const _NavEntry(this.icon, this.label);
}

const _navOperacion = [
  _NavEntry(Icons.dashboard_outlined, 'Dashboard'),
  _NavEntry(Icons.layers_outlined, 'Inventario / Lotes'),
  _NavEntry(Icons.medical_services_outlined, 'Kits de Procedimientos'),
  _NavEntry(Icons.swap_horiz_rounded, 'Movimientos'),
  _NavEntry(Icons.local_shipping_outlined, 'Transferencias'),
];
const _navInteligencia = [
  _NavEntry(Icons.auto_awesome_outlined, 'Analítica Predictiva'),
];
const _navSistema = [
  _NavEntry(Icons.group_outlined, 'Usuarios'),
];

const double _kSidebarBreakpoint = 1080;

// ─── Helpers ──────────────────────────────────────────────────────────────────
MovType _parseMovType(String? t) {
  switch (t) {
    case 'EGRESO_KIT': return MovType.egresoKit;
    case 'EGRESO_DIRECTO': return MovType.egresoDirecto;
    case 'INGRESO_INICIAL':
    case 'INGRESO': return MovType.ingreso;
    default: return MovType.transferencia;
  }
}

String _formatFecha(String? iso) {
  if (iso == null) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m · $h:$min';
  } catch (_) {
    return '—';
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// =============================================================================
//  HOME SCREEN
// =============================================================================
class HomeScreen extends StatefulWidget {
  final int idSucursal;
  final String rol;
  final String nomUsuario;
  final String nomSucursal;

  const HomeScreen({
    super.key,
    required this.idSucursal,
    required this.rol,
    required this.nomUsuario,
    required this.nomSucursal,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  int _activeNav = 0;
  StockState? _filtroEstadoInicialInventario;

  bool _loading = true;
  bool _loadingPrediccion = true;
  bool _errorConexion = false;

  // ── Notificaciones en tiempo real ──────────────────────────────────────────
  final List<Notificacion> _notificaciones = [];
  int _noLeidas = 0;
  StreamSubscription<Notificacion>? _socketSub;

  _KpiData _kpis = const _KpiData(
    totalProductos: 0,
    lotesVencer: 0,
    lotesBajoMinimo: 0,
    transferenciasPendientes: 0,
    ultimoMovNombre: '—',
    ultimoMovDetalle: '—',
  );
  List<Movement> _movements = [];
  List<RiskItem> _risks = [];
  List<ForecastBar> _forecast = [];
  int _totalPredicho30 = 0;
  int _totalReal4Sem = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _conectarSocket();
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    SocketService().desconectar();
    super.dispose();
  }

  Future<void> _conectarSocket() async {
    final token = await AuthService().getToken();
    if (token == null || !mounted) return;
    _socketSub = SocketService().stream.listen((notif) {
      if (mounted) {
        setState(() {
          _notificaciones.add(notif);
          _noLeidas++;
        });
      }
    });
    SocketService().conectar(token, onConnected: () {
      _api.revisarNotificaciones();
    });
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _loadingPrediccion = true; _errorConexion = false; });

    // Cargar datos rápidos primero (inventario, movimientos, transferencias)
    final results = await Future.wait([
      _api.getInventario(widget.idSucursal),
      _api.getMovimientos(widget.idSucursal),
      _api.getTransferencias(),
    ]);

    if (!mounted) return;

    final inventario     = results[0];
    final movimientos    = results[1];
    final transferencias = results[2];

    // 401 → token borrado → volver al login
    if (inventario == null && movimientos == null) {
      final token = await AuthService().getToken();
      if (token == null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return;
      }
      setState(() { _loading = false; _loadingPrediccion = false; _errorConexion = true; });
      return;
    }

    _processInventario(inventario);
    _processMovimientos(movimientos, transferencias);

    // Mostrar dashboard inmediatamente; IA carga en segundo plano
    setState(() => _loading = false);

    // Predicción puede tardar 30-120 s (Brain.js entrena en cada llamada)
    _api.getPrediccion(widget.idSucursal).then((prediccion) {
      if (!mounted) return;
      _processPrediccion(prediccion, movimientos);
      setState(() => _loadingPrediccion = false);
    // ignore: avoid_types_on_closure_parameters
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() => _loadingPrediccion = false);
    });
  }

  void _processInventario(List<dynamic>? inv) {
    if (inv == null) return;
    final total = inv.length;
    int bajoMinimo = 0;
    int lotesVencer = 0;
    for (final p in inv) {
      final stockMin = _toDouble(p['stock_min']);
      final stockTotal = _toDouble(p['stock_total']);
      if (stockMin > 0 && stockTotal < stockMin) bajoMinimo++;
      // campo agregado en el backend: lotes con fecha_venc entre hoy y +30 días
      lotesVencer += (p['lotes_proximos_vencer'] as int?) ?? 0;
    }
    _kpis = _KpiData(
      totalProductos: total,
      lotesVencer: lotesVencer,
      lotesBajoMinimo: bajoMinimo,
      transferenciasPendientes: _kpis.transferenciasPendientes,
      ultimoMovNombre: _kpis.ultimoMovNombre,
      ultimoMovDetalle: _kpis.ultimoMovDetalle,
    );
  }

  void _processMovimientos(List<dynamic>? movs, List<dynamic>? transfers) {
    if (movs == null) return;
    final hoy = DateTime.now();

    // Transferencias pendientes para esta sucursal
    int pendientes = 0;
    if (transfers != null) {
      pendientes = transfers.where((t) =>
        t['estado'] == 'EN_TRANSITO' &&
        t['id_sucursal_destino'] == widget.idSucursal,
      ).length;
    }

    // Último movimiento
    String ultimoNombre = '—';
    String ultimoDetalle = '—';
    final egreso = movs.where((m) =>
      m['tipo_mov'] == 'EGRESO_KIT' || m['tipo_mov'] == 'EGRESO_DIRECTO',
    ).toList();
    if (egreso.isNotEmpty) {
      final ult = egreso.first;
      ultimoNombre = ult['lotes']?['productos']?['nombre_mat'] ?? '—';
      final tipo = ult['tipo_mov'] ?? '';
      final cant = _toDouble(ult['cantidad']).round();
      ultimoDetalle = '$tipo · $cant u';
    }

    _kpis = _KpiData(
      totalProductos: _kpis.totalProductos,
      lotesVencer: _kpis.lotesVencer,
      lotesBajoMinimo: _kpis.lotesBajoMinimo,
      transferenciasPendientes: pendientes,
      ultimoMovNombre: ultimoNombre,
      ultimoMovDetalle: ultimoDetalle,
    );

    // Tabla de movimientos recientes (primeros 7)
    _movements = movs.take(7).map((m) {
      final lote = m['lotes'];
      final producto = lote?['productos'];
      final usuario = m['usuarios'];
      final nombreProd = producto?['nombre_mat'] ?? 'Producto desconocido';
      final sku = lote?['codigo_lote'] ?? '—';
      final type = _parseMovType(m['tipo_mov'] as String?);
      final qty = _toDouble(m['cantidad']);
      final nomUser = usuario?['nom_usuario'] ?? '—';
      final signedQty = (type == MovType.egresoKit || type == MovType.egresoDirecto || type == MovType.transferencia) ? -qty : qty;
      return Movement(
        _formatFecha(m['fecha_hora'] as String?),
        nombreProd,
        sku,
        type,
        signedQty,
        nomUser,
        _initials(nomUser),
      );
    }).toList();

    // Consumo real últimas 4 semanas para el gráfico
    final hace4sem = hoy.subtract(const Duration(days: 28));
    final semanas = [0.0, 0.0, 0.0, 0.0];
    for (final m in movs) {
      final tipo = m['tipo_mov'] as String?;
      if (tipo != 'EGRESO_KIT' && tipo != 'EGRESO_DIRECTO') continue;
      final fechaStr = m['fecha_hora'] as String?;
      if (fechaStr == null) continue;
      try {
        final fecha = DateTime.parse(fechaStr).toLocal();
        if (fecha.isBefore(hace4sem)) continue;
        final semIdx = fecha.difference(hace4sem).inDays ~/ 7;
        if (semIdx >= 0 && semIdx < 4) {
          semanas[semIdx] += _toDouble(m['cantidad']);
        }
      } catch (_) {}
    }
    _totalReal4Sem = semanas.fold(0, (a, b) => a + b.round());
  }

  void _processPrediccion(Map<String, dynamic>? pred, List<dynamic>? movs) {
    // Panel de riesgo
    if (pred != null) {
      final lista = pred['predicciones'] as List<dynamic>? ?? [];
      _risks = lista.take(5).map((p) {
        final dias = (p['dias_para_quiebre'] as num?)?.toInt() ?? 0;
        final stock = _toDouble(p['stock_total']);
        final consumoDia = dias > 0 ? stock / dias : 0.0;
        final fill = (1.0 - (dias / 30.0)).clamp(0.0, 1.0);
        return RiskItem(
          p['nombre_mat'] as String? ?? '—',
          dias,
          '${stock.toStringAsFixed(0)} u · consumo ~${consumoDia.toStringAsFixed(0)} u/día',
          fill,
        );
      }).toList();

      // Total predicho 30 días (suma de todos los productos)
      _totalPredicho30 = (pred['predicciones'] as List<dynamic>? ?? [])
          .fold<double>(0, (s, p) => s + _toDouble(p['consumo_predicho_30_dias']))
          .round();
    }

    // Barras del gráfico
    _buildForecast(movs);
  }

  void _buildForecast(List<dynamic>? movs) {
    final hoy = DateTime.now();
    final hace4sem = hoy.subtract(const Duration(days: 28));

    // Consumo real por semana (S-3, S-2, S-1, Actual)
    final realSem = [0.0, 0.0, 0.0, 0.0];
    if (movs != null) {
      for (final m in movs) {
        final tipo = m['tipo_mov'] as String?;
        if (tipo != 'EGRESO_KIT' && tipo != 'EGRESO_DIRECTO') continue;
        final fechaStr = m['fecha_hora'] as String?;
        if (fechaStr == null) continue;
        try {
          final fecha = DateTime.parse(fechaStr).toLocal();
          if (fecha.isBefore(hace4sem)) continue;
          final idx = fecha.difference(hace4sem).inDays ~/ 7;
          if (idx >= 0 && idx < 4) realSem[idx] += _toDouble(m['cantidad']);
        } catch (_) {}
      }
    }

    // Tasa de crecimiento histórica (S-3 → Actual), solo pares donde ambos > 0
    final ratios = <double>[];
    for (int i = 1; i < 4; i++) {
      if (realSem[i - 1] > 0 && realSem[i] > 0) {
        ratios.add(realSem[i] / realSem[i - 1]);
      }
    }
    double tasa = ratios.length >= 2
        ? ratios.reduce((a, b) => a + b) / ratios.length
        : 1.05;
    tasa = tasa.clamp(0.85, 1.20);

    // Distribuir proyección total con tendencia: S+n = base × tasa^n, luego normalizar
    final base = _totalPredicho30 / 4.0;
    final raw0 = base;
    final raw1 = base * tasa;
    final raw2 = base * tasa * tasa;
    final raw3 = base * tasa * tasa * tasa;
    final rawSum = raw0 + raw1 + raw2 + raw3;
    final List<int> proyecciones;
    if (rawSum > 0 && _totalPredicho30 > 0) {
      proyecciones = [
        (raw0 / rawSum * _totalPredicho30).round(),
        (raw1 / rawSum * _totalPredicho30).round(),
        (raw2 / rawSum * _totalPredicho30).round(),
        (raw3 / rawSum * _totalPredicho30).round(),
      ];
    } else {
      final equal = (_totalPredicho30 / 4).round();
      proyecciones = [equal, equal, equal, equal];
    }

    final labels = ['S-3', 'S-2', 'S-1', 'Actual', 'S+1', 'S+2', 'S+3', 'S+4'];
    final values = [
      realSem[0].round(), realSem[1].round(), realSem[2].round(), realSem[3].round(),
      proyecciones[0], proyecciones[1], proyecciones[2], proyecciones[3],
    ];

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) {
      _forecast = List.generate(8, (i) => ForecastBar(labels[i], 0, 0, i >= 4));
      return;
    }

    _forecast = List.generate(8, (i) => ForecastBar(
      labels[i],
      values[i],
      values[i] / maxVal,
      i >= 4,
    ));
  }

  Future<void> _logout() async {
    _socketSub?.cancel();
    SocketService().desconectar();
    await AuthService().logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _registrarConsumo() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => RegistrarConsumoDialog(idSucursal: widget.idSucursal),
    );
    if (result is Map && mounted) {
      _api.invalidateCache();
      _loadData();
      final loteUsado = result['lote_usado'];
      final String msg;
      if (loteUsado is Map) {
        final numLote = (loteUsado['num_lote'] ?? '—').toString();
        final fechaRaw = loteUsado['fecha_vencimiento'];
        final fecha = fechaRaw != null ? DateTime.tryParse(fechaRaw.toString()) : null;
        final fechaStr = fecha != null
            ? '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}'
            : '—';
        msg = 'Descontado del lote $numLote · Vence $fechaStr';
      } else {
        msg = 'Consumo registrado correctamente';
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CendentColors.ink,
          width: 480,
          duration: const Duration(seconds: 5),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF5FE3C2), size: 18),
              const SizedBox(width: 10),
              Flexible(child: Text(msg, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
            ],
          ),
        ));
    }
  }

  Future<void> _nuevaTransferencia() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => NuevaTransferenciaDialog(idSucursal: widget.idSucursal),
    );
    if (saved == true && mounted) {
      _api.invalidateCache();
      _loadData();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CendentColors.ink,
          width: 400,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF5FE3C2), size: 18),
              SizedBox(width: 10),
              Text('Transferencia enviada correctamente',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
            ],
          ),
        ));
    }
  }

  Future<void> _despacharKit() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => DespacharKitFlowDialog(idSucursal: widget.idSucursal),
    );
    if (result is Map && mounted) {
      _api.invalidateCache();
      _loadData();
      final lotes = result['lotes_usados'] as List? ?? [];
      final String msg;
      if (lotes.isEmpty) {
        msg = 'Kit despachado correctamente';
      } else {
        final parts = lotes.take(3).map((l) {
          final prod = (l['nombre_producto'] ?? '?').toString();
          final lote = (l['num_lote'] ?? '?').toString();
          final fechaRaw = l['fecha_vencimiento'];
          final fecha = fechaRaw != null ? DateTime.tryParse(fechaRaw.toString()) : null;
          final fechaStr = fecha != null
              ? '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}'
              : '—';
          return '$prod → $lote (vence $fechaStr)';
        }).join(' · ');
        final extra = lotes.length > 3 ? ' · +${lotes.length - 3} más' : '';
        msg = 'Kit despachado · $parts$extra';
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CendentColors.ink,
          width: 540,
          duration: const Duration(seconds: 6),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF5FE3C2), size: 18),
              const SizedBox(width: 10),
              Flexible(child: Text(msg, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500))),
            ],
          ),
        ));
    }
  }

  Widget _buildContentArea() {
    // nav index 6 → Usuarios
    if (_activeNav == 6) {
      return UsuariosScreen(userRol: widget.rol);
    }

    // nav index 5 → Analítica Predictiva
    if (_activeNav == 5) {
      return AnaliticaScreen(
        idSucursal: widget.idSucursal,
        nomSucursal: widget.nomSucursal,
      );
    }

    // nav index 4 → Transferencias
    if (_activeNav == 4) {
      return TransferenciasScreen(
        idSucursal: widget.idSucursal,
        nomSucursal: widget.nomSucursal,
      );
    }

    // nav index 3 → Movimientos
    if (_activeNav == 3) {
      return MovimientosScreen(
        idSucursal: widget.idSucursal,
        nomSucursal: widget.nomSucursal,
      );
    }

    // nav index 2 → Kits de Procedimientos
    if (_activeNav == 2) {
      return KitsScreen(idSucursal: widget.idSucursal);
    }

    // nav index 1 → Inventario / Lotes (pantalla completa con su propio footer)
    if (_activeNav == 1) {
      final filtro = _filtroEstadoInicialInventario;
      if (filtro != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _filtroEstadoInicialInventario = null);
        });
      }
      return InventarioScreen(
        idSucursal: widget.idSucursal,
        nomSucursal: widget.nomSucursal,
        filtroEstadoInicial: filtro,
      );
    }

    // Dashboard (index 0) y demás secciones sin implementar aún
    return Column(
      children: [
        Expanded(
          child: _loading
              ? const _DashboardSkeleton()
              : _errorConexion
                  ? _ErrorView(onRetry: _loadData)
                  : SingleChildScrollView(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1600),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
                            child: _DashboardBody(
                              kpis: _kpis,
                              movements: _movements,
                              risks: _risks,
                              forecast: _forecast,
                              totalReal: _totalReal4Sem,
                              totalPredicho: _totalPredicho30,
                              loadingPrediccion: _loadingPrediccion,
                              onRefresh: _loadData,
                              onDespacharKit: _despacharKit,
                              onRegistrarConsumo: _registrarConsumo,
                              onNuevaTransferencia: _nuevaTransferencia,
                              onProductosTap: () => setState(() => _activeNav = 1),
                              onTransferenciasTap: () => setState(() => _activeNav = 4),
                              onMovimientosTap: () => setState(() => _activeNav = 3),
                              onVerMovimientos: () => setState(() => _activeNav = 3),
                              onVerAnalitica: () => setState(() => _activeNav = 5),
                              onVencerTap: () => setState(() {
                                _filtroEstadoInicialInventario = StockState.porVencer;
                                _activeNav = 1;
                              }),
                              onBajoMinimoTap: () => setState(() {
                                _filtroEstadoInicialInventario = StockState.bajoMinimo;
                                _activeNav = 1;
                              }),
                            ),
                          ),
                        ),
                      ),
                    ),
        ),
        const _Footer(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final showSidebar = width >= _kSidebarBreakpoint;

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: CendentColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: CendentColors.primary,
          primary: CendentColors.primary,
        ),
      ),
      child: Scaffold(
        backgroundColor: CendentColors.bg,
        drawer: showSidebar
            ? null
            : Drawer(
                backgroundColor: CendentColors.card,
                child: _Sidebar(
                  active: _activeNav,
                  onSelect: (i) {
                    setState(() => _activeNav = i);
                    Navigator.of(context).maybePop();
                  },
                  onLogout: _logout,
                ),
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (showSidebar)
                _Sidebar(
                  active: _activeNav,
                  onSelect: (i) => setState(() => _activeNav = i),
                  onLogout: _logout,
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      showMenuButton: !showSidebar,
                      nomUsuario: widget.nomUsuario,
                      rol: widget.rol,
                      nomSucursal: widget.nomSucursal,
                      notificaciones: _notificaciones,
                      noLeidas: _noLeidas,
                      onLeer: () => setState(() => _noLeidas = 0),
                      onStockTap: () => setState(() {
                        _filtroEstadoInicialInventario = StockState.bajoMinimo;
                        _activeNav = 1;
                      }),
                      onVencimientoTap: () => setState(() {
                        _filtroEstadoInicialInventario = StockState.porVencer;
                        _activeNav = 1;
                      }),
                    ),
                    Expanded(child: _buildContentArea()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  SIDEBAR
// =============================================================================
class _Sidebar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  const _Sidebar({required this.active, required this.onSelect, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    int idx = 0;
    final children = <Widget>[];

    void addGroup(String section, List<_NavEntry> entries) {
      children.add(_sectionLabel(section));
      for (final e in entries) {
        final i = idx;
        children.add(_NavItem(entry: e, active: active == i, onTap: () => onSelect(i)));
        idx++;
      }
    }

    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: CendentColors.card,
        border: Border(right: BorderSide(color: CendentColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/LogoCendent.png',
                  height: 38,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: CendentColors.blueTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text('C', style: TextStyle(color: CendentColors.primary, fontWeight: FontWeight.w800, fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 11),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CENDENT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CendentColors.ink, letterSpacing: -0.2)),
                    Text('Gestión de Inventario', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CendentColors.secondary)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Builder(builder: (_) {
                addGroup('Operación', _navOperacion);
                addGroup('Inteligencia', _navInteligencia);
                addGroup('Sistema', _navSistema);
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
              }),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairlineSoft))),
            child: _LogoutItem(onTap: onLogout),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 7),
        child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.7, color: CendentColors.muted)),
      );
}

class _NavItem extends StatefulWidget {
  final _NavEntry entry;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.entry, required this.active, required this.onTap});
  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final fg = active ? CendentColors.primary : (_hover ? CendentColors.primary : CendentColors.steel);
    final bg = active ? CendentColors.blueTint : (_hover ? CendentColors.blueWash : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(widget.entry.icon, size: 18, color: fg),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.entry.label, style: TextStyle(fontSize: 14, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: fg))),
                  ],
                ),
              ),
              if (active)
                Positioned(
                  left: 0, top: 8, bottom: 8,
                  child: Container(width: 3, decoration: const BoxDecoration(color: CendentColors.primary, borderRadius: BorderRadius.horizontal(right: Radius.circular(3)))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutItem extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutItem({required this.onTap});
  @override
  State<_LogoutItem> createState() => _LogoutItemState();
}

class _LogoutItemState extends State<_LogoutItem> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: _hover ? CendentColors.redSoft : null, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: _hover ? CendentColors.red : CendentColors.steel),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _hover ? CendentColors.red : CendentColors.steel)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  TOP BAR
// =============================================================================
class _TopBar extends StatelessWidget {
  final bool showMenuButton;
  final String nomUsuario;
  final String rol;
  final String nomSucursal;
  final List<Notificacion> notificaciones;
  final int noLeidas;
  final VoidCallback onLeer;
  final VoidCallback? onStockTap;
  final VoidCallback? onVencimientoTap;
  const _TopBar({
    required this.showMenuButton,
    required this.nomUsuario,
    required this.rol,
    required this.nomSucursal,
    required this.notificaciones,
    required this.noLeidas,
    required this.onLeer,
    this.onStockTap,
    this.onVencimientoTap,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 720;
    final ini = _initials(nomUsuario);
    return Container(
      height: 70,
      decoration: const BoxDecoration(color: CendentColors.card, border: Border(bottom: BorderSide(color: CendentColors.hairline))),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: CendentColors.steel),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: CendentColors.blueTint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.apartment_rounded, size: 19, color: CendentColors.primary),
          ),
          const SizedBox(width: 11),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SUCURSAL ACTIVA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: CendentColors.secondary)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nomSucursal.isNotEmpty ? nomSucursal : 'Sin sucursal',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: CendentColors.ink, letterSpacing: -0.2),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: CendentColors.secondary),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (!narrow) ...[
            _LivePill(),
            const SizedBox(width: 18),
          ],
          _NotifButton(
            notificaciones: notificaciones,
            noLeidas: noLeidas,
            onLeer: onLeer,
            onStockTap: onStockTap,
            onVencimientoTap: onVencimientoTap,
          ),
          const SizedBox(width: 18),
          Container(
            padding: const EdgeInsets.only(left: 18),
            decoration: const BoxDecoration(border: Border(left: BorderSide(color: CendentColors.hairline))),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [CendentColors.primaryMid, CendentColors.primaryDeep],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(ini, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                ),
                if (!narrow) ...[
                  const SizedBox(width: 11),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nomUsuario, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                      Text(rol, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: CendentColors.secondary)),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: CendentColors.secondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: CendentColors.greenSoft, borderRadius: BorderRadius.circular(9999)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(),
          SizedBox(width: 7),
          Text('En línea', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CendentColors.green)),
        ],
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();
  @override
  Widget build(BuildContext context) {
    return Container(width: 7, height: 7, decoration: const BoxDecoration(color: CendentColors.green, shape: BoxShape.circle));
  }
}


// =============================================================================
//  DASHBOARD BODY
// =============================================================================
class _DashboardBody extends StatelessWidget {
  final _KpiData kpis;
  final List<Movement> movements;
  final List<RiskItem> risks;
  final List<ForecastBar> forecast;
  final int totalReal;
  final int totalPredicho;
  final bool loadingPrediccion;
  final VoidCallback onRefresh;
  final VoidCallback? onDespacharKit;
  final VoidCallback? onRegistrarConsumo;
  final VoidCallback? onNuevaTransferencia;
  final VoidCallback? onProductosTap;
  final VoidCallback? onVencerTap;
  final VoidCallback? onBajoMinimoTap;
  final VoidCallback? onTransferenciasTap;
  final VoidCallback? onMovimientosTap;
  final VoidCallback? onVerMovimientos;
  final VoidCallback? onVerAnalitica;

  const _DashboardBody({
    required this.kpis,
    required this.movements,
    required this.risks,
    required this.forecast,
    required this.totalReal,
    required this.totalPredicho,
    required this.loadingPrediccion,
    required this.onRefresh,
    this.onDespacharKit,
    this.onRegistrarConsumo,
    this.onNuevaTransferencia,
    this.onProductosTap,
    this.onVencerTap,
    this.onBajoMinimoTap,
    this.onTransferenciasTap,
    this.onMovimientosTap,
    this.onVerMovimientos,
    this.onVerAnalitica,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PageHead(onRefresh: onRefresh, onDespacharKit: onDespacharKit, onRegistrarConsumo: onRegistrarConsumo, onNuevaTransferencia: onNuevaTransferencia),
        const SizedBox(height: 22),
        _KpiGrid(kpis: kpis, onProductosTap: onProductosTap, onVencerTap: onVencerTap, onBajoMinimoTap: onBajoMinimoTap, onTransferenciasTap: onTransferenciasTap, onMovimientosTap: onMovimientosTap),
        const SizedBox(height: 20),
        if (width >= 1180)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 155, child: _ForecastPanel(forecast: forecast, totalReal: totalReal, totalPredicho: totalPredicho, loading: loadingPrediccion)),
                const SizedBox(width: 20),
                Expanded(flex: 100, child: _RiskPanel(risks: risks, loading: loadingPrediccion, onVerTodo: onVerAnalitica)),
              ],
            ),
          )
        else ...[
          _ForecastPanel(forecast: forecast, totalReal: totalReal, totalPredicho: totalPredicho, loading: loadingPrediccion),
          const SizedBox(height: 20),
          _RiskPanel(risks: risks, loading: loadingPrediccion, onVerTodo: onVerAnalitica),
        ],
        const SizedBox(height: 20),
        _MovementsPanel(movements: movements, onVerTodos: onVerMovimientos),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: CendentColors.secondary),
          const SizedBox(height: 16),
          const Text('No se pudo conectar con el servidor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CendentColors.ink)),
          const SizedBox(height: 8),
          const Text('Verifica que el backend esté corriendo en localhost:3000', style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(backgroundColor: CendentColors.primary, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─── Page head ────────────────────────────────────────────────────────────────
class _PageHead extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback? onDespacharKit;
  final VoidCallback? onRegistrarConsumo;
  final VoidCallback? onNuevaTransferencia;
  const _PageHead({required this.onRefresh, this.onDespacharKit, this.onRegistrarConsumo, this.onNuevaTransferencia});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 16,
      spacing: 20,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dashboard', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: CendentColors.ink)),
            SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: CendentColors.secondary),
                SizedBox(width: 7),
                Text('Inventario y Analítica Predictiva', style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
              ],
            ),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickButton(icon: Icons.medical_services_outlined, label: 'Despachar kit', primary: true, onTap: onDespacharKit ?? () {}),
            _QuickButton(icon: Icons.edit_note_rounded, label: 'Registrar consumo', onTap: onRegistrarConsumo ?? () {}),
            _QuickButton(icon: Icons.local_shipping_outlined, label: 'Nueva transferencia', onTap: onNuevaTransferencia ?? () {}),
            _QuickButton(icon: Icons.refresh_rounded, label: 'Actualizar', onTap: onRefresh),
          ],
        ),
      ],
    );
  }
}

class _QuickButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _QuickButton({required this.icon, required this.label, this.primary = false, required this.onTap});
  @override
  State<_QuickButton> createState() => _QuickButtonState();
}

class _QuickButtonState extends State<_QuickButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final primary = widget.primary;
    final bg = primary ? (_hover ? CendentColors.primaryDeep : CendentColors.primary) : (_hover ? CendentColors.blueTint : CendentColors.card);
    final fg = primary ? Colors.white : CendentColors.primary;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: primary ? null : Border.all(color: CendentColors.blueLight),
            boxShadow: primary ? const [BoxShadow(color: Color(0x8C1565C0), blurRadius: 16, spreadRadius: -6, offset: Offset(0, 6))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: fg),
              const SizedBox(width: 10),
              Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Tarjeta base ────────────────────────────────────────────────────────────
class CendentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const CendentCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline),
        boxShadow: CendentColors.cardShadow,
      ),
      child: child,
    );
  }
}

// =============================================================================
//  KPI GRID
// =============================================================================
enum _Tone { blue, amber, red, green, slate, mute, violet }

class _ToneStyle {
  final Color fg;
  final Color bg;
  const _ToneStyle(this.fg, this.bg);
  static _ToneStyle of(_Tone t) {
    switch (t) {
      case _Tone.blue:   return const _ToneStyle(CendentColors.primary, CendentColors.blueTint);
      case _Tone.amber:  return const _ToneStyle(CendentColors.amber, CendentColors.amberSoft);
      case _Tone.red:    return const _ToneStyle(CendentColors.red, CendentColors.redSoft);
      case _Tone.green:  return const _ToneStyle(CendentColors.green, CendentColors.greenSoft);
      case _Tone.violet: return const _ToneStyle(CendentColors.violet, CendentColors.violetSoft);
      case _Tone.slate:  return const _ToneStyle(CendentColors.steel, Color(0xFFEAEFF4));
      case _Tone.mute:   return const _ToneStyle(CendentColors.secondary, Color(0xFFEAEFF4));
    }
  }
}

class _KpiGrid extends StatelessWidget {
  final _KpiData kpis;
  final VoidCallback? onProductosTap;
  final VoidCallback? onVencerTap;
  final VoidCallback? onBajoMinimoTap;
  final VoidCallback? onTransferenciasTap;
  final VoidCallback? onMovimientosTap;
  const _KpiGrid({required this.kpis, this.onProductosTap, this.onVencerTap, this.onBajoMinimoTap, this.onTransferenciasTap, this.onMovimientosTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 1180 ? 5 : (w >= 720 ? 2 : 1);
      const gap = 16.0;
      final cardW = (w - gap * (cols - 1)) / cols;

      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(width: cardW, child: _KpiCard(
            icon: Icons.inventory_2_outlined, iconTone: _Tone.blue,
            value: '${kpis.totalProductos}', unit: 'SKU',
            label: 'Productos en inventario',
            footIcon: Icons.category_outlined, footText: 'Con stock activo',
            footTone: _Tone.mute,
            onTap: onProductosTap,
          )),
          SizedBox(width: cardW, child: _KpiCard(
            icon: Icons.event_busy_outlined, iconTone: _Tone.amber,
            chip: kpis.lotesVencer > 0 ? 'Atención' : null, chipTone: _Tone.amber,
            value: '${kpis.lotesVencer}', unit: 'lotes',
            label: 'Próximos a vencer (≤ 30 d)',
            footIcon: Icons.warning_amber_rounded, footText: 'Verificar antes de vencimiento',
            footTone: kpis.lotesVencer > 0 ? _Tone.amber : _Tone.mute,
            onTap: onVencerTap,
          )),
          SizedBox(width: cardW, child: _KpiCard(
            icon: Icons.trending_down_rounded, iconTone: _Tone.red,
            chip: kpis.lotesBajoMinimo > 0 ? 'Crítico' : null, chipTone: _Tone.red,
            value: '${kpis.lotesBajoMinimo}', unit: 'lotes',
            label: 'Stock bajo el mínimo',
            footIcon: Icons.error_outline_rounded, footText: 'Requieren reposición',
            footTone: kpis.lotesBajoMinimo > 0 ? _Tone.red : _Tone.mute,
            onTap: onBajoMinimoTap,
          )),
          SizedBox(width: cardW, child: _KpiCard(
            icon: Icons.local_shipping_outlined, iconTone: _Tone.slate,
            chip: kpis.transferenciasPendientes > 0 ? 'Pendiente' : null, chipTone: _Tone.green,
            value: '${kpis.transferenciasPendientes}', unit: 'envíos',
            label: 'Transferencias por recibir',
            footIcon: Icons.location_on_outlined, footText: 'En tránsito hacia esta sucursal',
            footTone: _Tone.mute,
            onTap: onTransferenciasTap,
          )),
          SizedBox(width: cardW, child: _KpiCard(
            icon: Icons.history_rounded, iconTone: _Tone.green,
            valueWidget: Text(
              kpis.ultimoMovNombre,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CendentColors.ink, letterSpacing: -0.3, height: 1.15),
            ),
            label: 'Último movimiento',
            footIcon: Icons.schedule_rounded, footText: kpis.ultimoMovDetalle,
            footTone: _Tone.mute,
            onTap: onMovimientosTap,
          )),
        ],
      );
    });
  }
}

class _KpiCard extends StatefulWidget {
  final IconData icon;
  final _Tone iconTone;
  final String? chip;
  final _Tone? chipTone;
  final String? value;
  final String? unit;
  final Widget? valueWidget;
  final String label;
  final IconData footIcon;
  final String footText;
  final _Tone footTone;

  final VoidCallback? onTap;

  const _KpiCard({
    required this.icon, required this.iconTone,
    this.chip, this.chipTone,
    this.value, this.unit, this.valueWidget,
    required this.label,
    required this.footIcon, required this.footText, required this.footTone,
    this.onTap,
  });
  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final iconStyle = _ToneStyle.of(widget.iconTone);
    final footStyle = _ToneStyle.of(widget.footTone);
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: _hover ? (Matrix4.identity()..translate(0.0, -2.0)) : Matrix4.identity(),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CendentColors.hairline),
          boxShadow: _hover ? const [BoxShadow(color: Color(0x331565C0), blurRadius: 32, spreadRadius: -8, offset: Offset(0, 12))] : CendentColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: iconStyle.bg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(widget.icon, size: 21, color: iconStyle.fg),
                ),
                const Spacer(),
                if (widget.chip != null) _Chip(text: widget.chip!, tone: widget.chipTone!),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.valueWidget != null)
              widget.valueWidget!
            else
              RichText(text: TextSpan(
                text: widget.value,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: CendentColors.ink, letterSpacing: -1, height: 1),
                children: [
                  if (widget.unit != null)
                    TextSpan(text: '  ${widget.unit}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: CendentColors.secondary, letterSpacing: 0)),
                ],
              )),
            const SizedBox(height: 6),
            Text(widget.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: CendentColors.secondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(widget.footIcon, size: 14, color: footStyle.fg),
                const SizedBox(width: 5),
                Flexible(child: Text(widget.footText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: footStyle.fg))),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final _Tone tone;
  const _Chip({required this.text, required this.tone});
  @override
  Widget build(BuildContext context) {
    final s = _ToneStyle.of(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(9999)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.fg)),
    );
  }
}

// =============================================================================
//  PANEL HEADER
// =============================================================================
class _PanelHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool aiBadge;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _PanelHeader({required this.title, this.subtitle, this.aiBadge = false, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(child: Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: CendentColors.ink, letterSpacing: -0.2))),
            if (aiBadge) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: CendentColors.blueTint, borderRadius: BorderRadius.circular(9999)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: CendentColors.primary),
                    SizedBox(width: 5),
                    Text('IA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: CendentColors.primary)),
                  ],
                ),
              ),
            ],
            const Spacer(),
            if (actionLabel != null) _LinkButton(label: actionLabel!, onTap: onAction),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: CendentColors.secondary)),
        ],
      ],
    );
  }
}

class _LinkButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _LinkButton({required this.label, required this.onTap});
  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: _hover ? CendentColors.blueWash : null, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CendentColors.primary)),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 15, color: CendentColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  FORECAST PANEL
// =============================================================================
class _ForecastPanel extends StatelessWidget {
  final List<ForecastBar> forecast;
  final int totalReal;
  final int totalPredicho;
  final bool loading;
  const _ForecastPanel({required this.forecast, required this.totalReal, required this.totalPredicho, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final variacion = totalReal > 0 ? ((totalPredicho - totalReal) / totalReal * 100) : 0.0;
    final String varStr;
    final Color varColor;
    if (loading) {
      varStr = '…';
      varColor = CendentColors.secondary;
    } else if (totalReal == 0) {
      varStr = '—';
      varColor = CendentColors.secondary;
    } else if (variacion > 999) {
      varStr = '> 999%';
      varColor = CendentColors.amber;
    } else if (variacion < -99) {
      varStr = '< -99%';
      varColor = CendentColors.green;
    } else {
      varStr = '${variacion >= 0 ? '+' : ''}${variacion.toStringAsFixed(1)}%';
      varColor = variacion >= 0 ? CendentColors.amber : CendentColors.green;
    }

    return CendentCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelHeader(
            title: 'Predicción de consumo — próximos 30 días',
            aiBadge: true,
            subtitle: 'Proyección de demanda por semana · modelo LSTM',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 26,
            runSpacing: 12,
            children: [
              _Metric(label: 'Consumo real (4 sem)', value: _fmt(totalReal), unit: 'u'),
              _Metric(label: 'Proyección (4 sem)', value: loading ? '…' : _fmt(totalPredicho), unit: loading ? null : 'u'),
              _Metric(label: 'Variación', value: varStr, valueColor: loading ? CendentColors.secondary : varColor),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 188,
            child: loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5),
                        SizedBox(height: 14),
                        Text('Calculando predicciones…', style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                      ],
                    ),
                  )
                : forecast.isEmpty
                    ? const Center(child: Text('Sin datos de predicción', style: TextStyle(color: CendentColors.secondary)))
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: forecast.map((b) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: _Bar(bar: b)))).toList(),
                      ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: CendentColors.hairlineSoft),
          const SizedBox(height: 14),
          const Row(
            children: [
              _LegendKey(projected: false, label: 'Consumo real'),
              SizedBox(width: 18),
              _LegendKey(projected: true, label: 'Proyección IA'),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  const _Metric({required this.label, required this.value, this.unit, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: CendentColors.secondary)),
        const SizedBox(height: 3),
        RichText(text: TextSpan(
          text: value,
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: valueColor ?? CendentColors.ink, letterSpacing: -0.5),
          children: [
            if (unit != null) TextSpan(text: ' $unit', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CendentColors.secondary)),
          ],
        )),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final ForecastBar bar;
  const _Bar({required this.bar});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(_fmt(bar.value), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CendentColors.ink)),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final h = c.maxHeight * bar.height;
            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 32, height: h,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7), bottom: Radius.circular(3)),
                  gradient: bar.projected ? null : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [CendentColors.primaryMid, CendentColors.primary]),
                  color: bar.projected ? const Color.fromRGBO(144, 202, 249, 0.55) : null,
                  border: bar.projected ? Border.all(color: CendentColors.primary) : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(bar.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CendentColors.secondary)),
      ],
    );
  }

  static String _fmt(int n) {
    final s = n.toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }
}

class _LegendKey extends StatelessWidget {
  final bool projected;
  final String label;
  const _LegendKey({required this.projected, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: projected ? const Color.fromRGBO(144, 202, 249, 0.55) : CendentColors.primary,
            border: projected ? Border.all(color: CendentColors.primary) : null,
          ),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: CendentColors.steel)),
      ],
    );
  }
}

// =============================================================================
//  RISK PANEL
// =============================================================================
class _RiskPanel extends StatelessWidget {
  final List<RiskItem> risks;
  final bool loading;
  final VoidCallback? onVerTodo;
  const _RiskPanel({required this.risks, this.loading = false, this.onVerTodo});

  @override
  Widget build(BuildContext context) {
    return CendentCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            title: 'Mayor riesgo de quiebre',
            subtitle: 'Ordenado por días estimados para quiebre de stock',
            actionLabel: 'Ver todo',
            onAction: onVerTodo,
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5),
                    SizedBox(height: 14),
                    Text('Analizando riesgos con IA…', style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                  ],
                ),
              ),
            )
          else if (risks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Sin datos de analítica predictiva', style: TextStyle(color: CendentColors.secondary))),
            )
          else
            ...List.generate(risks.length, (i) => _RiskRow(rank: i + 1, item: risks[i], isLast: i == risks.length - 1)),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final int rank;
  final RiskItem item;
  final bool isLast;
  const _RiskRow({required this.rank, required this.item, required this.isLast});

  _Tone get _tone {
    if (item.daysToBreak <= 4) return _Tone.red;
    if (item.daysToBreak <= 12) return _Tone.amber;
    return _Tone.green;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _ToneStyle.of(_tone);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: CendentColors.hairlineSoft))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(color: const Color(0xFFEAEFF4), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center,
                child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CendentColors.steel))),
              const SizedBox(width: 11),
              Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CendentColors.ink))),
              const SizedBox(width: 10),
              RichText(text: TextSpan(
                text: '${item.daysToBreak}',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: tone.fg),
                children: const [TextSpan(text: ' días', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: CendentColors.secondary))],
              )),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 37),
            child: Text(item.detail, style: const TextStyle(fontSize: 12, color: CendentColors.secondary)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(value: item.fill, minHeight: 5, backgroundColor: const Color(0xFFEDF1F5), valueColor: AlwaysStoppedAnimation<Color>(tone.fg)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  MOVEMENTS PANEL
// =============================================================================
class _MovementsPanel extends StatelessWidget {
  final List<Movement> movements;
  final VoidCallback? onVerTodos;
  const _MovementsPanel({required this.movements, this.onVerTodos});

  @override
  Widget build(BuildContext context) {
    return CendentCard(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(title: 'Movimientos recientes', actionLabel: 'Ver todos', onAction: onVerTodos),
          const SizedBox(height: 16),
          if (movements.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: Text('Sin movimientos registrados', style: TextStyle(color: CendentColors.secondary))),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 760),
                child: _MovementsTable(movements: movements),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementsTable extends StatelessWidget {
  final List<Movement> movements;
  const _MovementsTable({required this.movements});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(120),   // FECHA
        1: FixedColumnWidth(220),   // PRODUCTO (nombre largo + SKU)
        2: FixedColumnWidth(130),   // TIPO (badge abreviado)
        3: FixedColumnWidth(100),   // CANTIDAD
        4: FixedColumnWidth(160),   // USUARIO (avatar + nombre)
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
          children: [_th('Fecha'), _th('Producto'), _th('Tipo'), _th('Cantidad'), _th('Usuario')],
        ),
        ...movements.asMap().entries.map((e) {
          final m = e.value;
          final isLast = e.key == movements.length - 1;
          return TableRow(
            decoration: BoxDecoration(border: isLast ? null : const Border(bottom: BorderSide(color: CendentColors.hairlineSoft))),
            children: [
              _td(Text(m.date, style: const TextStyle(fontSize: 13, color: CendentColors.secondary))),
              _td(Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(m.product, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                const SizedBox(height: 2),
                Text(m.sku, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: CendentColors.secondary, fontFamily: 'monospace')),
              ])),
              _td(Align(alignment: Alignment.centerLeft, child: _MovTypeBadge(type: m.type))),
              _td(Text(_qtyLabel(m.qty), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: m.qty < 0 ? CendentColors.red : CendentColors.green))),
              _td(Row(children: [
                Container(width: 28, height: 28, decoration: BoxDecoration(color: const Color(0xFFEAEFF4), borderRadius: BorderRadius.circular(8)), alignment: Alignment.center,
                  child: Text(m.initials, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CendentColors.steel))),
                const SizedBox(width: 9),
                Flexible(child: Text(m.user, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: CendentColors.steel))),
              ])),
            ],
          );
        }),
      ],
    );
  }

  static String _qtyLabel(double qty) {
    final sign = qty < 0 ? '−' : '+';
    return '$sign${qty.abs().toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 1)} u';
  }

  Widget _th(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: Text(
      text.toUpperCase(),
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: CendentColors.secondary),
    ),
  );

  Widget _td(Widget child) => Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: child);
}

class _MovTypeBadge extends StatelessWidget {
  final MovType type;
  const _MovTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final String label;
    late final Color fg;
    late final Color bg;

    switch (type) {
      case MovType.egresoKit:
        icon = Icons.medical_services_outlined; label = 'KIT';
        fg = CendentColors.primary; bg = CendentColors.blueTint;
        break;
      case MovType.egresoDirecto:
        icon = Icons.edit_note_rounded; label = 'DIRECTO';
        fg = CendentColors.violet; bg = CendentColors.violetSoft;
        break;
      case MovType.ingreso:
        icon = Icons.south_rounded; label = 'INGRESO';
        fg = CendentColors.green; bg = CendentColors.greenSoft;
        break;
      case MovType.transferencia:
        icon = Icons.local_shipping_outlined; label = 'TRANSFER';
        fg = CendentColors.amber; bg = CendentColors.amberSoft;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: fg)),
        ],
      ),
    );
  }
}

// =============================================================================
//  DASHBOARD SKELETON
// =============================================================================
class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const _SkeletonBox({required this.width, required this.height, this.radius = 6});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width, height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEDF1F5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Page head
                const _SkeletonBox(width: 160, height: 26, radius: 8),
                const SizedBox(height: 8),
                const _SkeletonBox(width: 240, height: 14, radius: 5),
                const SizedBox(height: 22),
                // KPI cards
                LayoutBuilder(builder: (_, c) {
                  final cols = c.maxWidth >= 1180 ? 5 : (c.maxWidth >= 720 ? 2 : 1);
                  const gap = 16.0;
                  final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap, runSpacing: gap,
                    children: List.generate(5, (_) => SizedBox(
                      width: cardW,
                      child: Container(
                        height: 148,
                        decoration: BoxDecoration(
                          color: CendentColors.card,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: CendentColors.hairline),
                          boxShadow: CendentColors.cardShadow,
                        ),
                        padding: const EdgeInsets.all(20),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SkeletonBox(width: 42, height: 42, radius: 14),
                            SizedBox(height: 12),
                            _SkeletonBox(width: 70, height: 32, radius: 6),
                            SizedBox(height: 6),
                            _SkeletonBox(width: 130, height: 13, radius: 4),
                          ],
                        ),
                      ),
                    )),
                  );
                }),
                const SizedBox(height: 20),
                // Forecast + Risk panels
                LayoutBuilder(builder: (_, c) {
                  if (c.maxWidth >= 1180) {
                    return IntrinsicHeight(
                      child: Row(children: [
                        Expanded(flex: 155, child: Container(
                          height: 340,
                          decoration: BoxDecoration(color: CendentColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: CendentColors.hairline)),
                        )),
                        const SizedBox(width: 20),
                        Expanded(flex: 100, child: Container(
                          height: 340,
                          decoration: BoxDecoration(color: CendentColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: CendentColors.hairline)),
                        )),
                      ]),
                    );
                  }
                  return Column(children: [
                    Container(height: 260, decoration: BoxDecoration(color: CendentColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: CendentColors.hairline))),
                    const SizedBox(height: 20),
                    Container(height: 260, decoration: BoxDecoration(color: CendentColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: CendentColors.hairline))),
                  ]);
                }),
                const SizedBox(height: 20),
                Container(
                  height: 260,
                  decoration: BoxDecoration(color: CendentColors.card, borderRadius: BorderRadius.circular(24), border: Border.all(color: CendentColors.hairline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  NOTIFICATION BUTTON + PANEL
// =============================================================================

// Icono y color por tipo de notificación.
({IconData icon, Color color}) _notifStyle(String tipo) {
  switch (tipo) {
    case 'transferencia':
      return (icon: Icons.local_shipping_outlined, color: CendentColors.primary);
    case 'stock':
      return (icon: Icons.warning_amber_rounded, color: CendentColors.amber);
    case 'vencimiento':
      return (icon: Icons.schedule_outlined, color: CendentColors.amber);
    case 'kit':
      return (icon: Icons.medical_services_outlined, color: CendentColors.green);
    default:
      return (icon: Icons.notifications_none_rounded, color: CendentColors.secondary);
  }
}


class _NotifButton extends StatefulWidget {
  final List<Notificacion> notificaciones;
  final int noLeidas;
  final VoidCallback onLeer;
  final VoidCallback? onStockTap;
  final VoidCallback? onVencimientoTap;
  const _NotifButton({
    required this.notificaciones,
    required this.noLeidas,
    required this.onLeer,
    this.onStockTap,
    this.onVencimientoTap,
  });
  @override
  State<_NotifButton> createState() => _NotifButtonState();
}

class _NotifButtonState extends State<_NotifButton> {
  final _link = LayerLink();
  OverlayEntry? _entry;
  bool _hover = false;

  void _toggle() {
    if (_entry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    widget.onLeer();
    _entry = OverlayEntry(
      builder: (_) => _NotifPanel(
        link: _link,
        notificaciones: widget.notificaciones,
        onClose: _close,
        onStockTap: widget.onStockTap,
        onVencimientoTap: widget.onVencimientoTap,
      ),
    );
    Overlay.of(context).insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_NotifButton old) {
    super.didUpdateWidget(old);
    if (_entry != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = _entry != null;
    final hasUnread = widget.noLeidas > 0;
    // Badge muestra grupos distintos (stock, vencimiento), no items individuales.
    final groupCount = [
      if (widget.notificaciones.any((n) => n.tipo == 'stock')) 1,
      if (widget.notificaciones.any((n) => n.tipo == 'vencimiento')) 1,
    ].fold(0, (a, b) => a + b);
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _toggle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: open || _hover
                      ? CendentColors.blueWash
                      : CendentColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: open || _hover
                        ? CendentColors.blueLight
                        : CendentColors.hairline,
                  ),
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 19,
                  color: open || _hover
                      ? CendentColors.primary
                      : CendentColors.steel,
                ),
              ),
              if (hasUnread)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: CendentColors.red,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: CendentColors.card, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$groupCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifPanel extends StatelessWidget {
  final LayerLink link;
  final List<Notificacion> notificaciones;
  final VoidCallback onClose;
  final VoidCallback? onStockTap;
  final VoidCallback? onVencimientoTap;
  const _NotifPanel({
    required this.link,
    required this.notificaciones,
    required this.onClose,
    this.onStockTap,
    this.onVencimientoTap,
  });

  @override
  Widget build(BuildContext context) {
    final stockCount = notificaciones.where((n) => n.tipo == 'stock').length;
    final vencCount  = notificaciones.where((n) => n.tipo == 'vencimiento').length;
    final hasAlerts  = stockCount > 0 || vencCount > 0;
    final groupCount = (stockCount > 0 ? 1 : 0) + (vencCount > 0 ? 1 : 0);

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
          CompositedTransformFollower(
            link: link,
            showWhenUnlinked: false,
            offset: const Offset(-278, 48),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 320,
                  decoration: BoxDecoration(
                    color: CendentColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CendentColors.hairline),
                    boxShadow: CendentColors.popShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Row(
                          children: [
                            const Text(
                              'Notificaciones',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: CendentColors.ink,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasAlerts
                                    ? CendentColors.redSoft
                                    : CendentColors.greenSoft,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Text(
                                hasAlerts ? '$groupCount alerta${groupCount == 1 ? '' : 's'}' : 'Sin alertas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: hasAlerts
                                      ? CendentColors.red
                                      : CendentColors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: CendentColors.hairline),
                      if (!hasAlerts)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: 32, horizontal: 18),
                          child: Column(
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 32, color: CendentColors.green),
                              SizedBox(height: 10),
                              Text(
                                'Todo en orden. Sin alertas recientes.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: CendentColors.secondary),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (stockCount > 0) ...[
                              _NotifGroupTile(
                                tipo: 'stock',
                                count: stockCount,
                                onTap: () { onClose(); onStockTap?.call(); },
                              ),
                              if (vencCount > 0)
                                const Divider(
                                    height: 1,
                                    color: CendentColors.hairlineSoft),
                            ],
                            if (vencCount > 0)
                              _NotifGroupTile(
                                tipo: 'vencimiento',
                                count: vencCount,
                                onTap: () { onClose(); onVencimientoTap?.call(); },
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifGroupTile extends StatefulWidget {
  final String tipo;
  final int count;
  final VoidCallback? onTap;
  const _NotifGroupTile({
    required this.tipo,
    required this.count,
    this.onTap,
  });
  @override
  State<_NotifGroupTile> createState() => _NotifGroupTileState();
}

class _NotifGroupTileState extends State<_NotifGroupTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final style = _notifStyle(widget.tipo);
    final isStock = widget.tipo == 'stock';
    final title = isStock ? 'Stock bajo mínimo' : 'Lotes próximos a vencer';
    final n = widget.count;
    final subtitle = isStock
        ? '$n producto${n == 1 ? '' : 's'} ${n == 1 ? 'requiere' : 'requieren'} reposición'
        : '$n lote${n == 1 ? '' : 's'} ${n == 1 ? 'vence' : 'vencen'} pronto';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          color: _hover ? CendentColors.bg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(style.icon, size: 18, color: style.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CendentColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CendentColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _hover ? CendentColors.primary : CendentColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  FOOTER
// =============================================================================
class _Footer extends StatelessWidget {
  const _Footer();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
      child: const Column(
        children: [
          Text("Daniel's CENDENT S.A.  ·  Centro de Especialidades Odontológicas", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: CendentColors.secondary, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('© 2026 — Todos los derechos reservados', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: CendentColors.secondary)),
        ],
      ),
    );
  }
}
