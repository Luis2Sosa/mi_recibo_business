import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/app_frame.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

/// ==============================
/// CONFIGURACIÓN VISUAL AJUSTABLE
/// ==============================
class ReciboUIConfig {
  // Fondo pantalla
  final Alignment gradientBegin;
  final Alignment gradientEnd;
  final List<Color> gradientColors;

  // Área capturable (tarjeta/recibo)
  final double cardHeight;
  final double designWidth;
  final BorderRadius cardRadius;
  final EdgeInsets cardPadding;

  // Encabezado de pantalla
  final bool showHeaderTitle;
  final String headerTitle;
  final TextStyle headerTitleStyle;

  // Logo (independiente, overlay dentro de la tarjeta)
  final String brandLogoAsset;
  final double brandLogoHeight;   // tamaño del logo
  final double brandLogoTop;      // distancia desde arriba (no reserva espacio)
  final double brandLogoDx;       // desplazamiento horizontal (+ der / - izq)

  // Paloma
  final double checkCircleSize;
  final double checkBorderWidth;
  final double checkIconSize;

  // Título
  final TextStyle recibidoTitleStyle;
  final EdgeInsets titleMargin;

  // Monto
  final List<Color> amountPanelGradientColors;
  final BorderRadius amountPanelRadius;
  final EdgeInsets amountPanelPadding;
  final Color amountPanelBorder;
  final TextStyle amountPrefixStyle; // “RD$”
  final TextStyle amountNumberStyle; // “8.800”

  // Paleta tipográfica
  final Color navy;
  final Color label;
  final Color line;
  final Color brandTeal;

  // Bloques mint
  final Color mint;
  final Color mintBorder;
  final Color mintDivider;

  // Textos
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle valueStrongStyle;
  final TextStyle valueClientStyle;

  // Botones
  final Color btnWhatsapp;
  final Color btnPdf;

  final dynamic phoneStyle;

  const ReciboUIConfig({
    // Fondo
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
    this.gradientColors = const [Color(0xFF11A7A0), Color(0xFF1D60C9)],

    // Capturable (recibo)
    this.cardHeight = 600,
    this.designWidth = 450,
    this.cardRadius = const BorderRadius.all(Radius.circular(20)),
    this.cardPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),

    // Header
    this.showHeaderTitle = true,
    this.headerTitle = 'RECIBO',
    this.headerTitleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 30, // ↑ sutil
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),

    // Logo independiente (overlay)
    this.brandLogoAsset = 'assets/images/logoB.png',
    this.brandLogoHeight = 190,
    this.brandLogoTop = -60,
    this.brandLogoDx = 0,

    // Paloma
    this.checkCircleSize = 78,    // ↑
    this.checkBorderWidth = 5,
    this.checkIconSize = 40,      // ↑

    // Título
    this.recibidoTitleStyle = const TextStyle(
      fontSize: 27, // ↑
      fontWeight: FontWeight.w900,
      color: Color(0xFF0F172A),
      letterSpacing: 0.2,
    ),
    this.titleMargin = const EdgeInsets.only(top: 10, bottom: 12), // ↑

    // Monto
    this.amountPanelGradientColors = const [Color(0xFFF3FBF7), Color(0xFFEAF5F0)],
    this.amountPanelRadius = const BorderRadius.all(Radius.circular(18)),
    this.amountPanelPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14), // ↑
    this.amountPanelBorder = const Color(0xFFDDE7E1),
    this.amountPrefixStyle = const TextStyle(
      fontSize: 60, // ↑
      fontWeight: FontWeight.w900,
      color: Color(0xFF10B981),
      height: 1.0,
      letterSpacing: 0.2,
    ),
    this.amountNumberStyle = const TextStyle(
      fontSize: 68, // ↑
      fontWeight: FontWeight.w900,
      letterSpacing: 0.6,
      color: Color(0xFF10B981),
      height: 1.0,
    ),

    // Paleta
    this.navy = const Color(0xFF0F172A),
    this.label = const Color(0xFF667084),
    this.line = const Color(0xFFE7E9EE),
    this.brandTeal = const Color(0xFF10B981),

    // Mint blocks
    this.mint = const Color(0xFFF4FAF7),
    this.mintBorder = const Color(0xFFDDE7E1),
    this.mintDivider = const Color(0xFFE7F0EA),

    // Textos
    this.labelStyle = const TextStyle(
      fontSize: 17, // antes 20
      color: Color(0xFF667084),
      fontWeight: FontWeight.w600,
      letterSpacing: .1,
    ),
    this.valueStyle = const TextStyle(
      fontSize: 18, // antes 22
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w800,
      letterSpacing: .1,
    ),
    this.valueStrongStyle = const TextStyle(
      fontSize: 19, // antes 22
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w900,
      letterSpacing: .1,
    ),
    this.valueClientStyle = const TextStyle(
      fontSize: 20, // antes 23
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w900,
      letterSpacing: .2,
    ),
    this.phoneStyle = const TextStyle(
      fontSize: 16,
      color: Color(0xFF667084),
      fontWeight: FontWeight.w600,
    ),


    // Botones
    this.btnWhatsapp = const Color(0xFF22C55E),
    this.btnPdf = const Color(0xFF2563EB),
  });

  ReciboUIConfig copyWith({
    Alignment? gradientBegin, Alignment? gradientEnd, List<Color>? gradientColors,
    double? cardHeight, double? designWidth, BorderRadius? cardRadius, EdgeInsets? cardPadding,
    bool? showHeaderTitle, String? headerTitle, TextStyle? headerTitleStyle,
    String? brandLogoAsset, double? brandLogoHeight, double? brandLogoTop, double? brandLogoDx,
    double? checkCircleSize, double? checkBorderWidth, double? checkIconSize,
    TextStyle? recibidoTitleStyle, EdgeInsets? titleMargin,
    List<Color>? amountPanelGradientColors, BorderRadius? amountPanelRadius,
    EdgeInsets? amountPanelPadding, Color? amountPanelBorder, TextStyle? amountPrefixStyle, TextStyle? amountNumberStyle,
    Color? navy, Color? label, Color? line, Color? brandTeal,
    Color? mint, Color? mintBorder, Color? mintDivider,
    TextStyle? labelStyle, TextStyle? valueStyle, TextStyle? valueStrongStyle, TextStyle? valueClientStyle,
    Color? btnWhatsapp, Color? btnPdf,
  }) {
    return ReciboUIConfig(
      gradientBegin: gradientBegin ?? this.gradientBegin,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      gradientColors: gradientColors ?? this.gradientColors,
      cardHeight: cardHeight ?? this.cardHeight,
      designWidth: designWidth ?? this.designWidth,
      cardRadius: cardRadius ?? this.cardRadius,
      cardPadding: cardPadding ?? this.cardPadding,
      showHeaderTitle: showHeaderTitle ?? this.showHeaderTitle,
      headerTitle: headerTitle ?? this.headerTitle,
      headerTitleStyle: headerTitleStyle ?? this.headerTitleStyle,
      brandLogoAsset: brandLogoAsset ?? this.brandLogoAsset,
      brandLogoHeight: brandLogoHeight ?? this.brandLogoHeight,
      brandLogoTop: brandLogoTop ?? this.brandLogoTop,
      brandLogoDx: brandLogoDx ?? this.brandLogoDx,
      checkCircleSize: checkCircleSize ?? this.checkCircleSize,
      checkBorderWidth: checkBorderWidth ?? this.checkBorderWidth,
      checkIconSize: checkIconSize ?? this.checkIconSize,
      recibidoTitleStyle: recibidoTitleStyle ?? this.recibidoTitleStyle,
      titleMargin: titleMargin ?? this.titleMargin,
      amountPanelGradientColors: amountPanelGradientColors ?? this.amountPanelGradientColors,
      amountPanelRadius: amountPanelRadius ?? this.amountPanelRadius,
      amountPanelPadding: amountPanelPadding ?? this.amountPanelPadding,
      amountPanelBorder: amountPanelBorder ?? this.amountPanelBorder,
      amountPrefixStyle: amountPrefixStyle ?? this.amountPrefixStyle,
      amountNumberStyle: amountNumberStyle ?? this.amountNumberStyle,
      navy: navy ?? this.navy,
      label: label ?? this.label,
      line: line ?? this.line,
      brandTeal: brandTeal ?? this.brandTeal,
      mint: mint ?? this.mint,
      mintBorder: mintBorder ?? this.mintBorder,
      mintDivider: mintDivider ?? this.mintDivider,
      labelStyle: labelStyle ?? this.labelStyle,
      valueStyle: valueStyle ?? this.valueStyle,
      valueStrongStyle: valueStrongStyle ?? this.valueStrongStyle,
      valueClientStyle: valueClientStyle ?? this.valueClientStyle,
      btnWhatsapp: btnWhatsapp ?? this.btnWhatsapp,
      btnPdf: btnPdf ?? this.btnPdf,
    );
  }
}

/// =======================================
/// PANTALLA (lógica intacta)
/// =======================================
class ReciboScreen extends StatefulWidget {
  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final String cliente;
  final String telefonoCliente;
  final String numeroRecibo;
  final String producto;
  final DateTime fecha;
  final int capitalInicial;
  final int pagoInteres;
  final int pagoCapital;
  final int totalPagado;
  final int saldoAnterior;
  final int saldoActual;
  final DateTime proximaFecha;

  final ReciboUIConfig config;

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
    this.config = const ReciboUIConfig(),
  });

  @override
  State<ReciboScreen> createState() => _ReciboScreenState();
}

class _ReciboScreenState extends State<ReciboScreen> {
  // Capturamos fondo+recibo centrado
  final GlobalKey _captureKey = GlobalKey();

  DateTime? _lastBackPress;
  static const Duration _backWindow = Duration(seconds: 2);

  ReciboUIConfig get cfg => widget.config;

  // Formato RD$ con coma de miles
  String _monedaRD(int v) {
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]); c++;
      if (c == 3 && i != 0) { b.write(','); c = 0; }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  String _fmtFecha(DateTime d) {
    const m = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

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

  Future<Uint8List> _capturarArea() async {
    final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _compartirWhatsApp() async {
    try {
      // 1) Capturamos el área como imagen
      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0); // 3.0 está bien; WhatsApp comprime igual
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // 2) La metemos dentro de un PDF (sin pérdida)
      final pdf = pw.Document();
      final img = pw.MemoryImage(pngBytes);
      final pageFormat = PdfPageFormat(image.width.toDouble(), image.height.toDouble());
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(img, fit: pw.BoxFit.cover),
        ),
      );
      final pdfBytes = await pdf.save();

      // 3) Compartimos el PDF por el share sheet (WhatsApp lo respeta nítido)
      final caption = 'Recibo $_reciboFmt - ${_fmtFecha(widget.fecha)}';
      await Share.shareXFiles(
        [XFile.fromData(pdfBytes, name: 'recibo-$_reciboFmt.pdf', mimeType: 'application/pdf')],
        text: caption,
        subject: 'Recibo $_reciboFmt',
      );
    } catch (e) {
      // fallback opcional: si algo falla, comparte la imagen (no será tan nítida)
      try {
        final bytes = await _capturarArea();
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: 'recibo-$_reciboFmt.png', mimeType: 'image/png')],
          text: 'Recibo $_reciboFmt - ${_fmtFecha(widget.fecha)}',
          subject: 'Recibo $_reciboFmt',
        );
      } catch (_) {}
    } finally {
      _volverAClientes();
    }
  }


  Future<void> _guardarPdfYVolver() async {
    final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();

    final pdf = pw.Document();
    final img = pw.MemoryImage(pngBytes);
    final pageFormat = PdfPageFormat(image.width.toDouble(), image.height.toDouble());
    pdf.addPage(
      pw.Page(pageFormat: pageFormat, margin: pw.EdgeInsets.zero, build: (_) => pw.Image(img, fit: pw.BoxFit.cover)),
    );
    final pdfBytes = await pdf.save();

    try {
      final params = SaveFileDialogParams(
        data: pdfBytes,
        mimeTypesFilter: const ['application/pdf'],
        fileName: 'recibo-$_reciboFmt.pdf',
      );
      await FlutterFileDialog.saveFile(params: params);
    } catch (_) {
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/recibo-$_reciboFmt.pdf';
      await File(path).writeAsBytes(pdfBytes, flush: true);
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _volverAClientes());
  }

  @override
  Widget build(BuildContext context) {
    final cfg = this.cfg;
    final double captureHeight = MediaQuery.of(context).size.height * 0.9;

    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastBackPress == null || now.difference(_lastBackPress!) > _backWindow) {
          _lastBackPress = now;
          HapticFeedback.mediumImpact();

          _showModernSnackBar(
            icon: Icons.keyboard_return_rounded,
            text: 'Pulsa atrás otra vez para guardar PDF y volver a Clientes',
            bg: const Color(0xFF11A7A0),
          );
          return false;
        } else {
          await _guardarPdfYVolver();
          return false;
        }
      },
        child: Scaffold(
          body: AppGradientBackground(
            child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (cfg.showHeaderTitle)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Center(child: Text(cfg.headerTitle, style: GoogleFonts.playfair(textStyle: cfg.headerTitleStyle))),
                  ),

                // ====== CAPTURABLE: Fondo + Recibo centrado ======
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: RepaintBoundary(
                      key: _captureKey,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Altura máxima disponible para la tarjeta (dejamos aire arriba/abajo)
                          final double maxCardH = (constraints.maxHeight * 0.82).clamp(520.0, 760.0);

                          return Container(
                            // 👇 ocupa todo el alto disponible del Expanded (no se corta)
                            height: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppTheme.gradTop, AppTheme.gradBottom],
                              ),
                            ),
                            child: Center(
                              child: _PlainCardShell(
                                radius: cfg.cardRadius,
                                height: maxCardH,                 // 👈 la tarjeta se adapta
                                padding: cfg.cardPadding,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: cfg.designWidth,
                                    child: _ReceiptContent(
                                      cfg: cfg,
                                      empresa: widget.empresa,
                                      servidor: widget.servidor,
                                      telefonoServidor: widget.telefonoServidor,
                                      cliente: widget.cliente,
                                      telefonoCliente: widget.telefonoCliente,
                                      producto: widget.producto,
                                      numeroRecibo: _fmtNumReciboStr(widget.numeroRecibo),
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
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),




                const SizedBox(height: 8),

                // Botones (no se incluyen en la captura)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Container(
                            width: 28, height: 28,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Image.asset('assets/images/logo_whatsapp.png', fit: BoxFit.contain),
                            ),
                          ),
                          label: const Text('Enviar Recibo'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cfg.btnWhatsapp, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12), shape: const StadiumBorder(),
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
                            backgroundColor: cfg.btnPdf, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder(),
                          ),
                          onPressed: _guardarPdfYVolver,
                        ),
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

}

/// Card plana SIN brillo/sombras
class _PlainCardShell extends StatelessWidget {
  final Widget child;
  final double height;
  final BorderRadius radius;
  final EdgeInsets padding;
  const _PlainCardShell({
    required this.child,
    required this.height,
    required this.radius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFEFF1F5)),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// ===============================
/// CONTENIDO DEL RECIBO (usa cfg)
/// ===============================
class _ReceiptContent extends StatelessWidget {
  final ReciboUIConfig cfg;

  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final String cliente;
  final String telefonoCliente;
  final String producto;
  final String numeroRecibo;
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

  const _ReceiptContent({
    super.key,
    required this.cfg,
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

  @override
  Widget build(BuildContext context) {
    Widget label(String t) => Text(t, style: cfg.labelStyle);
    Widget value(String t) => Text(t, style: cfg.valueStyle, overflow: TextOverflow.ellipsis, maxLines: 1);
    Widget valueStrong(String t) => Text(t, style: cfg.valueStrongStyle);
    Widget valueClient(String t) => Text(t, style: cfg.valueClientStyle);

    // Espacio fijo arriba (el logo es overlay independiente)
    const double fixedTopSpacer = 80;

    return Stack(
      children: [
        // === CONTENIDO DEL RECIBO ===
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: fixedTopSpacer),

            // Paloma
            Center(
              child: Container(
                width: cfg.checkCircleSize, height: cfg.checkCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: cfg.brandTeal, width: cfg.checkBorderWidth),
                ),
                child: Icon(Icons.check_rounded, size: cfg.checkIconSize, color: cfg.brandTeal),
              ),
            ),

            Padding(
              padding: cfg.titleMargin,
              child: Center(
                child: Text(
                  saldoActual == 0 ? 'Pago finalizado' : 'Pago recibido',
                  style: cfg.recibidoTitleStyle,
                ),
              ),
            ),

            // Panel del monto
            Container(
              decoration: BoxDecoration(
                borderRadius: cfg.amountPanelRadius,
                gradient: LinearGradient(
                  colors: cfg.amountPanelGradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: cfg.amountPanelBorder),
              ),
              padding: cfg.amountPanelPadding,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _MontoGrande(
                    texto: monedaRD(totalPagado),
                    prefixStyle: cfg.amountPrefixStyle,
                    numberStyle: cfg.amountNumberStyle,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ================== PANEL ÚNICO (como la foto) ==================
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cfg.line),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Servidor — Recibo/Fecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label('Nombre del servidor'),
                            const SizedBox(height: 4),
                            value(servidor),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Tel:',
                                  style: cfg.valueStyle.copyWith(
                                    fontSize: 16,          // un poquito más grande
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87, // buen contraste
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  telefonoServidor,
                                  style: cfg.valueStyle.copyWith(
                                    fontSize: 18,          // más grande que el label
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),

                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              //Text('Recibo: ', style: cfg.valueStyle.copyWith(fontWeight: FontWeight.w600)),
                              Text(numeroRecibo, style: cfg.valueStrongStyle),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            fmtFecha(fecha),
                            style: cfg.valueStyle.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Divider(height: 14, thickness: 1, color: cfg.line),

                  // Empresa
                  label('Nombre de la empresa'),
                  const SizedBox(height: 4),
                  value(empresa),

                  const SizedBox(height: 10),

                  // Banda mint con filas (profesional, sin duplicados)
                  Container(
                    decoration: BoxDecoration(
                      color: cfg.mint,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cfg.mintBorder),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      children: [
                        // 1) Monto adeudado (antes del pago) => saldoAnterior
                        _row('Monto adeudado', monedaRD(saldoAnterior)),
                        Divider(height: 14, thickness: 1, color: cfg.mintDivider),

                        // 2) Pago de interés
                        _row('Pago de interés', monedaRD(pagoInteres)),
                        Divider(height: 14, thickness: 1, color: cfg.mintDivider),

                        // 3) Pago a capital
                        _row('Pago a capital', monedaRD(pagoCapital)),

                        // 4-5) Solo si queda deuda
                        if (saldoActual > 0) ...[
                          Divider(height: 14, thickness: 1, color: cfg.mintDivider),
                          _row('Saldo pendiente actual', monedaRD(saldoActual)),
                          Divider(height: 14, thickness: 1, color: cfg.mintDivider),
                          _row('Próxima fecha', fmtFecha(proximaFecha)),
                        ],

                        // 6) Producto (dentro de la banda) — solo si viene
                        if (producto.trim().isNotEmpty) ...[
                          Divider(height: 14, thickness: 1, color: cfg.mintDivider),
                          _row('Producto', producto),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  Divider(height: 14, thickness: 1, color: cfg.line),

                  // Cliente (queda dentro del mismo cuadro)
                  Row(
                    children: [
                      label('Cliente'),
                      const Spacer(),
                      valueClient(cliente),
                    ],
                  ),
                ],
              ),
            ),
            // ================== / PANEL ÚNICO ==================
          ],
        ),

        // === LOGO (overlay INDEPENDIENTE) ===
        Positioned(
          top: cfg.brandLogoTop,
          left: 0,
          right: 20,
          child: Transform.translate(
            offset: Offset(cfg.brandLogoDx, 0),
            child: Center(
              child: Image.asset(
                cfg.brandLogoAsset,
                height: cfg.brandLogoHeight, // cambia tamaño libremente: no empuja nada
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mintBlock({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cfg.mint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cfg.mintBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1) Divider(height: 14, thickness: 1, color: cfg.mintDivider),
          ],
        ],
      ),
    );
  }

  Widget _row(String t, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(t, style: cfg.valueStyle.copyWith(fontWeight: FontWeight.w600))),
          const SizedBox(width: 10),
          Text(v, style: cfg.valueStrongStyle),
        ],
      ),
    );
  }
}

/// ===== Monto grande “RD$ 8.800” =====
class _MontoGrande extends StatelessWidget {
  final String texto; // "RD$8.800" o "RD$ 8.800"
  final TextStyle prefixStyle;
  final TextStyle numberStyle;

  const _MontoGrande({
    super.key,
    required this.texto,
    required this.prefixStyle,
    required this.numberStyle,
  });

  @override
  Widget build(BuildContext context) {
    final s = texto.trim();
    String pref = 'RD\$';
    String num = s;
    if (s.startsWith('RD\$')) {
      num = s.substring(3).trimLeft();
    } else {
      final parts = s.split(' ');
      if (parts.length >= 2) {
        pref = parts.first;
        num = parts.sublist(1).join(' ');
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(pref, style: prefixStyle),
        const SizedBox(width: 6),
        Text(num, style: numberStyle),
      ],
    );
  }
}