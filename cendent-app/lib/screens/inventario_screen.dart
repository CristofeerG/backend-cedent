// =============================================================================
//  lib/screens/inventario_screen.dart
//  Inventario / Lotes — datos reales desde el backend en localhost:3000
// =============================================================================

import 'dart:async';
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';
import '../services/api_service.dart';
import '../utils/cendent_colors.dart';
import '../utils/inventario_pdf.dart';

// =============================================================================
//  ENUMS DE DOMINIO
// =============================================================================
enum ProductCategory { anestesicos, insumos, restauracion, instrumental }
enum StockState { normal, bajoMinimo, porVencer, sinStock }
enum MovKind { egreso, ingreso, transferencia }
enum LotState { vigente, porVencer, critico }


class Lote {
  final int idLote;
  final String code;
  final int stock;
  final String expiry;
  final String cost;
  final LotState state;
  final String? rawFechaVenc;
  final double? rawCosto;
  Lote(this.idLote, this.code, this.stock, this.expiry, this.cost, this.state, {this.rawFechaVenc, this.rawCosto});
}

class Mov {
  final MovKind kind;
  final String title;
  final String sub;
  final int qty;
  Mov(this.kind, this.title, this.sub, this.qty);
}

class Product {
  final int idProducto;
  final String name;
  final String sku;
  final ProductCategory category;
  final int stock;
  final int minStock;
  final StockState state;
  final int lotes;
  final String? nextExpiry;
  final bool expirySoon;
  // Campos raw para el formulario de edición
  final String rawNombre;
  final String? rawCategoria;
  final String? rawSubcategoria;
  final String rawUnidad;
  final int rawStockMin;
  Product({
    required this.idProducto,
    required this.name,
    required this.sku,
    required this.category,
    required this.stock,
    required this.minStock,
    required this.state,
    required this.lotes,
    required this.nextExpiry,
    required this.expirySoon,
    required this.rawNombre,
    this.rawCategoria,
    this.rawSubcategoria,
    required this.rawUnidad,
    required this.rawStockMin,
  });
}

// =============================================================================
//  HELPERS DE PARSEO
// =============================================================================
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// "2026-06-12" o "2026-06-12T05:00:00.000Z" → "12/06/2026"
String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  } catch (_) {
    return '—';
  }
}

/// Costo numérico → "S/ 2,50"
String _fmtCosto(dynamic v) {
  final d = _toDouble(v);
  return 'S/ ${d.toStringAsFixed(2).replaceAll('.', ',')}';
}

/// Tiempo relativo para subtítulo de movimientos
String _relTime(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    return '$d/$mo';
  } catch (_) {
    return '';
  }
}

ProductCategory _parseCat(String? sub) {
  final s = (sub ?? '').toUpperCase();
  if (s.contains('RESINA') || s.contains('MATER') || s.contains('CEMENTA') || s.contains('MATE')) {
    return ProductCategory.restauracion;
  }
  if (s.contains('ARCO') || s.contains('BRACKET') || s.contains('INSTR')) {
    return ProductCategory.instrumental;
  }
  return ProductCategory.insumos;
}

StockState _parseState(int stock, int stockMin, bool expirySoon) {
  if (stock <= 0) return StockState.sinStock;
  if (expirySoon) return StockState.porVencer;
  if (stockMin > 0 && stock < stockMin) return StockState.bajoMinimo;
  return StockState.normal;
}

LotState _parseLotState(String? expiryIso) {
  if (expiryIso == null) return LotState.vigente;
  try {
    final dt = DateTime.parse(expiryIso).toLocal();
    final diff = dt.difference(DateTime.now()).inDays;
    if (diff <= 14) return LotState.critico;
    if (diff <= 30) return LotState.porVencer;
    return LotState.vigente;
  } catch (_) {
    return LotState.vigente;
  }
}

MovKind _parseMovKind(String? tipo) {
  switch (tipo) {
    case 'INGRESO_INICIAL':
    case 'INGRESO':
      return MovKind.ingreso;
    case 'SALIDA_TRANSFERENCIA':
      return MovKind.transferencia;
    default:
      return MovKind.egreso;
  }
}

/// Inventario API → Product
Product _mapProduct(dynamic p) {
  final id = p['id_producto'] as int;
  final sub = (p['subcategoria'] as String?) ?? '';
  final prefix = sub.length >= 4 ? sub.substring(0, 4).toUpperCase() : sub.toUpperCase();
  final stock = _toDouble(p['stock_total']).round();
  final stockMin = _toDouble(p['stock_min']).round();
  final expirySoon = ((p['lotes_proximos_vencer'] as int?) ?? 0) > 0;
  return Product(
    idProducto: id,
    name: (p['nombre_mat'] as String?) ?? '—',
    sku: '$prefix-${id.toString().padLeft(4, '0')}',
    category: _parseCat(sub),
    stock: stock,
    minStock: stockMin,
    state: _parseState(stock, stockMin, expirySoon),
    lotes: (p['lotes_count'] as int?) ?? 0,
    nextExpiry: p['proxima_venc'] != null ? _fmtDate(p['proxima_venc'] as String?) : null,
    expirySoon: expirySoon,
    rawNombre: (p['nombre_mat'] as String?) ?? '',
    rawCategoria: p['categoria'] as String?,
    rawSubcategoria: p['subcategoria'] as String?,
    rawUnidad: (p['unidad_medida'] as String?) ?? '',
    rawStockMin: stockMin,
  );
}

/// Lotes API → Lote
Lote _mapLote(dynamic l) {
  return Lote(
    (l['id_lote'] as int?) ?? 0,
    (l['codigo_lote'] as String?) ?? '—',
    _toDouble(l['stock_actual']).round(),
    _fmtDate(l['fecha_venc'] as String?),
    _fmtCosto(l['costo_unit']),
    _parseLotState(l['fecha_venc'] as String?),
    rawFechaVenc: l['fecha_venc'] as String?,
    rawCosto: l['costo_unit'] != null ? _toDouble(l['costo_unit']) : null,
  );
}

/// Movimientos API → Mov
Mov _mapMov(dynamic m) {
  final tipo = (m['tipo_mov'] as String?) ?? '';
  final kind = _parseMovKind(tipo);
  final rawQty = _toDouble(m['cantidad']).round();
  final signed = (kind == MovKind.egreso || kind == MovKind.transferencia) ? -rawQty : rawQty;

  String title;
  switch (tipo) {
    case 'EGRESO_KIT':          title = 'Egreso por kit';   break;
    case 'EGRESO_DIRECTO':      title = 'Egreso directo';   break;
    case 'SALIDA_TRANSFERENCIA':title = 'Transferencia';    break;
    case 'INGRESO_INICIAL':     title = 'Ingreso inicial';  break;
    default:                    title = 'Ingreso';          break;
  }

  final usuario = (m['usuarios']?['nom_usuario'] as String?) ?? '—';
  final kit     = m['kits']?['nombre_procedimiento'] as String?;
  final time    = _relTime(m['fecha_hora'] as String?);
  final sub     = kit != null ? '$kit · $time' : '$usuario · $time';

  return Mov(kind, title, sub, signed);
}

// =============================================================================
//  ESTILOS DERIVADOS (sin cambios visuales)
// =============================================================================
class _CatStyle {
  final String label;
  final Color fg;
  final Color bg;
  const _CatStyle(this.label, this.fg, this.bg);

  static _CatStyle of(ProductCategory c) {
    switch (c) {
      case ProductCategory.anestesicos:
        return const _CatStyle('Anestésicos', CendentColors.primary, CendentColors.blueTint);
      case ProductCategory.insumos:
        return const _CatStyle('Insumos', CendentColors.teal, CendentColors.tealSoft);
      case ProductCategory.restauracion:
        return const _CatStyle('Restauración', CendentColors.violet, CendentColors.violetSoft);
      case ProductCategory.instrumental:
        return const _CatStyle('Instrumental', CendentColors.steel, Color(0xFFEAEFF4));
    }
  }
}

class _StateStyle {
  final String label;
  final IconData icon;
  final Color fg;
  final Color bg;
  const _StateStyle(this.label, this.icon, this.fg, this.bg);

  static _StateStyle of(StockState s) {
    switch (s) {
      case StockState.normal:
        return const _StateStyle('Normal', Icons.check_circle_outline_rounded, CendentColors.green, CendentColors.greenSoft);
      case StockState.bajoMinimo:
        return const _StateStyle('Bajo mínimo', Icons.trending_down_rounded, CendentColors.red, CendentColors.redSoft);
      case StockState.porVencer:
        return const _StateStyle('Por vencer', Icons.event_busy_outlined, CendentColors.amber, CendentColors.amberSoft);
      case StockState.sinStock:
        return const _StateStyle('Sin stock', Icons.inventory_2_outlined, CendentColors.steel, Color(0xFFEAEFF4));
    }
  }
}

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class InventarioScreen extends StatefulWidget {
  final int idSucursal;
  final String nomSucursal;
  final StockState? filtroEstadoInicial;
  const InventarioScreen({super.key, required this.idSucursal, required this.nomSucursal, this.filtroEstadoInicial});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final _api = ApiService();

  bool _loading = true;
  bool _errorConexion = false;
  List<Product> _products = [];

  // KPIs derivados del inventario
  int _kpiTotal = 0;
  int _kpiBajoMin = 0;
  int _kpiPorVencer = 0;
  int _kpiSinStock = 0;

  Product? _selected;
  int _perPage = 10;
  int _currentPage = 1;

  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  ProductCategory? _categoriaFiltro;
  StockState? _estadoFiltro;

  List<Product> get _filteredProducts {
    return _products.where((p) {
      if (_searchQuery.isNotEmpty &&
          !p.name.toLowerCase().contains(_searchQuery) &&
          !p.sku.toLowerCase().contains(_searchQuery)) return false;
      if (_categoriaFiltro != null && p.category != _categoriaFiltro) return false;
      if (_estadoFiltro != null && p.state != _estadoFiltro) return false;
      return true;
    }).toList();
  }

  void _onSearchChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _searchQuery = raw.toLowerCase().trim();
        _currentPage = 1;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.filtroEstadoInicial != null) {
      _estadoFiltro = widget.filtroEstadoInicial;
    }
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _errorConexion = false; });

    final raw = await _api.getInventario(widget.idSucursal);

    if (!mounted) return;

    if (raw == null) {
      setState(() { _loading = false; _errorConexion = true; });
      return;
    }

    try {
      final products = raw.map(_mapProduct).toList();

      // Derivar KPIs del mismo fetch
      int total     = products.length;
      int bajoMin   = 0;
      int porVencer = 0;
      int sinStock  = 0;
      for (final p in products) {
        if (p.state == StockState.bajoMinimo)  bajoMin++;
        if (p.state == StockState.porVencer)   porVencer++;
        if (p.state == StockState.sinStock)    sinStock++;
      }

      setState(() {
        _products      = products;
        _kpiTotal      = total;
        _kpiBajoMin    = bajoMin;
        _kpiPorVencer  = porVencer;
        _kpiSinStock   = sinStock;
        _loading       = false;
      });
    } catch (_) {
      setState(() { _loading = false; _errorConexion = true; });
    }
  }

  void _openDetail(Product p) => setState(() => _selected = p);
  void _closeDetail()         => setState(() => _selected = null);

  Future<void> _openAgregarProducto() async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (_) => const _AgregarProductoDialog(),
    );
    if (guardado == true && mounted) {
      _api.invalidateCache();
      _loadData();
    }
  }

  Future<void> _openAgregarLote(Product product) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (_) => _AgregarLoteDialog(product: product, idSucursal: widget.idSucursal),
    );
    if (guardado == true && mounted) {
      _api.invalidateCache();
      _loadData();
    }
  }

  Future<void> _exportarPdf() async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generando PDF…'),
        duration: Duration(seconds: 2),
        backgroundColor: CendentColors.primary,
      ),
    );

    // Fetch lots in parallel for products that have active lots
    final conLotes = _products.where((p) => p.lotes > 0).toList();

    final lotesRaw = await Future.wait(
      conLotes.map((p) => _api.getLotesProducto(p.idProducto)),
    );

    if (!mounted) return;

    // Map each product with its filtered lots
    final Map<int, List<dynamic>> lotesPorProducto = {};
    for (int i = 0; i < conLotes.length; i++) {
      final raw = lotesRaw[i];
      if (raw == null) continue;
      lotesPorProducto[conLotes[i].idProducto] = raw
          .where((l) =>
              l['id_sucursal'] == widget.idSucursal &&
              _toDouble(l['stock_actual']) > 0)
          .toList();
    }

    // Build PdfProducto list for all products (even those without lots)
    final pdfProductos = _products.map((p) {
      final rawLotes = lotesPorProducto[p.idProducto] ?? [];
      return PdfProducto(
        nombre: p.rawNombre,
        sku: p.sku,
        stockTotal: p.stock,
        stockMin: p.rawStockMin,
        lotes: rawLotes.map((l) {
          return PdfLote(
            codigo: (l['codigo_lote'] as String?) ?? '-',
            stock: _toDouble(l['stock_actual']).round(),
            vencimiento: _fmtDate(l['fecha_venc'] as String?).replaceAll('—', '-'),
          );
        }).toList(),
      );
    }).toList();

    final doc = generarInventarioPdf(
      nomSucursal: widget.nomSucursal,
      productos: pdfProductos,
      fechaGeneracion: DateTime.now(),
    );

    final nombre = 'inventario_${widget.nomSucursal.toLowerCase().replaceAll(' ', '_')}.pdf';

    if (kIsWeb) {
      // En web el navegador muestra el diálogo de impresión/guardar
      await Printing.layoutPdf(onLayout: (_) => doc.save(), name: nombre);
    } else {
      // En desktop: diálogo nativo "Guardar como"
      final location = await getSaveLocation(
        suggestedName: nombre,
        acceptedTypeGroups: [const XTypeGroup(label: 'PDF', extensions: ['pdf'])],
      );
      if (location == null || !mounted) return;
      final bytes = await doc.save();
      await File(location.path).writeAsBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado en ${location.path}'),
          backgroundColor: CendentColors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _InventorySkeleton();
    }

    if (_errorConexion) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: CendentColors.secondary),
            const SizedBox(height: 16),
            const Text('No se pudo conectar con el servidor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CendentColors.ink)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: CendentColors.primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
        Container(
          color: CendentColors.bg,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PageHead(onAdd: _openAgregarProducto, onExport: _exportarPdf),
                        const SizedBox(height: 20),
                        _Toolbar(
                          controller: _searchCtrl,
                          onSearch: _onSearchChanged,
                          nomSucursal: widget.nomSucursal,
                          onCategoriaChanged: (c) => setState(() { _categoriaFiltro = c; _currentPage = 1; }),
                          onEstadoChanged: (e) => setState(() { _estadoFiltro = e; _currentPage = 1; }),
                          estadoInicialLabel: _estadoToLabel(_estadoFiltro),
                        ),
                        const SizedBox(height: 18),
                        _SummaryChips(
                          totalProductos: _kpiTotal,
                          bajoMinimo: _kpiBajoMin,
                          porVencer30: _kpiPorVencer,
                          sinStock: _kpiSinStock,
                        ),
                        const SizedBox(height: 18),
                        _InventoryTableCard(
                          products: _filteredProducts,
                          selected: _selected,
                          onRowTap: _openDetail,
                          onAgregarLoteTap: _openAgregarLote,
                          onEditarProductoTap: (p) { _api.invalidateCache(); _loadData(); },
                          onEliminarProductoTap: (p) { _api.invalidateCache(); _loadData(); },
                          perPage: _perPage,
                          onPerPageChanged: (v) => setState(() { _perPage = v; _currentPage = 1; }),
                          currentPage: _currentPage,
                          onPageChanged: (p) => setState(() => _currentPage = p),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
              const _InvFooter(),
            ],
          ),
        ),

        // Scrim
        IgnorePointer(
          ignoring: _selected == null,
          child: AnimatedOpacity(
            opacity: _selected == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: _closeDetail,
              child: Container(color: const Color(0x6B0D1B2A)),
            ),
          ),
        ),

        // Panel lateral deslizante
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          top: 0, bottom: 0,
          right: _selected == null ? -460 : 0,
          width: 440,
          child: _selected == null
              ? const SizedBox.shrink()
              : LoteDetailPanel(
                  product: _selected!,
                  idSucursal: widget.idSucursal,
                  onClose: _closeDetail,
                  onAgregarLote: () => _openAgregarLote(_selected!),
                  onLoteActualizado: () { _api.invalidateCache(); _loadData(); },
                  onProductoActualizado: () { _api.invalidateCache(); _loadData(); },
                ),
        ),
      ],
    ),  // Stack
    );  // SizedBox.expand
  }
}

// =============================================================================
//  PAGE HEAD
// =============================================================================
class _PageHead extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onExport;
  const _PageHead({required this.onAdd, required this.onExport});

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
            Text('Inventario / Lotes',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: CendentColors.ink)),
            SizedBox(height: 4),
            Text('Control de existencias',
                style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AppButton(icon: Icons.download_rounded, label: 'Exportar', kind: _BtnKind.secondary, onTap: onExport),
            _AppButton(icon: Icons.add_rounded, label: 'Agregar producto', kind: _BtnKind.primary, onTap: onAdd),
          ],
        ),
      ],
    );
  }
}

enum _BtnKind { primary, secondary }

class _AppButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final _BtnKind kind;
  final VoidCallback onTap;
  const _AppButton({required this.icon, required this.label, required this.kind, required this.onTap});
  @override
  State<_AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<_AppButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final primary = widget.kind == _BtnKind.primary;
    final Color bg = primary
        ? (_hover ? CendentColors.primaryDeep : CendentColors.primary)
        : (_hover ? CendentColors.blueWash : CendentColors.card);
    final Color fg = primary ? Colors.white : (_hover ? CendentColors.primary : CendentColors.steel);
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
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: primary ? null : Border.all(color: _hover ? CendentColors.blueLight : CendentColors.hairline),
            boxShadow: primary
                ? const [BoxShadow(color: Color(0x801565C0), blurRadius: 16, spreadRadius: -6, offset: Offset(0, 6))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 17, color: fg),
              const SizedBox(width: 9),
              Text(widget.label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  TOOLBAR
// =============================================================================

// ─── Opciones y mapeos ────────────────────────────────────────────────────────
const _kCategoriaTodas = 'Todas';
const _kEstadoTodos = 'Todos';
const _categoriaOpciones = [
  'Todas', 'Anestésicos', 'Insumos', 'Restauración', 'Instrumental',
];
const _estadoOpciones = [
  'Todos', 'Normal', 'Bajo mínimo', 'Por vencer', 'Sin stock',
];

ProductCategory? _labelToCategoria(String label) {
  switch (label) {
    case 'Anestésicos':  return ProductCategory.anestesicos;
    case 'Insumos':      return ProductCategory.insumos;
    case 'Restauración': return ProductCategory.restauracion;
    case 'Instrumental': return ProductCategory.instrumental;
    default:             return null;
  }
}

StockState? _labelToEstado(String label) {
  switch (label) {
    case 'Normal':      return StockState.normal;
    case 'Bajo mínimo': return StockState.bajoMinimo;
    case 'Por vencer':  return StockState.porVencer;
    case 'Sin stock':   return StockState.sinStock;
    default:            return null;
  }
}

String _estadoToLabel(StockState? estado) {
  switch (estado) {
    case StockState.normal:     return 'Normal';
    case StockState.bajoMinimo: return 'Bajo mínimo';
    case StockState.porVencer:  return 'Por vencer';
    case StockState.sinStock:   return 'Sin stock';
    default:                    return _kEstadoTodos;
  }
}

class _Toolbar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final String nomSucursal;
  final ValueChanged<ProductCategory?> onCategoriaChanged;
  final ValueChanged<StockState?> onEstadoChanged;
  final String? estadoInicialLabel;
  const _Toolbar({
    required this.controller,
    required this.onSearch,
    required this.nomSucursal,
    required this.onCategoriaChanged,
    required this.onEstadoChanged,
    this.estadoInicialLabel,
  });
  @override
  State<_Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<_Toolbar> {
  String _categoriaLabel = _kCategoriaTodas;
  late String _estadoLabel;

  @override
  void initState() {
    super.initState();
    _estadoLabel = widget.estadoInicialLabel ?? _kEstadoTodos;
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12, runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SearchBox(controller: widget.controller, onChanged: widget.onSearch),
        _FilterDropdown(
          label: 'Categoría:',
          value: _categoriaLabel,
          options: _categoriaOpciones,
          onChanged: (opt) {
            setState(() => _categoriaLabel = opt);
            widget.onCategoriaChanged(_labelToCategoria(opt));
          },
        ),
        _FilterDropdown(
          label: 'Estado:',
          value: _estadoLabel,
          options: _estadoOpciones,
          onChanged: (opt) {
            setState(() => _estadoLabel = opt);
            widget.onEstadoChanged(_labelToEstado(opt));
          },
        ),
        _FilterDropdown(
          label: 'Sucursal:',
          value: widget.nomSucursal.isNotEmpty ? widget.nomSucursal : 'Activa',
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBox({required this.controller, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360, height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: CendentColors.ink),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Buscar producto por nombre o SKU…',
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

class _FilterDropdown extends StatefulWidget {
  final String label;
  final String value;
  final List<String>? options;
  final ValueChanged<String>? onChanged;
  const _FilterDropdown({
    required this.label,
    required this.value,
    this.options,
    this.onChanged,
  });
  @override
  State<_FilterDropdown> createState() => _FilterDropdownState();
}

class _FilterDropdownState extends State<_FilterDropdown> {
  bool _hover = false;
  final _key = GlobalKey();

  Future<void> _openMenu() async {
    if (widget.options == null || widget.onChanged == null) return;
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      items: widget.options!.map((opt) => PopupMenuItem<String>(
        value: opt,
        child: Text(
          opt,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: opt == widget.value ? FontWeight.w700 : FontWeight.w500,
            color: opt == widget.value ? CendentColors.primary : CendentColors.ink,
          ),
        ),
      )).toList(),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    if (selected != null) widget.onChanged!(selected);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _openMenu,
        child: AnimatedContainer(
          key: _key,
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hover ? CendentColors.blueWash : CendentColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _hover ? CendentColors.blueLight : CendentColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: CendentColors.secondary)),
              const SizedBox(width: 6),
              Text(widget.value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: CendentColors.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  SUMMARY CHIPS — reciben valores reales
// =============================================================================
class _SummaryChips extends StatelessWidget {
  final int totalProductos;
  final int bajoMinimo;
  final int porVencer30;
  final int sinStock;
  const _SummaryChips({
    required this.totalProductos,
    required this.bajoMinimo,
    required this.porVencer30,
    required this.sinStock,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1180 ? 4 : (c.maxWidth >= 640 ? 2 : 1);
      const gap = 16.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      final items = <Widget>[
        _ChipCard(icon: Icons.inventory_2_outlined, tone: _Tone.blue,  value: '$totalProductos', label: 'Total de productos'),
        _ChipCard(icon: Icons.trending_down_rounded, tone: _Tone.red,  value: '$bajoMinimo',     label: 'Bajo stock mínimo'),
        _ChipCard(icon: Icons.event_busy_outlined,  tone: _Tone.amber, value: '$porVencer30',    label: 'Por vencer en 30 días'),
        _ChipCard(icon: Icons.inventory_outlined,   tone: _Tone.slate, value: '$sinStock',       label: 'Stock en cero'),
      ];
      return Wrap(
        spacing: gap, runSpacing: gap,
        children: items.map((e) => SizedBox(width: w, child: e)).toList(),
      );
    });
  }
}

enum _Tone { blue, red, amber, slate }

class _ChipCard extends StatelessWidget {
  final IconData icon;
  final _Tone tone;
  final String value;
  final String label;
  const _ChipCard({required this.icon, required this.tone, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    late Color fg, bg;
    switch (tone) {
      case _Tone.blue:  fg = CendentColors.primary; bg = CendentColors.blueTint;  break;
      case _Tone.red:   fg = CendentColors.red;     bg = CendentColors.redSoft;   break;
      case _Tone.amber: fg = CendentColors.amber;   bg = CendentColors.amberSoft; break;
      case _Tone.slate: fg = CendentColors.steel;   bg = const Color(0xFFEAEFF4); break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline),
        boxShadow: CendentColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 22, color: fg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.1, color: CendentColors.ink)),
                const SizedBox(height: 1),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: CendentColors.secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
//  FOOTER
// =============================================================================
class _InvFooter extends StatelessWidget {
  const _InvFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
      child: const Column(
        children: [
          Text("Daniel's CEDENT S.A.  ·  Centro de Especialidades Odontológicas",
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

// =============================================================================
//  TABLA DE INVENTARIO + PAGINACIÓN
// =============================================================================
class _InventoryTableCard extends StatelessWidget {
  final List<Product> products;
  final Product? selected;
  final ValueChanged<Product> onRowTap;
  final ValueChanged<Product> onAgregarLoteTap;
  final ValueChanged<Product> onEditarProductoTap;
  final ValueChanged<Product> onEliminarProductoTap;
  final int perPage;
  final ValueChanged<int> onPerPageChanged;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  const _InventoryTableCard({
    required this.products,
    required this.selected,
    required this.onRowTap,
    required this.onAgregarLoteTap,
    required this.onEditarProductoTap,
    required this.onEliminarProductoTap,
    required this.perPage,
    required this.onPerPageChanged,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start = (currentPage - 1) * perPage;
    final end = (start + perPage).clamp(0, products.length);
    final pageItems = start < products.length ? products.sublist(start, end) : <Product>[];

    return Container(
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline),
        boxShadow: CendentColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final tableW = (!constraints.maxWidth.isInfinite && constraints.maxWidth > 1040)
                  ? constraints.maxWidth
                  : 1080.0;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableW,
                  child: _InventoryTable(products: pageItems, selected: selected, onRowTap: onRowTap, onAgregarLoteTap: onAgregarLoteTap, onEditarProductoTap: onEditarProductoTap, onEliminarProductoTap: onEliminarProductoTap),

                ),
              );
            },
          ),
          _PaginationBar(
            total: products.length,
            perPage: perPage,
            currentPage: currentPage,
            onPerPageChanged: onPerPageChanged,
            onPageChanged: onPageChanged,
          ),
        ],
      ),
    );
  }
}

class _InventoryTable extends StatelessWidget {
  final List<Product> products;
  final Product? selected;
  final ValueChanged<Product> onRowTap;
  final ValueChanged<Product> onAgregarLoteTap;
  final ValueChanged<Product> onEditarProductoTap;
  final ValueChanged<Product> onEliminarProductoTap;
  const _InventoryTable({required this.products, required this.selected, required this.onRowTap, required this.onAgregarLoteTap, required this.onEditarProductoTap, required this.onEliminarProductoTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAFBFD),
            border: Border(bottom: BorderSide(color: CendentColors.hairline)),
          ),
          child: const Row(
            children: [
              _HeaderCell('Producto',          flex: 220),
              _HeaderCell('Categoría',         flex: 130),
              _HeaderCell('Stock actual',      flex: 110),
              _HeaderCell('Stock mín.',        flex: 90),
              _HeaderCell('Lotes activos',     flex: 100),
              _HeaderCell('Próx. vencimiento', flex: 130),
              _HeaderCell('Estado',            flex: 120),
              _HeaderCell('Acciones',          flex: 190),
            ],
          ),
        ),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: Text('Sin productos en inventario', style: TextStyle(color: CendentColors.secondary))),
          )
        else
          ...List.generate(products.length, (i) {
            final p = products[i];
            return _InventoryRow(
              product: p,
              isSelected: selected?.idProducto == p.idProducto,
              isLast: i == products.length - 1,
              onTap: () => onRowTap(p),
              onAgregarLote: () => onAgregarLoteTap(p),
              onEditarProducto: () => onEditarProductoTap(p),
              onEliminarProducto: () => onEliminarProductoTap(p),
            );
          }),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell(this.label, {required this.flex});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(label.toUpperCase(),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: CendentColors.secondary)),
      ),
    );
  }
}

class _InventoryRow extends StatefulWidget {
  final Product product;
  final bool isSelected;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onAgregarLote;
  final VoidCallback onEditarProducto;
  final VoidCallback onEliminarProducto;
  const _InventoryRow({required this.product, required this.isSelected, required this.isLast, required this.onTap, required this.onAgregarLote, required this.onEditarProducto, required this.onEliminarProducto});
  @override
  State<_InventoryRow> createState() => _InventoryRowState();
}

class _InventoryRowState extends State<_InventoryRow> {
  bool _hover = false;
  final _api = ApiService();

  Future<void> _openEditarProducto() async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (_) => _EditarProductoDialog(product: widget.product),
    );
    if (guardado == true && mounted) {
      widget.onEditarProducto();
    }
  }

  Future<void> _openEliminarProducto() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar producto',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CendentColors.ink)),
        content: Text('¿Eliminar "${widget.product.name}"? Esta acción no se puede deshacer.',
            style: const TextStyle(fontSize: 14, color: CendentColors.secondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: CendentColors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final (:ok, :errorMsg) = await _api.eliminarProducto(widget.product.idProducto);
    if (!mounted) return;
    if (ok) {
      widget.onEliminarProducto();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? 'No se pudo eliminar el producto'),
          backgroundColor: CendentColors.red,
        ),
      );
    }
  }

  Color get _rowColor {
    final p = widget.product;
    if (widget.isSelected) return CendentColors.blueTint;
    if (_hover) {
      if (p.state == StockState.bajoMinimo) return const Color(0xFFF8DAD7);
      if (p.state == StockState.porVencer)  return const Color(0xFFF8E6BC);
      return CendentColors.blueWash;
    }
    if (p.state == StockState.bajoMinimo) return CendentColors.redSoft;
    if (p.state == StockState.porVencer)  return CendentColors.amberRow;
    return CendentColors.card;
  }

  @override
  Widget build(BuildContext context) {
    final p   = widget.product;
    final cat = _CatStyle.of(p.category);
    final st  = _StateStyle.of(p.state);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _rowColor,
            border: widget.isLast ? null : const Border(bottom: BorderSide(color: CendentColors.hairlineSoft)),
          ),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _Cell(flex: 220, child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                      const SizedBox(height: 2),
                      Text(p.sku, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: CendentColors.secondary, fontFamily: 'monospace')),
                    ],
                  )),
                  _Cell(flex: 130, child: Align(alignment: Alignment.centerLeft, child: _CategoryBadge(style: cat))),
                  _Cell(flex: 110, child: _stockWidget(p)),
                  _Cell(flex: 90,  child: Text('${p.minStock} u', style: const TextStyle(fontSize: 13.5, color: CendentColors.secondary))),
                  _Cell(flex: 100, child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.layers_outlined, size: 15, color: CendentColors.secondary),
                      const SizedBox(width: 6),
                      Text('${p.lotes}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                    ],
                  )),
                  _Cell(flex: 130, child: Text(
                    p.nextExpiry ?? '— sin lotes',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: p.expirySoon ? FontWeight.w600 : FontWeight.w400,
                      color: p.nextExpiry == null ? CendentColors.muted : (p.expirySoon ? CendentColors.amber : CendentColors.ink),
                    ),
                  )),
                  _Cell(flex: 120, child: Align(alignment: Alignment.centerLeft, child: _StatusChip(style: st))),
                  _Cell(flex: 190, child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RowAction(icon: Icons.visibility_outlined,        tooltip: 'Ver detalle',     onTap: widget.onTap),
                      _RowAction(icon: Icons.edit_outlined,              tooltip: 'Editar',          onTap: () => _openEditarProducto()),
                      _RowAction(icon: Icons.add_circle_outline_rounded, tooltip: 'Agregar lote',    onTap: widget.onAgregarLote),
                      _RowAction(icon: Icons.delete_outline_rounded,     tooltip: 'Eliminar',        onTap: () => _openEliminarProducto(), danger: true),
                    ],
                  )),
                ],
              ),
              if (widget.isSelected)
                Positioned(left: 0, top: 0, bottom: 0, child: Container(width: 3, color: CendentColors.primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockWidget(Product p) {
    if (p.state == StockState.sinStock) {
      return const Text('0', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CendentColors.muted, decoration: TextDecoration.lineThrough));
    }
    Color c = CendentColors.ink;
    if (p.state == StockState.bajoMinimo) c = CendentColors.red;
    if (p.state == StockState.porVencer)  c = CendentColors.amber;
    return RichText(
      text: TextSpan(
        text: '${p.stock}',
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c),
        children: const [TextSpan(text: ' u', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CendentColors.secondary))],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int flex;
  final Widget child;
  const _Cell({required this.flex, required this.child});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), child: child),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final _CatStyle style;
  const _CategoryBadge({required this.style});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: style.fg, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(style.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: style.fg)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _StateStyle style;
  const _StatusChip({required this.style});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: style.bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.fg),
          const SizedBox(width: 6),
          Flexible(child: Text(style.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: style.fg))),
        ],
      ),
    );
  }
}

class _RowAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;
  const _RowAction({required this.icon, required this.tooltip, required this.onTap, this.danger = false});
  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final hoverBg    = widget.danger ? CendentColors.redSoft  : CendentColors.blueTint;
    final hoverColor = widget.danger ? CendentColors.red      : CendentColors.primary;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32, height: 32,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _hover ? hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, size: 16, color: _hover ? hoverColor : CendentColors.secondary),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
//  Paginación
// -----------------------------------------------------------------------------
class _PaginationBar extends StatelessWidget {
  final int total;
  final int perPage;
  final int currentPage;
  final ValueChanged<int> onPerPageChanged;
  final ValueChanged<int> onPageChanged;

  const _PaginationBar({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.onPerPageChanged,
    required this.onPageChanged,
  });

  int get _totalPages => total == 0 ? 1 : (total / perPage).ceil();
  int get _startItem => total == 0 ? 0 : (currentPage - 1) * perPage + 1;
  int get _endItem => (currentPage * perPage).clamp(0, total);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 12, spacing: 16,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: CendentColors.secondary),
              children: [
                const TextSpan(text: 'Mostrando '),
                TextSpan(
                    text: total == 0 ? '0' : '$_startItem–$_endItem',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: CendentColors.ink)),
                const TextSpan(text: ' de '),
                TextSpan(
                    text: '$total',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: CendentColors.ink)),
                const TextSpan(text: ' productos'),
              ],
            ),
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16, runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Por página:', style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                  const SizedBox(width: 8),
                  _PerPageSegment(value: perPage, onChanged: onPerPageChanged),
                ],
              ),
              _Pager(current: currentPage, total: _totalPages, onChanged: onPageChanged),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerPageSegment extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _PerPageSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const options = [10, 25, 50];
    return Container(
      decoration: BoxDecoration(border: Border.all(color: CendentColors.hairline), borderRadius: BorderRadius.circular(10)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (i) {
          final opt = options[i];
          final active = opt == value;
          return GestureDetector(
            onTap: () => onChanged(opt),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: active ? CendentColors.blueTint : CendentColors.card,
                border: Border(right: i < options.length - 1 ? const BorderSide(color: CendentColors.hairline) : BorderSide.none),
              ),
              child: Text('$opt', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? CendentColors.primary : CendentColors.steel)),
            ),
          );
        }),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int current;
  final int total;
  final ValueChanged<int> onChanged;
  const _Pager({required this.current, required this.total, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final startPage = (current - 2).clamp(1, (total - 4).clamp(1, total));
    final endPage = (startPage + 4).clamp(1, total);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PagerBtn(
          enabled: current > 1,
          onTap: () => onChanged(current - 1),
          child: const Icon(Icons.chevron_left_rounded, size: 16),
        ),
        for (int p = startPage; p <= endPage; p++)
          _PagerBtn(
            active: p == current,
            onTap: () => onChanged(p),
            child: Text('$p'),
          ),
        _PagerBtn(
          enabled: current < total,
          onTap: () => onChanged(current + 1),
          child: const Icon(Icons.chevron_right_rounded, size: 16),
        ),
      ],
    );
  }
}

class _PagerBtn extends StatefulWidget {
  final Widget child;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;
  const _PagerBtn({required this.child, this.active = false, this.enabled = true, this.onTap});
  @override
  State<_PagerBtn> createState() => _PagerBtnState();
}

class _PagerBtnState extends State<_PagerBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    Color bg = CendentColors.card;
    Color fg = CendentColors.steel;
    Color border = CendentColors.hairline;
    if (active) { bg = CendentColors.primary; fg = Colors.white; border = CendentColors.primary; }
    else if (_hover && widget.enabled) { bg = CendentColors.blueWash; border = CendentColors.blueLight; }
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: Container(
            margin: const EdgeInsets.only(left: 4),
            constraints: const BoxConstraints(minWidth: 32),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
            child: DefaultTextStyle(
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg),
              child: IconTheme(data: IconThemeData(color: fg), child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  DIALOG — agregar lote
// =============================================================================
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: CendentColors.secondary),
  );
}

class _AgregarLoteDialog extends StatefulWidget {
  final Product product;
  final int idSucursal;
  const _AgregarLoteDialog({required this.product, required this.idSucursal});
  @override
  State<_AgregarLoteDialog> createState() => _AgregarLoteDialogState();
}

class _AgregarLoteDialogState extends State<_AgregarLoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stockCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _api = ApiService();

  DateTime? _fechaVenc;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _stockCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  Future<void> _selectFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: hoy.add(const Duration(days: 1)),
      firstDate: hoy.add(const Duration(days: 1)),
      lastDate: DateTime(hoy.year + 20),
    );
    if (picked != null) setState(() { _fechaVenc = picked; _error = null; });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaVenc == null) {
      setState(() => _error = 'Selecciona una fecha de vencimiento');
      return;
    }
    setState(() { _guardando = true; _error = null; });

    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final costoRaw = _costoCtrl.text.trim().replaceAll(',', '.');
    final costo = costoRaw.isEmpty ? null : double.tryParse(costoRaw);
    final f = _fechaVenc!;
    final fechaStr = '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

    final (:ok, :errorMsg) = await _api.crearLote(
      idProducto: widget.product.idProducto,
      stockInicial: stock,
      fechaVenc: fechaStr,
      costoUnit: costo,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _guardando = false; _error = errorMsg ?? 'No se pudo guardar el lote'; });
    }
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Agregar lote', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: CendentColors.ink)),
                            const SizedBox(height: 4),
                            Text(widget.product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: CendentColors.secondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CloseButton(onTap: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('Stock inicial'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        enabled: !_guardando,
                        style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                        decoration: _inputDeco('Ej. 50'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n <= 0) return 'Debe ser un número entero mayor a 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Fecha de vencimiento'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _guardando ? null : _selectFecha,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: CendentColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CendentColors.hairline),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 17, color: CendentColors.secondary),
                              const SizedBox(width: 10),
                              Text(
                                _fechaVenc != null ? _fmtFecha(_fechaVenc!) : 'Seleccionar fecha…',
                                style: TextStyle(fontSize: 14, color: _fechaVenc != null ? CendentColors.ink : CendentColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Costo unitario (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        enabled: !_guardando,
                        style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                        decoration: _inputDeco('Ej. 8.75'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim().replaceAll(',', '.'));
                          if (n == null || n < 0) return 'Ingresa un número válido mayor o igual a 0';
                          return null;
                        },
                      ),
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
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AppButton(
                          icon: Icons.close_rounded,
                          label: 'Cancelar',
                          kind: _BtnKind.secondary,
                          onTap: _guardando ? () {} : () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _guardando
                            ? const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 11),
                                child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5)),
                              ))
                            : _AppButton(icon: Icons.add_rounded, label: 'Guardar lote', kind: _BtnKind.primary, onTap: _guardar),
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

// =============================================================================
//  DIALOG — editar lote
// =============================================================================
class _EditarLoteDialog extends StatefulWidget {
  final Lote lote;
  const _EditarLoteDialog({required this.lote});
  @override
  State<_EditarLoteDialog> createState() => _EditarLoteDialogState();
}

class _EditarLoteDialogState extends State<_EditarLoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _stockCtrl = TextEditingController();
  final _costoCtrl = TextEditingController();
  final _api = ApiService();

  DateTime? _fechaVenc;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _stockCtrl.text = widget.lote.stock.toString();
    if (widget.lote.rawCosto != null) {
      _costoCtrl.text = widget.lote.rawCosto!.toStringAsFixed(2);
    }
    if (widget.lote.rawFechaVenc != null) {
      try { _fechaVenc = DateTime.parse(widget.lote.rawFechaVenc!).toLocal(); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _stockCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _selectFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVenc ?? hoy,
      firstDate: DateTime(hoy.year - 5),
      lastDate: DateTime(hoy.year + 20),
    );
    if (picked != null) setState(() { _fechaVenc = picked; _error = null; });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaVenc == null) {
      setState(() => _error = 'Selecciona una fecha de vencimiento');
      return;
    }
    setState(() { _guardando = true; _error = null; });

    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final costoRaw = _costoCtrl.text.trim().replaceAll(',', '.');
    final costo = costoRaw.isEmpty ? null : double.tryParse(costoRaw);
    final f = _fechaVenc!;
    final fechaStr = '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

    final (:ok, :errorMsg) = await _api.actualizarLote(
      idLote: widget.lote.idLote,
      stockActual: stock,
      fechaVenc: fechaStr,
      costoUnit: costo,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _guardando = false; _error = errorMsg ?? 'No se pudo actualizar el lote'; });
    }
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Editar lote', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: CendentColors.ink)),
                            const SizedBox(height: 4),
                            Text(widget.lote.code, style: const TextStyle(fontSize: 13, color: CendentColors.secondary, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CloseButton(onTap: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('Stock actual'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _stockCtrl,
                        keyboardType: TextInputType.number,
                        enabled: !_guardando,
                        style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                        decoration: _inputDeco('Ej. 50'),
                        validator: (v) {
                          final n = int.tryParse(v?.trim() ?? '');
                          if (n == null || n < 0) return 'Debe ser un número entero mayor o igual a 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Fecha de vencimiento'),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _guardando ? null : _selectFecha,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: CendentColors.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: CendentColors.hairline),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 17, color: CendentColors.secondary),
                              const SizedBox(width: 10),
                              Text(
                                _fechaVenc != null ? _fmtFecha(_fechaVenc!) : 'Seleccionar fecha…',
                                style: TextStyle(fontSize: 14, color: _fechaVenc != null ? CendentColors.ink : CendentColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Costo unitario (opcional)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _costoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        enabled: !_guardando,
                        style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                        decoration: _inputDeco('Ej. 8.75'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final n = double.tryParse(v.trim().replaceAll(',', '.'));
                          if (n == null || n < 0) return 'Ingresa un número válido mayor o igual a 0';
                          return null;
                        },
                      ),
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
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AppButton(
                          icon: Icons.close_rounded,
                          label: 'Cancelar',
                          kind: _BtnKind.secondary,
                          onTap: _guardando ? () {} : () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _guardando
                            ? const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 11),
                                child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5)),
                              ))
                            : _AppButton(icon: Icons.save_outlined, label: 'Guardar cambios', kind: _BtnKind.primary, onTap: _guardar),
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

// =============================================================================
//  SKELETON — placeholder mientras carga inventario
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

class _InventorySkeleton extends StatelessWidget {
  const _InventorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CendentColors.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page head
            const _SkeletonBox(width: 200, height: 26, radius: 8),
            const SizedBox(height: 8),
            const _SkeletonBox(width: 300, height: 14, radius: 5),
            const SizedBox(height: 20),
            // Toolbar
            const _SkeletonBox(width: 360, height: 44, radius: 14),
            const SizedBox(height: 18),
            // Summary chips
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth >= 1180 ? 4 : (c.maxWidth >= 640 ? 2 : 1);
              const gap = 16.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap, runSpacing: gap,
                children: List.generate(4, (_) => SizedBox(
                  width: w,
                  child: Container(
                    height: 76,
                    decoration: BoxDecoration(
                      color: CendentColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: CendentColors.hairline),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: const Row(children: [
                      _SkeletonBox(width: 44, height: 44, radius: 14),
                      SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        _SkeletonBox(width: 40, height: 24, radius: 5),
                        SizedBox(height: 4),
                        _SkeletonBox(width: 100, height: 12, radius: 4),
                      ]),
                    ]),
                  ),
                )),
              );
            }),
            const SizedBox(height: 18),
            // Table card skeleton
            Container(
              decoration: BoxDecoration(
                color: CendentColors.card,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: CendentColors.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Header row
                  Container(
                    color: const Color(0xFFFAFBFD),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: const Row(children: [
                      Expanded(flex: 220, child: _SkeletonBox(width: 80, height: 11, radius: 3)),
                      Expanded(flex: 130, child: _SkeletonBox(width: 70, height: 11, radius: 3)),
                      Expanded(flex: 110, child: _SkeletonBox(width: 80, height: 11, radius: 3)),
                      Expanded(flex: 90,  child: _SkeletonBox(width: 70, height: 11, radius: 3)),
                      Expanded(flex: 100, child: _SkeletonBox(width: 75, height: 11, radius: 3)),
                      Expanded(flex: 130, child: _SkeletonBox(width: 100, height: 11, radius: 3)),
                      Expanded(flex: 120, child: _SkeletonBox(width: 60, height: 11, radius: 3)),
                      Expanded(flex: 150, child: _SkeletonBox(width: 70, height: 11, radius: 3)),
                    ]),
                  ),
                  ...List.generate(8, (i) => Container(
                    decoration: BoxDecoration(
                      border: i < 7 ? const Border(bottom: BorderSide(color: CendentColors.hairlineSoft)) : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: const Row(children: [
                      Expanded(flex: 220, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _SkeletonBox(width: 130, height: 13, radius: 4),
                        SizedBox(height: 4),
                        _SkeletonBox(width: 70, height: 11, radius: 3),
                      ])),
                      Expanded(flex: 130, child: _SkeletonBox(width: 70, height: 22, radius: 9999)),
                      Expanded(flex: 110, child: _SkeletonBox(width: 40, height: 19, radius: 4)),
                      Expanded(flex: 90,  child: _SkeletonBox(width: 30, height: 13, radius: 4)),
                      Expanded(flex: 100, child: _SkeletonBox(width: 24, height: 13, radius: 4)),
                      Expanded(flex: 130, child: _SkeletonBox(width: 80, height: 13, radius: 4)),
                      Expanded(flex: 120, child: _SkeletonBox(width: 80, height: 22, radius: 9999)),
                      Expanded(flex: 150, child: _SkeletonBox(width: 90, height: 28, radius: 10)),
                    ]),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  PANEL LATERAL DE DETALLE — carga lotes y movimientos de forma lazy
// =============================================================================
class LoteDetailPanel extends StatefulWidget {
  final Product product;
  final int idSucursal;
  final VoidCallback onClose;
  final VoidCallback onAgregarLote;
  final VoidCallback? onLoteActualizado;
  final VoidCallback? onProductoActualizado;
  const LoteDetailPanel({super.key, required this.product, required this.idSucursal, required this.onClose, required this.onAgregarLote, this.onLoteActualizado, this.onProductoActualizado});

  @override
  State<LoteDetailPanel> createState() => _LoteDetailPanelState();
}

class _LoteDetailPanelState extends State<LoteDetailPanel> {
  final _api = ApiService();
  bool _loading = true;
  bool _error   = false;
  List<Lote> _lotes = [];
  List<Mov>  _movs  = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void didUpdateWidget(LoteDetailPanel old) {
    super.didUpdateWidget(old);
    // Recargar si cambia el producto seleccionado
    if (old.product.idProducto != widget.product.idProducto) {
      _loadDetail();
    }
  }

  Future<void> _openEditarProducto() async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (_) => _EditarProductoDialog(product: widget.product),
    );
    if (guardado == true && mounted) {
      widget.onProductoActualizado?.call();
    }
  }

  Future<void> _openEditarLote(Lote lote) async {
    final guardado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (_) => _EditarLoteDialog(lote: lote),
    );
    if (guardado == true && mounted) {
      _api.invalidateCache();
      _loadDetail();
      widget.onLoteActualizado?.call();
    }
  }

  Future<void> _openDarDeBajaLote(Lote lote) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x6B0D1B2A),
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Dar de baja este lote',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: CendentColors.ink)),
        content: const Text('¿Dar de baja este lote? Esta acción no se puede deshacer.',
            style: TextStyle(fontSize: 14, color: CendentColors.secondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: CendentColors.red),
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final (:ok, :errorMsg) = await _api.darDeBajaLote(lote.idLote);
    if (!mounted) return;
    if (ok) {
      _api.invalidateCache();
      _loadDetail();
      widget.onLoteActualizado?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg ?? 'No se pudo dar de baja el lote'),
          backgroundColor: CendentColors.red,
        ),
      );
    }
  }

  Future<void> _loadDetail() async {
    setState(() { _loading = true; _error = false; });

    final results = await Future.wait([
      _api.getLotesProducto(widget.product.idProducto),
      _api.getMovimientos(widget.idSucursal, idProducto: widget.product.idProducto),
    ]);

    if (!mounted) return;

    final rawLotes = results[0];
    final rawMovs  = results[1];

    if (rawLotes == null) {
      setState(() { _loading = false; _error = true; });
      return;
    }

    setState(() {
      _lotes   = rawLotes.map(_mapLote).where((l) => l.stock > 0).toList();
      _movs    = (rawMovs ?? []).map(_mapMov).toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cat = _CatStyle.of(widget.product.category);
    return Material(
      color: CendentColors.card,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(color: CendentColors.card, boxShadow: CendentColors.popShadow),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.product.name,
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: CendentColors.ink)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _CategoryBadge(style: cat),
                            const SizedBox(width: 10),
                            Text(widget.product.sku, style: const TextStyle(fontSize: 12, color: CendentColors.secondary, fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PanelEditBtn(onTap: () => _openEditarProducto()),
                  const SizedBox(width: 6),
                  _CloseButton(onTap: widget.onClose),
                ],
              ),
            ),
            // Body
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5),
                          SizedBox(height: 14),
                          Text('Cargando lotes y movimientos…', style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                        ],
                      ),
                    )
                  : _error
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 40, color: CendentColors.secondary),
                              const SizedBox(height: 12),
                              const Text('No se pudieron cargar los datos', style: TextStyle(color: CendentColors.secondary)),
                              const SizedBox(height: 12),
                              TextButton(onPressed: _loadDetail, child: const Text('Reintentar')),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(
                                'Lotes activos',
                                trailing: _lotes.length == 1 ? '1 vigente' : '${_lotes.length} vigentes',
                              ),
                              const SizedBox(height: 12),
                              if (_lotes.isEmpty)
                                _EmptyLotes()
                              else
                                ..._lotes.map((l) => _LoteCard(lote: l, onEdit: () => _openEditarLote(l), onBaja: () => _openDarDeBajaLote(l))),
                              const SizedBox(height: 26),
                              const _SectionTitle('Movimientos recientes', trailing: 'últimos 10'),
                              const SizedBox(height: 4),
                              if (_movs.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Text('Sin movimientos registrados', textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                                )
                              else
                                ..._movs.asMap().entries.map((e) => _MovRow(
                                      mov: e.value,
                                      isLast: e.key == _movs.length - 1,
                                    )),
                            ],
                          ),
                        ),
            ),
            // Footer actions
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
              child: Row(
                children: [
                  Expanded(child: _AppButton(icon: Icons.note_add_outlined, label: 'Registrar mov.', kind: _BtnKind.secondary, onTap: () {})),
                  const SizedBox(width: 12),
                  Expanded(child: _AppButton(icon: Icons.add_rounded, label: 'Agregar lote', kind: _BtnKind.primary, onTap: widget.onAgregarLote)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});
  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const _SectionTitle(this.title, {this.trailing});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: CendentColors.secondary)),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CendentColors.muted)),
      ],
    );
  }
}

class _EmptyLotes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: CendentColors.hairline)),
      child: const Text('Sin lotes vigentes. Agregue uno para reponer stock.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
    );
  }
}

// =============================================================================
//  BOTÓN EDITAR PANEL (header del LoteDetailPanel)
// =============================================================================
class _PanelEditBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _PanelEditBtn({required this.onTap});
  @override
  State<_PanelEditBtn> createState() => _PanelEditBtnState();
}

class _PanelEditBtnState extends State<_PanelEditBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Editar producto',
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: _hover ? CendentColors.blueTint : CendentColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CendentColors.hairline),
            ),
            child: Icon(Icons.edit_outlined, size: 17, color: _hover ? CendentColors.primary : CendentColors.steel),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  DIALOG — editar producto
// =============================================================================
class _EditarProductoDialog extends StatefulWidget {
  final Product product;
  const _EditarProductoDialog({required this.product});
  @override
  State<_EditarProductoDialog> createState() => _EditarProductoDialogState();
}

class _EditarProductoDialogState extends State<_EditarProductoDialog> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _catCtrl      = TextEditingController();
  final _subCtrl      = TextEditingController();
  final _unidadCtrl   = TextEditingController();
  final _stockMinCtrl = TextEditingController();
  final _api = ApiService();

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text   = widget.product.rawNombre;
    _catCtrl.text      = widget.product.rawCategoria ?? '';
    _subCtrl.text      = widget.product.rawSubcategoria ?? '';
    _unidadCtrl.text   = widget.product.rawUnidad;
    _stockMinCtrl.text = widget.product.rawStockMin.toString();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _catCtrl.dispose();
    _subCtrl.dispose();
    _unidadCtrl.dispose();
    _stockMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _guardando = true; _error = null; });

    final nombre   = _nombreCtrl.text.trim();
    final cat      = _catCtrl.text.trim();
    final sub      = _subCtrl.text.trim();
    final unidad   = _unidadCtrl.text.trim();
    final stockMin = int.tryParse(_stockMinCtrl.text.trim()) ?? 0;

    final (:ok, :errorMsg) = await _api.actualizarProducto(
      idProducto:   widget.product.idProducto,
      nombre:       nombre,
      categoria:    cat.isEmpty ? null : cat,
      subcategoria: sub.isEmpty ? null : sub,
      unidadMedida: unidad,
      stockMin:     stockMin,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _guardando = false; _error = errorMsg ?? 'No se pudo actualizar el producto'; });
    }
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
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
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Editar producto', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: CendentColors.ink)),
                            const SizedBox(height: 4),
                            Text(widget.product.sku, style: const TextStyle(fontSize: 13, color: CendentColors.secondary, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CloseButton(onTap: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FieldLabel('Nombre'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nombreCtrl,
                          enabled: !_guardando,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Nombre del producto'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Categoría (opcional)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _catCtrl,
                          enabled: !_guardando,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej. Odontología'),
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Subcategoría (opcional)'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _subCtrl,
                          enabled: !_guardando,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej. Material de Impresión'),
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Unidad de medida'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _unidadCtrl,
                          enabled: !_guardando,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej. Kg, Unidad, Caja'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'La unidad de medida es requerida' : null,
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Stock mínimo'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _stockMinCtrl,
                          keyboardType: TextInputType.number,
                          enabled: !_guardando,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej. 5'),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) return 'Debe ser un número entero mayor o igual a 0';
                            return null;
                          },
                        ),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AppButton(
                          icon: Icons.close_rounded,
                          label: 'Cancelar',
                          kind: _BtnKind.secondary,
                          onTap: _guardando ? () {} : () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _guardando
                            ? const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 11),
                                child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5)),
                              ))
                            : _AppButton(icon: Icons.save_outlined, label: 'Guardar', kind: _BtnKind.primary, onTap: _guardar),
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

// =============================================================================
//  DIALOG — agregar producto
// =============================================================================
class _AgregarProductoDialog extends StatefulWidget {
  const _AgregarProductoDialog();
  @override
  State<_AgregarProductoDialog> createState() => _AgregarProductoDialogState();
}

class _AgregarProductoDialogState extends State<_AgregarProductoDialog> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _catCtrl       = TextEditingController();
  final _subCtrl       = TextEditingController();
  final _unidadCtrl    = TextEditingController();
  final _stockMinCtrl  = TextEditingController(text: '0');
  final _stockIniCtrl  = TextEditingController();
  final _costoCtrl     = TextEditingController();
  final _api = ApiService();

  DateTime? _fechaVenc;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _catCtrl.dispose();
    _subCtrl.dispose();
    _unidadCtrl.dispose();
    _stockMinCtrl.dispose();
    _stockIniCtrl.dispose();
    _costoCtrl.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  }

  Future<void> _selectFecha() async {
    final hoy = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: hoy.add(const Duration(days: 1)),
      firstDate: hoy.add(const Duration(days: 1)),
      lastDate: DateTime(hoy.year + 20),
    );
    if (picked != null) setState(() { _fechaVenc = picked; _error = null; });
  }

  bool get _tieneStockInicial {
    final v = int.tryParse(_stockIniCtrl.text.trim());
    return v != null && v > 0;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tieneStockInicial && _fechaVenc == null) {
      setState(() => _error = 'Selecciona la fecha de vencimiento del lote inicial');
      return;
    }
    setState(() { _guardando = true; _error = null; });

    final nombre     = _nombreCtrl.text.trim();
    final cat        = _catCtrl.text.trim();
    final sub        = _subCtrl.text.trim();
    final unidad     = _unidadCtrl.text.trim();
    final stockMin   = int.tryParse(_stockMinCtrl.text.trim()) ?? 0;
    final stockIni   = int.tryParse(_stockIniCtrl.text.trim());
    final costoRaw   = _costoCtrl.text.trim().replaceAll(',', '.');
    final costo      = costoRaw.isEmpty ? null : double.tryParse(costoRaw);
    String? fechaStr;
    if (_fechaVenc != null) {
      final f = _fechaVenc!;
      fechaStr = '${f.year}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';
    }

    final (:ok, :errorMsg) = await _api.crearProducto(
      nombre:       nombre,
      categoria:    cat.isEmpty ? null : cat,
      subcategoria: sub.isEmpty ? null : sub,
      unidadMedida: unidad,
      stockMin:     stockMin,
      stockInicial: stockIni,
      fechaVenc:    fechaStr,
      costoUnit:    costo,
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() { _guardando = false; _error = errorMsg ?? 'No se pudo crear el producto'; });
    }
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 720),
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
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agregar producto', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.25, color: CendentColors.ink)),
                            SizedBox(height: 4),
                            Text('El código de lote se genera automáticamente', style: TextStyle(fontSize: 13, color: CendentColors.secondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CloseButton(onTap: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),
                // Body
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Datos del producto ──────────────────────────────
                        const _FieldLabel('Nombre del producto'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nombreCtrl,
                          enabled: !_guardando,
                          style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej. Alginato Cromo Rojo'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel('Categoría (opcional)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _catCtrl,
                                    enabled: !_guardando,
                                    style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                                    decoration: _inputDeco('Ej. Odontología'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel('Subcategoría (opcional)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _subCtrl,
                                    enabled: !_guardando,
                                    style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                                    decoration: _inputDeco('Ej. Material de Impresión'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel('Unidad de medida'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _unidadCtrl,
                                    enabled: !_guardando,
                                    style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                                    decoration: _inputDeco('Ej. Kg, Unidad, Caja'),
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerida' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel('Stock mínimo'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _stockMinCtrl,
                                    keyboardType: TextInputType.number,
                                    enabled: !_guardando,
                                    style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                                    decoration: _inputDeco('Ej. 5'),
                                    validator: (v) {
                                      final n = int.tryParse(v?.trim() ?? '');
                                      if (n == null || n < 0) return 'Mín. 0';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // ── Lote inicial (opcional) ─────────────────────────
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: CendentColors.blueTint, borderRadius: BorderRadius.circular(12)),
                          child: const Text('Lote inicial (opcional) — completa estos campos para crear el primer lote automáticamente',
                              style: TextStyle(fontSize: 12, color: CendentColors.primary)),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel('Stock inicial'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _stockIniCtrl,
                                    keyboardType: TextInputType.number,
                                    enabled: !_guardando,
                                    style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                                    decoration: _inputDeco('Ej. 50'),
                                    onChanged: (_) => setState(() {}),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return null;
                                      final n = int.tryParse(v.trim());
                                      if (n == null || n <= 0) return 'Debe ser mayor a 0';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel('Costo unitario (opcional)'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _costoCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    enabled: !_guardando,
                                    style: const TextStyle(fontSize: 14, color: CendentColors.ink),
                                    decoration: _inputDeco('Ej. 8.75'),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return null;
                                      final n = double.tryParse(v.trim().replaceAll(',', '.'));
                                      if (n == null || n < 0) return 'Número inválido';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const _FieldLabel('Fecha de vencimiento del lote'),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: _guardando ? null : _selectFecha,
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: CendentColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: (_tieneStockInicial && _fechaVenc == null && _error != null)
                                    ? CendentColors.red
                                    : CendentColors.hairline,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_outlined, size: 17,
                                    color: _tieneStockInicial ? CendentColors.primary : CendentColors.secondary),
                                const SizedBox(width: 10),
                                Text(
                                  _fechaVenc != null
                                      ? _fmtFecha(_fechaVenc!)
                                      : (_tieneStockInicial ? 'Requerida — seleccionar…' : 'Opcional — seleccionar…'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _fechaVenc != null
                                        ? CendentColors.ink
                                        : (_tieneStockInicial ? CendentColors.primary : CendentColors.muted),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    children: [
                      Expanded(
                        child: _AppButton(
                          icon: Icons.close_rounded,
                          label: 'Cancelar',
                          kind: _BtnKind.secondary,
                          onTap: _guardando ? () {} : () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _guardando
                            ? const Center(child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 11),
                                child: SizedBox(width: 22, height: 22,
                                  child: CircularProgressIndicator(color: CendentColors.primary, strokeWidth: 2.5)),
                              ))
                            : _AppButton(icon: Icons.add_rounded, label: 'Crear producto', kind: _BtnKind.primary, onTap: _guardar),
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

class _LoteCard extends StatelessWidget {
  final Lote lote;
  final VoidCallback? onEdit;
  final VoidCallback? onBaja;
  const _LoteCard({required this.lote, this.onEdit, this.onBaja});

  ({String label, Color fg, Color bg}) get _pill {
    switch (lote.state) {
      case LotState.critico:   return (label: 'Crítico',    fg: CendentColors.red,   bg: CendentColors.redSoft);
      case LotState.porVencer: return (label: 'Por vencer', fg: CendentColors.amber, bg: CendentColors.amberSoft);
      case LotState.vigente:   return (label: 'Vigente',    fg: CendentColors.green, bg: CendentColors.greenSoft);
    }
  }

  Color get _expColor {
    if (lote.state == LotState.critico)   return CendentColors.red;
    if (lote.state == LotState.porVencer) return CendentColors.amber;
    return CendentColors.ink;
  }

  @override
  Widget build(BuildContext context) {
    final pill = _pill;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CendentColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(lote.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CendentColors.ink, fontFamily: 'monospace')),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: pill.bg, borderRadius: BorderRadius.circular(9999)),
                child: Text(pill.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pill.fg)),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 6),
                _LoteEditBtn(onTap: onEdit!),
              ],
              if (onBaja != null) ...[
                const SizedBox(width: 4),
                _LoteBajaBtn(onTap: onBaja!),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [
            _LoteField(label: 'Stock actual',   value: '${lote.stock} u'),
            _LoteField(label: 'Vencimiento',    value: lote.expiry, valueColor: _expColor),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _LoteField(label: 'Costo unitario', value: lote.cost),
            _LoteField(label: 'Valorizado',     value: '${lote.cost} ×${lote.stock}'),
          ]),
        ],
      ),
    );
  }
}

class _LoteEditBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _LoteEditBtn({required this.onTap});
  @override
  State<_LoteEditBtn> createState() => _LoteEditBtnState();
}

class _LoteEditBtnState extends State<_LoteEditBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Editar lote',
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _hover ? CendentColors.blueTint : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.edit_outlined, size: 14, color: _hover ? CendentColors.primary : CendentColors.secondary),
          ),
        ),
      ),
    );
  }
}

class _LoteBajaBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _LoteBajaBtn({required this.onTap});
  @override
  State<_LoteBajaBtn> createState() => _LoteBajaBtnState();
}

class _LoteBajaBtnState extends State<_LoteBajaBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'Dar de baja',
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: _hover ? CendentColors.redSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.block_outlined, size: 14, color: _hover ? CendentColors.red : CendentColors.secondary),
          ),
        ),
      ),
    );
  }
}

class _LoteField extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _LoteField({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.4, color: CendentColors.secondary)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? CendentColors.ink)),
        ],
      ),
    );
  }
}

class _MovRow extends StatelessWidget {
  final Mov mov;
  final bool isLast;
  const _MovRow({required this.mov, required this.isLast});

  ({IconData icon, Color fg, Color bg}) get _style {
    switch (mov.kind) {
      case MovKind.ingreso:      return (icon: Icons.south_rounded,           fg: CendentColors.green, bg: CendentColors.greenSoft);
      case MovKind.transferencia: return (icon: Icons.local_shipping_outlined, fg: CendentColors.amber, bg: CendentColors.amberSoft);
      case MovKind.egreso:       return (icon: Icons.north_rounded,            fg: CendentColors.red,   bg: CendentColors.redSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    final neg = mov.qty < 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: CendentColors.hairlineSoft)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: s.bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(s.icon, size: 15, color: s.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mov.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CendentColors.ink)),
                Text(mov.sub,   style: const TextStyle(fontSize: 11.5, color: CendentColors.secondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${neg ? '−' : '+'}${mov.qty.abs()} u',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: neg ? CendentColors.red : CendentColors.green),
          ),
        ],
      ),
    );
  }
}
