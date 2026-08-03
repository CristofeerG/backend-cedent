// =============================================================================
//  lib/screens/usuarios_screen.dart
//  Sistema Web Daniel's CENDENT S.A. — Centro de Especialidades Odontológicas
//  Gestión de Usuarios — Flutter 3.24 · Material 3 · desktop-first
//
//  API:
//    GET    /usuarios        → getUsuarios
//    POST   /usuarios        → crearUsuario
//    PATCH  /usuarios/:id    → editarUsuario
//    DELETE /usuarios/:id    → eliminarUsuario
// =============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/cendent_colors.dart';

// =============================================================================
//  MODELO
// =============================================================================
class _UUsuario {
  final int id;
  final String nomUsuario;
  final String rol;
  final int? idSucursal;
  final String? nomSucursal;
  const _UUsuario({
    required this.id,
    required this.nomUsuario,
    required this.rol,
    this.idSucursal,
    this.nomSucursal,
  });
}

_UUsuario _uMap(dynamic raw) => _UUsuario(
      id: (raw['id_usuario'] as int?) ?? 0,
      nomUsuario: (raw['nom_usuario'] as String?) ?? '—',
      rol: (raw['rol'] as String?) ?? '—',
      idSucursal: raw['id_sucursal'] as int?,
      nomSucursal: raw['sucursales']?['nom_sucursal'] as String?,
    );

// =============================================================================
//  MODELO SUCURSAL
// =============================================================================
class _SSucursal {
  final int id;
  final String nomSucursal;
  final String? ubicacion;
  const _SSucursal({
    required this.id,
    required this.nomSucursal,
    this.ubicacion,
  });
}

_SSucursal _sMap(Map<String, dynamic> raw) => _SSucursal(
      id: (raw['id_sucursal'] as int?) ?? 0,
      nomSucursal: (raw['nom_sucursal'] as String?) ?? '',
      ubicacion: raw['ubicacion'] as String?,
    );

// =============================================================================
//  ROL STYLES
// =============================================================================
class _URolStyle {
  final Color fg;
  final Color bg;
  final String label;
  const _URolStyle(this.fg, this.bg, this.label);

  static _URolStyle of(String rol) {
    switch (rol) {
      case 'administrador':
        return const _URolStyle(
            CendentColors.primary, CendentColors.blueTint, 'Administrador');
      case 'auxiliar':
        return const _URolStyle(
            CendentColors.violet, CendentColors.violetSoft, 'Auxiliar');
      case 'doctor':
        return const _URolStyle(
            CendentColors.teal, CendentColors.tealSoft, 'Doctor');
      default:
        return const _URolStyle(
            CendentColors.secondary, Color(0xFFEAEFF4), 'Desconocido');
    }
  }
}

// =============================================================================
//  PANTALLA PRINCIPAL
// =============================================================================
class UsuariosScreen extends StatefulWidget {
  final String userRol;
  const UsuariosScreen({super.key, required this.userRol});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final _api = ApiService();
  bool _loading = true;
  String? _loadError;
  List<_UUsuario> _usuarios = [];
  List<_SSucursal> _sucursales = [];
  String _search = '';
  String? _filtroRol;

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
    final results = await Future.wait([
      _api.getUsuarios(),
      _api.getSucursales(),
    ]);
    if (!mounted) return;
    final rawU = results[0];
    final rawS = results[1];
    setState(() {
      if (rawU == null) {
        _loadError = 'No se pudo cargar la lista de usuarios. Reintente.';
      } else {
        _usuarios = rawU.map<_UUsuario>(_uMap).toList();
      }
      _sucursales = (rawS ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) => s['estado'] != false)
          .map<_SSucursal>(_sMap)
          .toList();
      _loading = false;
    });
  }

  List<_UUsuario> get _visible {
    var list = _usuarios;
    if (_filtroRol != null) {
      list = list.where((u) => u.rol == _filtroRol).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((u) =>
              u.nomUsuario.toLowerCase().contains(q) ||
              (u.nomSucursal?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  int _countRol(String rol) => _usuarios.where((u) => u.rol == rol).length;

  Future<void> _openNuevo() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => const _UNuevoDialog(),
    );
    if (ok == true && mounted) {
      _api.invalidateCache();
      await _load();
      _toast('Usuario creado correctamente');
    }
  }

  Future<void> _openEditar(_UUsuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _UEditarDialog(usuario: u),
    );
    if (ok == true && mounted) {
      _api.invalidateCache();
      await _load();
      _toast('Usuario actualizado');
    }
  }

  Future<void> _openEliminar(_UUsuario u) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _UEliminarDialog(usuario: u),
    );
    if (ok == true && mounted) {
      _api.invalidateCache();
      await _load();
      _toast('Usuario eliminado');
    }
  }

  Future<void> _openNuevaSucursal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => const _CrearSucursalDialog(),
    );
    if (result == true && mounted) {
      _api.invalidateCache();
      await _load();
      _toast('Sucursal creada correctamente');
    }
  }

  Future<void> _openEditarSucursal(_SSucursal s) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _SEditarDialog(sucursal: s),
    );
    if (ok == true && mounted) {
      _api.invalidateCache();
      await _load();
      _toast('Sucursal actualizada');
    }
  }

  Future<void> _openEliminarSucursal(_SSucursal s) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x800D1B2A),
      builder: (_) => _SEliminarDialog(sucursal: s),
    );
    if (ok == true && mounted) {
      _api.invalidateCache();
      await _load();
      _toast('Sucursal eliminada');
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
    if (_loading) return const _USkeleton();
    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Sección Usuarios ──────────────────────────────────────────────────
        _SSectionHeader(
          icon: Icons.group_outlined,
          title: 'Usuarios',
          count: _usuarios.length,
        ),
        const SizedBox(height: 18),
        if (_loadError != null)
          _UErrorState(message: _loadError!, onRetry: _load)
        else if (_usuarios.isEmpty)
          _UEmptyState(onCreate: _openNuevo)
        else ...[
          _UToolbar(
            onSearch: (s) => setState(() => _search = s),
            filtroRol: _filtroRol,
            onFiltro: (r) => setState(() => _filtroRol = r),
            total: _usuarios.length,
            admins: _countRol('administrador'),
            auxiliares: _countRol('auxiliar'),
            doctores: _countRol('doctor'),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const _UEmptyFiltered()
          else
            _UTable(
              usuarios: visible,
              onEditar: _openEditar,
              onEliminar: _openEliminar,
            ),
        ],
        // ── Sección Sucursales ────────────────────────────────────────────────
        const SizedBox(height: 36),
        _SSectionHeader(
          icon: Icons.apartment_rounded,
          title: 'Sucursales',
          count: _sucursales.length,
        ),
        const SizedBox(height: 18),
        if (_sucursales.isEmpty)
          _SSucursalesEmpty(onCrear: _openNuevaSucursal)
        else
          _STable(
            sucursales: _sucursales,
            onEditar: _openEditarSucursal,
            onEliminar: _openEliminarSucursal,
          ),
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
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 26, 28, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _UPageHead(
          onCreate: _openNuevo,
          onNuevaSucursal: widget.userRol == 'administrador' ? _openNuevaSucursal : null,
        ),
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
          const _UFooter(),
        ],
      ),
    );
  }
}

// =============================================================================
//  PAGE HEAD
// =============================================================================
class _UPageHead extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback? onNuevaSucursal;
  const _UPageHead({required this.onCreate, this.onNuevaSucursal});

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
              'Usuarios y Sucursales',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: CendentColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Gestión de cuentas, roles y sucursales del sistema',
              style: TextStyle(fontSize: 14, color: CendentColors.secondary),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onNuevaSucursal != null) ...[
              _UBtn(
                icon: Icons.add_business_outlined,
                label: 'Nueva sucursal',
                kind: _UBtnKind.secondary,
                onTap: onNuevaSucursal,
              ),
              const SizedBox(width: 10),
            ],
            _UBtn(
              icon: Icons.person_add_outlined,
              label: 'Nuevo usuario',
              kind: _UBtnKind.primary,
              onTap: onCreate,
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
//  TOOLBAR
// =============================================================================
class _UToolbar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final String? filtroRol;
  final ValueChanged<String?> onFiltro;
  final int total;
  final int admins;
  final int auxiliares;
  final int doctores;
  const _UToolbar({
    required this.onSearch,
    required this.filtroRol,
    required this.onFiltro,
    required this.total,
    required this.admins,
    required this.auxiliares,
    required this.doctores,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          height: 44,
          child: TextField(
            onChanged: onSearch,
            style: const TextStyle(fontSize: 14, color: CendentColors.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar por nombre o sucursal…',
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
        _UFilterChip(
          label: 'Todos',
          count: total,
          active: filtroRol == null,
          onTap: () => onFiltro(null),
          fg: CendentColors.primary,
          bg: CendentColors.blueTint,
        ),
        _UFilterChip(
          label: 'Administradores',
          count: admins,
          active: filtroRol == 'administrador',
          onTap: () => onFiltro('administrador'),
          fg: CendentColors.primary,
          bg: CendentColors.blueTint,
        ),
        _UFilterChip(
          label: 'Auxiliares',
          count: auxiliares,
          active: filtroRol == 'auxiliar',
          onTap: () => onFiltro('auxiliar'),
          fg: CendentColors.violet,
          bg: CendentColors.violetSoft,
        ),
        _UFilterChip(
          label: 'Doctores',
          count: doctores,
          active: filtroRol == 'doctor',
          onTap: () => onFiltro('doctor'),
          fg: CendentColors.teal,
          bg: CendentColors.tealSoft,
        ),
      ],
    );
  }
}

class _UFilterChip extends StatefulWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  final Color fg;
  final Color bg;
  const _UFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
    required this.fg,
    required this.bg,
  });
  @override
  State<_UFilterChip> createState() => _UFilterChipState();
}

class _UFilterChipState extends State<_UFilterChip> {
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
                color: active ? widget.fg : CendentColors.hairline),
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
class _UTable extends StatelessWidget {
  final List<_UUsuario> usuarios;
  final ValueChanged<_UUsuario> onEditar;
  final ValueChanged<_UUsuario> onEliminar;
  const _UTable({
    required this.usuarios,
    required this.onEditar,
    required this.onEliminar,
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
          constraints: const BoxConstraints(minWidth: 700),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(60),  // ID
                1: FlexColumnWidth(2),    // USUARIO
                2: FixedColumnWidth(160), // ROL
                3: FlexColumnWidth(2),    // SUCURSAL
                4: FixedColumnWidth(100), // ACCIONES
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: CendentColors.hairline)),
                  ),
                  children: [
                    _th('ID'),
                    _th('Usuario'),
                    _th('Rol'),
                    _th('Sucursal'),
                    _th(''),
                  ],
                ),
                ...usuarios.asMap().entries.map((e) {
                  final u = e.value;
                  final isLast = e.key == usuarios.length - 1;
                  final rol = _URolStyle.of(u.rol);
                  return TableRow(
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(
                                  color: CendentColors.hairlineSoft)),
                    ),
                    children: [
                      _td(Text(
                        '#${u.id}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: CendentColors.secondary),
                      )),
                      _td(Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: rol.bg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              u.nomUsuario.isNotEmpty
                                  ? u.nomUsuario[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: rol.fg),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              u.nomUsuario,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CendentColors.ink),
                            ),
                          ),
                        ],
                      )),
                      _td(Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: rol.bg,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              u.rol == 'administrador'
                                  ? Icons.admin_panel_settings_outlined
                                  : u.rol == 'doctor'
                                      ? Icons.medical_services_outlined
                                      : Icons.person_outline_rounded,
                              size: 13,
                              color: rol.fg,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              rol.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: rol.fg),
                            ),
                          ],
                        ),
                      )),
                      _td(u.nomSucursal != null
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.apartment_rounded,
                                    size: 13,
                                    color: CendentColors.secondary),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    u.nomSucursal!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: CendentColors.ink),
                                  ),
                                ),
                              ],
                            )
                          : const Text('—',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CendentColors.secondary))),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _UActBtn(
                              icon: Icons.edit_outlined,
                              tooltip: 'Editar',
                              onTap: () => onEditar(u),
                            ),
                            _UActBtn(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Eliminar',
                              danger: true,
                              onTap: () => onEliminar(u),
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
//  NUEVO USUARIO DIALOG
// =============================================================================
class _UNuevoDialog extends StatefulWidget {
  const _UNuevoDialog();
  @override
  State<_UNuevoDialog> createState() => _UNuevoDialogState();
}

class _UNuevoDialogState extends State<_UNuevoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _api = ApiService();
  String _rol = 'auxiliar';
  bool _saving = false;
  bool _obscurePass = true;
  String? _error;

  List<Map<String, dynamic>> _sucursales = [];
  int? _sucursalId;
  bool _loadingSucs = true;

  @override
  void initState() {
    super.initState();
    _loadSucursales();
  }

  Future<void> _loadSucursales() async {
    final raw = await _api.getSucursales();
    if (!mounted) return;
    setState(() {
      _sucursales = (raw ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) => s['estado'] != false)
          .toList();
      _loadingSucs = false;
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _api.crearUsuario(
      nomUsuario: _nomCtrl.text.trim(),
      password: _passCtrl.text,
      rol: _rol,
      idSucursal: _sucursalId,
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMsg ?? 'No se pudo crear el usuario';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                _UDialogHeader(
                  title: 'Nuevo usuario',
                  subtitle: 'Complete los datos para crear la cuenta.',
                  onClose: () => Navigator.of(context).pop(false),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _UFieldLabel('Nombre de usuario', required: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _nomCtrl,
                          enabled: !_saving,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('usuario123'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo requerido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Contraseña', required: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _passCtrl,
                          enabled: !_saving,
                          obscureText: _obscurePass,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Mínimo 6 caracteres').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: CendentColors.secondary,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Campo requerido.';
                            if (v.length < 6) return 'Mínimo 6 caracteres.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Rol', required: true),
                        const SizedBox(height: 7),
                        _URolSelector(
                          value: _rol,
                          enabled: !_saving,
                          onChanged: (r) => setState(() => _rol = r),
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Sucursal'),
                        const SizedBox(height: 7),
                        _loadingSucs
                            ? const SizedBox(
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: CendentColors.primary),
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<int?>(
                                value: _sucursalId,
                                isExpanded: true,
                                style: const TextStyle(
                                    fontSize: 14, color: CendentColors.ink),
                                decoration:
                                    _inputDeco('Sin sucursal asignada'),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: CendentColors.secondary),
                                dropdownColor: CendentColors.card,
                                menuMaxHeight: 260,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Sin sucursal',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: CendentColors.secondary)),
                                  ),
                                  ..._sucursales.map((s) {
                                    final id = s['id_sucursal'] as int?;
                                    final nom =
                                        (s['nom_sucursal'] as String?) ?? '';
                                    return DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text(nom,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: CendentColors.ink)),
                                    );
                                  }),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (val) =>
                                        setState(() => _sucursalId = val),
                              ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _UErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _UDialogFooter(
                  onCancel: _saving ? null : () => Navigator.of(context).pop(false),
                  onConfirm: _saving ? null : _guardar,
                  confirmLabel: _saving ? 'Creando…' : 'Crear usuario',
                  confirmIcon: _saving ? null : Icons.person_add_outlined,
                  busy: _saving,
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
//  EDITAR USUARIO DIALOG
// =============================================================================
class _UEditarDialog extends StatefulWidget {
  final _UUsuario usuario;
  const _UEditarDialog({required this.usuario});
  @override
  State<_UEditarDialog> createState() => _UEditarDialogState();
}

class _UEditarDialogState extends State<_UEditarDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  final _passCtrl = TextEditingController();
  final _api = ApiService();
  late String _rol;
  bool _saving = false;
  bool _obscurePass = true;
  String? _error;

  List<Map<String, dynamic>> _sucursales = [];
  int? _sucursalId;
  bool _loadingSucs = true;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.usuario.nomUsuario);
    _rol = widget.usuario.rol;
    _sucursalId = widget.usuario.idSucursal;
    _loadSucursales();
  }

  Future<void> _loadSucursales() async {
    final raw = await _api.getSucursales();
    if (!mounted) return;
    setState(() {
      _sucursales = (raw ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) => s['estado'] != false)
          .toList();
      _loadingSucs = false;
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final pass = _passCtrl.text;
    final result = await _api.editarUsuario(
      widget.usuario.id,
      nomUsuario: _nomCtrl.text.trim(),
      password: pass.isNotEmpty ? pass : null,
      rol: _rol,
      idSucursal: _sucursalId,
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMsg ?? 'No se pudo actualizar el usuario';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                _UDialogHeader(
                  title: 'Editar usuario',
                  subtitle:
                      'Modifica los datos de "${widget.usuario.nomUsuario}". Deja la contraseña en blanco para no cambiarla.',
                  onClose: () => Navigator.of(context).pop(false),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _UFieldLabel('Nombre de usuario', required: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _nomCtrl,
                          enabled: !_saving,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('usuario123'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo requerido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Nueva contraseña'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _passCtrl,
                          enabled: !_saving,
                          obscureText: _obscurePass,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration:
                              _inputDeco('Dejar vacío para no cambiar').copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePass
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                                color: CendentColors.secondary,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePass = !_obscurePass),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return null;
                            if (v.length < 6) return 'Mínimo 6 caracteres.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Rol', required: true),
                        const SizedBox(height: 7),
                        _URolSelector(
                          value: _rol,
                          enabled: !_saving,
                          onChanged: (r) => setState(() => _rol = r),
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Sucursal'),
                        const SizedBox(height: 7),
                        _loadingSucs
                            ? const SizedBox(
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: CendentColors.primary),
                                  ),
                                ),
                              )
                            : DropdownButtonFormField<int?>(
                                value: _sucursalId,
                                isExpanded: true,
                                style: const TextStyle(
                                    fontSize: 14, color: CendentColors.ink),
                                decoration:
                                    _inputDeco('Sin sucursal asignada'),
                                icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: CendentColors.secondary),
                                dropdownColor: CendentColors.card,
                                menuMaxHeight: 260,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Sin sucursal',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: CendentColors.secondary)),
                                  ),
                                  ..._sucursales.map((s) {
                                    final id = s['id_sucursal'] as int?;
                                    final nom =
                                        (s['nom_sucursal'] as String?) ?? '';
                                    return DropdownMenuItem<int?>(
                                      value: id,
                                      child: Text(nom,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              color: CendentColors.ink)),
                                    );
                                  }),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (val) =>
                                        setState(() => _sucursalId = val),
                              ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _UErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _UDialogFooter(
                  onCancel:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  onConfirm: _saving ? null : _guardar,
                  confirmLabel: _saving ? 'Guardando…' : 'Guardar cambios',
                  confirmIcon: _saving ? null : Icons.save_outlined,
                  busy: _saving,
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
//  ELIMINAR USUARIO DIALOG
// =============================================================================
class _UEliminarDialog extends StatefulWidget {
  final _UUsuario usuario;
  const _UEliminarDialog({required this.usuario});
  @override
  State<_UEliminarDialog> createState() => _UEliminarDialogState();
}

class _UEliminarDialogState extends State<_UEliminarDialog> {
  final _api = ApiService();
  bool _deleting = false;
  String? _error;

  Future<void> _eliminar() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    final result = await _api.eliminarUsuario(widget.usuario.id);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _deleting = false;
        _error = result.errorMsg ?? 'No se pudo eliminar el usuario';
      });
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
              _UDialogHeader(
                title: 'Eliminar usuario',
                subtitle:
                    'Se eliminará permanentemente la cuenta de "${widget.usuario.nomUsuario}". Esta acción no se puede deshacer.',
                onClose: () => Navigator.of(context).pop(false),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 0),
                  child: _UErrorBanner(message: _error!),
                ),
              _UDialogFooter(
                onCancel:
                    _deleting ? null : () => Navigator.of(context).pop(false),
                onConfirm: _deleting ? null : _eliminar,
                confirmLabel: _deleting ? 'Eliminando…' : 'Confirmar',
                confirmIcon: Icons.delete_outline_rounded,
                busy: _deleting,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  CREAR SUCURSAL DIALOG
// =============================================================================
class _CrearSucursalDialog extends StatefulWidget {
  const _CrearSucursalDialog();
  @override
  State<_CrearSucursalDialog> createState() => _CrearSucursalDialogState();
}

class _CrearSucursalDialogState extends State<_CrearSucursalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _ubCtrl = TextEditingController();
  final _api = ApiService();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _ubCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final nom = _nomCtrl.text.trim();
    final result = await _api.crearSucursal(
      nomSucursal: nom,
      ubicacion: _ubCtrl.text.trim().isEmpty ? null : _ubCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CendentColors.ink,
          width: 420,
          duration: const Duration(seconds: 4),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF5FE3C2), size: 18),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  "Sucursal '$nom' creada correctamente",
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ));
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMsg ?? 'No se pudo crear la sucursal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                _UDialogHeader(
                  title: 'Nueva sucursal',
                  subtitle: 'Complete los datos para registrar la sucursal.',
                  onClose: () => Navigator.of(context).pop(false),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _UFieldLabel('Nombre de sucursal', required: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _nomCtrl,
                          enabled: !_saving,
                          maxLength: 100,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej: Guayaquil Norte'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo requerido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Ubicación'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _ubCtrl,
                          enabled: !_saving,
                          maxLength: 255,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration:
                              _inputDeco('Ej: Av. Francisco de Orellana, Edif. Torre B'),
                          validator: (v) => null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _UErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _UDialogFooter(
                  onCancel:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  onConfirm: _saving ? null : _guardar,
                  confirmLabel: _saving ? 'Creando…' : 'Crear sucursal',
                  confirmIcon: _saving ? null : Icons.add_business_outlined,
                  busy: _saving,
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
//  SUCURSALES — SECTION HEADER
// =============================================================================
class _SSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  const _SSectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: CendentColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 20, color: CendentColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: CendentColors.ink,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: CendentColors.blueTint,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: CendentColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
//  SUCURSALES — EMPTY STATE
// =============================================================================
class _SSucursalesEmpty extends StatelessWidget {
  final VoidCallback onCrear;
  const _SSucursalesEmpty({required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: CendentColors.blueTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.apartment_rounded,
                  size: 28, color: CendentColors.primary),
            ),
            const SizedBox(height: 14),
            const Text('Sin sucursales registradas',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CendentColors.ink)),
            const SizedBox(height: 5),
            const Text('Crea la primera sucursal del sistema.',
                style: TextStyle(
                    fontSize: 13.5, color: CendentColors.secondary)),
            const SizedBox(height: 18),
            _UBtn(
              icon: Icons.add_business_outlined,
              label: 'Nueva sucursal',
              kind: _UBtnKind.primary,
              onTap: onCrear,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  SUCURSALES — TABLE
// =============================================================================
class _STable extends StatelessWidget {
  final List<_SSucursal> sucursales;
  final ValueChanged<_SSucursal> onEditar;
  final ValueChanged<_SSucursal> onEliminar;
  const _STable({
    required this.sucursales,
    required this.onEditar,
    required this.onEliminar,
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
          constraints: const BoxConstraints(minWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(60),  // ID
                1: FlexColumnWidth(2),    // SUCURSAL
                2: FlexColumnWidth(3),    // UBICACIÓN
                3: FixedColumnWidth(100), // ACCIONES
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: CendentColors.hairline)),
                  ),
                  children: [
                    _sth('ID'),
                    _sth('Sucursal'),
                    _sth('Ubicación'),
                    _sth(''),
                  ],
                ),
                ...sucursales.asMap().entries.map((e) {
                  final s = e.value;
                  final isLast = e.key == sucursales.length - 1;
                  return TableRow(
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(
                                  color: CendentColors.hairlineSoft)),
                    ),
                    children: [
                      _std(Text(
                        '#${s.id}',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: CendentColors.secondary),
                      )),
                      _std(Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: CendentColors.blueTint,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.apartment_rounded,
                                size: 16, color: CendentColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              s.nomSucursal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CendentColors.ink),
                            ),
                          ),
                        ],
                      )),
                      _std(s.ubicacion != null && s.ubicacion!.isNotEmpty
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13,
                                    color: CendentColors.secondary),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    s.ubicacion!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w500,
                                        color: CendentColors.ink),
                                  ),
                                ),
                              ],
                            )
                          : const Text('-',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: CendentColors.secondary))),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _UActBtn(
                              icon: Icons.edit_outlined,
                              tooltip: 'Editar',
                              onTap: () => onEditar(s),
                            ),
                            _UActBtn(
                              icon: Icons.delete_outline_rounded,
                              tooltip: 'Eliminar',
                              danger: true,
                              onTap: () => onEliminar(s),
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

  Widget _sth(String text) => Padding(
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

  Widget _std(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      );
}

// =============================================================================
//  EDITAR SUCURSAL DIALOG
// =============================================================================
class _SEditarDialog extends StatefulWidget {
  final _SSucursal sucursal;
  const _SEditarDialog({required this.sucursal});
  @override
  State<_SEditarDialog> createState() => _SEditarDialogState();
}

class _SEditarDialogState extends State<_SEditarDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _ubCtrl;
  final _api = ApiService();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.sucursal.nomSucursal);
    _ubCtrl = TextEditingController(text: widget.sucursal.ubicacion ?? '');
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _ubCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await _api.actualizarSucursal(
      widget.sucursal.id,
      nomSucursal: _nomCtrl.text.trim(),
      ubicacion: _ubCtrl.text.trim().isEmpty ? '' : _ubCtrl.text.trim(),
    );
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error = result.errorMsg ?? 'No se pudo actualizar la sucursal';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                _UDialogHeader(
                  title: 'Editar sucursal',
                  subtitle:
                      'Modifica los datos de "${widget.sucursal.nomSucursal}".',
                  onClose: () => Navigator.of(context).pop(false),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _UFieldLabel('Nombre de sucursal', required: true),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _nomCtrl,
                          enabled: !_saving,
                          maxLength: 100,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco('Ej: Guayaquil Norte'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Campo requerido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        const _UFieldLabel('Ubicación'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _ubCtrl,
                          enabled: !_saving,
                          maxLength: 255,
                          style: const TextStyle(
                              fontSize: 14, color: CendentColors.ink),
                          decoration: _inputDeco(
                              'Ej: Av. Francisco de Orellana, Edif. Torre B'),
                          validator: (v) => null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _UErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                _UDialogFooter(
                  onCancel:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  onConfirm: _saving ? null : _guardar,
                  confirmLabel: _saving ? 'Guardando…' : 'Guardar cambios',
                  confirmIcon: _saving ? null : Icons.save_outlined,
                  busy: _saving,
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
//  ELIMINAR SUCURSAL DIALOG
// =============================================================================
class _SEliminarDialog extends StatefulWidget {
  final _SSucursal sucursal;
  const _SEliminarDialog({required this.sucursal});
  @override
  State<_SEliminarDialog> createState() => _SEliminarDialogState();
}

class _SEliminarDialogState extends State<_SEliminarDialog> {
  final _api = ApiService();
  bool _deleting = false;
  String? _error;

  Future<void> _eliminar() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    final result = await _api.eliminarSucursal(widget.sucursal.id);
    if (!mounted) return;
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _deleting = false;
        _error = result.errorMsg ?? 'No se pudo eliminar la sucursal';
      });
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
              _UDialogHeader(
                title: 'Eliminar sucursal',
                subtitle:
                    'Se desactivará "${widget.sucursal.nomSucursal}". El historial de lotes y transferencias se preserva.',
                onClose: () => Navigator.of(context).pop(false),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 16, 26, 0),
                  child: _UErrorBanner(message: _error!),
                ),
              _UDialogFooter(
                onCancel:
                    _deleting ? null : () => Navigator.of(context).pop(false),
                onConfirm: _deleting ? null : _eliminar,
                confirmLabel: _deleting ? 'Eliminando…' : 'Confirmar',
                confirmIcon: Icons.delete_outline_rounded,
                busy: _deleting,
                danger: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  ROL SELECTOR
// =============================================================================
class _URolSelector extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;
  const _URolSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _URolOption(
          label: 'Auxiliar',
          icon: Icons.person_outline_rounded,
          selected: value == 'auxiliar',
          enabled: enabled,
          onTap: () => onChanged('auxiliar'),
          fg: CendentColors.violet,
          bg: CendentColors.violetSoft,
        ),
        const SizedBox(width: 10),
        _URolOption(
          label: 'Administrador',
          icon: Icons.admin_panel_settings_outlined,
          selected: value == 'administrador',
          enabled: enabled,
          onTap: () => onChanged('administrador'),
          fg: CendentColors.primary,
          bg: CendentColors.blueTint,
        ),
        const SizedBox(width: 10),
        _URolOption(
          label: 'Doctor',
          icon: Icons.medical_services_outlined,
          selected: value == 'doctor',
          enabled: enabled,
          onTap: () => onChanged('doctor'),
          fg: CendentColors.teal,
          bg: CendentColors.tealSoft,
        ),
      ],
    );
  }
}

class _URolOption extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final Color fg;
  final Color bg;
  const _URolOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
    required this.fg,
    required this.bg,
  });
  @override
  State<_URolOption> createState() => _URolOptionState();
}

class _URolOptionState extends State<_URolOption> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.bg
                : (_hover ? CendentColors.bg : CendentColors.card),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.selected
                  ? widget.fg
                  : CendentColors.hairline,
              width: widget.selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: widget.selected ? widget.fg : CendentColors.secondary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: widget.selected ? widget.fg : CendentColors.steel,
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, size: 14, color: widget.fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
//  SHARED DIALOG COMPONENTS
// =============================================================================
class _UDialogHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _UDialogHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 18),
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
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: CendentColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: CendentColors.secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _UCloseBtn(onTap: onClose),
        ],
      ),
    );
  }
}

class _UDialogFooter extends StatelessWidget {
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String confirmLabel;
  final IconData? confirmIcon;
  final bool busy;
  final bool danger;
  const _UDialogFooter({
    required this.onCancel,
    required this.onConfirm,
    required this.confirmLabel,
    this.confirmIcon,
    this.busy = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 16, 26, 24),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: CendentColors.hairline))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _UBtn(
            icon: Icons.close_rounded,
            label: 'Cancelar',
            kind: _UBtnKind.secondary,
            onTap: onCancel ?? () {},
          ),
          const SizedBox(width: 10),
          _UBtn(
            icon: confirmIcon,
            label: confirmLabel,
            kind: danger ? _UBtnKind.danger : _UBtnKind.primary,
            busy: busy,
            onTap: onConfirm,
          ),
        ],
      ),
    );
  }
}

class _UErrorBanner extends StatelessWidget {
  final String message;
  const _UErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: CendentColors.redSoft,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 16, color: CendentColors.red),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13, color: CendentColors.red))),
        ],
      ),
    );
  }
}

// =============================================================================
//  EMPTY / ERROR / SKELETON
// =============================================================================
class _UEmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _UEmptyState({required this.onCreate});
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
              child: const Icon(Icons.group_outlined,
                  size: 32, color: CendentColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('Sin usuarios registrados',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CendentColors.ink)),
            const SizedBox(height: 6),
            const Text('Crea el primer usuario del sistema.',
                style:
                    TextStyle(fontSize: 13.5, color: CendentColors.secondary)),
            const SizedBox(height: 20),
            _UBtn(
              icon: Icons.person_add_outlined,
              label: 'Nuevo usuario',
              kind: _UBtnKind.primary,
              onTap: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

class _UEmptyFiltered extends StatelessWidget {
  const _UEmptyFiltered();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'Sin usuarios para el filtro o búsqueda actual.',
          style: TextStyle(fontSize: 14, color: CendentColors.secondary),
        ),
      ),
    );
  }
}

class _UErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _UErrorState({required this.message, required this.onRetry});
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
            _UBtn(
              icon: Icons.refresh_rounded,
              label: 'Reintentar',
              kind: _UBtnKind.secondary,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _USkeleton extends StatelessWidget {
  const _USkeleton();
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
            color: CendentColors.primary, strokeWidth: 2.5),
      ),
    );
  }
}

// =============================================================================
//  SHARED UI COMPONENTS
// =============================================================================
enum _UBtnKind { primary, secondary, danger }

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: CendentColors.muted, fontSize: 14),
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

class _UBtn extends StatefulWidget {
  final IconData? icon;
  final String label;
  final _UBtnKind kind;
  final bool busy;
  final VoidCallback? onTap;
  const _UBtn({
    this.icon,
    required this.label,
    required this.kind,
    this.busy = false,
    required this.onTap,
  });
  @override
  State<_UBtn> createState() => _UBtnState();
}

class _UBtnState extends State<_UBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.busy;
    Color bg;
    Color fg;
    Border? border;
    switch (widget.kind) {
      case _UBtnKind.primary:
        bg = disabled
            ? CendentColors.blueLight
            : (_hover ? CendentColors.primaryDeep : CendentColors.primary);
        fg = Colors.white;
        break;
      case _UBtnKind.secondary:
        bg = _hover ? CendentColors.blueTint : CendentColors.card;
        fg = CendentColors.primary;
        border = Border.all(color: CendentColors.blueLight);
        break;
      case _UBtnKind.danger:
        bg = disabled
            ? CendentColors.redSoft
            : (_hover ? const Color(0xFFB71C1C) : CendentColors.red);
        fg = Colors.white;
        break;
    }
    return MouseRegion(
      cursor:
          disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
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
              border: border),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy)
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: fg, strokeWidth: 2))
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

class _UActBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  const _UActBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });
  @override
  State<_UActBtn> createState() => _UActBtnState();
}

class _UActBtnState extends State<_UActBtn> {
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

class _UCloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _UCloseBtn({required this.onTap});
  @override
  State<_UCloseBtn> createState() => _UCloseBtnState();
}

class _UCloseBtnState extends State<_UCloseBtn> {
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
              color: _hover ? CendentColors.red : CendentColors.steel),
        ),
      ),
    );
  }
}

class _UFieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _UFieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CendentColors.ink)),
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

class _UFooter extends StatelessWidget {
  const _UFooter();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 22, 32, 24),
      child: const Column(
        children: [
          Text("Daniel's CENDENT S.A.  ·  Centro de Especialidades Odontológicas",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: CendentColors.secondary,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('© 2026 — Todos los derechos reservados',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: CendentColors.secondary)),
        ],
      ),
    );
  }
}
