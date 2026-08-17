// =============================================================================
//  lib/screens/transferencias_screen.dart
//  Sistema Web Daniel's CEDENT S.A. — Centro de Especialidades Odontológicas
//  Transferencias — Flutter 3.24 · Material 3 · desktop-first
//
//  API:
//    GET    /transferencias              → _load
//    POST   /transferencias/enviar       → crearTransferencia
//    PATCH  /transferencias/:id/cancelar → cancelarTransferencia
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/cendent_colors.dart';

// =============================================================================
//  HELPERS
// =============================================================================
double _tDbl(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _tFmt(String? iso) {
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

String _tFmtDate(String? iso) {
  if (iso == null) return '—';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}';
  } catch (_) {
    return '—';
  }
}

// =============================================================================
//  MODELOS
// =============================================================================
class _TItem {
  final String nombreProducto;
  final int cantidad;
  final String codigoLote;
  const _TItem({
    required this.nombreProducto,
    required this.cantidad,
    required this.codigoLote,
  });
}

class _Transfer {
  final int idTransferencia;
  final String codigoTrz;
  final String nomOrigen;
  final String nomDestino;
  final String estado;
  final String fechaEnvio;
  final String? fechaRecepcion;
  final String? usuarioEnvia;
  final String? usuarioRecibe;
  final List<_TItem> items;
  const _Transfer({
    required this.idTransferencia,
    required this.codigoTrz,
    required this.nomOrigen,
    required this.nomDestino,
    required this.estado,
    required this.fechaEnvio,
    this.fechaRecepcion,
    this.usuarioEnvia,
    this.usuarioRecibe,
    required this.items,
  });

  bool get enTransito => estado == 'EN_TRANSITO';
  bool get recibida => estado == 'RECIBIDA';
  bool get cancelada => estado == 'CANCELADA';
}

class _TProdInfo {
  final int idProducto;
  final String nombre;
  final String sku;
  final int stock;
  const _TProdInfo({
    required this.idProducto,
    required this.nombre,
    required this.sku,
    required this.stock,
  });
}

class _TDraftItem {
  final int idProducto;
  final String nombre;
  final String sku;
  int qty = 1;
  _TDraftItem({
    required this.idProducto,
    required this.nombre,
    required this.sku,
  });
}

// =============================================================================
//  MAPPERS
// =============================================================================
_Transfer _tMapTransfer(dynamic raw) {
  final detalle = (raw['detalle_transferencia'] as List?) ?? [];
  final origen = raw['sucursales_transferencias_id_sucursal_origenTosucursales'];
  final destino = raw['sucursales_transferencias_id_sucursal_destinoTosucursales'];
  final envia = raw['usuarios_transferencias_id_usuario_enviaTousuarios'];
  final recibe = raw['usuarios_transferencias_id_usuario_recibeTousuarios'];

  final items = detalle.map<_TItem>((d) {
    final lote = d['lotes'];
    final prod = lote?['productos'];
    return _TItem(
      nombreProducto: (prod?['nombre_mat'] as String?) ?? '—',
      cantidad: _tDbl(d['cantidad']).round(),
      codigoLote: (lote?['codigo_lote'] as String?) ?? '—',
    );
  }).toList();

  return _Transfer(
    idTransferencia: (raw['id_transferencia'] as int?) ?? 0,
    codigoTrz: (raw['codigo_trz'] as String?) ?? '—',
    nomOrigen: (origen?['nom_sucursal'] as String?) ?? '—',
    nomDestino: (destino?['nom_sucursal'] as String?) ?? '—',
    estado: (raw['estado'] as String?) ?? '—',
    fechaEnvio: _tFmt(raw['fecha_envio'] as String?),
    fechaRecepcion: raw['fecha_recepcion'] != null
        ? _tFmtDate(raw['fecha_recepcion'] as String?)
        : null,
    usuarioEnvia: envia?['nom_usuario'] as String?,
    usuarioRecibe: recibe?['nom_usuario'] as String?,
    items: items,
  );
}

_TProdInfo _tMapProd(dynamic p) {
  final id = (p['id_producto'] as int?) ?? 0;
  final sub = (p['subcategoria'] as String?) ?? '';
  final prefix =
      sub.length >= 4 ? sub.substring(0, 4).toUpperCase() : sub.toUpperCase();
  return _TProdInfo(
    idProducto: id,
    nombre: (p['nombre_mat'] as String?) ?? '—',
    sku: '$prefix-${id.toString().padLeft(4, '0')}',
    stock: _tDbl(p['stock_total']).round(),
  );
}

// =============================================================================
//  ESTADO STYLES
// =============================================================================
class _TEstadoStyle {
  final Color fg;
  final Color bg;
  final IconData icon;
  final String label;
  const _TEstadoStyle(this.fg, this.bg, this.icon, this.label);

  static _TEstadoStyle of(String estado) {
    switch (estado) {
      case 'EN_TRANSITO':
        return const _TEstadoStyle(
          CendentColors.amber,
          CendentColors.amberSoft,
          Icons.local_shipping_outlined,
          'En tránsito',
        );
      case 'RECIBIDA':
        return const _TEstadoStyle(
          CendentColors.green,
          CendentColors.greenSoft,
          Icons.check_circle_outline_rounded,
          'Recibida',
        );
      case 'CANCELADA':
        return const _TEstadoStyle(
          CendentColors.red,
          CendentColors.redSoft,
          Icons.cancel_outlined,
          'Cancelada',
        );
      default:
        return const _TEstadoStyle(
          CendentColors.secondary,
          Color(0xFFEAEFF4),
          Icons.help_outline_rounded,
          'Desconocido',
        );
    }
  }
}

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class TransferenciasScreen extends StatefulWidget {
  final int idSucursal;
  final String nomSucursal;
  const TransferenciasScreen({
    super.key,
    required this.idSucursal,
    required this.nomSucursal,
  });

  @override
  State<TransferenciasScreen> createState() => _TransferenciasScreenState();
}

class _TransferenciasScreenState extends State<TransferenciasScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _loadError;
  List<_Transfer> _transfers = [];

  String _search = '';
  String? _filtroEstado;
  _Transfer? _detailTransfer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final rawTransfers = await _api.getTransferencias();
      if (!mounted) return;

      if (rawTransfers == null) {
        setState(() {
          _loading = false;
          _loadError = 'No se pudieron cargar las transferencias. Reintente.';
        });
        return;
      }

      setState(() {
        _transfers = rawTransfers.map<_Transfer>(_tMapTransfer).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'No se pudieron cargar las transferencias. Reintente.';
      });
    }
  }

  List<_Transfer> get _visible {
    var list = _transfers;
    if (_filtroEstado != null) {
      list = list.where((t) => t.estado == _filtroEstado).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((t) =>
          t.codigoTrz.toLowerCase().contains(q) ||
          t.nomOrigen.toLowerCase().contains(q) ||
          t.nomDestino.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _openCreate() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => NuevaTransferenciaDialog(idSucursal: widget.idSucursal),
    );
    if (saved == true && mounted) {
      _api.invalidateCache();
      await _load();
      if (mounted) _toast('Transferencia enviada');
    }
  }

  Future<void> _openRecibir() async {
    final received = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => const _RecibirTransferenciaDialog(),
    );
    if (received == true && mounted) {
      _api.invalidateCache();
      await _load();
      if (!mounted) return;
      _toast('Transferencia recibida');
    }
  }

  Future<void> _confirmCancel(_Transfer t) async {
    final cancelled = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _TCancelarDialog(transfer: t),
    );
    if (cancelled == true && mounted) {
      _api.invalidateCache();
      if (_detailTransfer?.idTransferencia == t.idTransferencia) {
        setState(() => _detailTransfer = null);
      }
      await _load();
      if (mounted) _toast('Transferencia cancelada');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CendentColors.ink,
        width: 420,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF5FE3C2), size: 18),
            const SizedBox(width: 10),
            Flexible(
              child: Text(msg,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ));
  }

  Widget _buildBody() {
    if (_loading) return const _TSkeleton();
    if (_loadError != null) {
      return _TErrorState(message: _loadError!, onRetry: _load);
    }
    if (_transfers.isEmpty) {
      return _TEmptyState(onCreate: _openCreate, noneAtAll: true);
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return const _TEmptyState(noneAtAll: false);
    }
    return _TTable(
      transfers: visible,
      onView: (t) => setState(() => _detailTransfer = t),
      onCancel: _confirmCancel,
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
                            _TPageHead(onCreate: _openCreate, onRecibir: _openRecibir),
                            const SizedBox(height: 22),
                            _TToolbar(
                              onSearch: (s) => setState(() => _search = s),
                              filtroEstado: _filtroEstado,
                              transfers: _transfers,
                              onFiltro: (e) =>
                                  setState(() => _filtroEstado = e),
                            ),
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
              const _TFooter(),
            ],
          ),
        ),

        // Scrim
        IgnorePointer(
          ignoring: _detailTransfer == null,
          child: AnimatedOpacity(
            opacity: _detailTransfer == null ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: () => setState(() => _detailTransfer = null),
              child: Container(color: const Color(0x6B0D1B2A)),
            ),
          ),
        ),

        // Detail panel
        AnimatedPositioned(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          right: _detailTransfer == null ? -480 : 0,
          width: 460,
          child: _detailTransfer == null
              ? const SizedBox.shrink()
              : _TDetailPanel(
                  transfer: _detailTransfer!,
                  onClose: () => setState(() => _detailTransfer = null),
                  onCancel: () => _confirmCancel(_detailTransfer!),
                ),
        ),
      ],
    );
  }
}

// =============================================================================
//  PAGE HEAD
// =============================================================================
class _TPageHead extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onRecibir;
  const _TPageHead({required this.onCreate, required this.onRecibir});

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
            Text(
              'Transferencias',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: CendentColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Envío y seguimiento de stock entre sucursales',
              style: TextStyle(fontSize: 14, color: CendentColors.secondary),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TBtn(
              icon: Icons.move_to_inbox_outlined,
              label: 'Recibir transferencia',
              kind: _TBtnKind.secondary,
              onTap: onRecibir,
            ),
            const SizedBox(width: 10),
            _TBtn(
              icon: Icons.local_shipping_outlined,
              label: 'Nueva transferencia',
              kind: _TBtnKind.primary,
              onTap: onCreate,
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
//  TOOLBAR (búsqueda + filtros)
// =============================================================================
class _TToolbar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final String? filtroEstado;
  final List<_Transfer> transfers;
  final ValueChanged<String?> onFiltro;
  const _TToolbar({
    required this.onSearch,
    required this.filtroEstado,
    required this.transfers,
    required this.onFiltro,
  });

  int _countEstado(String e) =>
      transfers.where((t) => t.estado == e).length;

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
              hintText: 'Buscar por código, origen o destino…',
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
                borderSide:
                    const BorderSide(color: CendentColors.hairline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: CendentColors.primary, width: 1.6),
              ),
            ),
          ),
        ),
        _TFilterChip(
          label: 'Todas',
          count: transfers.length,
          active: filtroEstado == null,
          onTap: () => onFiltro(null),
          fg: CendentColors.primary,
          bg: CendentColors.blueTint,
        ),
        _TFilterChip(
          label: 'En tránsito',
          count: _countEstado('EN_TRANSITO'),
          active: filtroEstado == 'EN_TRANSITO',
          onTap: () => onFiltro('EN_TRANSITO'),
          fg: CendentColors.amber,
          bg: CendentColors.amberSoft,
        ),
        _TFilterChip(
          label: 'Recibidas',
          count: _countEstado('RECIBIDA'),
          active: filtroEstado == 'RECIBIDA',
          onTap: () => onFiltro('RECIBIDA'),
          fg: CendentColors.green,
          bg: CendentColors.greenSoft,
        ),
        _TFilterChip(
          label: 'Canceladas',
          count: _countEstado('CANCELADA'),
          active: filtroEstado == 'CANCELADA',
          onTap: () => onFiltro('CANCELADA'),
          fg: CendentColors.red,
          bg: CendentColors.redSoft,
        ),
      ],
    );
  }
}

class _TFilterChip extends StatefulWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final Color fg;
  final Color bg;
  const _TFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    required this.fg,
    required this.bg,
  });
  @override
  State<_TFilterChip> createState() => _TFilterChipState();
}

class _TFilterChipState extends State<_TFilterChip> {
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
class _TTable extends StatelessWidget {
  final List<_Transfer> transfers;
  final ValueChanged<_Transfer> onView;
  final ValueChanged<_Transfer> onCancel;
  const _TTable({
    required this.transfers,
    required this.onView,
    required this.onCancel,
  });

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
                0: FixedColumnWidth(170), // CÓDIGO
                1: FixedColumnWidth(200), // ORIGEN
                2: FixedColumnWidth(200), // DESTINO
                3: FixedColumnWidth(150), // ESTADO
                4: FixedColumnWidth(130), // FECHA
                5: FixedColumnWidth(80),  // ÍTEMS
                6: FixedColumnWidth(100), // ACCIONES
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: CendentColors.hairline)),
                  ),
                  children: [
                    _th('Código'),
                    _th('Origen'),
                    _th('Destino'),
                    _th('Estado'),
                    _th('Fecha'),
                    _th('Ítems'),
                    _th(''),
                  ],
                ),
                ...transfers.asMap().entries.map((e) {
                  final t = e.value;
                  final isLast = e.key == transfers.length - 1;
                  final est = _TEstadoStyle.of(t.estado);
                  return TableRow(
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(
                                  color: CendentColors.hairlineSoft)),
                    ),
                    children: [
                      _TRowCell(onTap: () => onView(t), child: Text(
                        t.codigoTrz,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: CendentColors.primary,
                        ),
                      )),
                      _TRowCell(
                        onTap: () => onView(t),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.apartment_rounded,
                                size: 13, color: CendentColors.secondary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                t.nomOrigen,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: CendentColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TRowCell(
                        onTap: () => onView(t),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: CendentColors.secondary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                t.nomDestino,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: CendentColors.ink),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _TRowCell(
                        onTap: () => onView(t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: est.bg,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(est.icon, size: 12, color: est.fg),
                              const SizedBox(width: 5),
                              Text(
                                est.label,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: est.fg),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _TRowCell(
                        onTap: () => onView(t),
                        child: Text(
                          t.fechaEnvio,
                          style: const TextStyle(
                              fontSize: 13, color: CendentColors.secondary),
                        ),
                      ),
                      _TRowCell(
                        onTap: () => onView(t),
                        child: Text(
                          '${t.items.length}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CendentColors.ink),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TActBtn(
                              icon: Icons.visibility_outlined,
                              tooltip: 'Ver detalle',
                              onTap: () => onView(t),
                            ),
                            if (t.enTransito)
                              _TActBtn(
                                icon: Icons.cancel_outlined,
                                tooltip: 'Cancelar transferencia',
                                danger: true,
                                onTap: () => onCancel(t),
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
}

class _TRowCell extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TRowCell({required this.child, required this.onTap});
  @override
  State<_TRowCell> createState() => _TRowCellState();
}

class _TRowCellState extends State<_TRowCell> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: widget.child,
        ),
      ),
    );
  }
}

// =============================================================================
//  DETAIL PANEL
// =============================================================================
class _TDetailPanel extends StatefulWidget {
  final _Transfer transfer;
  final VoidCallback onClose;
  final VoidCallback onCancel;
  const _TDetailPanel({
    required this.transfer,
    required this.onClose,
    required this.onCancel,
  });

  @override
  State<_TDetailPanel> createState() => _TDetailPanelState();
}

class _TDetailPanelState extends State<_TDetailPanel> {
  Future<void> _copiarCodigo() async {
    await Clipboard.setData(ClipboardData(text: widget.transfer.codigoTrz));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CendentColors.ink,
        width: 320,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Color(0xFF5FE3C2), size: 18),
            SizedBox(width: 10),
            Text('Código copiado',
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w500)),
          ],
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final transfer = widget.transfer;
    final est = _TEstadoStyle.of(transfer.estado);
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
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: CendentColors.hairline))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Tooltip(
                          message: 'Copiar código',
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: _copiarCodigo,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    transfer.codigoTrz,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                      letterSpacing: 0.5,
                                      color: CendentColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.copy_all_outlined,
                                    size: 14,
                                    color: CendentColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: est.bg,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(est.icon, size: 12, color: est.fg),
                              const SizedBox(width: 5),
                              Text(est.label,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: est.fg)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _TCloseBtn(onTap: widget.onClose),
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
                    // Info block
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: CendentColors.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: CendentColors.hairline),
                      ),
                      child: Column(
                        children: [
                          _TInfoRow(
                            icon: Icons.apartment_rounded,
                            label: 'Origen',
                            value: transfer.nomOrigen,
                          ),
                          const SizedBox(height: 12),
                          _TInfoRow(
                            icon: Icons.location_on_outlined,
                            label: 'Destino',
                            value: transfer.nomDestino,
                          ),
                          const SizedBox(height: 12),
                          _TInfoRow(
                            icon: Icons.calendar_today_outlined,
                            label: 'Fecha de envío',
                            value: transfer.fechaEnvio,
                          ),
                          if (transfer.fechaRecepcion != null) ...[
                            const SizedBox(height: 12),
                            _TInfoRow(
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Fecha de recepción',
                              value: transfer.fechaRecepcion!,
                            ),
                          ],
                          if (transfer.usuarioEnvia != null) ...[
                            const SizedBox(height: 12),
                            _TInfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Enviado por',
                              value: transfer.usuarioEnvia!,
                            ),
                          ],
                          if (transfer.usuarioRecibe != null) ...[
                            const SizedBox(height: 12),
                            _TInfoRow(
                              icon: Icons.person_outline_rounded,
                              label: 'Recibido por',
                              value: transfer.usuarioRecibe!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Products
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PRODUCTOS TRANSFERIDOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: CendentColors.secondary,
                          ),
                        ),
                        Text(
                          '${transfer.items.length} ítem${transfer.items.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: CendentColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (transfer.items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CendentColors.hairline),
                        ),
                        child: const Text(
                          'Sin ítems registrados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: CendentColors.secondary),
                        ),
                      )
                    else
                      ...transfer.items.asMap().entries.map((e) {
                        final item = e.value;
                        final isLast = e.key == transfer.items.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
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
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: CendentColors.blueTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.inventory_2_outlined,
                                    size: 17, color: CendentColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nombreProducto,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: CendentColors.ink),
                                    ),
                                    Text(
                                      item.codigoLote,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          color: CendentColors.secondary,
                                          fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${item.cantidad} ',
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: CendentColors.ink),
                              ),
                              const Text(
                                'u',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: CendentColors.secondary),
                              ),
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
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: CendentColors.hairline))),
              child: transfer.enTransito
                  ? _TBtn(
                      icon: Icons.cancel_outlined,
                      label: 'Cancelar transferencia',
                      kind: _TBtnKind.danger,
                      onTap: widget.onCancel,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _TInfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CendentColors.secondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: CendentColors.secondary),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CendentColors.ink),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  NUEVA TRANSFERENCIA DIALOG
// =============================================================================
class NuevaTransferenciaDialog extends StatefulWidget {
  final int idSucursal;
  const NuevaTransferenciaDialog({super.key, required this.idSucursal});

  @override
  State<NuevaTransferenciaDialog> createState() =>
      _NuevaTransferenciaDialogState();
}

class _NuevaTransferenciaDialogState
    extends State<NuevaTransferenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _api = ApiService();

  List<_TProdInfo> _productos = [];
  final List<_TDraftItem> _draft = [];
  List<_TProdInfo> _results = [];
  bool _showResults = false;
  bool _loadingProds = true;
  bool _loadingSucs = true;
  bool _saving = false;
  String? _error;

  // Sucursales destino disponibles
  List<Map<String, dynamic>> _sucursales = [];
  String? _sucursalNom; // valor seleccionado en el dropdown

  @override
  void initState() {
    super.initState();
    _loadProds();
    _loadSucursales();
  }

  Future<void> _loadProds() async {
    final raw = await _api.getInventario(widget.idSucursal);
    if (!mounted) return;
    setState(() {
      _productos = (raw ?? []).map<_TProdInfo>(_tMapProd).toList();
      _loadingProds = false;
    });
  }

  Future<void> _loadSucursales() async {
    final raw = await _api.getSucursales();
    if (!mounted) return;
    setState(() {
      _sucursales = (raw ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) =>
              s['estado'] != false &&
              (s['id_sucursal'] as int?) != widget.idSucursal)
          .toList();
      _loadingSucs = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }
    final matches = _productos
        .where((p) =>
            p.nombre.toLowerCase().contains(t) ||
            p.sku.toLowerCase().contains(t))
        .take(8)
        .toList();
    setState(() {
      _results = matches;
      _showResults = true;
    });
  }

  void _addProduct(_TProdInfo p) {
    if (_draft.any((d) => d.idProducto == p.idProducto)) return;
    setState(() {
      _draft.add(_TDraftItem(
          idProducto: p.idProducto, nombre: p.nombre, sku: p.sku));
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

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_draft.isEmpty) {
      setState(
          () => _error = 'Agregue al menos un producto a la transferencia.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await _api.crearTransferencia(
      nombreSucursalDestino: _sucursalNom!,
      productos: _draft.map((d) => {
            'nombre_producto': d.nombre,
            'cantidad': d.qty,
          }).toList(),
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _saving = false;
        _error = result.errorMsg ?? 'Error al enviar la transferencia';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: CendentColors.muted, fontSize: 14),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        filled: true,
        fillColor: CendentColors.card,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CendentColors.hairline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: CendentColors.primary, width: 1.6)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: CendentColors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: CendentColors.red, width: 1.6)),
      );

  @override
  Widget build(BuildContext context) {
    if (_loadingProds || _loadingSucs) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Material(
            color: CendentColors.card,
            borderRadius: BorderRadius.circular(24),
            child: const SizedBox(
              height: 140,
              child: Center(
                child: CircularProgressIndicator(
                    color: CendentColors.primary, strokeWidth: 2.5),
              ),
            ),
          ),
        ),
      );
    }

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
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom:
                              BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nueva transferencia',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: CendentColors.ink),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Seleccione la sucursal destino y los productos a enviar.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CendentColors.secondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _TCloseBtn(
                          onTap: () => Navigator.of(context).pop(false)),
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
                        // Sucursal destino
                        const _TFieldLabel('Sucursal destino',
                            required: true),
                        const SizedBox(height: 7),
                        if (_sucursales.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: CendentColors.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: CendentColors.hairline),
                            ),
                            child: const Text(
                              'No hay otras sucursales activas disponibles.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: CendentColors.secondary),
                            ),
                          )
                        else
                          DropdownButtonFormField<String>(
                            value: _sucursalNom,
                            isExpanded: true,
                            style: const TextStyle(
                                fontSize: 14, color: CendentColors.ink),
                            decoration:
                                _inputDeco('Seleccione una sucursal…'),
                            icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: CendentColors.secondary),
                            dropdownColor: CendentColors.card,
                            menuMaxHeight: 260,
                            items: _sucursales.map((s) {
                              final nom =
                                  (s['nom_sucursal'] as String?) ?? '';
                              return DropdownMenuItem<String>(
                                value: nom,
                                child: Text(nom,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: CendentColors.ink)),
                              );
                            }).toList(),
                            onChanged: _saving
                                ? null
                                : (val) =>
                                    setState(() => _sucursalNom = val),
                            validator: (v) =>
                                (v == null || v.isEmpty)
                                    ? 'Seleccione la sucursal destino.'
                                    : null,
                          ),
                        const SizedBox(height: 20),

                        // Product picker
                        const _TFieldLabel('Productos a transferir',
                            required: true),
                        const SizedBox(height: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchCtrl,
                              enabled: !_saving,
                              onChanged: _onSearch,
                              style: const TextStyle(
                                  fontSize: 14, color: CendentColors.ink),
                              decoration: InputDecoration(
                                hintText:
                                    'Buscar producto del inventario…',
                                hintStyle: const TextStyle(
                                    color: CendentColors.muted,
                                    fontSize: 14),
                                prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: CendentColors.secondary),
                                prefixIconConstraints:
                                    const BoxConstraints(
                                        minWidth: 42, minHeight: 0),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                filled: true,
                                fillColor: CendentColors.card,
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: CendentColors.hairline)),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(
                                        color: CendentColors.primary,
                                        width: 1.6)),
                              ),
                            ),
                            if (_showResults && _results.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                constraints:
                                    const BoxConstraints(maxHeight: 220),
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
                                  itemCount: _results.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(
                                          height: 1,
                                          color:
                                              CendentColors.hairlineSoft),
                                  itemBuilder: (ctx, i) {
                                    final p = _results[i];
                                    final added = _draft.any((d) =>
                                        d.idProducto == p.idProducto);
                                    return InkWell(
                                      onTap: added
                                          ? null
                                          : () => _addProduct(p),
                                      borderRadius: i == 0
                                          ? const BorderRadius.vertical(
                                              top: Radius.circular(14))
                                          : i == _results.length - 1
                                              ? const BorderRadius
                                                  .vertical(
                                                  bottom:
                                                      Radius.circular(14))
                                              : BorderRadius.zero,
                                      child: Opacity(
                                        opacity: added ? 0.45 : 1,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(p.nombre,
                                                        style: const TextStyle(
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: CendentColors.ink)),
                                                    Text(p.sku,
                                                        style: const TextStyle(
                                                            fontSize: 11.5,
                                                            color: CendentColors.secondary,
                                                            fontFamily: 'monospace')),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                  added
                                                      ? 'Agregado'
                                                      : '${p.stock} u',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: CendentColors
                                                          .secondary)),
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
                        const SizedBox(height: 14),

                        // Draft list
                        if (_draft.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: CendentColors.hairline),
                            ),
                            child: const Text(
                              'Aún no hay productos. Búsquelos arriba.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CendentColors.secondary),
                            ),
                          )
                        else
                          ..._draft.map((d) => _TDraftRow(
                                item: d,
                                onRemove: () =>
                                    _removeProduct(d.idProducto),
                                onQtyChanged: (q) =>
                                    _setQty(d.idProducto, q),
                                enabled: !_saving,
                              )),

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
                      border: Border(
                          top:
                              BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _TBtn(
                        icon: Icons.close_rounded,
                        label: 'Cancelar',
                        kind: _TBtnKind.secondary,
                        onTap: _saving
                            ? () {}
                            : () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _TBtn(
                        icon: _saving ? null : Icons.local_shipping_outlined,
                        label: _saving ? 'Enviando…' : 'Enviar transferencia',
                        kind: _TBtnKind.primary,
                        busy: _saving,
                        onTap: _saving ? null : _enviar,
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

class _TDraftRow extends StatelessWidget {
  final _TDraftItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQtyChanged;
  final bool enabled;
  const _TDraftRow({
    required this.item,
    required this.onRemove,
    required this.onQtyChanged,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
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
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: CendentColors.blueTint,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.inventory_2_outlined,
                size: 16, color: CendentColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: CendentColors.ink)),
                Text(item.sku,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: CendentColors.secondary,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TQtyStepper(
              qty: item.qty, enabled: enabled, onChanged: onQtyChanged),
          const SizedBox(width: 6),
          _TActBtn(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Quitar',
              danger: true,
              onTap: onRemove),
        ],
      ),
    );
  }
}

class _TQtyStepper extends StatelessWidget {
  final int qty;
  final bool enabled;
  final ValueChanged<int> onChanged;
  const _TQtyStepper(
      {required this.qty, required this.enabled, required this.onChanged});

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
          _TStepBtn(
              icon: Icons.remove,
              onTap: enabled ? () => onChanged(qty - 1) : null),
          Container(width: 1, height: 32, color: CendentColors.hairline),
          SizedBox(
            width: 40,
            height: 32,
            child: Center(
              child: Text('$qty',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CendentColors.ink)),
            ),
          ),
          Container(width: 1, height: 32, color: CendentColors.hairline),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('u',
                style: TextStyle(fontSize: 11, color: CendentColors.secondary)),
          ),
          Container(width: 1, height: 32, color: CendentColors.hairline),
          _TStepBtn(
              icon: Icons.add,
              onTap: enabled ? () => onChanged(qty + 1) : null),
        ],
      ),
    );
  }
}

class _TStepBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _TStepBtn({required this.icon, required this.onTap});
  @override
  State<_TStepBtn> createState() => _TStepBtnState();
}

class _TStepBtnState extends State<_TStepBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 30,
          height: 32,
          color: _hover && widget.onTap != null
              ? CendentColors.blueWash
              : Colors.transparent,
          child: Icon(widget.icon,
              size: 16,
              color: _hover && widget.onTap != null
                  ? CendentColors.primary
                  : CendentColors.steel),
        ),
      ),
    );
  }
}

// =============================================================================
//  RECIBIR TRANSFERENCIA DIALOG
// =============================================================================
class _RecibirTransferenciaDialog extends StatefulWidget {
  const _RecibirTransferenciaDialog();
  @override
  State<_RecibirTransferenciaDialog> createState() =>
      _RecibirTransferenciaDialogState();
}

class _RecibirTransferenciaDialogState
    extends State<_RecibirTransferenciaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _api = ApiService();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _recibir() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _api.recibirTransferencia(_codigoCtrl.text.trim());
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMsg ?? 'No se pudo registrar la recepción';
      });
    }
  }

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
                  padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recibir transferencia',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                  color: CendentColors.ink),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ingrese el código de trazabilidad para registrar la recepción y acreditar el stock.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CendentColors.secondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _TCloseBtn(
                          onTap: () => Navigator.of(context).pop(false)),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 22, 26, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _TFieldLabel('Código de trazabilidad',
                          required: true),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _codigoCtrl,
                        enabled: !_saving,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: CendentColors.primary),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'TRZ-AAAAMMDD-XXXXX',
                          hintStyle: const TextStyle(
                              color: CendentColors.muted,
                              fontSize: 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.qr_code_outlined,
                              size: 18, color: CendentColors.secondary),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 46, minHeight: 0),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          filled: true,
                          fillColor: CendentColors.card,
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: CendentColors.hairline)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: CendentColors.primary, width: 1.6)),
                          errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: CendentColors.red)),
                          focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: CendentColors.red, width: 1.6)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingrese el código de trazabilidad.';
                          }
                          final re = RegExp(r'^TRZ-\d{8}-[A-Z0-9]+$');
                          if (!re.hasMatch(v.trim())) {
                            return 'Formato inválido. Ej: TRZ-20260605-AB1C2';
                          }
                          return null;
                        },
                      ),
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

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(color: CendentColors.hairline))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _TBtn(
                        icon: Icons.close_rounded,
                        label: 'Cancelar',
                        kind: _TBtnKind.secondary,
                        onTap: _saving
                            ? () {}
                            : () => Navigator.of(context).pop(false),
                      ),
                      const SizedBox(width: 10),
                      _TBtn(
                        icon: _saving ? null : Icons.move_to_inbox_outlined,
                        label: _saving ? 'Registrando…' : 'Confirmar recepción',
                        kind: _TBtnKind.primary,
                        busy: _saving,
                        onTap: _saving ? null : _recibir,
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
//  CANCELAR DIALOG
// =============================================================================
class _TCancelarDialog extends StatefulWidget {
  final _Transfer transfer;
  const _TCancelarDialog({required this.transfer});
  @override
  State<_TCancelarDialog> createState() => _TCancelarDialogState();
}

class _TCancelarDialogState extends State<_TCancelarDialog> {
  final _api = ApiService();
  bool _cancelling = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() {
      _cancelling = true;
      _error = null;
    });
    final result = await _api
        .cancelarTransferencia(widget.transfer.idTransferencia);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _cancelling = false;
        _error = result.errorMsg ?? 'No se pudo cancelar la transferencia';
      });
    }
  }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: CendentColors.hairline))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cancelar transferencia',
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: CendentColors.ink),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Se cancelará "${widget.transfer.codigoTrz}" y se restaurará el stock en ${widget.transfer.nomOrigen}. Esta acción no se puede deshacer.',
                            style: const TextStyle(
                                fontSize: 13,
                                color: CendentColors.secondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _TCloseBtn(
                        onTap: () => Navigator.of(context).pop(false)),
                  ],
                ),
              ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(26, 16, 26, 0),
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
              Container(
                padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _TBtn(
                      icon: Icons.close_rounded,
                      label: 'Volver',
                      kind: _TBtnKind.secondary,
                      onTap: _cancelling
                          ? () {}
                          : () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 10),
                    _TBtn(
                      icon: Icons.cancel_outlined,
                      label: _cancelling ? 'Cancelando…' : 'Confirmar',
                      kind: _TBtnKind.danger,
                      busy: _cancelling,
                      onTap: _cancelling ? null : _cancel,
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
//  EMPTY / ERROR / SKELETON
// =============================================================================
class _TEmptyState extends StatelessWidget {
  final VoidCallback? onCreate;
  final bool noneAtAll;
  const _TEmptyState({this.onCreate, required this.noneAtAll});

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
              child: const Icon(Icons.local_shipping_outlined,
                  size: 32, color: CendentColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              noneAtAll
                  ? 'Sin transferencias registradas'
                  : 'Sin resultados para el filtro actual',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CendentColors.ink),
            ),
            const SizedBox(height: 6),
            Text(
              noneAtAll
                  ? 'Crea una nueva transferencia para enviar stock a otra sucursal.'
                  : 'Prueba cambiando el filtro de estado o el texto de búsqueda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13.5, color: CendentColors.secondary),
            ),
            if (noneAtAll && onCreate != null) ...[
              const SizedBox(height: 20),
              _TBtn(
                icon: Icons.local_shipping_outlined,
                label: 'Nueva transferencia',
                kind: _TBtnKind.primary,
                onTap: onCreate!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _TErrorState({required this.message, required this.onRetry});

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
            _TBtn(
              icon: Icons.refresh_rounded,
              label: 'Reintentar',
              kind: _TBtnKind.secondary,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _TSkeleton extends StatelessWidget {
  const _TSkeleton();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: CendentColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: CendentColors.hairline),
        boxShadow: CendentColors.cardShadow,
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: CendentColors.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

// =============================================================================
//  SHARED UI COMPONENTS
// =============================================================================
enum _TBtnKind { primary, secondary, danger }

class _TBtn extends StatefulWidget {
  final IconData? icon;
  final String label;
  final _TBtnKind kind;
  final bool busy;
  final VoidCallback? onTap;
  const _TBtn({
    this.icon,
    required this.label,
    required this.kind,
    this.busy = false,
    required this.onTap,
  });
  @override
  State<_TBtn> createState() => _TBtnState();
}

class _TBtnState extends State<_TBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.busy;
    Color bg;
    Color fg;
    Border? border;

    switch (widget.kind) {
      case _TBtnKind.primary:
        bg = disabled
            ? CendentColors.blueLight
            : (_hover ? CendentColors.primaryDeep : CendentColors.primary);
        fg = Colors.white;
        break;
      case _TBtnKind.secondary:
        bg = _hover ? CendentColors.blueTint : CendentColors.card;
        fg = CendentColors.primary;
        border = Border.all(color: CendentColors.blueLight);
        break;
      case _TBtnKind.danger:
        bg = disabled
            ? CendentColors.redSoft
            : (_hover ? const Color(0xFFB71C1C) : CendentColors.red);
        fg = Colors.white;
        break;
    }

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      color: fg, strokeWidth: 2),
                )
              else if (widget.icon != null)
                Icon(widget.icon, size: 16, color: fg),
              if (widget.icon != null || widget.busy)
                const SizedBox(width: 8),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TActBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  const _TActBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });
  @override
  State<_TActBtn> createState() => _TActBtnState();
}

class _TActBtnState extends State<_TActBtn> {
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
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(widget.icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}

class _TCloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _TCloseBtn({required this.onTap});
  @override
  State<_TCloseBtn> createState() => _TCloseBtnState();
}

class _TCloseBtnState extends State<_TCloseBtn> {
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
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hover ? CendentColors.redSoft : CendentColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CendentColors.hairline),
          ),
          child: Icon(Icons.close_rounded,
              size: 18,
              color:
                  _hover ? CendentColors.red : CendentColors.steel),
        ),
      ),
    );
  }
}

class _TFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _TFieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CendentColors.ink),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CendentColors.red)),
        ],
      ],
    );
  }
}

class _TFooter extends StatelessWidget {
  const _TFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
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
