import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:intl/intl.dart'; // ✅ intl
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:media_store_plus/media_store_plus.dart';

import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/app_frame.dart';

// 👇 Banner premium
import '../core/notifications_plus.dart';

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

  // Encabezado flotante
  final bool showHeaderTitle;
  final String headerTitle;
  final TextStyle headerTitleStyle;

  // Logo (overlay dentro de la tarjeta capturable)
  final String brandLogoAsset;
  final double brandLogoHeight;
  final double brandLogoTop;
  final double brandLogoDx;

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
  final TextStyle amountPrefixStyle; // “RD$ / $ / MX$ …”
  final TextStyle amountNumberStyle; // “8,800.00”

  // Paleta
  final Color navy;
  final Color label;
  final Color line;
  final Color brandTeal;

  // Mint blocks
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
    this.gradientBegin = Alignment.topCenter,
    this.gradientEnd = Alignment.bottomCenter,
    this.gradientColors = const [AppTheme.gradTop, AppTheme.gradBottom],

    // Capturable (recibo)
    this.cardHeight = 600,
    this.designWidth = 450,
    this.cardRadius = const BorderRadius.all(Radius.circular(20)),
    this.cardPadding = const EdgeInsets.fromLTRB(16, 16, 16, 16),

    // Header flotante
    this.showHeaderTitle = true,
    this.headerTitle = 'RECIBO',
    this.headerTitleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    ),

    // Logo (overlay)
    this.brandLogoAsset = 'assets/images/logoB.png',
    this.brandLogoHeight = 190,
    this.brandLogoTop = -60,
    this.brandLogoDx = 0,

    // Paloma
    this.checkCircleSize = 78,
    this.checkBorderWidth = 5,
    this.checkIconSize = 40,

    // Título
    this.recibidoTitleStyle = const TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w900,
      color: Color(0xFF0F172A),
      letterSpacing: 0.2,
    ),
    this.titleMargin = const EdgeInsets.only(top: 10, bottom: 12),

    // Monto
    this.amountPanelGradientColors = const [Color(0xFFF3FBF7), Color(0xFFEAF5F0)],
    this.amountPanelRadius = const BorderRadius.all(Radius.circular(18)),
    this.amountPanelPadding = const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    this.amountPanelBorder = const Color(0xFFDDE7E1),
    this.amountPrefixStyle = const TextStyle(
      fontSize: 60,
      fontWeight: FontWeight.w900,
      color: Color(0xFF10B981),
      height: 1.0,
      letterSpacing: 0.2,
    ),
    this.amountNumberStyle = const TextStyle(
      fontSize: 68,
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
      fontSize: 18,
      color: Color(0xFF667084),
      fontWeight: FontWeight.w600,
      letterSpacing: .1,
    ),
    this.valueStyle = const TextStyle(
      fontSize: 19,
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w800,
      letterSpacing: .1,
    ),
    this.valueStrongStyle = const TextStyle(
      fontSize: 20,
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w900,
      letterSpacing: .1,
    ),
    this.valueClientStyle = const TextStyle(
      fontSize: 21,
      color: Color(0xFF0F172A),
      fontWeight: FontWeight.w900,
      letterSpacing: .2,
    ),
    this.phoneStyle = const TextStyle(
      fontSize: 17,
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

/// Formatea según locale del dispositivo.
/// RD (_DO) → "RD$ 8,800" sin decimales; otros → símbolo local sin decimales.
String monedaLocal(int valor) {
  final locale = Platform.localeName; // ej: es_DO, es_CO, en_US, pt_BR...
  if (locale.toUpperCase().contains('_DO')) {
    return 'RD\$ ${NumberFormat("#,##0", "en_US").format(valor)}';
  }
  final symbol = NumberFormat.simpleCurrency(locale: locale).currencySymbol;
  final number = NumberFormat.currency(
    locale: locale,
    symbol: '',
    decimalDigits: 0,
  ).format(valor);
  return '$symbol $number';
}

/// 💵 Solo signo de peso + miles, SIN decimales (para filas)
String pesoSolo(int v) => '\$ ${NumberFormat("#,##0", "en_US").format(v)}';

/// =======================================
/// PANTALLA
/// =======================================
class ReciboScreen extends StatefulWidget {
  final int moraCobrada;
  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final String cliente;
  final String telefonoCliente;
  final String producto;
  final String? tipoProducto;   // 'vehiculo' | 'otro'
  final String? vehiculoTipo;   // 'carro' | 'guagua' | 'moto'
  final String numeroRecibo;
  final DateTime fecha;
  final int capitalInicial;
  final int pagoInteres;
  final int pagoCapital;
  final int totalPagado;
  final int saldoAnterior;

  final int saldoRestante; // 👈 AÑADIR ESTA LÍNEA

  final int saldoActual;
  final DateTime proximaFecha;

  final ReciboUIConfig config;
  final double tasaInteres;


  const ReciboScreen({
    super.key,
    required this.empresa,
    required this.servidor,
    required this.telefonoServidor,
    required this.cliente,
    required this.telefonoCliente,
    required this.numeroRecibo,
    required this.producto,
    this.tipoProducto,
    this.vehiculoTipo,

    required this.fecha,
    required this.capitalInicial,
    required this.pagoInteres,
    required this.pagoCapital,
    required this.totalPagado,
    required this.saldoAnterior,
    required this.saldoRestante, // 👈 AÑADIR AQUÍ
    required this.saldoActual,
    required this.proximaFecha,
    this.config = const ReciboUIConfig(),
    required this.tasaInteres,
    this.moraCobrada = 0,
  });

  @override
  State<ReciboScreen> createState() => _ReciboScreenState();
}

class _ReciboScreenState extends State<ReciboScreen> {
  final GlobalKey _captureKey = GlobalKey();

  DateTime? _lastBackPress;
  static const Duration _backWindow = Duration(seconds: 2);

  ReciboUIConfig get cfg => widget.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.saldoActual <= 0) {
        NotificationsPlus.trigger('deuda_finalizada');
      } else {
        NotificationsPlus.trigger('pago_ok');
      }
    });
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

  String _sanitizeToken(String s) {
    const src = 'áéíóúüñÁÉÍÓÚÜÑ';
    const rep = 'aeiouunAEIOUUN';
    var out = s.trim();
    for (int i = 0; i < src.length; i++) {
      out = out.replaceAll(src[i], rep[i]);
    }
    out = out.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return out;
  }

  String get _reciboFmt => _fmtNumReciboStr(widget.numeroRecibo);

  void _volverAClientes() {
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _compartirWhatsApp() async {
    try {
      final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();

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

      final clienteTok = _sanitizeToken(widget.cliente);
      final numeroTok = _sanitizeToken(_reciboFmt);
      final fileName = 'Recibo-$clienteTok-$numeroTok.pdf';

      final savedUri = await _guardarSilencioso(pdfBytes, fileName);
      if (mounted && savedUri != null) {
        _showModernSnackBar(
          icon: Icons.download_done_rounded,
          text: Platform.isAndroid ? 'Guardado en Descargas ✅' : 'Guardado en Documents ✅',
          bg: const Color(0xFF1F623A),
        );
      }

      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';
      await File(tempPath).writeAsBytes(pdfBytes, flush: true);

      _showModernSnackBar(
        icon: Icons.check_circle_rounded,
        text: 'Recibo listo para enviar 📄✅',
        bg: const Color(0xFF2563EB),
      );

      final caption = '📄 Recibo de pago N°: $_reciboFmt • Cliente: ${widget.cliente} • Fecha: ${_fmtFecha(widget.fecha)}';
      await Share.shareXFiles(
        [XFile(tempPath, mimeType: 'application/pdf')],
        text: caption,
        subject: 'Recibo $_reciboFmt',
      );
    } catch (e, st) {
      debugPrint('Error generando/compartiendo PDF: $e\n$st');
      try {
        final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
        final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return;
        final pngBytes = byteData.buffer.asUint8List();

        final caption = '📄 Recibo de pago N°: $_reciboFmt • Cliente: ${widget.cliente} • Fecha: ${_fmtFecha(widget.fecha)}';
        await Share.shareXFiles(
          [XFile.fromData(pngBytes, name: 'Recibo-${_sanitizeToken(widget.cliente)}-${_sanitizeToken(_reciboFmt)}.png', mimeType: 'image/png')],
          text: caption,
          subject: 'Recibo $_reciboFmt',
        );
      } catch (e2, st2) {
        debugPrint('Fallback PNG también falló: $e2\n$st2');
      }
    } finally {
      _volverAClientes();
    }
  }

  Future<String?> _guardarSilencioso(Uint8List bytes, String fileName) async {
    try {
      if (Platform.isAndroid) {
        final tempDir = await getTemporaryDirectory();
        final tmpPath = '${tempDir.path}/$fileName';
        final tmpFile = File(tmpPath);
        await tmpFile.writeAsBytes(bytes, flush: true);

        final ms = MediaStore();
        final savedUri = await ms.saveFile(
          tempFilePath: tmpPath,
          dirType: DirType.download,
          dirName: DirName.download,
        );
        return savedUri?.toString();
      } else if (Platform.isIOS) {
        final docs = await getApplicationDocumentsDirectory();
        final path = '${docs.path}/$fileName';
        await File(path).writeAsBytes(bytes, flush: true);
        return path;
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/$fileName';
        await File(path).writeAsBytes(bytes, flush: true);
        return path;
      }
    } catch (e, st) {
      debugPrint('Error guardando archivo: $e\n$st');
      return null;
    }
  }

  void _showBackBanner() {
    final messenger = ScaffoldMessenger.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 3),
        duration: _backWindow,
        content: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFE082),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 10)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Flexible(
                child: Text(
                  'Atrás otra vez para ir a Clientes',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
                ),
              ),
              SizedBox(width: 10),
              Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPress == null || now.difference(_lastBackPress!) > _backWindow) {
      _lastBackPress = now;
      _showBackBanner();
      return false;
    }
    _volverAClientes();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = this.cfg;
    final padding = MediaQuery.of(context).padding;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: AppGradientBackground(
          child: Stack(
            children: [
              // ===== CAPA CAPTURABLE: fondo + recibo centrado =====
              RepaintBoundary(
                key: _captureKey,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: cfg.gradientBegin,
                      end: cfg.gradientEnd,
                      colors: cfg.gradientColors,
                    ),
                  ),
                  child: Center(
                    child: _PlainCardShell(
                      radius: cfg.cardRadius,
                      height: cfg.cardHeight.clamp(520.0, 760.0),
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
                            tipoProducto: widget.tipoProducto,
                            vehiculoTipo: widget.vehiculoTipo,
                            numeroRecibo: _fmtNumReciboStr(widget.numeroRecibo),
                            fecha: widget.fecha,
                            capitalInicial: widget.capitalInicial,
                            pagoInteres: widget.pagoInteres,
                            pagoCapital: widget.pagoCapital,
                            totalPagado: widget.totalPagado,
                            saldoAnterior: widget.saldoAnterior,
                            saldoActual: widget.saldoActual,
                            saldoRestante: widget.saldoRestante,
                            proximaFecha: widget.proximaFecha,
                            fmtFecha: _fmtFecha,
                            tasaInteres: widget.tasaInteres,
                            moraCobrada: widget.moraCobrada, // 👈 NUEVO
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ===== TÍTULO flotante (NO capturable) =====
              if (cfg.showHeaderTitle)
                Positioned(
                  top: padding.top + 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      cfg.headerTitle,
                      style: GoogleFonts.playfairDisplay(textStyle: cfg.headerTitleStyle),
                    ),
                  ),
                ),

              // ===== BOTÓN flotante (NO capturable) =====
              Positioned(
                left: 16,
                right: 16,
                bottom: padding.bottom + 16,
                child: ElevatedButton.icon(
                  icon: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Image.asset('assets/images/logo_whatsapp.png', fit: BoxFit.contain),
                    ),
                  ),
                  label: const Text('Enviar recibo por WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cfg.btnPdf,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _compartirWhatsApp,
                ),
              ),
            ],
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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

/// Card plana SIN sombras
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
      constraints: const BoxConstraints(minHeight: 650), // fuerza altura mínima
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: const Color(0xFFEFF1F5)),
      ),
      child: ClipRRect(borderRadius: radius, child: Padding(padding: padding, child: child)),
    );
  }
}

/// ===============================
/// WIDGET: MONTO GRANDE (prefijo + número con estilos)
/// ===============================
class MontoGrande extends StatelessWidget {
  final String texto;
  final TextStyle prefixStyle;
  final TextStyle numberStyle;
  const MontoGrande({
    super.key,
    required this.texto,
    required this.prefixStyle,
    required this.numberStyle,
  });

  bool _isDigit(int code) => code >= 48 && code <= 57;

  @override
  Widget build(BuildContext context) {
    final s = texto.trim();
    int idx = 0;
    for (; idx < s.length; idx++) {
      final c = s.codeUnitAt(idx);
      if (_isDigit(c)) break;
    }
    final prefix = s.substring(0, idx);
    final number = s.substring(idx);

    return Text.rich(
      TextSpan(children: [
        if (prefix.isNotEmpty) TextSpan(text: prefix, style: prefixStyle),
        TextSpan(text: number, style: numberStyle),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// ===============================
/// CONTENIDO DEL RECIBO (usa cfg)
/// ===============================
class _ReceiptContent extends StatelessWidget {
  final ReciboUIConfig cfg;
  final int moraCobrada; // 👈 NUEVO
  final double tasaInteres;

  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final String cliente;
  final String telefonoCliente;
  final String producto;
  final String? tipoProducto; // 👈 nuevo
  final String? vehiculoTipo; // 👈 nuevo

  final String numeroRecibo;
  final DateTime fecha;
  final int capitalInicial;
  final int pagoInteres;
  final int pagoCapital;
  final int totalPagado;
  final int saldoAnterior;
  final int saldoRestante; // 👈 AÑADIR
  final int saldoActual;
  final DateTime proximaFecha;

  final String Function(DateTime) fmtFecha;

  const _ReceiptContent({
    super.key,
    required this.cfg,
    required this.empresa,
    required this.servidor,
    required this.telefonoServidor,
    required this.cliente,
    required this.telefonoCliente,
    required this.producto,
    this.tipoProducto, // 👈 nuevo
    this.vehiculoTipo, // 👈 nuevo
    required this.numeroRecibo,
    required this.fecha,
    required this.capitalInicial,
    required this.pagoInteres,
    required this.pagoCapital,
    required this.totalPagado,
    required this.saldoAnterior,
    required this.saldoRestante, // 👈 AÑADIR
    required this.saldoActual,
    required this.proximaFecha,
    required this.fmtFecha,
    required this.tasaInteres,
    this.moraCobrada = 0, // 👈 NUEVO
  });

  @override
  Widget build(BuildContext context) {
    // ===== Detectar tipo correctamente por el texto del producto =====
    final t = producto.toLowerCase().trim();
    final bool esPrestamo = t.isEmpty ||
        t.contains('prest') ||
        t.contains('crédito') ||
        t.contains('credito') ||
        t.contains('loan');

    final bool esArriendo = t.contains('arriendo') ||
        t.contains('alquiler') ||
        t.contains('renta') ||
        t.contains('apartamento') ||
        t.contains('casa');

    // Todo lo que no sea préstamo ni arriendo => producto
    final bool esProducto = !esPrestamo && !esArriendo;

    // 👇 DETECCIÓN DE VEHÍCULO
    final bool esVehiculo =
        (tipoProducto?.toLowerCase().trim() == 'vehiculo') ||
            ((vehiculoTipo
                ?.trim()
                .isNotEmpty ?? false)) ||
            RegExp(r'\b(carro|auto|moto|motocicleta|guagua|bus)\b',
                caseSensitive: false)
                .hasMatch(producto.toLowerCase());

    String vehiculoEtiqueta = (vehiculoTipo ?? '').trim();
    if (vehiculoEtiqueta.isEmpty) {
      // Si no vino vehiculoTipo, intenta deducirlo del texto del producto
      final p = producto.toLowerCase();
      if (p.contains('moto') || p.contains('motocicleta')) {
        vehiculoEtiqueta = 'moto';
      } else if (p.contains('guagua') || p.contains('bus')) {
        vehiculoEtiqueta = 'guagua';
      } else if (p.contains('carro') || p.contains('auto')) {
        vehiculoEtiqueta = 'carro';
      }
    }

    // 👇 SELECCIONA ICONO SEGÚN TIPO
    IconData _vehIcon(String s) {
      switch (s.toLowerCase()) {
        case 'moto':
        case 'motocicleta':
          return Icons.two_wheeler_rounded;
        case 'guagua':
        case 'bus':
          return Icons.directions_bus_rounded;
        default:
          return Icons.directions_car_rounded;
      }
    }

    Widget label(String t) => Text(t, style: cfg.labelStyle);
    Widget value(String t) =>
        Text(t, style: cfg.valueStyle,
            overflow: TextOverflow.ellipsis,
            maxLines: 1);
    Widget valueStrong(String t) => Text(t, style: cfg.valueStrongStyle);
    Widget valueClient(String t) => Text(t, style: cfg.valueClientStyle);

    const double fixedTopSpacer = 80;

    final bool pagoFinalizado = saldoActual == 0;

    // Títulos bonitos según tipo
    String tituloPrincipal;
    if (esArriendo && pagoFinalizado) {
      tituloPrincipal = 'Arriendo saldado';
    } else if (esArriendo && !pagoFinalizado) {
      tituloPrincipal = 'Pago de arriendo recibido';
    } else if (esProducto && !pagoFinalizado) {
      tituloPrincipal = 'Pago de producto recibido';
    } else if (esProducto && pagoFinalizado) {
      tituloPrincipal = 'Producto pagado por completo';
    } else if (pagoFinalizado) {
      tituloPrincipal = 'Préstamo saldado';
    } else {
      tituloPrincipal = 'Pago recibido';
    }

    // Interés solo se usa/enseña para PRÉSTAMO
    final int proximoInteres = (saldoActual * (tasaInteres / 100)).round();
    final int saldoProximoPago = !pagoFinalizado ? (saldoActual +
        proximoInteres) : 0;

    // ===== Helper fila con ícono =====
    Widget _rowIcon(IconData icon, String t, String v,
        {Color? iconBg, Color? iconColor}) {
      final bg = iconBg ?? const Color(0xFFEFF6FF);
      final ic = iconColor ?? const Color(0xFF2563EB);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDCE7FF)),
              ),
              child: Icon(icon, size: 16, color: ic),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t,
                  style: cfg.valueStyle.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            Text(v, style: cfg.valueStrongStyle),
          ],
        ),
      );
    }

    // ===== CONTENIDO COMPLETO =====
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: fixedTopSpacer),

            // ✔ Paloma
            Center(
              child: Container(
                width: cfg.checkCircleSize,
                height: cfg.checkCircleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: cfg.brandTeal, width: cfg.checkBorderWidth),
                ),
                child: Icon(Icons.check_rounded, size: cfg.checkIconSize,
                    color: cfg.brandTeal),
              ),
            ),

            // ✔ Título
            Padding(
              padding: cfg.titleMargin,
              child: Center(
                  child: Text(tituloPrincipal, style: cfg.recibidoTitleStyle)),
            ),

            // ✔ MONTO GRANDE
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
                  child: MontoGrande(
                    texto: monedaLocal(totalPagado),
                    prefixStyle: cfg.amountPrefixStyle,
                    numberStyle: cfg.amountNumberStyle,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ✔ CABECERA DATOS
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Empresa / Servidor
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            label('Nombre de la empresa'),
                            const SizedBox(height: 4),
                            value(empresa),
                            const SizedBox(height: 10),

                            label('Nombre del servidor'),
                            const SizedBox(height: 4),
                            value(servidor),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Tel:',
                                  style: cfg.valueStyle.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  telefonoServidor,
                                  style: cfg.valueStyle.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Recibo / Fecha
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(numeroRecibo, style: cfg.valueStrongStyle)
                          ]),
                          const SizedBox(height: 4),
                          Text(fmtFecha(fecha), style: cfg.valueStyle.copyWith(
                              fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Divider(height: 14, thickness: 1, color: cfg.line),

                  // Cliente
                  label('Cliente'),
                  const SizedBox(height: 4),
                  valueClient(cliente),

                  const SizedBox(height: 10),

                  // ===== BLOQUE DE PAGO SEGÚN TIPO =====
                  Builder(
                    builder: (context) {
                      // Texto base para detección (seguro si 'producto' viene null)
                      final String t = (producto ?? '').toLowerCase();

                      // Vehículo: deducido por tipo o por palabras clave
                      final bool esVehiculoLocal =
                          (tipoProducto?.toLowerCase() == 'vehiculo') ||
                              (vehiculoTipo != null && vehiculoTipo!.trim()
                                  .isNotEmpty) ||
                              t.contains('carro') ||
                              t.contains('moto') ||
                              t.contains('guagua') ||
                              t.contains('bus') ||
                              t.contains('vehiculo');

                      // Etiqueta visible del vehículo
                      String vehiculoEtiquetaLocal() {
                        final s = (vehiculoTipo ?? '').trim().toLowerCase();
                        if (s.isNotEmpty) return s;
                        if (t.contains('moto')) return 'moto';
                        if (t.contains('guagua') || t.contains('bus'))
                          return 'guagua';
                        if (t.contains('carro') || t.contains('auto') ||
                            t.contains('coche')) return 'carro';
                        return '';
                      }

                      // Ícono según el tipo
                      IconData vehIcon(String v) {
                        switch (v.toLowerCase()) {
                          case 'moto':
                            return Icons.two_wheeler_rounded;
                          case 'guagua':
                          case 'bus':
                            return Icons.directions_bus_filled_rounded;
                          default:
                            return Icons.directions_car_rounded;
                        }
                      }

                      final String vEt = vehiculoEtiquetaLocal();

                      return Container(
                        constraints: const BoxConstraints(minHeight: 240),
                        decoration: BoxDecoration(
                          color: cfg.mint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cfg.mintBorder),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 18),
                        child: pagoFinalizado
                            ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_rounded, color: cfg.brandTeal,
                                size: 32),
                            const SizedBox(height: 8),
                            Text(
                              esArriendo
                                  ? 'Arriendo saldado'
                                  : esProducto
                                  ? 'Producto pagado por completo'
                                  : 'Préstamo saldado',
                              style: cfg.valueStrongStyle.copyWith(
                                  fontSize: 20),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),

                            // === MONTO PAGADO ===
                            const SizedBox(height: 6),
                            _rowIcon(
                              Icons.attach_money_rounded,
                              esArriendo
                                  ? 'Pago de arriendo'
                                  : (esProducto
                                  ? 'Pago de producto'
                                  : 'Pago realizado'),
                              pesoSolo(totalPagado),
                              iconBg: const Color(0xFFFFF7ED),
                              iconColor: const Color(0xFFB45309),
                            ),

                            // 👉 Producto / Vehículo (solo si es producto)
                            if (esProducto && (producto
                                .trim()
                                .isNotEmpty)) ...[
                              const SizedBox(height: 6),
                              _rowIcon(
                                esVehiculoLocal ? vehIcon(vEt) : Icons
                                    .shopping_bag_rounded,
                                esVehiculoLocal ? 'Vehículo' : 'Producto',
                                esVehiculoLocal ? (vEt.isEmpty
                                    ? 'vehículo'
                                    : vEt) : producto,
                                iconBg: esVehiculoLocal ? const Color(
                                    0xFFEFF6FF) : const Color(0xFFF3F0FF),
                                iconColor: esVehiculoLocal ? const Color(
                                    0xFF2563EB) : const Color(0xFF6D28D9),
                              ),
                            ],

                            // 👉 Mora (si aplica)
                            if (moraCobrada > 0) ...[
                              const SizedBox(height: 6),
                              _rowIcon(
                                Icons.local_fire_department_rounded,
                                'Mora cobrada',
                                pesoSolo(moraCobrada),
                                iconBg: const Color(0xFFFFEBEE),
                                iconColor: const Color(0xFFE11D48),
                              ),
                            ],

                            const SizedBox(height: 50),
                            Text(
                              esArriendo
                                  ? 'Gracias por ponerte al día con tu alquiler.'
                                  : esProducto
                                  ? (saldoRestante > 0
                                  ? 'Gracias por tu compra. Nos vemos en el próximo pago.'
                                  : '¡Disfruta tu compra! No quedan pagos pendientes.')
                                  : 'No quedan pagos pendientes.',
                              style: cfg.labelStyle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                            : Column(
                          children: [
                            // ====== ARRIENDO / ALQUILER ======
                            if (esArriendo) ...[
                              _rowIcon(
                                Icons.home_rounded,
                                'Pago mensual de arriendo',
                                pesoSolo(totalPagado),
                                iconBg: const Color(0xFFFFFAE6),
                                iconColor: const Color(0xFF92400E),
                              ),

                              if (moraCobrada > 0) ...[
                                const SizedBox(height: 6),
                                _rowIcon(
                                  Icons.local_fire_department_rounded,
                                  'Mora cobrada',
                                  pesoSolo(moraCobrada),
                                  iconBg: const Color(0xFFFFEBEE),
                                  iconColor: const Color(0xFFE11D48),
                                ),
                              ],

                              Divider(height: 14,
                                  thickness: 1,
                                  color: cfg.mintDivider),
                              _rowIcon(
                                Icons.request_quote_rounded,
                                'Saldo restante',
                                pesoSolo(saldoActual),
                                iconBg: const Color(0xFFEFF6FF),
                                iconColor: const Color(0xFF2563EB),
                              ),
                            ]

                            // ====== PRODUCTO ======
                            else
                              if (esProducto) ...[
                                _rowIcon(
                                  Icons.shopping_bag_rounded,
                                  'Pago mensual de producto',
                                  pesoSolo(totalPagado),
                                  iconBg: const Color(0xFFF3F0FF),
                                  iconColor: const Color(0xFF6D28D9),
                                ),

                                if (moraCobrada > 0) ...[
                                  const SizedBox(height: 6),
                                  _rowIcon(
                                    Icons.local_fire_department_rounded,
                                    'Mora cobrada',
                                    pesoSolo(moraCobrada),
                                    iconBg: const Color(0xFFFFEBEE),
                                    iconColor: const Color(0xFFE11D48),
                                  ),
                                ],

                                Divider(height: 14,
                                    thickness: 1,
                                    color: cfg.mintDivider),
                                _rowIcon(
                                  Icons.request_quote_rounded,
                                  'Saldo restante',
                                  pesoSolo(saldoActual),
                                  iconBg: const Color(0xFFEFF6FF),
                                  iconColor: const Color(0xFF2563EB),
                                ),

                                // 👉 Producto / Vehículo ARRIBA del texto
                                Divider(height: 14,
                                    thickness: 1,
                                    color: cfg.mintDivider),
                                _rowIcon(
                                  esVehiculoLocal ? vehIcon(vEt) : Icons
                                      .shopping_bag_rounded,
                                  esVehiculoLocal ? 'Vehículo' : 'Producto',
                                  esVehiculoLocal ? (vEt.isEmpty
                                      ? 'vehículo'
                                      : vEt) : producto,
                                  iconBg: esVehiculoLocal ? const Color(
                                      0xFFEFF6FF) : const Color(0xFFF3F0FF),
                                  iconColor: esVehiculoLocal ? const Color(
                                      0xFF2563EB) : const Color(0xFF6D28D9),
                                ),

                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'Gracias por tu compra. Nos vemos en el próximo pago.',
                                    style: cfg.labelStyle,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ]

                              // ====== PRÉSTAMO ======
                              else
                                ...[
                                  _rowIcon(
                                    Icons.account_balance_wallet_rounded,
                                    'Monto adeudado',
                                    pesoSolo(saldoAnterior),
                                    iconBg: const Color(0xFFF2F6FD),
                                    iconColor: const Color(0xFF2563EB),
                                  ),
                                  Divider(height: 14,
                                      thickness: 1,
                                      color: cfg.mintDivider),
                                  _rowIcon(
                                    Icons.trending_up_rounded,
                                    'Pago de interés',
                                    pesoSolo(pagoInteres),
                                    iconBg: const Color(0xFFEFFAF4),
                                    iconColor: const Color(0xFF22C55E),
                                  ),
                                  Divider(height: 14,
                                      thickness: 1,
                                      color: cfg.mintDivider),
                                  _rowIcon(
                                    Icons.savings_rounded,
                                    'Pago a capital',
                                    pesoSolo(pagoCapital),
                                    iconBg: const Color(0xFFFFF2F6),
                                    iconColor: const Color(0xFFE11D48),
                                  ),
                                  if (saldoActual > 0) ...[
                                    Divider(height: 14,
                                        thickness: 1,
                                        color: cfg.mintDivider),
                                    _rowIcon(
                                      Icons.request_quote_rounded,
                                      'Próximo pago',
                                      pesoSolo(saldoProximoPago),
                                      iconBg: const Color(0xFFFFFAE6),
                                      iconColor: const Color(0xFF92400E),
                                    ),
                                    Divider(height: 14,
                                        thickness: 1,
                                        color: cfg.mintDivider),
                                    _rowIcon(
                                      Icons.event_rounded,
                                      'Próxima fecha',
                                      fmtFecha(proximaFecha),
                                      iconBg: const Color(0xFFEFF6FF),
                                      iconColor: const Color(0xFF2563EB),
                                    ),
                                  ],
                                ],
                          ],
                        ),
                      );
                    },
                  ),

                  // ====== LÍNEA “TIPO/DETALLE” ======
                  if (!esProducto && producto
                      .trim()
                      .isNotEmpty) ...[
                    Divider(height: 14, thickness: 1, color: cfg.mintDivider),
                    _rowIcon(
                      esArriendo ? Icons.home_work_rounded : (esProducto ? Icons
                          .shopping_bag_rounded : Icons.description_rounded),
                      esArriendo ? 'Arriendo' : (esProducto
                          ? 'Producto'
                          : 'Detalle'),
                      producto,
                      iconBg: esArriendo ? const Color(0xFFFFF7ED) : (esProducto
                          ? const Color(0xFFF3F0FF)
                          : const Color(0xFFF2F6FD)),
                      iconColor: esArriendo
                          ? const Color(0xFFB45309)
                          : (esProducto ? const Color(0xFF6D28D9) : const Color(
                          0xFF2563EB)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // LOGO OVERLAY
        Positioned(
          top: cfg.brandLogoTop,
          left: 0,
          right: 20,
          child: Transform.translate(
            offset: Offset(cfg.brandLogoDx, 0),
            child: Center(
              child: Image.asset(
                cfg.brandLogoAsset,
                height: cfg.brandLogoHeight,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }
}