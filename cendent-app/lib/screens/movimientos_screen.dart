// =============================================================================
//  lib/screens/movimientos_screen.dart
//  Sistema Web Daniel's CENDENT S.A. — Centro de Especialidades Odontológicas
//  Pantalla: Movimientos (historial de inventario, solo lectura)
//
//  Flutter 3.24 · Material 3 · desktop-first (Flutter Web, ≥1280px).
//  Mismo lenguaje visual que inventario_screen.dart / kits_screen.dart.
//
//  Backend: GET /movimientos?id_sucursal=X  →  ApiService.getMovimientos()
// =============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/cendent_colors.dart';

// =============================================================================
//  ENUMS Y MODELOS
// =============================================================================
enum TipoMovimiento {
  ingreso,
  egreso,
  egresoDirecto,
  transferenciaEntrada,
  transferenciaSalida,
  despachoKit,
}

enum MovGroup { ingresos, egresos, transferencias, despachos }

extension TipoMovimientoX on TipoMovimiento {
  String get raw {
    switch (this) {
      case TipoMovimiento.ingreso:
        return 'INGRESO';
      case TipoMovimiento.egreso:
        return 'EGRESO';
      case TipoMovimiento.egresoDirecto:
        return 'EGRESO_DIRECTO';
      case TipoMovimiento.transferenciaEntrada:
        return 'TRANSFERENCIA_ENTRADA';
      case TipoMovimiento.transferenciaSalida:
        return 'TRANSFERENCIA_SALIDA';
      case TipoMovimiento.despachoKit:
        return 'DESPACHO_KIT';
    }
  }

  static TipoMovimiento fromRaw(String s) {
    // El backend puede usar EGRESO_KIT para despachos de kits
    if (s == 'EGRESO_KIT') return TipoMovimiento.despachoKit;
    if (s == 'INGRESO_INICIAL') return TipoMovimiento.ingreso;
    if (s == 'INGRESO_TRANSFERENCIA') return TipoMovimiento.transferenciaEntrada;
    if (s == 'SALIDA_TRANSFERENCIA')  return TipoMovimiento.transferenciaSalida;
    return TipoMovimiento.values.firstWhere(
      (t) => t.raw == s,
      orElse: () => TipoMovimiento.egreso,
    );
  }

  String get label {
    switch (this) {
      case TipoMovimiento.ingreso:
        return 'INGRESO';
      case TipoMovimiento.egreso:
        return 'EGRESO';
      case TipoMovimiento.egresoDirecto:
        return 'EGRESO_DIRECTO';
      case TipoMovimiento.transferenciaEntrada:
        return 'INGRESO';
      case TipoMovimiento.transferenciaSalida:
        return 'TRANSF. SALIDA';
      case TipoMovimiento.despachoKit:
        return 'DESPACHO KIT';
    }
  }

  MovGroup get group {
    switch (this) {
      case TipoMovimiento.ingreso:
        return MovGroup.ingresos;
      case TipoMovimiento.egreso:
      case TipoMovimiento.egresoDirecto:
        return MovGroup.egresos;
      case TipoMovimiento.transferenciaEntrada:
        return MovGroup.ingresos;
      case TipoMovimiento.transferenciaSalida:
        return MovGroup.transferencias;
      case TipoMovimiento.despachoKit:
        return MovGroup.despachos;
    }
  }

  int get sign {
    switch (this) {
      case TipoMovimiento.ingreso:
      case TipoMovimiento.transferenciaEntrada:
        return 1;
      default:
        return -1;
    }
  }

  IconData get icon {
    switch (this) {
      case TipoMovimiento.ingreso:
        return Icons.south_rounded;
      case TipoMovimiento.egreso:
        return Icons.north_rounded;
      case TipoMovimiento.egresoDirecto:
        return Icons.edit_note_rounded;
      case TipoMovimiento.transferenciaEntrada:
        return Icons.south_west_rounded;
      case TipoMovimiento.transferenciaSalida:
        return Icons.north_east_rounded;
      case TipoMovimiento.despachoKit:
        return Icons.medical_services_outlined;
    }
  }

  ({Color fg, Color bg}) get colors {
    switch (group) {
      case MovGroup.ingresos:
        return (fg: CendentColors.green, bg: CendentColors.greenSoft);
      case MovGroup.egresos:
      case MovGroup.despachos:
        return (fg: CendentColors.red, bg: CendentColors.redSoft);
      case MovGroup.transferencias:
        return this == TipoMovimiento.transferenciaEntrada
            ? (fg: CendentColors.teal, bg: CendentColors.tealSoft)
            : (fg: CendentColors.amber, bg: CendentColors.amberSoft);
    }
  }
}

class ProductoRef {
  final String nombreMat;
  final String subcategoria;
  const ProductoRef(this.nombreMat, this.subcategoria);
}

class LoteRef {
  final String codigoLote;
  const LoteRef(this.codigoLote);
}

class UsuarioRef {
  final String nomUsuario;
  const UsuarioRef(this.nomUsuario);
}

class KitRef {
  final String nombreProcedimiento;
  const KitRef(this.nombreProcedimiento);
}

class TransferenciaRef {
  final String sucursalOrigen;
  final String sucursalDestino;
  const TransferenciaRef(this.sucursalOrigen, this.sucursalDestino);
}

class Movimiento {
  final String idMovimiento;
  final TipoMovimiento tipo;
  final int cantidad;
  final DateTime fecha;
  final ProductoRef producto;
  final LoteRef lote;
  final UsuarioRef usuario;
  final KitRef? kit;
  final TransferenciaRef? transferencia;

  const Movimiento({
    required this.idMovimiento,
    required this.tipo,
    required this.cantidad,
    required this.fecha,
    required this.producto,
    required this.lote,
    required this.usuario,
    this.kit,
    this.transferencia,
  });
}

// =============================================================================
//  MAPEO JSON → Movimiento
// =============================================================================

// Convierte cualquier valor numérico o string numérico a int de forma segura.
int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

Movimiento _fromJson(dynamic j) {
  final tipoRaw = j['tipo_mov']?.toString() ?? '';
  final tipo = TipoMovimientoX.fromRaw(tipoRaw);

  // Las relaciones Prisma pueden venir como null si la FK es null.
  final loteJson = j['lotes'];
  final prod     = loteJson != null ? loteJson['productos']  : null;
  final suc      = loteJson != null ? loteJson['sucursales'] : null;
  final usuario  = j['usuarios'];
  final kitJson  = j['kits'];

  final isTransfer = tipo == TipoMovimiento.transferenciaEntrada ||
      tipo == TipoMovimiento.transferenciaSalida;
  final sucNombre = suc != null ? (suc['nom_sucursal']?.toString() ?? '—') : '—';

  return Movimiento(
    idMovimiento: j['id_movimiento']?.toString() ?? '—',
    tipo: tipo,
    cantidad: _toInt(j['cantidad']),
    // fecha_hora llega como ISO-8601 string desde Prisma.
    fecha: DateTime.tryParse(j['fecha_hora']?.toString() ?? '') ?? DateTime.now(),
    producto: ProductoRef(
      prod != null ? (prod['nombre_mat']?.toString()  ?? '—') : '—',
      prod != null ? (prod['subcategoria']?.toString() ?? '—') : '—',
    ),
    lote: LoteRef(loteJson != null ? (loteJson['codigo_lote']?.toString() ?? '—') : '—'),
    usuario: UsuarioRef(usuario != null ? (usuario['nom_usuario']?.toString() ?? '—') : '—'),
    kit: kitJson != null
        ? KitRef(kitJson['nombre_procedimiento']?.toString() ?? '—')
        : null,
    transferencia: isTransfer ? TransferenciaRef(sucNombre, sucNombre) : null,
  );
}

// =============================================================================
//  UTILIDADES DE FORMATO (es-LA)
// =============================================================================
String _two(int n) => n.toString().padLeft(2, '0');
String _fmtFecha(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _fmtHora(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String _fmtNum(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

String _iniciales(String nombre) {
  const stop = {'dra.', 'dr.', 'sr.', 'sra.', 'lic.'};
  final w = nombre
      .split(' ')
      .where((x) => x.isNotEmpty && !stop.contains(x.toLowerCase()))
      .toList();
  return w.take(2).map((x) => x[0]).join().toUpperCase();
}

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class MovimientosScreen extends StatefulWidget {
  final int idSucursal;
  final String nomSucursal;
  const MovimientosScreen({
    super.key,
    required this.idSucursal,
    this.nomSucursal = '',
  });

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

enum _LoadState { loading, error, ready }

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _api = ApiService();
  _LoadState _state = _LoadState.loading;
  List<Movimiento> _all = [];
  List<Movimiento> _visible = [];
  Map<MovGroup?, int> _counts = {
    null: 0,
    MovGroup.ingresos: 0,
    MovGroup.egresos: 0,
    MovGroup.transferencias: 0,
    MovGroup.despachos: 0,
  };

  MovGroup? _filter;
  String _search = '';
  String? _expandedId;

  DateTime _desde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _hasta = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _state = _LoadState.loading);
    try {
      final raw = await _api.getMovimientos(widget.idSucursal);
      if (!mounted) return;
      if (raw == null) {
        debugPrint('[MovimientosScreen] raw == null — fallo de conexión o auth expirado');
        setState(() => _state = _LoadState.error);
        return;
      }
      debugPrint('[MovimientosScreen] ${raw.length} movimientos recibidos, iniciando mapeo');
      final movs = raw.map<Movimiento>(_fromJson).toList();
      if (!mounted) return;
      debugPrint('[MovimientosScreen] mapeo OK — ${movs.length} movimientos');
      setState(() {
        _all = movs;
        _state = _LoadState.ready;
        _applyFilters();
      });
    } catch (e, st) {
      debugPrint('[MovimientosScreen] excepción en _load: $e\n$st');
      if (!mounted) return;
      setState(() => _state = _LoadState.error);
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _desde, end: _hasta),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: CendentColors.primary,
            onPrimary: Colors.white,
            surface: CendentColors.card,
            onSurface: CendentColors.ink,
          ),
        ),
        child: child!,
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _desde = range.start;
        _hasta = range.end;
        _applyFilters();
      });
    }
  }

  // Recalcula _visible y _counts a partir del estado actual. Llamar siempre
  // dentro de setState() cuando cambie _all, _filter, _search, _desde o _hasta.
  void _applyFilters() {
    final desdeDate = DateTime(_desde.year, _desde.month, _desde.day);
    final hastaDate = DateTime(_hasta.year, _hasta.month, _hasta.day, 23, 59, 59);

    // base: aplicar solo búsqueda y rango (sin filtro de grupo → sirve para counts)
    final base = _all.where((m) {
      if (_search.isNotEmpty &&
          !m.producto.nombreMat.toLowerCase().contains(_search.toLowerCase())) {
        return false;
      }
      return !m.fecha.isBefore(desdeDate) && !m.fecha.isAfter(hastaDate);
    }).toList();

    final c = <MovGroup?, int>{
      null: 0,
      MovGroup.ingresos: 0,
      MovGroup.egresos: 0,
      MovGroup.transferencias: 0,
      MovGroup.despachos: 0,
    };
    for (final m in base) {
      c[null] = (c[null] ?? 0) + 1;
      c[m.tipo.group] = (c[m.tipo.group] ?? 0) + 1;
    }
    _counts = c;

    // visible: aplicar adicionalmente el filtro de grupo
    _visible = _filter == null
        ? base
        : base.where((m) => m.tipo.group == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CendentColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Encabezado fijo ──────────────────────────────────────
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PageHead(nomSucursal: widget.nomSucursal),
                    const SizedBox(height: 22),
                    _Toolbar(
                      desde: _fmtFecha(_desde),
                      hasta: _fmtFecha(_hasta),
                      onSearch: (s) => setState(() {
                        _search = s;
                        _applyFilters();
                      }),
                      onPickRange: _pickRange,
                    ),
                    const SizedBox(height: 14),
                    _TypeChips(
                      active: _filter,
                      counts: _counts,
                      onChanged: (g) => setState(() {
                        _filter = g;
                        _applyFilters();
                      }),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
          // ─── Tabla (ocupa el espacio restante) ────────────────────
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                  child: _TableCard(
                    state: _state,
                    rows: _visible,
                    total: _counts[null] ?? 0,
                    expandedId: _expandedId,
                    onToggle: (id) => setState(() =>
                        _expandedId = _expandedId == id ? null : id),
                    onRetry: _load,
                  ),
                ),
              ),
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

// =============================================================================
//  PAGE HEAD
// =============================================================================
class _PageHead extends StatelessWidget {
  final String nomSucursal;
  const _PageHead({required this.nomSucursal});

  @override
  Widget build(BuildContext context) {
    final subtitle = nomSucursal.isNotEmpty
        ? 'Historial completo de movimientos'
        : 'Historial completo de movimientos';
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 14,
      spacing: 20,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Movimientos',
                style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: CendentColors.ink)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 14, color: CendentColors.secondary)),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
//  TOOLBAR — rango de fechas + búsqueda
// =============================================================================
class _Toolbar extends StatelessWidget {
  final String desde;
  final String hasta;
  final ValueChanged<String> onSearch;
  final VoidCallback onPickRange;
  const _Toolbar({
    required this.desde,
    required this.hasta,
    required this.onSearch,
    required this.onPickRange,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Rango de fechas
        InkWell(
          onTap: onPickRange,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: CendentColors.card,
              border: Border.all(color: CendentColors.hairline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dateCell(Icons.calendar_today_outlined, 'Desde', desde),
                Container(width: 1, height: 24, color: CendentColors.hairline),
                _dateCell(null, 'Hasta', hasta, trailingChevron: true),
              ],
            ),
          ),
        ),
        // Búsqueda
        SizedBox(
          width: 320,
          height: 44,
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 14, color: CendentColors.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar por producto…',
              hintStyle:
                  const TextStyle(color: CendentColors.muted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded,
                  size: 18, color: CendentColors.secondary),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 42, minHeight: 0),
              filled: true,
              fillColor: CendentColors.card,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CendentColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                    color: CendentColors.primary, width: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateCell(IconData? icon, String label, String value,
      {bool trailingChevron = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: CendentColors.secondary),
            const SizedBox(width: 9),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: CendentColors.muted)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: CendentColors.ink)),
            ],
          ),
          if (trailingChevron) ...[
            const SizedBox(width: 9),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: CendentColors.secondary),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
//  CHIPS DE TIPO
// =============================================================================
class _TypeChips extends StatelessWidget {
  final MovGroup? active;
  final Map<MovGroup?, int> counts;
  final ValueChanged<MovGroup?> onChanged;
  const _TypeChips(
      {required this.active, required this.counts, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = <({MovGroup? g, String label, Color? dot})>[
      (g: null, label: 'Todos', dot: null),
      (g: MovGroup.ingresos, label: 'Ingresos', dot: CendentColors.green),
      (g: MovGroup.egresos, label: 'Egresos', dot: CendentColors.red),
      (
        g: MovGroup.transferencias,
        label: 'Transferencias',
        dot: CendentColors.teal
      ),
      (g: MovGroup.despachos, label: 'Despachos', dot: CendentColors.red),
    ];
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: items
          .map((it) => _Chip(
                label: it.label,
                count: counts[it.g] ?? 0,
                dotColor: it.dot,
                active: active == it.g,
                onTap: () => onChanged(it.g),
              ))
          .toList(),
    );
  }
}

class _Chip extends StatefulWidget {
  final String label;
  final int count;
  final Color? dotColor;
  final bool active;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.count,
    required this.dotColor,
    required this.active,
    required this.onTap,
  });

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final Color bg = active
        ? CendentColors.primary
        : (_hover ? CendentColors.blueWash : CendentColors.card);
    final Color fg = active ? Colors.white : CendentColors.steel;
    final Color border = active
        ? CendentColors.primary
        : (_hover ? CendentColors.blueLight : CendentColors.hairline);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: active ? Colors.white : widget.dotColor,
                      shape: BoxShape.circle),
                ),
                const SizedBox(width: 7),
              ],
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.25)
                      : CendentColors.hairlineSoft,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text('${widget.count}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : CendentColors.steel)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  TARJETA DE TABLA + ESTADOS
// =============================================================================
class _TableCard extends StatelessWidget {
  final _LoadState state;
  final List<Movimiento> rows;
  final int total;
  final String? expandedId;
  final ValueChanged<String> onToggle;
  final VoidCallback onRetry;
  const _TableCard({
    required this.state,
    required this.rows,
    required this.total,
    required this.expandedId,
    required this.onToggle,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // SizedBox.expand() convierte las constraints sueltas que entrega Center
    // en constraints ajustadas (tight), de modo que el Container siempre tiene
    // tamaño definido. Esto es necesario para clipBehavior y para que los
    // Expanded hijos de la Column interior puedan distribuir altura.
    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: CendentColors.hairline),
          boxShadow: CendentColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (state == _LoadState.loading)
              const Expanded(child: _SkeletonTable())
            else if (state == _LoadState.error)
              Expanded(child: _ErrorState(onRetry: onRetry))
            else if (rows.isEmpty)
              const Expanded(child: _EmptyState())
            else ...[
              Expanded(
                // LayoutBuilder obtiene el ancho real acotado (ya no
                // double.infinity), evitando constraints inválidas en el
                // scroll horizontal.
                child: LayoutBuilder(
                  builder: (ctx, c) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      // Si el espacio disponible es mayor que 1080, la tabla
                      // se estira para llenarlo; si no, se fija en 1080 y el
                      // scroll horizontal se activa.
                      width: c.maxWidth > 1080 ? c.maxWidth : 1080,
                      child: _MovTable(
                        rows: rows,
                        expandedId: expandedId,
                        onToggle: onToggle,
                      ),
                    ),
                  ),
                ),
              ),
              _Pagination(shown: rows.length, total: total),
            ],
          ],
        ),
      ),
    );
  }
}

// ---- Tabla ----
class _MovTable extends StatelessWidget {
  final List<Movimiento> rows;
  final String? expandedId;
  final ValueChanged<String> onToggle;
  const _MovTable(
      {required this.rows, required this.expandedId, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Encabezado
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFBFD),
            border: Border(bottom: BorderSide(color: CendentColors.hairline)),
          ),
          child: const Row(
            children: [
              _HCell('Fecha y hora', width: 150),
              _HCell('Tipo', width: 180),
              _HCell('Producto', flex: true),
              _HCell('Cantidad', width: 120),
              _HCell('Responsable', width: 190),
              _HCell('Detalle', width: 210),
              _HCell('', width: 44),
            ],
          ),
        ),
        // Filas (lazy — solo construye las visibles en pantalla)
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (ctx, i) => _MovRow(
              mov: rows[i],
              expanded: expandedId == rows[i].idMovimiento,
              onTap: () => onToggle(rows[i].idMovimiento),
            ),
          ),
        ),
      ],
    );
  }
}

class _HCell extends StatelessWidget {
  final String label;
  final double? width;
  final bool flex;
  const _HCell(this.label, {this.width, this.flex = false});

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: CendentColors.secondary)),
    );
    if (flex) return Expanded(child: child);
    return SizedBox(width: width, child: child);
  }
}

class _MovRow extends StatefulWidget {
  final Movimiento mov;
  final bool expanded;
  final VoidCallback onTap;
  const _MovRow(
      {required this.mov, required this.expanded, required this.onTap});

  @override
  State<_MovRow> createState() => _MovRowState();
}

class _MovRowState extends State<_MovRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mov;
    final t = m.tipo;
    final pos = t.sign > 0;
    final qtyColor = pos ? CendentColors.green : CendentColors.red;
    final rowBg = (_hover || widget.expanded)
        ? CendentColors.blueWash
        : CendentColors.card;

    return Column(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              color: rowBg,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Fecha
                  SizedBox(
                    width: 150,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_fmtFecha(m.fecha),
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: CendentColors.ink)),
                          Text(_fmtHora(m.fecha),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: CendentColors.secondary)),
                        ],
                      ),
                    ),
                  ),
                  // Tipo
                  SizedBox(
                    width: 180,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _TypeBadge(tipo: t),
                      ),
                    ),
                  ),
                  // Producto
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(m.producto.nombreMat,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: CendentColors.ink)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(m.lote.codigoLote,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: CendentColors.secondary,
                                      fontFamily: 'monospace')),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 1),
                                decoration: BoxDecoration(
                                  color: CendentColors.hairlineSoft,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(m.producto.subcategoria,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: CendentColors.secondary)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Cantidad
                  SizedBox(
                    width: 120,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                          '${pos ? '+' : '−'}${_fmtNum(m.cantidad)} u',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: qtyColor)),
                    ),
                  ),
                  // Responsable
                  SizedBox(
                    width: 190,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color: CendentColors.blueTint,
                                borderRadius: BorderRadius.circular(9)),
                            alignment: Alignment.center,
                            child: Text(_iniciales(m.usuario.nomUsuario),
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: CendentColors.primary)),
                          ),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(m.usuario.nomUsuario,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: CendentColors.steel)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Detalle
                  SizedBox(
                    width: 210,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _DetailChip(mov: m),
                      ),
                    ),
                  ),
                  // Chevron
                  SizedBox(
                    width: 44,
                    child: AnimatedRotation(
                      turns: widget.expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: widget.expanded
                              ? CendentColors.primary
                              : CendentColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Detalle expandido
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: _ExpandedDetail(mov: m),
          crossFadeState: widget.expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
          sizeCurve: Curves.easeInOut,
        ),
        const Divider(height: 1, color: CendentColors.hairlineSoft),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final TipoMovimiento tipo;
  const _TypeBadge({required this.tipo});
  @override
  Widget build(BuildContext context) {
    final c = tipo.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tipo.icon, size: 13, color: c.fg),
          const SizedBox(width: 7),
          Text(tipo.label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                  color: c.fg)),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final Movimiento mov;
  const _DetailChip({required this.mov});

  @override
  Widget build(BuildContext context) {
    if (mov.kit != null) {
      return _chip(Icons.medical_services_outlined,
          mov.kit!.nombreProcedimiento,
          CendentColors.violet, CendentColors.violetSoft);
    }
    if (mov.transferencia != null) {
      final out = mov.tipo == TipoMovimiento.transferenciaSalida;
      final branch = out
          ? mov.transferencia!.sucursalDestino
          : mov.transferencia!.sucursalOrigen;
      return _chip(
          out ? Icons.north_east_rounded : Icons.south_west_rounded,
          out ? 'a $branch' : 'de $branch',
          CendentColors.primary,
          CendentColors.blueTint);
    }
    return const Text('—',
        style: TextStyle(fontSize: 13, color: CendentColors.muted));
  }

  Widget _chip(IconData icon, String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _ExpandedDetail extends StatelessWidget {
  final Movimiento mov;
  const _ExpandedDetail({required this.mov});

  @override
  Widget build(BuildContext context) {
    final pos = mov.tipo.sign > 0;
    final fields = <({String label, String value, bool mono, Color? color})>[
      (label: 'ID Movimiento', value: mov.idMovimiento, mono: true, color: null),
      (label: 'Lote', value: mov.lote.codigoLote, mono: true, color: null),
      (
        label: 'Subcategoría',
        value: mov.producto.subcategoria,
        mono: false,
        color: null
      ),
      (
        label: 'Cantidad',
        value: '${pos ? '+' : '−'}${_fmtNum(mov.cantidad)} unidades',
        mono: false,
        color: pos ? CendentColors.green : CendentColors.red
      ),
      (
        label: 'Responsable',
        value: mov.usuario.nomUsuario,
        mono: false,
        color: null
      ),
      (
        label: 'Fecha completa',
        value: '${_fmtFecha(mov.fecha)} ${_fmtHora(mov.fecha)}',
        mono: false,
        color: null
      ),
      if (mov.kit != null)
        (
          label: 'Kit despachado',
          value: mov.kit!.nombreProcedimiento,
          mono: false,
          color: null
        ),
      if (mov.transferencia != null)
        (
          label: 'Origen → Destino',
          value:
              '${mov.transferencia!.sucursalOrigen} → ${mov.transferencia!.sucursalDestino}',
          mono: false,
          color: null
        ),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFFAFBFE),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        children: fields
            .map((f) => SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(f.label.toUpperCase(),
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: CendentColors.muted)),
                      const SizedBox(height: 4),
                      Text(f.value,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: f.mono ? 'monospace' : null,
                              color: f.color ?? CendentColors.ink)),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ---- Paginación (informativa) ----
class _Pagination extends StatelessWidget {
  final int shown;
  final int total;
  const _Pagination({required this.shown, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CendentColors.hairline)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 10,
        spacing: 16,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: CendentColors.secondary),
              children: [
                const TextSpan(text: 'Mostrando '),
                TextSpan(
                    text: '$shown',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: CendentColors.ink)),
                const TextSpan(text: ' de '),
                TextSpan(
                    text: _fmtNum(total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: CendentColors.ink)),
                const TextSpan(text: ' movimientos'),
              ],
            ),
          ),
          const SizedBox.shrink(),
        ],
      ),
    );
  }
}

// =============================================================================
//  ESTADOS — skeleton / empty / error
// =============================================================================
class _SkeletonTable extends StatefulWidget {
  const _SkeletonTable();
  @override
  State<_SkeletonTable> createState() => _SkeletonTableState();
}

class _SkeletonTableState extends State<_SkeletonTable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(8, (_) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: CendentColors.hairlineSoft)),
          ),
          child: Row(
            children: [
              SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(80, 14),
                      const SizedBox(height: 6),
                      _bar(50, 11),
                    ],
                  )),
              const SizedBox(width: 20),
              _bar(130, 24, radius: 9999),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(180, 14),
                    const SizedBox(height: 6),
                    _bar(120, 11),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              _bar(60, 15),
              const SizedBox(width: 20),
              _bar(140, 30),
              const SizedBox(width: 20),
              _bar(120, 24, radius: 9999),
            ],
          ),
        );
      }),
    );
  }

  Widget _bar(double w, double h, {double radius = 7}) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t, 0),
              end: Alignment(1 + 3 * t, 0),
              colors: const [
                Color(0xFFEDF1F6),
                Color(0xFFF5F8FB),
                Color(0xFFEDF1F6),
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: CendentColors.blueTint,
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.inbox_outlined,
                size: 34, color: CendentColors.primary),
          ),
          const SizedBox(height: 20),
          const Text('Sin movimientos en este periodo',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: CendentColors.ink)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: const Text(
              'No se registraron movimientos para los filtros seleccionados. Ajuste el rango de fechas o el tipo de movimiento.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: CendentColors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: CendentColors.redSoft,
                borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.warning_amber_rounded,
                size: 34, color: CendentColors.red),
          ),
          const SizedBox(height: 18),
          const Text('No se pudo cargar el historial',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: CendentColors.ink)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: const Text(
              'Ocurrió un problema al obtener los movimientos. Verifique su conexión y reintente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: CendentColors.secondary),
            ),
          ),
          const SizedBox(height: 20),
          _RetryBtn(onTap: onRetry),
        ],
      ),
    );
  }
}

class _RetryBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _RetryBtn({required this.onTap});
  @override
  State<_RetryBtn> createState() => _RetryBtnState();
}

class _RetryBtnState extends State<_RetryBtn> {
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
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: _hover ? CendentColors.blueWash : CendentColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _hover ? CendentColors.blueLight : CendentColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.refresh_rounded,
                  size: 17,
                  color: _hover ? CendentColors.primary : CendentColors.steel),
              const SizedBox(width: 9),
              Text('Reintentar',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _hover
                          ? CendentColors.primary
                          : CendentColors.steel)),
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
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
      child: const Column(
        children: [
          Text(
            "Daniel's CEDENT S.A.  ·  Centro de Especialidades Odontológicas",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: CendentColors.secondary,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text('© 2026 — Todos los derechos reservados',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: CendentColors.secondary)),
        ],
      ),
    );
  }
}
