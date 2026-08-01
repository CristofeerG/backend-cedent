// lib/utils/inventario_pdf.dart
// Generación de PDF de inventario — usa el paquete pdf

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─── Colores (espejo de CendentColors) ───────────────────────────────────────
// PdfColor(red, green, blue) recibe doubles en rango 0.0–1.0
const _cPrimary   = PdfColor(21 / 255, 101 / 255, 192 / 255);  // #1565C0
const _cInk       = PdfColor(13 / 255, 27  / 255, 42  / 255);  // #0D1B2A
const _cSecondary = PdfColor(120 / 255, 144 / 255, 156 / 255); // #78909C
const _cHairline  = PdfColor(227 / 255, 233 / 255, 240 / 255); // #E3E9F0
const _cBlueWash  = PdfColor(244 / 255, 248 / 255, 253 / 255); // #F4F8FD
const _cBlueTint  = PdfColor(227 / 255, 240 / 255, 252 / 255); // #E3F0FC
const _cGreen     = PdfColor(46 / 255, 158 / 255, 107 / 255);  // #2E9E6B
const _cAmber     = PdfColor(199 / 255, 119 / 255, 0   / 255); // #C77700
const _cRed       = PdfColor(213 / 255, 69  / 255, 59  / 255); // #D5453B

// ─── Modelos de datos para PDF ────────────────────────────────────────────────
class PdfLote {
  final String codigo;
  final int stock;
  final String vencimiento;
  const PdfLote({required this.codigo, required this.stock, required this.vencimiento});
}

class PdfProducto {
  final String nombre;
  final String sku;
  final int stockTotal;
  final int stockMin;
  final List<PdfLote> lotes;
  const PdfProducto({
    required this.nombre,
    required this.sku,
    required this.stockTotal,
    required this.stockMin,
    required this.lotes,
  });
}

// ─── Punto de entrada ─────────────────────────────────────────────────────────
pw.Document generarInventarioPdf({
  required String nomSucursal,
  required List<PdfProducto> productos,
  required DateTime fechaGeneracion,
}) {
  final doc = pw.Document();

  final d  = fechaGeneracion.day.toString().padLeft(2, '0');
  final mo = fechaGeneracion.month.toString().padLeft(2, '0');
  final fechaStr = '$d/$mo/${fechaGeneracion.year}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      header: (ctx) => _header(nomSucursal, fechaStr),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 14),
        _tableHeader(),
        pw.SizedBox(height: 2),
        ...productos.asMap().entries.expand(
          (e) => _productoRows(e.value, e.key),
        ),
        pw.SizedBox(height: 12),
        _resumen(productos),
      ],
    ),
  );

  return doc;
}

// ─── Encabezado de página ─────────────────────────────────────────────────────
pw.Widget _header(String sucursal, String fecha) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 10),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _cPrimary, width: 1.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        // Marca
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'CENDENT',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: _cPrimary,
                letterSpacing: 2,
              ),
            ),
            pw.Text(
              "Daniel's CENDENT S.A.  ·  Centro de Especialidades Odontológicas",
              style: const pw.TextStyle(fontSize: 7, color: _cSecondary),
            ),
          ],
        ),
        // Metadatos
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INVENTARIO DE STOCK',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _cInk,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text('Sucursal: $sucursal',
                style: const pw.TextStyle(fontSize: 9, color: _cSecondary)),
            pw.Text('Generado: $fecha',
                style: const pw.TextStyle(fontSize: 9, color: _cSecondary)),
          ],
        ),
      ],
    ),
  );
}

// ─── Pie de página ────────────────────────────────────────────────────────────
pw.Widget _footer(pw.Context ctx) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: _cHairline, width: 0.5)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          '© 2026 Daniel\'s CENDENT S.A. - Todos los derechos reservados',
          style: const pw.TextStyle(fontSize: 7, color: _cSecondary),
        ),
        pw.Text(
          'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: _cSecondary),
        ),
      ],
    ),
  );
}

// ─── Cabecera de tabla ────────────────────────────────────────────────────────
pw.Widget _tableHeader() {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      color: _cPrimary,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Row(
      children: [
        _hCell('PRODUCTO / SKU', flex: 38),
        _hCell('STOCK TOTAL',    flex: 13, align: pw.TextAlign.center),
        _hCell('CÓDIGO DE LOTE', flex: 22, align: pw.TextAlign.center),
        _hCell('STOCK LOTE',     flex: 13, align: pw.TextAlign.center),
        _hCell('VENCIMIENTO',    flex: 14, align: pw.TextAlign.center),
      ],
    ),
  );
}

pw.Widget _hCell(String text, {required int flex, pw.TextAlign align = pw.TextAlign.left}) {
  return pw.Expanded(
    flex: flex,
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        letterSpacing: 0.4,
      ),
    ),
  );
}

// ─── Filas de producto + lotes ────────────────────────────────────────────────
List<pw.Widget> _productoRows(PdfProducto p, int index) {
  final even   = index.isEven;
  final rowBg  = even ? _cBlueWash : PdfColors.white;
  final result = <pw.Widget>[];

  PdfColor stockColor() {
    if (p.stockTotal == 0) return _cSecondary;
    if (p.stockMin > 0 && p.stockTotal < p.stockMin) return _cAmber;
    return _cInk;
  }

  final sc = stockColor();

  if (p.lotes.isEmpty) {
    result.add(_singleRow(
      bg: rowBg,
      producto: p,
      stockColor: sc,
      lot: null,
      showProduct: true,
    ));
  } else {
    for (int i = 0; i < p.lotes.length; i++) {
      result.add(_singleRow(
        bg: rowBg,
        producto: p,
        stockColor: sc,
        lot: p.lotes[i],
        showProduct: i == 0,
      ));
    }
  }

  result.add(pw.Container(height: 0.4, color: _cHairline));
  return result;
}

pw.Widget _singleRow({
  required PdfColor bg,
  required PdfProducto producto,
  required PdfColor stockColor,
  required PdfLote? lot,
  required bool showProduct,
}) {
  return pw.Container(
    color: bg,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Columna: nombre + SKU (solo en primera fila del producto)
        pw.Expanded(
          flex: 38,
          child: showProduct
              ? pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      producto.nombre,
                      maxLines: 2,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _cInk,
                      ),
                    ),
                    pw.Text(
                      producto.sku,
                      style: pw.TextStyle(
                        fontSize: 7.5,
                        color: _cSecondary,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                )
              : pw.SizedBox(),
        ),
        // Stock total (solo en primera fila)
        pw.Expanded(
          flex: 13,
          child: showProduct
              ? pw.Text(
                  '${producto.stockTotal} u',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: stockColor,
                  ),
                )
              : pw.SizedBox(),
        ),
        // Código de lote
        pw.Expanded(
          flex: 22,
          child: lot != null
              ? pw.Text(
                  lot.codigo,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: _cInk),
                )
              : pw.Text(
                  '-',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 8, color: _cSecondary),
                ),
        ),
        // Stock del lote
        pw.Expanded(
          flex: 13,
          child: lot != null
              ? pw.Text(
                  '${lot.stock} u',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9, color: _cInk),
                )
              : pw.Text(
                  '-',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 9, color: _cSecondary),
                ),
        ),
        // Vencimiento
        pw.Expanded(
          flex: 14,
          child: lot != null
              ? _vencBadge(lot.vencimiento)
              : pw.Text(
                  'Sin lotes activos',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: _cSecondary),
                ),
        ),
      ],
    ),
  );
}

// Badge con color según proximidad de vencimiento
pw.Widget _vencBadge(String fechaStr) {
  PdfColor color = _cInk;
  if (fechaStr.isNotEmpty && fechaStr != '-') {
    try {
      final parts = fechaStr.split('/');
      if (parts.length == 3) {
        final dt = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
        final diff = dt.difference(DateTime.now()).inDays;
        if (diff <= 14) {
          color = _cRed;
        } else if (diff <= 30) {
          color = _cAmber;
        } else {
          color = _cGreen;
        }
      }
    } catch (_) {}
  }
  return pw.Text(
    fechaStr,
    textAlign: pw.TextAlign.center,
    style: pw.TextStyle(fontSize: 8.5, color: color, fontWeight: pw.FontWeight.bold),
  );
}

// ─── Resumen al final ─────────────────────────────────────────────────────────
pw.Widget _resumen(List<PdfProducto> productos) {
  final total      = productos.length;
  final conStock   = productos.where((p) => p.stockTotal > 0).length;
  final sinStock   = productos.where((p) => p.stockTotal == 0).length;
  final bajoMin    = productos.where((p) => p.stockMin > 0 && p.stockTotal > 0 && p.stockTotal < p.stockMin).length;
  final totalLotes = productos.fold<int>(0, (s, p) => s + p.lotes.length);

  return pw.Container(
    decoration: const pw.BoxDecoration(
      color: _cBlueTint,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _resumenItem('Total productos', '$total'),
        _resumenItem('Con stock',       '$conStock', color: _cGreen),
        _resumenItem('Sin stock',       '$sinStock', color: _cSecondary),
        _resumenItem('Bajo mínimo',     '$bajoMin',  color: _cAmber),
        _resumenItem('Lotes activos',   '$totalLotes'),
      ],
    ),
  );
}

pw.Widget _resumenItem(String label, String value, {PdfColor color = _cInk}) {
  return pw.Column(
    children: [
      pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
      pw.SizedBox(height: 2),
      pw.Text(label, style: const pw.TextStyle(fontSize: 7.5, color: _cSecondary)),
    ],
  );
}
