// =============================================================================
//  lib/screens/analitica_screen.dart
//  Sistema Web Daniel's CENDENT S.A. — Centro de Especialidades Odontológicas
//  Analítica Predictiva — Flutter 3.24 · Material 3 · desktop-first
//
//  API:
//    GET /analitica/prediccion/:idSucursal → getPrediccion
// =============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/cendent_colors.dart';

// =============================================================================
//  HELPERS
// =============================================================================
double _aDbl(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

// =============================================================================
//  MODELO
// =============================================================================
class _APrediccion {
  final String nombre;
  final double stock;
  final double consumo30;
  final int diasQuiebre;

  const _APrediccion({
    required this.nombre,
    required this.stock,
    required this.consumo30,
    required this.diasQuiebre,
  });

  double get consumoDia => diasQuiebre > 0 ? stock / diasQuiebre : 0;

  _ARiesgoStyle get riesgo => _ARiesgoStyle.of(diasQuiebre);
}

// =============================================================================
//  RIESGO STYLE
// =============================================================================
class _ARiesgoStyle {
  final Color fg;
  final Color bg;
  final String label;
  final double fill;
  const _ARiesgoStyle(this.fg, this.bg, this.label, this.fill);

  static _ARiesgoStyle of(int dias) {
    if (dias <= 7) {
      return _ARiesgoStyle(
        CendentColors.red,
        CendentColors.redSoft,
        'Crítico',
        (1.0 - (dias / 30.0)).clamp(0.0, 1.0),
      );
    } else if (dias <= 20) {
      return _ARiesgoStyle(
        CendentColors.amber,
        CendentColors.amberSoft,
        'Atención',
        (1.0 - (dias / 30.0)).clamp(0.0, 1.0),
      );
    } else {
      return _ARiesgoStyle(
        CendentColors.green,
        CendentColors.greenSoft,
        'Estable',
        (1.0 - (dias / 60.0)).clamp(0.0, 1.0),
      );
    }
  }
}

// =============================================================================
//  MAPPER
// =============================================================================
_APrediccion _aMapPrediccion(dynamic raw) => _APrediccion(
      nombre: (raw['nombre_mat'] as String?) ?? '—',
      stock: _aDbl(raw['stock_total']),
      consumo30: _aDbl(raw['consumo_predicho_30_dias']),
      diasQuiebre: (_aDbl(raw['dias_para_quiebre'])).round(),
    );

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class AnaliticaScreen extends StatefulWidget {
  final int idSucursal;
  final String nomSucursal;
  const AnaliticaScreen({
    super.key,
    required this.idSucursal,
    required this.nomSucursal,
  });

  @override
  State<AnaliticaScreen> createState() => _AnaliticaScreenState();
}

class _AnaliticaScreenState extends State<AnaliticaScreen> {
  final _api = ApiService();
  bool _loading = true;
  bool _loadingPrediccion = true;
  String? _loadError;
  List<_APrediccion> _predicciones = [];

  String _search = '';
  String? _filtroRiesgo; // null=todas, 'critico', 'atencion', 'estable'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = false; // muestra estructura inmediatamente
      _loadingPrediccion = true;
      _loadError = null;
      _predicciones = [];
    });

    _api.getPrediccion(widget.idSucursal).then((data) {
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _loadingPrediccion = false;
          _loadError = 'No se pudo obtener la predicción. Reintente.';
        });
        return;
      }
      final lista = (data['predicciones'] as List<dynamic>? ?? [])
          .map<_APrediccion>(_aMapPrediccion)
          .toList()
        ..sort((a, b) => a.diasQuiebre.compareTo(b.diasQuiebre));
      setState(() {
        _predicciones = lista;
        _loadingPrediccion = false;
      });
    // ignore: avoid_types_on_closure_parameters
    }).catchError((Object _) {
      if (!mounted) return;
      setState(() {
        _loadingPrediccion = false;
        _loadError = 'No se pudo obtener la predicción. Reintente.';
      });
    });
  }

  List<_APrediccion> get _visible {
    var list = _predicciones;
    if (_filtroRiesgo == 'critico') {
      list = list.where((p) => p.diasQuiebre <= 7).toList();
    } else if (_filtroRiesgo == 'atencion') {
      list = list.where((p) => p.diasQuiebre > 7 && p.diasQuiebre <= 20).toList();
    } else if (_filtroRiesgo == 'estable') {
      list = list.where((p) => p.diasQuiebre > 20).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) => p.nombre.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  int _count(String filtro) {
    if (filtro == 'critico') return _predicciones.where((p) => p.diasQuiebre <= 7).length;
    if (filtro == 'atencion') return _predicciones.where((p) => p.diasQuiebre > 7 && p.diasQuiebre <= 20).length;
    return _predicciones.where((p) => p.diasQuiebre > 20).length;
  }

  double get _totalConsumo30 =>
      _predicciones.fold(0, (s, p) => s + p.consumo30);

  Widget _buildContentSection() {
    if (_loadingPrediccion) return const _ASkeleton();
    if (_loadError != null) return _AErrorState(message: _loadError!, onRetry: _load);
    if (_predicciones.isEmpty) return const _AEmptyState();
    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AToolbar(
          onSearch: (s) => setState(() => _search = s),
          filtroRiesgo: _filtroRiesgo,
          onFiltro: (f) => setState(() => _filtroRiesgo = f),
          criticos: _count('critico'),
          atencion: _count('atencion'),
          estables: _count('estable'),
          total: _predicciones.length,
        ),
        const SizedBox(height: 18),
        if (visible.isEmpty)
          const _AEmptyFiltered()
        else
          _ATable(predicciones: visible),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const _ASkeleton();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AResumenCards(
          total: _loadingPrediccion ? null : _predicciones.length,
          criticos: _loadingPrediccion ? null : _count('critico'),
          consumoTotal: _loadingPrediccion ? null : _totalConsumo30,
        ),
        const SizedBox(height: 20),
        _buildContentSection(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CendentColors.bg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _APageHead(),
                        const SizedBox(height: 22),
                        _buildBody(),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const _AFooter(),
        ],
      ),
    );
  }
}

// =============================================================================
//  PAGE HEAD
// =============================================================================
class _APageHead extends StatelessWidget {
  const _APageHead();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Analítica Predictiva',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: CendentColors.ink,
                    ),
                  ),
                  SizedBox(width: 12),
                  _AIaBadge(),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Predicción de quiebre de stock por producto · modelo Brain.js',
                style: TextStyle(fontSize: 14, color: CendentColors.secondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AIaBadge extends StatelessWidget {
  const _AIaBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CendentColors.blueTint,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 13, color: CendentColors.primary),
          SizedBox(width: 5),
          Text(
            'IA',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: CendentColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  RESUMEN CARDS
// =============================================================================
class _AResumenCards extends StatelessWidget {
  final int? total;
  final int? criticos;
  final double? consumoTotal;
  const _AResumenCards({
    required this.total,
    required this.criticos,
    required this.consumoTotal,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      const gap = 16.0;
      final cols = c.maxWidth >= 900 ? 3 : 1;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          SizedBox(
            width: w,
            child: _AResumenCard(
              icon: Icons.inventory_2_outlined,
              iconColor: CendentColors.primary,
              iconBg: CendentColors.blueTint,
              value: total != null ? '$total' : '…',
              label: 'Productos analizados',
              sub: 'Con predicción de consumo',
            ),
          ),
          SizedBox(
            width: w,
            child: _AResumenCard(
              icon: Icons.trending_down_rounded,
              iconColor: CendentColors.red,
              iconBg: CendentColors.redSoft,
              value: criticos != null ? '$criticos' : '…',
              label: 'En estado crítico',
              sub: 'Quiebre en ≤ 7 días',
              valueColor: (criticos != null && criticos! > 0)
                  ? CendentColors.red
                  : null,
            ),
          ),
          SizedBox(
            width: w,
            child: _AResumenCard(
              icon: Icons.show_chart_rounded,
              iconColor: CendentColors.violet,
              iconBg: CendentColors.violetSoft,
              value: consumoTotal != null ? _fmt(consumoTotal!) : '…',
              unit: consumoTotal != null ? 'u' : null,
              label: 'Consumo predicho (30 d)',
              sub: 'Suma total de todos los productos',
            ),
          ),
        ],
      );
    });
  }

  static String _fmt(double n) {
    final s = n.round().toString();
    if (s.length <= 3) return s;
    return '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}';
  }
}

class _AResumenCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String? unit;
  final String label;
  final String sub;
  final Color? valueColor;
  const _AResumenCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    this.unit,
    required this.label,
    required this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline),
        boxShadow: CendentColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 21, color: iconColor),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
                height: 1,
                color: valueColor ?? CendentColors.ink,
              ),
              children: [
                if (unit != null)
                  TextSpan(
                    text: '  $unit',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CendentColors.secondary,
                      letterSpacing: 0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CendentColors.secondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 13, color: CendentColors.muted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  sub,
                  style: const TextStyle(
                      fontSize: 12, color: CendentColors.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  TOOLBAR
// =============================================================================
class _AToolbar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final String? filtroRiesgo;
  final ValueChanged<String?> onFiltro;
  final int total;
  final int criticos;
  final int atencion;
  final int estables;
  const _AToolbar({
    required this.onSearch,
    required this.filtroRiesgo,
    required this.onFiltro,
    required this.total,
    required this.criticos,
    required this.atencion,
    required this.estables,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 340,
          height: 44,
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 14, color: CendentColors.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar producto…',
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
        _AFilterChip(
          label: 'Todos',
          count: total,
          active: filtroRiesgo == null,
          onTap: () => onFiltro(null),
          fg: CendentColors.primary,
          bg: CendentColors.blueTint,
        ),
        _AFilterChip(
          label: 'Crítico',
          count: criticos,
          active: filtroRiesgo == 'critico',
          onTap: () => onFiltro('critico'),
          fg: CendentColors.red,
          bg: CendentColors.redSoft,
        ),
        _AFilterChip(
          label: 'Atención',
          count: atencion,
          active: filtroRiesgo == 'atencion',
          onTap: () => onFiltro('atencion'),
          fg: CendentColors.amber,
          bg: CendentColors.amberSoft,
        ),
        _AFilterChip(
          label: 'Estable',
          count: estables,
          active: filtroRiesgo == 'estable',
          onTap: () => onFiltro('estable'),
          fg: CendentColors.green,
          bg: CendentColors.greenSoft,
        ),
      ],
    );
  }
}

class _AFilterChip extends StatefulWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final Color fg;
  final Color bg;
  const _AFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    required this.fg,
    required this.bg,
  });
  @override
  State<_AFilterChip> createState() => _AFilterChipState();
}

class _AFilterChipState extends State<_AFilterChip> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? widget.fg
                : (_hover ? widget.bg : CendentColors.card),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? widget.fg : CendentColors.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : CendentColors.steel,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.25)
                      : widget.bg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : widget.fg,
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

// =============================================================================
//  TABLE
// =============================================================================
class _ATable extends StatelessWidget {
  final List<_APrediccion> predicciones;
  const _ATable({required this.predicciones});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline),
        boxShadow: CendentColors.cardShadow,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 900),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(3),    // PRODUCTO
                1: FixedColumnWidth(120), // STOCK
                2: FixedColumnWidth(140), // CONSUMO 30d
                3: FixedColumnWidth(140), // DÍAS QUIEBRE
                4: FlexColumnWidth(2),    // RIESGO (barra)
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: CendentColors.hairline)),
                  ),
                  children: [
                    _th('Producto'),
                    _th('Stock actual'),
                    _th('Consumo 30 d'),
                    _th('Días al quiebre'),
                    _th('Nivel de riesgo'),
                  ],
                ),
                ...predicciones.asMap().entries.map((e) {
                  final p = e.value;
                  final isLast = e.key == predicciones.length - 1;
                  final r = p.riesgo;
                  return TableRow(
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(
                                  color: CendentColors.hairlineSoft)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: r.bg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.inventory_2_outlined,
                                  size: 16, color: r.fg),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                p.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: CendentColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _td(Text(
                        '${p.stock.toStringAsFixed(0)} u',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: CendentColors.ink),
                      )),
                      _td(Text(
                        '~${p.consumo30.toStringAsFixed(0)} u',
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: CendentColors.ink),
                      )),
                      _td(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: r.bg,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${p.diasQuiebre}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: r.fg,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                ' días',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: r.fg),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  r.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: r.fg,
                                  ),
                                ),
                                Text(
                                  '~${p.consumoDia.toStringAsFixed(0)} u/día',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: CendentColors.secondary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9999),
                              child: LinearProgressIndicator(
                                value: r.fill,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFEDF1F5),
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(r.fg),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _th(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: CendentColors.secondary,
          ),
        ),
      );

  Widget _td(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      );
}

// =============================================================================
//  ESTADOS VACÍO / ERROR / SKELETON
// =============================================================================
class _AEmptyState extends StatelessWidget {
  const _AEmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: CendentColors.blueTint,
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.auto_awesome_outlined,
                  size: 32, color: CendentColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin datos de predicción',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CendentColors.ink),
            ),
            const SizedBox(height: 6),
            const Text(
              'Registra movimientos de egreso para que el modelo pueda entrenarse.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: CendentColors.secondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _AEmptyFiltered extends StatelessWidget {
  const _AEmptyFiltered();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Sin productos para el filtro seleccionado.',
          style: TextStyle(fontSize: 14, color: CendentColors.secondary),
        ),
      ),
    );
  }
}

class _AErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _AErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: CendentColors.secondary),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CendentColors.ink)),
            const SizedBox(height: 18),
            _ABtn(
              icon: Icons.refresh_rounded,
              label: 'Reintentar',
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ASkeleton extends StatelessWidget {
  const _ASkeleton();
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Resumen cards skeleton
        LayoutBuilder(builder: (_, c) {
          const gap = 16.0;
          final cols = c.maxWidth >= 900 ? 3 : 1;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: List.generate(
              3,
              (_) => SizedBox(
                width: w,
                height: 130,
                child: Container(
                  decoration: BoxDecoration(
                    color: CendentColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: CendentColors.hairline),
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        // Loading notice
        Container(
          height: 280,
          decoration: BoxDecoration(
            color: CendentColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: CendentColors.hairline),
            boxShadow: CendentColors.cardShadow,
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                    color: CendentColors.primary, strokeWidth: 2.5),
                SizedBox(height: 18),
                Text(
                  'Calculando predicciones con IA…',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CendentColors.secondary),
                ),
                SizedBox(height: 6),
                Text(
                  'El modelo Brain.js puede tardar hasta 2 minutos.',
                  style:
                      TextStyle(fontSize: 12, color: CendentColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  BOTÓN SIMPLE
// =============================================================================
class _ABtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ABtn({required this.icon, required this.label, required this.onTap});
  @override
  State<_ABtn> createState() => _ABtnState();
}

class _ABtnState extends State<_ABtn> {
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
            color: _hover ? CendentColors.blueTint : CendentColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CendentColors.blueLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: CendentColors.primary),
              const SizedBox(width: 8),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: CendentColors.primary)),
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
class _AFooter extends StatelessWidget {
  const _AFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
      child: const Column(
        children: [
          Text(
            "Daniel's CENDENT S.A.  ·  Centro de Especialidades Odontológicas",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12,
                color: CendentColors.secondary,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4),
          Text(
            '© 2026 — Todos los derechos reservados',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: CendentColors.secondary),
          ),
        ],
      ),
    );
  }
}
