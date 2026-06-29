// =============================================================================
//  lib/screens/kits_screen.dart
//  Sistema Web Daniel's CENDENT S.A. — Centro de Especialidades Odontológicas
//  Kits de Procedimientos — Flutter 3.24 · Material 3 · desktop-first
//
//  API real:
//    GET    /kits                         → _loadKits
//    GET    /productos/inventario?id_sucursal=X → productos para el picker
//    POST   /kits                         → crearKit
//    PATCH  /kits/:id                     → actualizarKit
//    DELETE /kits/:id                     → eliminarKit
//    POST   /movimientos/despachar-kit    → despacharKit
// =============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/cendent_colors.dart';

// =============================================================================
//  ENUMS & MODELOS  (prefijo _K para no colisionar con inventario_screen.dart)
// =============================================================================
enum _KProdCat { anestesicos, insumos, restauracion, instrumental }

class _KItem {
  final int idProducto;
  final String nombre;
  final String sku;
  final _KProdCat cat;
  final int cantidad;
  final int stock;
  final bool esVariable;
  final int idDetalle;
  const _KItem({
    required this.idProducto,
    required this.nombre,
    required this.sku,
    required this.cat,
    required this.cantidad,
    required this.stock,
    this.esVariable = false,
    this.idDetalle = 0,
  });
  bool get stockInsuficiente => stock < cantidad;
}

class _Kit {
  final int idKit;
  final String nombre;
  final List<_KItem> items;
  const _Kit({required this.idKit, required this.nombre, required this.items});
}

class _ProdInfo {
  final int idProducto;
  final String nombre;
  final String sku;
  final _KProdCat cat;
  final int stock;
  const _ProdInfo({
    required this.idProducto,
    required this.nombre,
    required this.sku,
    required this.cat,
    required this.stock,
  });
}

class _DraftItem {
  final int idProducto;
  final String nombre;
  final String sku;
  final _KProdCat cat;
  int qty;
  _DraftItem({
    required this.idProducto,
    required this.nombre,
    required this.sku,
    required this.cat,
    this.qty = 1,
  });
}

// =============================================================================
//  HELPERS
// =============================================================================
double _kToDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

_KProdCat _kParseCat(String? sub) {
  final s = (sub ?? '').toUpperCase();
  if (s.contains('ANES')) return _KProdCat.anestesicos;
  if (s.contains('RESINA') || s.contains('CEMENTA') || s.contains('MATER')) {
    return _KProdCat.restauracion;
  }
  if (s.contains('INSTR') || s.contains('ARCO') || s.contains('BRACKET')) {
    return _KProdCat.instrumental;
  }
  return _KProdCat.insumos;
}

class _KCatStyle {
  final IconData icon;
  final Color fg;
  final Color bg;
  const _KCatStyle(this.icon, this.fg, this.bg);

  static _KCatStyle of(_KProdCat c) {
    switch (c) {
      case _KProdCat.anestesicos:
        return const _KCatStyle(Icons.vaccines_outlined, CendentColors.primary, CendentColors.blueTint);
      case _KProdCat.insumos:
        return const _KCatStyle(Icons.inventory_2_outlined, CendentColors.teal, CendentColors.tealSoft);
      case _KProdCat.restauracion:
        return const _KCatStyle(Icons.circle_outlined, CendentColors.violet, CendentColors.violetSoft);
      case _KProdCat.instrumental:
        return const _KCatStyle(Icons.handyman_outlined, CendentColors.steel, Color(0xFFEAEFF4));
    }
  }
}

_ProdInfo _kMapProdInfo(dynamic p) {
  final id = (p['id_producto'] as int?) ?? 0;
  final sub = (p['subcategoria'] as String?) ?? '';
  final prefix = sub.length >= 4 ? sub.substring(0, 4).toUpperCase() : sub.toUpperCase();
  return _ProdInfo(
    idProducto: id,
    nombre: (p['nombre_mat'] as String?) ?? '—',
    sku: '$prefix-${id.toString().padLeft(4, '0')}',
    cat: _kParseCat(sub),
    stock: _kToDouble(p['stock_total']).round(),
  );
}

_Kit _kMapKit(dynamic raw, Map<int, _ProdInfo> prodMap) {
  final id = (raw['id_kit'] as int?) ?? 0;
  final nombre = (raw['nombre_procedimiento'] as String?) ?? '—';
  final rawItems = (raw['detalle_kit'] as List?) ?? [];

  final items = rawItems.map<_KItem>((d) {
    final idProd = (d['id_producto'] as int?) ?? 0;
    final idDetalle = (d['id_detalle'] as int?) ?? 0;
    final esVariable = (d['es_variable'] as bool?) ?? false;
    final prod = d['productos'];
    final prodInfo = prodMap[idProd];
    final sub = (prod?['subcategoria'] as String?) ?? '';
    return _KItem(
      idProducto: idProd,
      nombre: (prod?['nombre_mat'] as String?) ?? '—',
      sku: prodInfo?.sku ?? '—',
      cat: _kParseCat(sub),
      cantidad: _kToDouble(d['cantidad_estandar']).round(),
      stock: prodInfo?.stock ?? 0,
      esVariable: esVariable,
      idDetalle: idDetalle,
    );
  }).toList();

  return _Kit(idKit: id, nombre: nombre, items: items);
}

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class KitsScreen extends StatefulWidget {
  final int idSucursal;
  const KitsScreen({super.key, required this.idSucursal});

  @override
  State<KitsScreen> createState() => _KitsScreenState();
}

class _KitsScreenState extends State<KitsScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _loadError;
  List<_Kit> _kits = [];
  List<_ProdInfo> _productos = [];

  String _search = '';
  _Kit? _detailKit;

  @override
  void initState() {
    super.initState();
    _loadKits();
  }

  Future<void> _loadKits() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final results = await Future.wait([
        _api.getKits(),
        _api.getInventario(widget.idSucursal),
      ]);
      if (!mounted) return;

      final rawKits = results[0];
      final rawProds = results[1];

      if (rawKits == null) {
        setState(() { _loading = false; _loadError = 'No se pudieron cargar los kits. Reintente.'; });
        return;
      }

      final prods = (rawProds ?? []).map<_ProdInfo>(_kMapProdInfo).toList();
      final map = <int, _ProdInfo>{for (final p in prods) p.idProducto: p};
      final kits = rawKits.map<_Kit>((k) => _kMapKit(k, map)).toList();

      setState(() {
        _productos = prods;
        _kits = kits;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _loadError = 'No se pudieron cargar los kits. Reintente.'; });
    }
  }

  List<_Kit> get _visible {
    if (_search.isEmpty) return _kits;
    final q = _search.toLowerCase();
    return _kits.where((k) => k.nombre.toLowerCase().contains(q)).toList();
  }

  Future<void> _openCreate() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _KitEditorDialog(kit: null, productos: _productos),
    );
    if (saved == true && mounted) {
      _api.invalidateCache();
      await _loadKits();
      if (mounted) _toast('Kit creado');
    }
  }

  Future<void> _openEditFor(_Kit k) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _KitEditorDialog(kit: k, productos: _productos),
    );
    if (saved == true && mounted) {
      _api.invalidateCache();
      await _loadKits();
      if (mounted) _toast('Kit actualizado');
    }
  }

  Future<void> _confirmDelete(_Kit k) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _DeleteKitDialog(kit: k),
    );
    if (deleted == true && mounted) {
      _api.invalidateCache();
      if (_detailKit?.idKit == k.idKit) setState(() => _detailKit = null);
      await _loadKits();
      if (mounted) _toast('Kit eliminado');
    }
  }

  Future<void> _dispatch(_Kit k) async {
    setState(() => _detailKit = null);
    final varItems = k.items.where((i) => i.esVariable).toList();

    if (varItems.isEmpty) {
      final (:ok, :errorMsg, :data) = await _api.despacharKit(k.idKit);
      if (!mounted) return;
      if (ok) {
        _api.invalidateCache();
        _loadKits();
        _toastLotes(k.nombre, data);
      } else {
        _toast(errorMsg ?? 'Error al despachar el kit');
      }
    } else {
      final despachoData = await showDialog<dynamic>(
        context: context,
        barrierDismissible: true,
        barrierColor: const Color(0x800D1B2A),
        builder: (_) => _DespacharKitDialog(kit: k, productos: _productos),
      );
      if (despachoData is Map && mounted) {
        _api.invalidateCache();
        await _loadKits();
        if (mounted) _toastLotes(k.nombre, despachoData);
      }
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CendentColors.ink,
        width: 400,
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

  void _toastLotes(String kitNombre, dynamic data) {
    final lotes = data is Map ? (data['lotes_usados'] as List? ?? <dynamic>[]) : <dynamic>[];
    final String msg;
    if (lotes.isEmpty) {
      msg = 'Kit "$kitNombre" despachado';
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

  Widget _buildBody() {
    if (_loading) return const _KitsSkeleton();
    if (_loadError != null) return _KErrorState(message: _loadError!, onRetry: _loadKits);
    if (_kits.isEmpty) return _KEmptyState(onCreate: _openCreate, noneAtAll: true);
    final visible = _visible;
    if (visible.isEmpty) return const _KEmptyState(noneAtAll: false);
    return _KitGrid(
      kits: visible,
      onView: (k) => setState(() => _detailKit = k),
      onEdit: _openEditFor,
      onDelete: _confirmDelete,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
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
                            _KPageHead(onCreate: _openCreate),
                            const SizedBox(height: 22),
                            _KToolbar(onSearch: (s) => setState(() => _search = s)),
                            const SizedBox(height: 18),
                            _buildBody(),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const _KFooter(),
            ],
          ),
        ),

        // Scrim
        IgnorePointer(
          ignoring: _detailKit == null,
          child: AnimatedOpacity(
            opacity: _detailKit == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () => setState(() => _detailKit = null),
              child: Container(color: const Color(0x6B0D1B2A)),
            ),
          ),
        ),

        // Detail panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          top: 0, bottom: 0,
          right: _detailKit == null ? -460 : 0,
          width: 440,
          child: _detailKit == null
              ? const SizedBox.shrink()
              : _KitDetailPanel(
                  kit: _detailKit!,
                  onClose: () => setState(() => _detailKit = null),
                  onEdit: () {
                    final k = _detailKit!;
                    setState(() => _detailKit = null);
                    _openEditFor(k);
                  },
                  onDispatch: () => _dispatch(_detailKit!),
                ),
        ),
      ],
    );
  }
}

// =============================================================================
//  PAGE HEAD
// =============================================================================
class _KPageHead extends StatelessWidget {
  final VoidCallback onCreate;
  const _KPageHead({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 14,
      spacing: 20,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kits de Procedimientos',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: CendentColors.ink)),
            SizedBox(height: 4),
            Text('Gestión de kits para procedimientos odontológicos',
                style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
          ],
        ),
        _KBtn(icon: Icons.add_rounded, label: 'Crear kit', kind: _KBtnKind.primary, onTap: onCreate),
      ],
    );
  }
}

// =============================================================================
//  TOOLBAR
// =============================================================================
class _KToolbar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  const _KToolbar({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 380,
      height: 44,
      child: TextField(
        onChanged: onSearch,
        style: const TextStyle(fontSize: 14, color: CendentColors.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar kit por nombre…',
          hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: CendentColors.secondary),
          prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 0),
          filled: true,
          fillColor: CendentColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CendentColors.hairline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CendentColors.primary, width: 1.6),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  KIT GRID
// =============================================================================
class _KitGrid extends StatelessWidget {
  final List<_Kit> kits;
  final ValueChanged<_Kit> onView;
  final ValueChanged<_Kit> onEdit;
  final ValueChanged<_Kit> onDelete;
  const _KitGrid({required this.kits, required this.onView, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = box.maxWidth;
        final cols = (w / 400).floor().clamp(1, 4);
        final itemW = (w - (cols - 1) * 18) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: kits.map((k) => SizedBox(
            width: itemW,
            child: _KitCard(
              kit: k,
              onView: () => onView(k),
              onEdit: () => onEdit(k),
              onDelete: () => onDelete(k),
            ),
          )).toList(),
        );
      },
    );
  }
}

// =============================================================================
//  KIT CARD
// =============================================================================
class _KitCard extends StatefulWidget {
  final _Kit kit;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _KitCard({required this.kit, required this.onView, required this.onEdit, required this.onDelete});

  @override
  State<_KitCard> createState() => _KitCardState();
}

class _KitCardState extends State<_KitCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final k = widget.kit;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onView,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: CendentColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _hover ? CendentColors.blueLight : CendentColors.hairline),
            boxShadow: _hover
                ? [const BoxShadow(color: Color(0x331565C0), blurRadius: 32, spreadRadius: -8, offset: Offset(0, 12))]
                : CendentColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + name
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: CendentColors.blueTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medical_services_outlined, size: 24, color: CendentColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(k.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2, height: 1.3, color: CendentColors.ink)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: CendentColors.greenSoft, borderRadius: BorderRadius.circular(9999)),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 11, color: CendentColors.green),
                              SizedBox(width: 4),
                              Text('Activo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CendentColors.green)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Footer: item count + actions
              Container(
                padding: const EdgeInsets.only(top: 14),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairlineSoft))),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 15, color: CendentColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      '${k.items.length} producto${k.items.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CendentColors.steel),
                    ),
                    const Spacer(),
                    _KActBtn(
                      icon: Icons.visibility_outlined,
                      tooltip: 'Ver detalle',
                      onTap: widget.onView,
                    ),
                    _KActBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Editar',
                      onTap: widget.onEdit,
                    ),
                    _KActBtn(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Eliminar',
                      danger: true,
                      onTap: widget.onDelete,
                    ),
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

class _KActBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  const _KActBtn({required this.icon, required this.tooltip, required this.onTap, this.danger = false});

  @override
  State<_KActBtn> createState() => _KActBtnState();
}

class _KActBtnState extends State<_KActBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final Color fg = widget.danger
        ? (_hover ? CendentColors.red : CendentColors.secondary)
        : (_hover ? CendentColors.primary : CendentColors.secondary);
    final Color bg = widget.danger
        ? (_hover ? CendentColors.redSoft : Colors.transparent)
        : (_hover ? CendentColors.blueTint : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34, height: 34,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  DETAIL PANEL
// =============================================================================
class _KitDetailPanel extends StatelessWidget {
  final _Kit kit;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDispatch;
  const _KitDetailPanel({
    required this.kit,
    required this.onClose,
    required this.onEdit,
    required this.onDispatch,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CendentColors.card,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: CendentColors.card,
          boxShadow: CendentColors.popShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(kit.nombre,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: CendentColors.ink)),
                  ),
                  const SizedBox(width: 12),
                  _KCloseBtn(onTap: onClose),
                ],
              ),
            ),

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('PRODUCTOS DEL KIT',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: CendentColors.secondary)),
                        Text('${kit.items.length} producto${kit.items.length != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CendentColors.muted)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (kit.items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CendentColors.hairline),
                        ),
                        child: const Text('Este kit no tiene productos definidos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                      )
                    else
                      ...kit.items.asMap().entries.map((e) {
                        final item = e.value;
                        final cat = _KCatStyle.of(item.cat);
                        final isLast = e.key == kit.items.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: isLast ? BorderSide.none : const BorderSide(color: CendentColors.hairlineSoft),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(color: cat.bg, borderRadius: BorderRadius.circular(10)),
                                child: Icon(cat.icon, size: 18, color: cat.fg),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.nombre,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                                    Text(item.sku,
                                        style: const TextStyle(fontSize: 11.5, color: CendentColors.secondary, fontFamily: 'monospace')),
                                    if (item.stockInsuficiente)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, size: 11, color: CendentColors.red),
                                            const SizedBox(width: 4),
                                            Text('Stock insuficiente (${item.stock} u disponibles)',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CendentColors.red)),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text('${item.cantidad} ',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CendentColors.ink)),
                              const Text('u', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CendentColors.secondary)),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
              child: Row(
                children: [
                  Expanded(child: _KBtn(icon: Icons.edit_outlined, label: 'Editar kit', kind: _KBtnKind.secondary, onTap: onEdit)),
                  const SizedBox(width: 12),
                  Expanded(child: _KBtn(icon: Icons.check_circle_outline_rounded, label: 'Despachar', kind: _KBtnKind.primary, onTap: onDispatch)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KCloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _KCloseBtn({required this.onTap});
  @override
  State<_KCloseBtn> createState() => _KCloseBtnState();
}

class _KCloseBtnState extends State<_KCloseBtn> {
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
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _hover ? CendentColors.redSoft : CendentColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CendentColors.hairline),
          ),
          child: Icon(Icons.close_rounded, size: 18, color: _hover ? CendentColors.red : CendentColors.steel),
        ),
      ),
    );
  }
}

// =============================================================================
//  EDITOR MODAL (crear / editar)
// =============================================================================
class _KitEditorDialog extends StatefulWidget {
  final _Kit? kit;
  final List<_ProdInfo> productos;
  const _KitEditorDialog({required this.kit, required this.productos});

  @override
  State<_KitEditorDialog> createState() => _KitEditorDialogState();
}

class _KitEditorDialogState extends State<_KitEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _api = ApiService();

  List<_DraftItem> _draft = [];
  List<_ProdInfo> _results = [];
  bool _showResults = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final k = widget.kit;
    if (k != null) {
      _nombreCtrl.text = k.nombre;
      _draft = k.items.map((i) => _DraftItem(
        idProducto: i.idProducto,
        nombre: i.nombre,
        sku: i.sku,
        cat: i.cat,
        qty: i.cantidad,
      )).toList();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) {
      setState(() { _results = []; _showResults = false; });
      return;
    }
    final matches = widget.productos
        .where((p) => p.nombre.toLowerCase().contains(t) || p.sku.toLowerCase().contains(t))
        .take(8)
        .toList();
    setState(() { _results = matches; _showResults = true; });
  }

  void _addProduct(_ProdInfo p) {
    if (_draft.any((d) => d.idProducto == p.idProducto)) return;
    setState(() {
      _draft.add(_DraftItem(idProducto: p.idProducto, nombre: p.nombre, sku: p.sku, cat: p.cat));
      _searchCtrl.clear();
      _results = [];
      _showResults = false;
      _error = null;
    });
  }

  void _removeProduct(int idProducto) {
    setState(() => _draft.removeWhere((d) => d.idProducto == idProducto));
  }

  void _setQty(int idProducto, int qty) {
    setState(() {
      final item = _draft.firstWhere((d) => d.idProducto == idProducto);
      item.qty = qty.clamp(1, 9999);
    });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_draft.isEmpty) {
      setState(() => _error = 'Agregue al menos un producto al kit.');
      return;
    }
    setState(() { _saving = true; _error = null; });

    final nombre = _nombreCtrl.text.trim();
    final detalle = _draft.map((d) => {
      'id_producto': d.idProducto,
      'cantidad_estandar': d.qty,
      'es_variable': false,
    }).toList();

    if (widget.kit != null) {
      final result = await _api.actualizarKit(
        idKit: widget.kit!.idKit,
        nombreProcedimiento: nombre,
        detalle: detalle,
      );
      if (!mounted) return;
      if (!result.ok) {
        setState(() { _saving = false; _error = result.errorMsg ?? 'Error al actualizar el kit'; });
        return;
      }
    } else {
      final create = await _api.crearKit(nombreProcedimiento: nombre, detalle: detalle);
      if (!mounted) return;
      if (!create.ok) {
        setState(() { _saving = false; _error = create.errorMsg ?? 'Error al crear el kit'; });
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: CendentColors.card,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.hairline)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.primary, width: 1.6)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.red, width: 1.6)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.hairline)),
  );

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.kit != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 780),
        child: Material(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isEdit ? 'Editar kit' : 'Crear kit',
                                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: CendentColors.ink)),
                            const SizedBox(height: 4),
                            Text(isEdit ? 'Modifique el procedimiento y sus productos.' : 'Defina el procedimiento y los productos que lo componen.',
                                style: const TextStyle(fontSize: 13, color: CendentColors.secondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _KCloseBtn(onTap: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),

                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Nombre
                        const _KFieldLabel('Nombre del procedimiento', required: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _nombreCtrl,
                          enabled: !_saving,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('p. ej. Extracción simple'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingrese el nombre del procedimiento.' : null,
                        ),
                        const SizedBox(height: 20),

                        // Product picker
                        const _KFieldLabel('Productos del kit', required: true),
                        const SizedBox(height: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              enabled: !_saving,
                              onChanged: _onSearch,
                              style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                              decoration: InputDecoration(
                                hintText: 'Buscar producto del inventario para agregar…',
                                hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
                                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: CendentColors.secondary),
                                prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 0),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                filled: true,
                                fillColor: CendentColors.card,
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.hairline)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: CendentColors.primary, width: 1.6)),
                              ),
                            ),
                            if (_showResults && _results.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints: const BoxConstraints(maxHeight: 220),
                                decoration: BoxDecoration(
                                  color: CendentColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: CendentColors.hairline),
                                  boxShadow: const [BoxShadow(color: Color(0x220D1B2A), blurRadius: 16, offset: Offset(0, 6))],
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  itemCount: _results.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: CendentColors.hairlineSoft),
                                  itemBuilder: (ctx, i) {
                                    final p = _results[i];
                                    final added = _draft.any((d) => d.idProducto == p.idProducto);
                                    return InkWell(
                                      onTap: added ? null : () => _addProduct(p),
                                      borderRadius: i == 0
                                          ? const BorderRadius.vertical(top: Radius.circular(14))
                                          : i == _results.length - 1
                                              ? const BorderRadius.vertical(bottom: Radius.circular(14))
                                              : BorderRadius.zero,
                                      child: Opacity(
                                        opacity: added ? 0.45 : 1,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(p.nombre, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                                                    Text(p.sku, style: const TextStyle(fontSize: 11.5, color: CendentColors.secondary, fontFamily: 'monospace')),
                                                  ],
                                                ),
                                              ),
                                              Text(added ? 'Agregado' : '${p.stock} u',
                                                  style: const TextStyle(fontSize: 12, color: CendentColors.secondary)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            if (_showResults && _results.isEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: CendentColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: CendentColors.hairline),
                                ),
                                child: const Text('Sin productos que coincidan.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Draft items list
                        if (_draft.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(style: BorderStyle.solid, color: CendentColors.hairline),
                            ),
                            child: const Text('Aún no hay productos. Búsquelos arriba y agréguelos al kit.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                          )
                        else
                          ..._draft.map((d) => _DraftRow(
                            item: d,
                            onRemove: () => _removeProduct(d.idProducto),
                            onQtyChanged: (q) => _setQty(d.idProducto, q),
                            enabled: !_saving,
                          )),

                        // Error banner
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: CendentColors.redSoft, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, size: 16, color: CendentColors.red),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: CendentColors.red))),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _KBtn(
                        icon: Icons.close_rounded,
                        label: 'Cancelar',
                        kind: _KBtnKind.secondary,
                        onTap: _saving ? () {} : () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _KBtn(
                        icon: _saving ? null : Icons.check_rounded,
                        label: _saving ? 'Guardando…' : 'Guardar kit',
                        kind: _KBtnKind.primary,
                        busy: _saving,
                        onTap: _saving ? null : _guardar,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Row para cada item en el editor
class _DraftRow extends StatelessWidget {
  final _DraftItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;
  final bool enabled;
  const _DraftRow({required this.item, required this.onRemove, required this.onQtyChanged, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final cat = _KCatStyle.of(item.cat);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CendentColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: cat.bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(cat.icon, size: 16, color: cat.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                Text(item.sku, style: const TextStyle(fontSize: 11.5, color: CendentColors.secondary, fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Qty stepper
          _QtyStepper(qty: item.qty, enabled: enabled, onChanged: onQtyChanged),
          const SizedBox(width: 6),
          // Remove
          _KActBtn(icon: Icons.delete_outline_rounded, tooltip: 'Quitar', danger: true, onTap: onRemove),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final bool enabled;
  final ValueChanged<int> onChanged;
  const _QtyStepper({required this.qty, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CendentColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepBtn(icon: Icons.remove, onTap: enabled ? () => onChanged(qty - 1) : null),
          Container(
            width: 1, height: 32,
            color: CendentColors.hairline,
          ),
          SizedBox(
            width: 40,
            height: 32,
            child: Center(
              child: Text('$qty',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CendentColors.ink)),
            ),
          ),
          Container(width: 1, height: 32, color: CendentColors.hairline),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('u', style: TextStyle(fontSize: 11, color: CendentColors.secondary)),
          ),
          Container(width: 1, height: 32, color: CendentColors.hairline),
          _StepBtn(icon: Icons.add, onTap: enabled ? () => onChanged(qty + 1) : null),
        ],
      ),
    );
  }
}

class _StepBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.onTap});
  @override
  State<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends State<_StepBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 30, height: 32,
          color: _hover && widget.onTap != null ? CendentColors.blueWash : Colors.transparent,
          child: Icon(widget.icon, size: 16, color: _hover && widget.onTap != null ? CendentColors.primary : CendentColors.steel),
        ),
      ),
    );
  }
}

// =============================================================================
//  DELETE CONFIRM
// =============================================================================
class _DeleteKitDialog extends StatefulWidget {
  final _Kit kit;
  const _DeleteKitDialog({required this.kit});
  @override
  State<_DeleteKitDialog> createState() => _DeleteKitDialogState();
}

class _DeleteKitDialogState extends State<_DeleteKitDialog> {
  final _api = ApiService();
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() { _deleting = true; _error = null; });
    final (:ok, :errorMsg) = await _api.eliminarKit(widget.kit.idKit);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _deleting = false; _error = errorMsg ?? 'No se pudo eliminar el kit'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Eliminar kit',
                              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: CendentColors.ink)),
                          const SizedBox(height: 4),
                          Text('Se eliminará el kit "${widget.kit.nombre}". Esta acción no se puede deshacer.',
                              style: const TextStyle(fontSize: 13, color: CendentColors.secondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _KCloseBtn(onTap: () => Navigator.of(context).pop(false)),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(26, 16, 26, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: CendentColors.redSoft, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: CendentColors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontSize: 13, color: CendentColors.red))),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _KBtn(icon: Icons.close_rounded, label: 'Cancelar', kind: _KBtnKind.secondary,
                        onTap: _deleting ? () {} : () => Navigator.of(context).pop(false)),
                    const SizedBox(width: 10),
                    _KBtn(icon: Icons.delete_outline_rounded, label: _deleting ? 'Eliminando…' : 'Eliminar',
                        kind: _KBtnKind.danger, busy: _deleting, onTap: _deleting ? null : _delete),
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
//  DESPACHAR KIT — modal para ítems variables
// =============================================================================
class _DespacharKitDialog extends StatefulWidget {
  final _Kit kit;
  final List<_ProdInfo> productos;
  const _DespacharKitDialog({required this.kit, required this.productos});

  @override
  State<_DespacharKitDialog> createState() => _DespacharKitDialogState();
}

class _DespacharKitDialogState extends State<_DespacharKitDialog> {
  final _api = ApiService();
  late final List<_KItem> _varItems;
  late final List<_KItem> _fixedItems;
  late final Map<int, TextEditingController> _ctrls;
  final Map<int, _ProdInfo?> _sel = {};
  final Map<int, List<_ProdInfo>> _results = {};
  final Map<int, bool> _showRes = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _varItems  = widget.kit.items.where((i) => i.esVariable).toList();
    _fixedItems = widget.kit.items.where((i) => !i.esVariable).toList();
    _ctrls = { for (final i in _varItems) i.idDetalle: TextEditingController() };
    for (final i in _varItems) {
      _sel[i.idDetalle] = null;
      _results[i.idDetalle] = [];
      _showRes[i.idDetalle] = false;
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _search(int idDetalle, String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) {
      setState(() {
        _results[idDetalle] = [];
        _showRes[idDetalle] = false;
        _sel[idDetalle] = null;
      });
      return;
    }
    final matches = widget.productos
        .where((p) => p.nombre.toLowerCase().contains(t) || p.sku.toLowerCase().contains(t))
        .take(8)
        .toList();
    setState(() { _results[idDetalle] = matches; _showRes[idDetalle] = true; });
  }

  void _pick(int idDetalle, _ProdInfo p) {
    setState(() {
      _sel[idDetalle] = p;
      _ctrls[idDetalle]!.text = p.nombre;
      _results[idDetalle] = [];
      _showRes[idDetalle] = false;
      _error = null;
    });
  }

  bool get _ready => _varItems.every((i) => _sel[i.idDetalle] != null);

  Future<void> _despachar() async {
    if (!_ready) {
      setState(() => _error = 'Seleccione un producto para cada ítem variable.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final subs = _varItems.map((i) => {
      'id_detalle': i.idDetalle,
      'id_producto': _sel[i.idDetalle]!.idProducto,
    }).toList();
    final (:ok, :errorMsg, :data) = await _api.despacharKit(widget.kit.idKit, sustituciones: subs);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(data);
    } else {
      setState(() { _saving = false; _error = errorMsg ?? 'Error al despachar el kit'; });
    }
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: CendentColors.card,
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CendentColors.hairline)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CendentColors.primary, width: 1.6)),
    suffixIcon: const Icon(Icons.search_rounded, size: 16, color: CendentColors.secondary),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 780),
        child: Material(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
                decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Despachar kit',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: CendentColors.ink)),
                          const SizedBox(height: 4),
                          Text(widget.kit.nombre,
                              style: const TextStyle(
                                  fontSize: 13, color: CendentColors.secondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _KCloseBtn(onTap: () => Navigator.of(context).pop(false)),
                  ],
                ),
              ),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fixed items — reference only
                      if (_fixedItems.isNotEmpty) ...[
                        const _KFieldLabel('Ítems fijos del kit'),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: CendentColors.hairline),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: _fixedItems.asMap().entries.map((e) {
                              final item = e.value;
                              final cat = _KCatStyle.of(item.cat);
                              final isLast = e.key == _fixedItems.length - 1;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: isLast
                                        ? BorderSide.none
                                        : const BorderSide(
                                            color: CendentColors.hairlineSoft),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                          color: cat.bg,
                                          borderRadius: BorderRadius.circular(10)),
                                      child: Icon(cat.icon, size: 16, color: cat.fg),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(item.nombre,
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: CendentColors.ink)),
                                    ),
                                    Text('${item.cantidad} u',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: CendentColors.secondary)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 22),
                      ],

                      // Variable slots
                      const _KFieldLabel('Ítems variables', required: true),
                      const SizedBox(height: 4),
                      const Text(
                        'Seleccione el producto concreto para cada slot variable.',
                        style: TextStyle(fontSize: 12.5, color: CendentColors.secondary),
                      ),
                      const SizedBox(height: 14),

                      ..._varItems.asMap().entries.map((e) {
                        final item = e.value;
                        final idDet = item.idDetalle;
                        final selected = _sel[idDet];
                        final results = _results[idDet] ?? [];
                        final showRes = _showRes[idDet] ?? false;
                        final isLast = e.key == _varItems.length - 1;

                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Slot label row
                              Row(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: selected != null
                                          ? CendentColors.greenSoft
                                          : CendentColors.amberSoft,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      selected != null
                                          ? Icons.check_rounded
                                          : Icons.help_outline_rounded,
                                      size: 13,
                                      color: selected != null
                                          ? CendentColors.green
                                          : CendentColors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Slot ${e.key + 1}',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: CendentColors.ink)),
                                  if (selected != null) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '→ ${selected.nombre}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color: CendentColors.green,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 7),

                              // Search field
                              TextField(
                                controller: _ctrls[idDet],
                                enabled: !_saving,
                                onChanged: (v) => _search(idDet, v),
                                style: const TextStyle(
                                    fontSize: 14, color: CendentColors.ink),
                                decoration:
                                    _inputDeco('Buscar producto del inventario…'),
                              ),

                              // Results dropdown
                              if (showRes && results.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  constraints:
                                      const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    color: CendentColors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: CendentColors.hairline),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Color(0x220D1B2A),
                                          blurRadius: 16,
                                          offset: Offset(0, 6))
                                    ],
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    padding: EdgeInsets.zero,
                                    itemCount: results.length,
                                    separatorBuilder: (_, __) => const Divider(
                                        height: 1,
                                        color: CendentColors.hairlineSoft),
                                    itemBuilder: (ctx, i) {
                                      final p = results[i];
                                      return InkWell(
                                        onTap: () => _pick(idDet, p),
                                        borderRadius: i == 0
                                            ? const BorderRadius.vertical(
                                                top: Radius.circular(14))
                                            : i == results.length - 1
                                                ? const BorderRadius.vertical(
                                                    bottom: Radius.circular(14))
                                                : BorderRadius.zero,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(p.nombre,
                                                        style: const TextStyle(
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: CendentColors
                                                                .ink)),
                                                    Text(p.sku,
                                                        style: const TextStyle(
                                                            fontSize: 11.5,
                                                            color: CendentColors
                                                                .secondary,
                                                            fontFamily:
                                                                'monospace')),
                                                  ],
                                                ),
                                              ),
                                              Text('${p.stock} u',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: CendentColors
                                                          .secondary)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                              if (showRes && results.isEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: CendentColors.card,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: CendentColors.hairline),
                                  ),
                                  child: const Text(
                                      'Sin productos que coincidan.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: CendentColors.secondary)),
                                ),
                            ],
                          ),
                        );
                      }),

                      // Error banner
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: CendentColors.redSoft,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: CendentColors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: CendentColors.red))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: CendentColors.hairline))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _KBtn(
                      icon: Icons.close_rounded,
                      label: 'Cancelar',
                      kind: _KBtnKind.secondary,
                      onTap: _saving ? () {} : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 10),
                    _KBtn(
                      icon: _saving ? null : Icons.check_circle_outline_rounded,
                      label: _saving ? 'Despachando…' : 'Confirmar despacho',
                      kind: _KBtnKind.primary,
                      busy: _saving,
                      onTap: _saving ? null : _despachar,
                    ),
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
//  REGISTRAR CONSUMO DIALOG  (public — usado desde home_screen.dart)
// =============================================================================
class RegistrarConsumoDialog extends StatefulWidget {
  final int idSucursal;
  const RegistrarConsumoDialog({super.key, required this.idSucursal});

  @override
  State<RegistrarConsumoDialog> createState() => _RegistrarConsumoDialogState();
}

class _RegistrarConsumoDialogState extends State<RegistrarConsumoDialog> {
  final _api = ApiService();
  bool _loading = true;
  List<_ProdInfo> _productos = [];
  String? _loadError;

  final _ctrlBuscar = TextEditingController();
  List<_ProdInfo> _results = [];
  bool _showRes = false;
  _ProdInfo? _selProd;

  final _ctrlQty = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrlBuscar.dispose();
    _ctrlQty.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _loadError = null; });
    final raw = await _api.getInventario(widget.idSucursal);
    if (!mounted) return;
    if (raw == null) {
      setState(() { _loading = false; _loadError = 'No se pudo cargar el inventario.'; });
      return;
    }
    setState(() { _productos = raw.map<_ProdInfo>(_kMapProdInfo).toList(); _loading = false; });
  }

  void _searchProd(String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) {
      setState(() { _results = []; _showRes = false; _selProd = null; _error = null; });
      return;
    }
    final matches = _productos
        .where((p) => p.nombre.toLowerCase().contains(t) || p.sku.toLowerCase().contains(t))
        .take(8)
        .toList();
    setState(() { _results = matches; _showRes = true; });
  }

  void _pickProd(_ProdInfo p) {
    setState(() {
      _selProd = p;
      _ctrlBuscar.text = p.nombre;
      _results = [];
      _showRes = false;
      _ctrlQty.clear();
      _error = null;
    });
  }

  Future<void> _confirmar() async {
    final qty = int.tryParse(_ctrlQty.text.trim()) ?? 0;
    if (_selProd == null) {
      setState(() => _error = 'Selecciona un producto.');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'La cantidad debe ser mayor a 0.');
      return;
    }
    if (qty > _selProd!.stock) {
      setState(() => _error = 'Stock insuficiente. Disponible: ${_selProd!.stock} u.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final (:ok, :errorMsg, :data) = await _api.consumirProducto(
      idProducto: _selProd!.idProducto,
      cantidad: qty,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(data);
    } else {
      setState(() { _saving = false; _error = errorMsg ?? 'Error al registrar el consumo.'; });
    }
  }

  InputDecoration _inputDeco(String hint, {bool withSearchIcon = false}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: CendentColors.card,
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CendentColors.hairline)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CendentColors.primary, width: 1.6)),
    suffixIcon: withSearchIcon
        ? const Icon(Icons.search_rounded, size: 16, color: CendentColors.secondary)
        : null,
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Material(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: _loading
              ? _buildLoading()
              : _loadError != null
                  ? _buildError()
                  : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 72),
        CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5),
        SizedBox(height: 20),
        Text('Cargando inventario…', style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
        SizedBox(height: 72),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: CendentColors.secondary),
              const SizedBox(height: 16),
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: CendentColors.ink)),
              const SizedBox(height: 24),
              _KBtn(icon: Icons.refresh_rounded, label: 'Reintentar', kind: _KBtnKind.secondary, onTap: _load),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    final cat = _selProd != null ? _KCatStyle.of(_selProd!.cat) : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _KFieldLabel('Producto', required: true),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrlBuscar,
                  enabled: !_saving,
                  onChanged: _searchProd,
                  style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                  decoration: _inputDeco('Buscar producto del inventario…', withSearchIcon: true),
                ),
                if (_showRes && _results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: CendentColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CendentColors.hairline),
                      boxShadow: const [
                        BoxShadow(color: Color(0x220D1B2A), blurRadius: 16, offset: Offset(0, 6))
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: CendentColors.hairlineSoft),
                      itemBuilder: (ctx, i) {
                        final p = _results[i];
                        final pCat = _KCatStyle.of(p.cat);
                        return InkWell(
                          onTap: () => _pickProd(p),
                          borderRadius: i == 0
                              ? const BorderRadius.vertical(top: Radius.circular(14))
                              : i == _results.length - 1
                                  ? const BorderRadius.vertical(bottom: Radius.circular(14))
                                  : BorderRadius.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                      color: pCat.bg, borderRadius: BorderRadius.circular(9)),
                                  child: Icon(pCat.icon, size: 15, color: pCat.fg),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.nombre,
                                          style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: CendentColors.ink)),
                                      Text(p.sku,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: CendentColors.secondary,
                                              fontFamily: 'monospace')),
                                    ],
                                  ),
                                ),
                                Text('${p.stock} u',
                                    style: const TextStyle(
                                        fontSize: 12, color: CendentColors.secondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                if (_showRes && _results.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CendentColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CendentColors.hairline),
                    ),
                    child: const Text('Sin productos que coincidan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                  ),

                if (_selProd != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                        color: CendentColors.greenSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                              color: cat!.bg, borderRadius: BorderRadius.circular(8)),
                          child: Icon(cat.icon, size: 14, color: cat.fg),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_selProd!.nombre,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: CendentColors.ink)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _selProd!.stock > 0
                                ? CendentColors.greenSoft
                                : CendentColors.redSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Stock: ${_selProd!.stock} u',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _selProd!.stock > 0
                                    ? CendentColors.green
                                    : CendentColors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                const _KFieldLabel('Cantidad', required: true),
                const SizedBox(height: 8),
                TextField(
                  controller: _ctrlQty,
                  enabled: !_saving && _selProd != null,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                  onChanged: (_) { if (_error != null) setState(() => _error = null); },
                  decoration: _inputDeco(
                    _selProd != null
                        ? 'Máx. ${_selProd!.stock} u disponibles'
                        : 'Selecciona un producto primero',
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: CendentColors.redSoft, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: CendentColors.red),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(fontSize: 13, color: CendentColors.red))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: CendentColors.hairline))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _KBtn(
                icon: Icons.close_rounded,
                label: 'Cancelar',
                kind: _KBtnKind.secondary,
                onTap: _saving ? () {} : () => Navigator.of(context).pop(false),
              ),
              const SizedBox(width: 10),
              _KBtn(
                icon: _saving ? null : Icons.arrow_downward_rounded,
                label: _saving ? 'Registrando…' : 'Registrar egreso',
                kind: _KBtnKind.primary,
                busy: _saving,
                onTap: _saving ? null : _confirmar,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CendentColors.hairline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registrar Consumo',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: CendentColors.ink)),
                SizedBox(height: 4),
                Text('Egreso directo de inventario',
                    style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _KCloseBtn(onTap: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }
}

// =============================================================================
//  DESPACHAR KIT FLOW DIALOG  (public — usado desde home_screen.dart)
// =============================================================================
enum _FlowStep { loading, error, select, varItems }

class DespacharKitFlowDialog extends StatefulWidget {
  final int idSucursal;
  const DespacharKitFlowDialog({super.key, required this.idSucursal});

  @override
  State<DespacharKitFlowDialog> createState() => _DespacharKitFlowDialogState();
}

class _DespacharKitFlowDialogState extends State<DespacharKitFlowDialog> {
  final _api = ApiService();
  _FlowStep _step = _FlowStep.loading;
  List<_Kit> _kits = [];
  List<_ProdInfo> _productos = [];
  String _kitSearch = '';
  String? _loadError;
  bool _saving = false;
  String? _error;

  // Step 2 — variable items (same logic as _DespacharKitDialogState)
  _Kit? _selKit;
  List<_KItem> _varItems = [];
  List<_KItem> _fixedItems = [];
  Map<int, TextEditingController> _ctrls = {};
  final Map<int, _ProdInfo?> _sel = {};
  final Map<int, List<_ProdInfo>> _results = {};
  final Map<int, bool> _showRes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _step = _FlowStep.loading; _loadError = null; });
    final results = await Future.wait([
      _api.getKits(),
      _api.getInventario(widget.idSucursal),
    ]);
    if (!mounted) return;
    final rawKits = results[0];
    final rawProds = results[1];
    if (rawKits == null) {
      setState(() { _step = _FlowStep.error; _loadError = 'No se pudo cargar la lista de kits.'; });
      return;
    }
    final prods = (rawProds ?? []).map<_ProdInfo>(_kMapProdInfo).toList();
    final map = <int, _ProdInfo>{for (final p in prods) p.idProducto: p};
    final kits = rawKits.map<_Kit>((k) => _kMapKit(k, map)).toList();
    setState(() { _productos = prods; _kits = kits; _step = _FlowStep.select; });
  }

  List<_Kit> get _filteredKits {
    if (_kitSearch.isEmpty) return _kits;
    final t = _kitSearch.toLowerCase();
    return _kits.where((k) => k.nombre.toLowerCase().contains(t)).toList();
  }

  Future<void> _onSelectKit(_Kit k) async {
    final varItems = k.items.where((i) => i.esVariable).toList();
    if (varItems.isEmpty) {
      setState(() { _saving = true; _error = null; });
      final (:ok, :errorMsg, :data) = await _api.despacharKit(k.idKit);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(data);
      } else {
        setState(() { _saving = false; _error = errorMsg ?? 'Error al despachar el kit.'; });
      }
    } else {
      for (final c in _ctrls.values) {
        c.dispose();
      }
      final newCtrls = {for (final i in varItems) i.idDetalle: TextEditingController()};
      setState(() {
        _selKit = k;
        _varItems = varItems;
        _fixedItems = k.items.where((i) => !i.esVariable).toList();
        _ctrls = newCtrls;
        for (final i in varItems) {
          _sel[i.idDetalle] = null;
          _results[i.idDetalle] = [];
          _showRes[i.idDetalle] = false;
        }
        _error = null;
        _step = _FlowStep.varItems;
      });
    }
  }

  void _searchProd(int idDetalle, String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) {
      setState(() { _results[idDetalle] = []; _showRes[idDetalle] = false; _sel[idDetalle] = null; });
      return;
    }
    final matches = _productos
        .where((p) => p.nombre.toLowerCase().contains(t) || p.sku.toLowerCase().contains(t))
        .take(8)
        .toList();
    setState(() { _results[idDetalle] = matches; _showRes[idDetalle] = true; });
  }

  void _pickProd(int idDetalle, _ProdInfo p) {
    setState(() {
      _sel[idDetalle] = p;
      _ctrls[idDetalle]!.text = p.nombre;
      _results[idDetalle] = [];
      _showRes[idDetalle] = false;
      _error = null;
    });
  }

  bool get _ready => _varItems.every((i) => _sel[i.idDetalle] != null);

  Future<void> _despacharConSubs() async {
    if (!_ready) {
      setState(() => _error = 'Seleccione un producto para cada ítem variable.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    final subs = _varItems.map((i) => {
      'id_detalle': i.idDetalle,
      'id_producto': _sel[i.idDetalle]!.idProducto,
    }).toList();
    final (:ok, :errorMsg, :data) = await _api.despacharKit(_selKit!.idKit, sustituciones: subs);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(data);
    } else {
      setState(() { _saving = false; _error = errorMsg ?? 'Error al despachar el kit.'; });
    }
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: CendentColors.card,
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CendentColors.hairline)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CendentColors.primary, width: 1.6)),
    suffixIcon: const Icon(Icons.search_rounded, size: 16, color: CendentColors.secondary),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 780),
        child: Material(
          color: CendentColors.card,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _FlowStep.loading: return _buildLoading();
      case _FlowStep.error:   return _buildError();
      case _FlowStep.select:  return _buildSelect();
      case _FlowStep.varItems: return _buildVarItems();
    }
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 72),
        CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5),
        SizedBox(height: 20),
        Text('Cargando kits…', style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
        SizedBox(height: 72),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Despachar Kit', 'Error al cargar'),
        Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: CendentColors.secondary),
              const SizedBox(height: 16),
              Text(_loadError ?? 'Error desconocido',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: CendentColors.ink)),
              const SizedBox(height: 24),
              _KBtn(icon: Icons.refresh_rounded, label: 'Reintentar', kind: _KBtnKind.secondary, onTap: _load),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelect() {
    final filtered = _filteredKits;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Despachar Kit', 'Selecciona un procedimiento'),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 12),
          child: TextField(
            onChanged: (v) => setState(() => _kitSearch = v),
            style: const TextStyle(fontSize: 14, color: CendentColors.ink),
            decoration: _inputDeco('Buscar kit de procedimiento…'),
          ),
        ),
        Flexible(
          child: filtered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text('Sin kits que coincidan.',
                        style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: CendentColors.hairlineSoft),
                  itemBuilder: (_, i) {
                    final k = filtered[i];
                    final insuf = k.items.any((it) => it.stockInsuficiente);
                    return InkWell(
                      onTap: _saving ? null : () => _onSelectKit(k),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 42, height: 42,
                              decoration: BoxDecoration(
                                  color: CendentColors.blueTint,
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.medical_services_outlined,
                                  size: 20, color: CendentColors.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(k.nombre,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: CendentColors.ink)),
                                  const SizedBox(height: 3),
                                  Text('${k.items.length} ítem${k.items.length != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                          fontSize: 12.5, color: CendentColors.secondary)),
                                ],
                              ),
                            ),
                            if (insuf)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: CendentColors.amberSoft,
                                    borderRadius: BorderRadius.circular(8)),
                                child: const Text('Stock bajo',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: CendentColors.amber)),
                              ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded,
                                size: 20, color: CendentColors.muted),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_error != null) _buildErrorBanner(_error!),
        Container(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: CendentColors.hairline))),
          child: Align(
            alignment: Alignment.centerRight,
            child: _KBtn(
              icon: Icons.close_rounded,
              label: 'Cancelar',
              kind: _KBtnKind.secondary,
              onTap: () => Navigator.of(context).pop(false),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVarItems() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Despachar kit', _selKit!.nombre),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_fixedItems.isNotEmpty) ...[
                  const _KFieldLabel('Ítems fijos del kit'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: CendentColors.hairline),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: _fixedItems.asMap().entries.map((e) {
                        final item = e.value;
                        final cat = _KCatStyle.of(item.cat);
                        final isLast = e.key == _fixedItems.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: isLast
                                  ? BorderSide.none
                                  : const BorderSide(color: CendentColors.hairlineSoft),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                    color: cat.bg, borderRadius: BorderRadius.circular(10)),
                                child: Icon(cat.icon, size: 16, color: cat.fg),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(item.nombre,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: CendentColors.ink)),
                              ),
                              Text('${item.cantidad} u',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: CendentColors.secondary)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                const _KFieldLabel('Ítems variables', required: true),
                const SizedBox(height: 4),
                const Text(
                  'Seleccione el producto concreto para cada slot variable.',
                  style: TextStyle(fontSize: 12.5, color: CendentColors.secondary),
                ),
                const SizedBox(height: 14),

                ..._varItems.asMap().entries.map((e) {
                  final item = e.value;
                  final idDet = item.idDetalle;
                  final selected = _sel[idDet];
                  final results = _results[idDet] ?? [];
                  final showRes = _showRes[idDet] ?? false;
                  final isLast = e.key == _varItems.length - 1;

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: selected != null
                                    ? CendentColors.greenSoft
                                    : CendentColors.amberSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                selected != null
                                    ? Icons.check_rounded
                                    : Icons.help_outline_rounded,
                                size: 13,
                                color: selected != null
                                    ? CendentColors.green
                                    : CendentColors.amber,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Slot ${e.key + 1}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: CendentColors.ink)),
                            if (selected != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '→ ${selected.nombre}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: CendentColors.green,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        TextField(
                          controller: _ctrls[idDet],
                          enabled: !_saving,
                          onChanged: (v) => _searchProd(idDet, v),
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Buscar producto del inventario…'),
                        ),
                        if (showRes && results.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(maxHeight: 200),
                            decoration: BoxDecoration(
                              color: CendentColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: CendentColors.hairline),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x220D1B2A),
                                    blurRadius: 16,
                                    offset: Offset(0, 6))
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: CendentColors.hairlineSoft),
                              itemBuilder: (ctx, i) {
                                final p = results[i];
                                return InkWell(
                                  onTap: () => _pickProd(idDet, p),
                                  borderRadius: i == 0
                                      ? const BorderRadius.vertical(top: Radius.circular(14))
                                      : i == results.length - 1
                                          ? const BorderRadius.vertical(
                                              bottom: Radius.circular(14))
                                          : BorderRadius.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(p.nombre,
                                                  style: const TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: CendentColors.ink)),
                                              Text(p.sku,
                                                  style: const TextStyle(
                                                      fontSize: 11.5,
                                                      color: CendentColors.secondary,
                                                      fontFamily: 'monospace')),
                                            ],
                                          ),
                                        ),
                                        Text('${p.stock} u',
                                            style: const TextStyle(
                                                fontSize: 12, color: CendentColors.secondary)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        if (showRes && results.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CendentColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: CendentColors.hairline),
                            ),
                            child: const Text('Sin productos que coincidan.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 13, color: CendentColors.secondary)),
                          ),
                      ],
                    ),
                  );
                }),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(_error!),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
          decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: CendentColors.hairline))),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _KBtn(
                icon: Icons.arrow_back_rounded,
                label: 'Volver',
                kind: _KBtnKind.secondary,
                onTap: _saving
                    ? () {}
                    : () => setState(() {
                          _step = _FlowStep.select;
                          _error = null;
                        }),
              ),
              const SizedBox(width: 10),
              _KBtn(
                icon: _saving ? null : Icons.check_circle_outline_rounded,
                label: _saving ? 'Despachando…' : 'Confirmar despacho',
                kind: _KBtnKind.primary,
                busy: _saving,
                onTap: _saving ? null : _despacharConSubs,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: CendentColors.hairline))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: CendentColors.ink)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 13, color: CendentColors.secondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _KCloseBtn(onTap: () => Navigator.of(context).pop(false)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: CendentColors.redSoft, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: CendentColors.red),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13, color: CendentColors.red))),
        ],
      ),
    );
  }
}

// =============================================================================
//  SKELETON
// =============================================================================
class _KitsSkeleton extends StatelessWidget {
  const _KitsSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final cols = (box.maxWidth / 400).floor().clamp(1, 4);
        final itemW = (box.maxWidth - (cols - 1) * 18) / cols;
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: List.generate(6, (_) => SizedBox(
            width: itemW,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CendentColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CendentColors.hairline),
                boxShadow: CendentColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KSkelBox(width: 48, height: 48, radius: 14),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _KSkelBox(height: 16, widthFraction: 0.6),
                            SizedBox(height: 9),
                            _KSkelBox(height: 11, widthFraction: 0.35),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: CendentColors.hairlineSoft),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _KSkelBox(width: 90, height: 13),
                      _KSkelBox(width: 110, height: 28),
                    ],
                  ),
                ],
              ),
            ),
          )),
        );
      },
    );
  }
}

class _KSkelBox extends StatelessWidget {
  final double? width;
  final double height;
  final double? widthFraction;
  final double radius;
  const _KSkelBox({this.width, required this.height, this.widthFraction, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, box) {
        final w = width ?? (widthFraction != null ? box.maxWidth * widthFraction! : double.infinity);
        return Container(
          width: w,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1F6),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }
}

// =============================================================================
//  EMPTY & ERROR STATE
// =============================================================================
class _KEmptyState extends StatelessWidget {
  final bool noneAtAll;
  final VoidCallback? onCreate;
  const _KEmptyState({required this.noneAtAll, this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline, style: BorderStyle.solid),
        boxShadow: CendentColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: CendentColors.blueTint, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.medical_services_outlined, size: 34, color: CendentColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            noneAtAll ? 'Aún no hay kits de procedimientos' : 'Sin resultados',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: CendentColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            noneAtAll
                ? 'Cree su primer kit para agrupar los productos que se consumen\njuntos en cada procedimiento.'
                : 'No hay kits que coincidan con la búsqueda actual.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: CendentColors.secondary, height: 1.55),
          ),
          if (noneAtAll && onCreate != null) ...[
            const SizedBox(height: 22),
            _KBtn(icon: Icons.add_rounded, label: 'Crear el primer kit', kind: _KBtnKind.primary, onTap: onCreate!),
          ],
        ],
      ),
    );
  }
}

class _KErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _KErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: CendentColors.secondary),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CendentColors.ink)),
          const SizedBox(height: 24),
          _KBtn(icon: Icons.refresh_rounded, label: 'Reintentar', kind: _KBtnKind.secondary, onTap: onRetry),
        ],
      ),
    );
  }
}

// =============================================================================
//  BOTÓN COMPARTIDO
// =============================================================================
enum _KBtnKind { primary, secondary, danger }

class _KBtn extends StatefulWidget {
  final IconData? icon;
  final String label;
  final _KBtnKind kind;
  final VoidCallback? onTap;
  final bool busy;
  const _KBtn({this.icon, required this.label, required this.kind, required this.onTap, this.busy = false});
  @override
  State<_KBtn> createState() => _KBtnState();
}

class _KBtnState extends State<_KBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.busy;
    late Color bg, fg, border;
    switch (widget.kind) {
      case _KBtnKind.primary:
        bg = _hover && !disabled ? CendentColors.primaryDeep : CendentColors.primary;
        fg = Colors.white;
        border = bg;
        break;
      case _KBtnKind.secondary:
        bg = _hover && !disabled ? CendentColors.blueWash : CendentColors.card;
        fg = _hover && !disabled ? CendentColors.primary : CendentColors.steel;
        border = _hover && !disabled ? CendentColors.blueLight : CendentColors.hairline;
        break;
      case _KBtnKind.danger:
        bg = _hover && !disabled ? CendentColors.redSoft : CendentColors.card;
        fg = CendentColors.red;
        border = _hover && !disabled ? const Color(0xFFF1B6B2) : CendentColors.hairline;
        break;
    }
    return Opacity(
      opacity: disabled && !widget.busy ? 0.6 : 1,
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: disabled ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
              boxShadow: widget.kind == _KBtnKind.primary && !disabled
                  ? const [BoxShadow(color: Color(0x801565C0), blurRadius: 16, spreadRadius: -6, offset: Offset(0, 6))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.busy)
                  SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(fg)))
                else if (widget.icon != null)
                  Icon(widget.icon, size: 17, color: fg),
                if (widget.busy || widget.icon != null) const SizedBox(width: 9),
                Text(widget.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  FIELD LABEL
// =============================================================================
class _KFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _KFieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: CendentColors.secondary)),
      if (required) const Text(' *', style: TextStyle(fontSize: 11, color: CendentColors.red, fontWeight: FontWeight.w700)),
    ],
  );
}

// =============================================================================
//  FOOTER
// =============================================================================
class _KFooter extends StatelessWidget {
  const _KFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
      child: const Column(
        children: [
          Text("Daniel's CENDENT S.A.  ·  Centro de Especialidades Odontológicas",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: CendentColors.secondary, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('© 2026 — Todos los derechos reservados',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: CendentColors.secondary)),
        ],
      ),
    );
  }
}
