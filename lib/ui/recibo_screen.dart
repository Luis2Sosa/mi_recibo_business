import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // 👈 HAPTIC

import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart'; // 👈 ya lo tenías
import 'package:file_saver/file_saver.dart'; // 👈 (queda importado, aunque no lo usemos)
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

class ReciboScreen extends StatefulWidget {
  final String empresa;
  final String servidor; // prestamista
  final String telefonoServidor;
  final String cliente;
  final String telefonoCliente;
  final String numeroRecibo; // ID corto que tú envías (p.ej. "ID-1")
  final String producto;     // producto a mostrar (puede venir vacío)
  final DateTime fecha;
  final int capitalInicial;
  final int pagoInteres;
  final int pagoCapital;
  final int totalPagado;
  final int saldoAnterior;
  final int saldoActual;
  final DateTime proximaFecha;

  // Logo independiente
  static const double _logoHeight = 128;
  static const double _logoTop = -32;

  const ReciboScreen({
    super.key,
    required this.empresa,
    required this.servidor,
    required this.telefonoServidor,
    required this.cliente,
    required this.telefonoCliente,
    required this.numeroRecibo,
    required this.producto,
    required this.fecha,
    required this.capitalInicial,
    required this.pagoInteres,
    required this.pagoCapital,
    required this.totalPagado,
    required this.saldoAnterior,
    required this.saldoActual,
    required this.proximaFecha,
  });

  @override
  State<ReciboScreen> createState() => _ReciboScreenState();
}

class _ReciboScreenState extends State<ReciboScreen> {
  final GlobalKey _cardKey = GlobalKey();

  // Alto fijo del recibo (sin scroll)
  static const double _cardHeight = 640;
  // Desplaza la columna interna (no el logo)
  static const double _contentTopPadding = 90;

  // Control de doble-atrás
  DateTime? _lastBackPress;
  static const Duration _backWindow = Duration(seconds: 2);

  String _monedaRD(int v) {
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write('.');
        c = 0;
      }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  String _fmtFecha(DateTime d) {
    const m = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  /// Formatea cualquier entrada a "REC-0001".
  String _fmtNumReciboStr(String s) {
    final trimmed = s.trim();
    final recLike = RegExp(r'^\s*REC-\d{4}\s*$', caseSensitive: false);
    if (recLike.hasMatch(trimmed)) return trimmed.toUpperCase();

    final match = RegExp(r'\d+').firstMatch(trimmed);
    if (match != null) {
      final n = int.tryParse(match.group(0)!) ?? 0;
      return 'REC-${n.toString().padLeft(4, '0')}';
    }
    return 'REC-$trimmed';
  }

  String get _reciboFmt => _fmtNumReciboStr(widget.numeroRecibo);

  void _volverAClientes() {
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<Uint8List> _capturarReciboPng() async {
    final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _compartirWhatsApp() async {
    try {
      final bytes = await _capturarReciboPng();
      final caption = 'Recibo $_reciboFmt - ${_fmtFecha(widget.fecha)}';
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'recibo-$_reciboFmt.png', mimeType: 'image/png')],
        text: caption,
        subject: 'Recibo $_reciboFmt',
      );
    } catch (_) {
      final bytes = await _capturarReciboPng();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'recibo-$_reciboFmt.png', mimeType: 'image/png')],
        text: 'Recibo $_reciboFmt',
        subject: 'Recibo $_reciboFmt',
      );
    } finally {
      _volverAClientes();
    }
  }

  Future<void> _guardarPdfYVolver() async {
    // 1) Capturar el recibo como imagen
    final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    // 2) Crear PDF del MISMO tamaño que el recibo (sin márgenes ⇒ sin espacios)
    final pdf = pw.Document();
    final img = pw.MemoryImage(pngBytes);
    final pageFormat = PdfPageFormat(image.width.toDouble(), image.height.toDouble());

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(img, fit: pw.BoxFit.fill),
      ),
    );
    final pdfBytes = await pdf.save();

    try {
      // 3) Guardar con FlutterFileDialog (abre el diálogo del sistema, pero GUARDA seguro)
      final params = SaveFileDialogParams(
        data: pdfBytes,
        mimeTypesFilter: const ['application/pdf'],
        fileName: 'recibo-$_reciboFmt.pdf',
      );
      await FlutterFileDialog.saveFile(params: params);

      if (!mounted) return;
      _showModernSnackBar(
        icon: Icons.check_circle_rounded,
        text: 'PDF guardado: $_reciboFmt',
        bg: const Color(0xFF10B981),
      );
    } catch (e) {
      // 4) Fallback: carpeta privada de la app
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/recibo-$_reciboFmt.pdf';
      await File(path).writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      _showModernSnackBar(
        icon: Icons.error_outline_rounded,
        text: 'Guardado interno: $_reciboFmt',
        bg: Colors.orange,
      );
    }

    // 5) Volver a Clientes
    _volverAClientes();
  }

  // --- SnackBar moderno y flotante ---
  void _showModernSnackBar({
    required IconData icon,
    required String text,
    required Color bg,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 6,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Manejo del botón/gesto Atrás: doble-press para guardar y salir
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > _backWindow) {
      _lastBackPress = now;

      // 👇 vibración suave en el primer "Atrás"
      HapticFeedback.mediumImpact();

      if (mounted) {
        _showModernSnackBar(
          icon: Icons.keyboard_return_rounded,
          text: 'Pulsa atrás otra vez para guardar PDF y volver a Clientes',
          bg: const Color(0xFF0EA5E9), // azul
        );
      }
      return false; // se queda en Recibo
    } else {
      // segunda vez dentro de la ventana -> guarda y sale a Clientes
      await _guardarPdfYVolver();
      return false; // manejado manualmente
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: Text(
                                'RECIBO',
                                style: GoogleFonts.playfair(
                                  textStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ===== Recibo estático (se captura) =====
                            RepaintBoundary(
                              key: _cardKey,
                              child: _CardRecibo(
                                height: _cardHeight,
                                contentTopPadding: _contentTopPadding,
                                logoTop: ReciboScreen._logoTop,
                                logoHeight: ReciboScreen._logoHeight,
                                empresa: widget.empresa,
                                servidor: widget.servidor,
                                telefonoServidor: widget.telefonoServidor,
                                cliente: widget.cliente,
                                telefonoCliente: widget.telefonoCliente,
                                producto: widget.producto,
                                numeroRecibo: _reciboFmt,
                                fecha: widget.fecha,
                                capitalInicial: widget.capitalInicial,
                                pagoInteres: widget.pagoInteres,
                                pagoCapital: widget.pagoCapital,
                                totalPagado: widget.totalPagado,
                                saldoAnterior: widget.saldoAnterior,
                                saldoActual: widget.saldoActual,
                                proximaFecha: widget.proximaFecha,
                                fmtFecha: _fmtFecha,
                                monedaRD: _monedaRD,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Container(
                                      width: 28, height: 28,
                                      decoration: const BoxDecoration(
                                        color: Colors.white, shape: BoxShape.circle,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Image.asset('assets/images/logo_whatsapp.png', fit: BoxFit.contain),
                                      ),
                                    ),
                                    label: const Text('Enviar Recibo'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF22C55E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: _compartirWhatsApp,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Image.asset('assets/images/logo_pdf.png', height: 22),
                                    label: const Text('Guardar PDF'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: const StadiumBorder(),
                                    ),
                                    onPressed: _guardarPdfYVolver, // descarga + volver
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =================== Card de Recibo (contenido estático capturable) ===================
class _CardRecibo extends StatelessWidget {
  final double height;
  final double contentTopPadding;
  final double logoTop;
  final double logoHeight;

  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final String cliente;
  final String telefonoCliente;
  final String producto;
  final String numeroRecibo; // ya formateado como REC-0001
  final DateTime fecha;
  final int capitalInicial;
  final int pagoInteres;
  final int pagoCapital;
  final int totalPagado;
  final int saldoAnterior;
  final int saldoActual;
  final DateTime proximaFecha;

  final String Function(DateTime) fmtFecha;
  final String Function(int) monedaRD;

  const _CardRecibo({
    required this.height,
    required this.contentTopPadding,
    required this.logoTop,
    required this.logoHeight,
    required this.empresa,
    required this.servidor,
    required this.telefonoServidor,
    required this.cliente,
    required this.telefonoCliente,
    required this.producto,
    required this.numeroRecibo,
    required this.fecha,
    required this.capitalInicial,
    required this.pagoInteres,
    required this.pagoCapital,
    required this.totalPagado,
    required this.saldoAnterior,
    required this.saldoActual,
    required this.proximaFecha,
    required this.fmtFecha,
    required this.monedaRD,
  });

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 12,
      color: Color(0xFF64748B),
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _value(String t,
      {double size = 14,
        FontWeight w = FontWeight.w700,
        Color c = const Color(0xFF0F172A)}) =>
      Text(
        t,
        style: TextStyle(fontSize: size, fontWeight: w, color: c),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Logo independiente
          Positioned(
            top: logoTop,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Image.asset(
                  'assets/images/logoB.png',
                  height: logoHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // Columna de contenido (independiente del logo)
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, contentTopPadding, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Servidor a la izquierda, Recibo + Fecha a la derecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Nombre del servidor:'),
                            const SizedBox(height: 2),
                            _value(servidor, size: 15),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _value('Recibo: $numeroRecibo', size: 14),
                          const SizedBox(height: 2),
                          _value(fmtFecha(fecha), size: 14),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  _label('Nombre de la empresa:'),
                  const SizedBox(height: 2),
                  _value(empresa, size: 15),
                  const SizedBox(height: 8),

                  _label('Teléfono:'),
                  const SizedBox(height: 2),
                  _value(
                    telefonoServidor,
                    size: 15,
                    w: FontWeight.w600,
                    c: const Color(0xFF475569),
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 6),

                  // ====== MONTO GRANDE + "Pago recibido" (auto-ajustable, sin overflow) ======
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _MontoGrande(
                            texto: monedaRD(totalPagado).replaceFirst('RD\$', 'RD '),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24), // más a la derecha
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: const Text(
                            'Pago recibido',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 6),

                  // Montos (sin "Total pagado" aquí, va arriba en grande)
                  _row('Capital inicial', monedaRD(capitalInicial)),
                  _row('Pago de interés', monedaRD(pagoInteres)),
                  _row('Pago a capital', monedaRD(pagoCapital)),

                  const Divider(height: 18, thickness: 1, color: Color(0xFFE5E7EB)),

                  _row('Saldo anterior', monedaRD(saldoAnterior)),
                  _row('Saldo actual', monedaRD(saldoActual)),
                  _row('Próxima fecha', fmtFecha(proximaFecha)),

                  const SizedBox(height: 8),
                  // Línea final + Cliente
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _label('Cliente'),
                      const Spacer(),
                      _value(cliente, size: 18, w: FontWeight.w800),
                    ],
                  ),

                  // Producto debajo del cliente (si hay)
                  if (producto.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _label('Producto'),
                        const Spacer(),
                        _value(producto, size: 16, w: FontWeight.w700),
                      ],
                    ),
                  ],

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String t, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(t, style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)))),
          const SizedBox(width: 10),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }
}

// ===== Widget interno para el monto grande "RD 1.400" (RD al lado) =====
class _MontoGrande extends StatelessWidget {
  final String texto; // viene como "RD 1.400"
  const _MontoGrande({required this.texto});

  @override
  Widget build(BuildContext context) {
    final parts = texto.split(' ');
    final pref = parts.isNotEmpty ? parts.first : 'RD';
    final num = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          pref, // "RD"
          style: const TextStyle(
            fontSize: 26, // balance con número
            fontWeight: FontWeight.w900,
            color: Color(0xFF14B8A6),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          num,  // "1.400"
          style: const TextStyle(
            fontSize: 54,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: Color(0xFF14B8A6),
          ),
        ),
      ],
    );
  }
}