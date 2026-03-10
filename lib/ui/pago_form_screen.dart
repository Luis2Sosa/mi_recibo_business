import 'dart:io';
import 'dart:ui' show FontFeature, ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PagoFormScreen extends StatefulWidget {
  final int saldoAnterior;
  final double tasaInteres;
  final String periodo;
  final DateTime proximaFecha;
  final bool esPrestamo;
  final String nombreCliente;
  final String producto;
  final int moraActual;
  final bool autoFecha;
  final List<dynamic> productosLista;

  const PagoFormScreen({
    super.key,
    required this.saldoAnterior,
    required this.tasaInteres,
    required this.periodo,
    required this.proximaFecha,
    this.esPrestamo = true,
    this.nombreCliente = '',
    this.producto = '',
    this.moraActual = 0,
    this.autoFecha = true,
    this.productosLista = const [],
  });

  @override
  State<PagoFormScreen> createState() => _PagoFormScreenState();
}

class _PagoFormScreenState extends State<PagoFormScreen> {
  final _interesCtrl = TextEditingController();
  final _capitalCtrl = TextEditingController();

  DateTime? _proxima;
  late DateTime _baseProximaLocal;
  int _pagoInteres = 0;
  int _pagoCapital = 0;
  bool _btnContinuarBusy = false;

  // ─── Getters de tipo ─────────────────────────────────────────────────────
  bool get _esAlquiler => _esArriendoDesdeTexto(widget.producto);
  bool get _esProducto => !widget.esPrestamo && !_esAlquiler;

  bool _esArriendoDesdeTexto(String? p) {
    if (p == null) return false;
    final t = p.toLowerCase().trim();
    return t.contains('alquiler') ||
        t.contains('arriendo') ||
        t.contains('renta') ||
        t.contains('casa') ||
        t.contains('apartamento');
  }

  // ─── Cálculos ────────────────────────────────────────────────────────────
  int get _interesMax => widget.esPrestamo
      ? (widget.saldoAnterior * (widget.tasaInteres / 100)).round()
      : 0;

  int get _totalPagado => _pagoCapital;

  int get _saldoNuevo {
    if (widget.esPrestamo) {
      final abonoCapital = _pagoCapital - _pagoInteres;
      final nuevo = widget.saldoAnterior - (abonoCapital > 0 ? abonoCapital : 0);
      return nuevo < 0 ? 0 : nuevo;
    } else {
      final nuevo = widget.saldoAnterior - _pagoCapital;
      return nuevo < 0 ? 0 : nuevo;
    }
  }

  int get _abonoCapitalReal {
    if (!widget.esPrestamo) return _pagoCapital;
    final abono = _pagoCapital - _pagoInteres;
    return abono > 0 ? abono : 0;
  }

  // ─── Validaciones ────────────────────────────────────────────────────────
  String? get _errorInteres {
    if (!widget.esPrestamo) return null;
    if (_pagoInteres < 0) return 'No puede ser negativo';
    if (_pagoInteres > _interesMax) return 'Máximo ${_fmt(_interesMax)}';
    return null;
  }

  String? get _errorCapital {
    if (_pagoCapital <= 0) return 'Ingresa un monto mayor a 0';
    final montoMax = widget.esPrestamo
        ? widget.saldoAnterior + _pagoInteres
        : widget.saldoAnterior;
    if (_pagoCapital > montoMax) return 'Máximo ${_fmt(montoMax)}';
    return null;
  }

  bool get _formOk =>
      _errorInteres == null &&
          _errorCapital == null &&
          (widget.autoFecha || _proxima != null);

  // ─── Formato ─────────────────────────────────────────────────────────────
  String _fmt(int v) => NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  ).format(v);

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  DateTime _addOneMonthSameDay(DateTime d) {
    final nextMonth = DateTime(d.year, d.month + 1, 1);
    final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final day = d.day.clamp(1, lastDay);
    return DateTime(nextMonth.year, nextMonth.month, day, 12);
  }

  DateTime _calcNextDate(DateTime base) {
    if (_esAlquiler) return _addOneMonthSameDay(base);
    final deltaDias = widget.periodo.toLowerCase().contains('quin') ||
        widget.periodo.toLowerCase().contains('15')
        ? 15
        : 30;
    return _atNoon(base.add(Duration(days: deltaDias)));
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _baseProximaLocal = _atNoon(widget.proximaFecha.toLocal());
    _proxima = null;

    if (widget.esPrestamo) {
      _interesCtrl.text = _interesMax.toString();
      _pagoInteres = _interesMax;
    } else {
      _interesCtrl.text = '0';
      _pagoInteres = 0;
    }

    if (_esAlquiler) {
      _capitalCtrl.text = widget.saldoAnterior.toString();
      _pagoCapital = widget.saldoAnterior;
    }

    _interesCtrl.addListener(_recalcular);
    _capitalCtrl.addListener(_recalcular);
  }

  void _recalcular() {
    setState(() {
      _pagoInteres = widget.esPrestamo
          ? (int.tryParse(
          _interesCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
          0)
          : 0;
      _pagoCapital =
          int.tryParse(_capitalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
              0;
    });
  }

  @override
  void dispose() {
    _interesCtrl.dispose();
    _capitalCtrl.dispose();
    super.dispose();
  }

  // ─── Conexión ────────────────────────────────────────────────────────────
  Future<bool> _verificarConexion() async {
    try {
      final result = await Connectivity().checkConnectivity();
      if (result == ConnectivityResult.none) return false;
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _mostrarSinConexion() {
    if (!mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        final curvedVal = Curves.easeOutBack.transform(anim1.value) - 1.0;
        return Transform.translate(
          offset: Offset(0, curvedVal * -60),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(colors: [
                      Colors.white.withOpacity(0.15),
                      Colors.white.withOpacity(0.05),
                    ]),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1.3),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 30,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [
                                Color(0xFF2458D6),
                                Color(0xFF0A9A76)
                              ]),
                            ),
                            padding: const EdgeInsets.all(14),
                            child: const Icon(Icons.wifi_off_rounded,
                                color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Sin conexión a internet',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Conéctate para registrar el pago.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 14,
                              height: 1.3,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    });
  }

  // ─── Confirmar ───────────────────────────────────────────────────────────
  Future<void> _confirmar() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() => _btnContinuarBusy = true);

    final conectado = await _verificarConexion();
    if (!conectado) {
      _mostrarSinConexion();
      if (mounted) setState(() => _btnContinuarBusy = false);
      return;
    }

    final DateTime proximaOut =
    widget.autoFecha ? _calcNextDate(_baseProximaLocal) : _proxima!;

    Navigator.pop(context, {
      'pagoInteres': widget.esPrestamo ? _pagoInteres : 0,
      'pagoCapital': _pagoCapital,
      'totalPagado': _totalPagado,
      'moraCobrada':
      (!widget.esPrestamo && widget.moraActual > 0) ? widget.moraActual : 0,
      'saldoAnterior': widget.saldoAnterior,
      'saldoNuevo': _saldoNuevo,
      'proximaFecha': proximaOut,
    });

    if (mounted) setState(() => _btnContinuarBusy = false);
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenW = mq.size.width;
    final screenH = mq.size.height;
    final kb = mq.viewInsets.bottom;
    final botPad = mq.padding.bottom;
    final bool tecladoAbierto = kb > 0.0;

    final double baseFontSize = (screenW * 0.038).clamp(13.0, 15.5);
    final double titleFontSize = (screenW * 0.062).clamp(20.0, 26.0);
    final double btnFontSize = (screenW * 0.04).clamp(14.0, 16.0);
    final double hPad = (screenW * 0.04).clamp(12.0, 22.0);
    final double btnHeight = (screenH * 0.066).clamp(48.0, 56.0);

    // Colores por tipo
    final List<Color> gradiente;
    final Color borde;
    final Color colorTexto;
    final String tipoLabel;

    if (widget.esPrestamo) {
      gradiente = [const Color(0xFFBBDEFB), const Color(0xFF64B5F6)];
      borde = const Color(0xFF1E3A8A);
      colorTexto = const Color(0xFF0D47A1);
      tipoLabel = 'Préstamo';
    } else if (_esAlquiler) {
      gradiente = [const Color(0xFFFFE0B2), const Color(0xFFFFB74D)];
      borde = const Color(0xFFFF9800);
      colorTexto = const Color(0xFF4E342E);
      tipoLabel = 'Alquiler';
    } else {
      gradiente = [const Color(0xFFC8E6C9), const Color(0xFF81C784)];
      borde = const Color(0xFF2E7D32);
      colorTexto = const Color(0xFF065F46);
      tipoLabel = 'Producto';
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Título: altura fija proporcional, desaparece con teclado ──
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                height: tecladoAbierto
                    ? 0
                    : (screenH * 0.09).clamp(52.0, 76.0),
                child: AnimatedOpacity(
                  opacity: tecladoAbierto ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  child: Center(
                    child: Text(
                      'Registrar Pago',
                      style: GoogleFonts.playfairDisplay(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 0.4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Tarjeta: ocupa TODO el espacio restante ────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPad,
                    0,
                    hPad,
                    botPad > 0 ? botPad : 12,
                  ),
                  // LayoutBuilder mide el espacio exacto disponible
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableH = constraints.maxHeight;

                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        // ConstrainedBox fuerza altura mínima = espacio disponible
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: availableH,
                          ),
                          // IntrinsicHeight hace que la Column se estire hasta minHeight
                          child: IntrinsicHeight(
                            child: Container(
                              margin: const EdgeInsets.only(top: 6, bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                                border:
                                Border.all(color: const Color(0xFFE9EEF5)),
                              ),
                              padding: EdgeInsets.all(
                                  (screenW * 0.04).clamp(14.0, 20.0)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Badge cliente + tipo ───────────────
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: gradiente,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border:
                                      Border.all(color: borde, width: 1.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: borde.withOpacity(0.28),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            widget.nombreCliente.trim().isEmpty
                                                ? 'Cliente'
                                                : widget.nombreCliente,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: baseFontSize + 0.5,
                                              fontWeight: FontWeight.w800,
                                              color: colorTexto,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color:
                                            Colors.white.withOpacity(0.9),
                                            borderRadius:
                                            BorderRadius.circular(999),
                                            border:
                                            Border.all(color: borde),
                                          ),
                                          child: Text(
                                            tipoLabel,
                                            style: TextStyle(
                                              fontSize: baseFontSize - 0.5,
                                              fontWeight: FontWeight.w900,
                                              color: colorTexto,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // ── Pendiente ──────────────────────────
                                  _filaResumen(
                                    'Pendiente',
                                    _fmt(widget.saldoAnterior),
                                    baseFontSize,
                                    valorNegrita: true,
                                  ),

                                  // ── Mora ───────────────────────────────
                                  if (!widget.esPrestamo &&
                                      widget.moraActual > 0) ...[
                                    const SizedBox(height: 8),
                                    _filaResumen(
                                      'Mora vigente',
                                      _fmt(widget.moraActual),
                                      baseFontSize,
                                      valorColor: const Color(0xFFDC2626),
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  // ── Campos ─────────────────────────────
                                  if (widget.esPrestamo) ...[
                                    Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _campoValidado(
                                            label: 'Pago interés',
                                            controller: _interesCtrl,
                                            errorText: _errorInteres,
                                            fontSize: baseFontSize,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _campoValidado(
                                            label: 'Monto a pagar',
                                            controller: _capitalCtrl,
                                            errorText: _errorCapital,
                                            fontSize: baseFontSize,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Aviso interés no cubierto
                                    if (_pagoCapital > 0 &&
                                        _pagoCapital < _pagoInteres) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                          border: Border.all(
                                              color:
                                              const Color(0xFFFDE68A)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline,
                                                color: Color(0xFF92400E),
                                                size: 16),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                'El monto no cubre el interés completo. El saldo no bajará.',
                                                style: TextStyle(
                                                  fontSize: baseFontSize - 1,
                                                  color:
                                                  const Color(0xFF78350F),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ] else ...[
                                    _campoValidado(
                                      label: _esAlquiler
                                          ? 'Pago del alquiler'
                                          : 'Pago del producto',
                                      controller: _capitalCtrl,
                                      errorText: _errorCapital,
                                      fontSize: baseFontSize,
                                    ),
                                  ],

                                  const SizedBox(height: 14),

                                  // ── Tarjeta resumen ────────────────────
                                  _TarjetaResumen(
                                    esPrestamo: widget.esPrestamo,
                                    esAlquiler: _esAlquiler,
                                    fmt: _fmt,
                                    fmtFecha: _fmtFecha,
                                    totalPagado: _totalPagado,
                                    pagoInteres: _pagoInteres,
                                    abonoCapital: _abonoCapitalReal,
                                    saldoAnterior: widget.saldoAnterior,
                                    saldoNuevo: _saldoNuevo,
                                    moraActual: widget.moraActual,
                                    productosLista: widget.productosLista,
                                    producto: widget.producto,
                                    proximaFecha:
                                    _calcNextDate(_baseProximaLocal),
                                    baseFontSize: baseFontSize,
                                    borde: borde,
                                    colorTexto: colorTexto,
                                  ),

                                  // Spacer empuja el botón al fondo
                                  const Spacer(),

                                  const SizedBox(height: 16),

                                  // ── Botón continuar ────────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    height: btnHeight,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _formOk
                                            ? const Color(0xFF2563EB)
                                            : const Color(0xFF94A3B8),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: const StadiumBorder(),
                                        textStyle: TextStyle(
                                          fontSize: btnFontSize,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      onPressed: (_formOk && !_btnContinuarBusy)
                                          ? _confirmar
                                          : null,
                                      child: _btnContinuarBusy
                                          ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                          : const Text('Continuar'),
                                    ),
                                  ),

                                  SizedBox(height: botPad > 0 ? botPad : 4),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets auxiliares ──────────────────────────────────────────────────
  Widget _campoValidado({
    required String label,
    required TextEditingController controller,
    String? errorText,
    required double fontSize,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: false, signed: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: fontSize + 0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: const Color(0xFF6B7280), fontSize: fontSize - 0.5),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        errorText: errorText,
        errorStyle:
        const TextStyle(fontSize: 11.5, color: Color(0xFFEF4444)),
        errorMaxLines: 2,
      ),
    );
  }

  Widget _filaResumen(
      String label,
      String valor,
      double fontSize, {
        bool valorNegrita = false,
        Color? valorColor,
      }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: const Color(0xFF374151),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          valor,
          style: TextStyle(
            fontSize: fontSize + 0.5,
            fontWeight: valorNegrita ? FontWeight.w900 : FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: valorColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

// ─── Tarjeta resumen ─────────────────────────────────────────────────────────
class _TarjetaResumen extends StatelessWidget {
  final bool esPrestamo;
  final bool esAlquiler;
  final String Function(int) fmt;
  final String Function(DateTime) fmtFecha;
  final int totalPagado;
  final int pagoInteres;
  final int abonoCapital;
  final int saldoAnterior;
  final int saldoNuevo;
  final int moraActual;
  final List<dynamic> productosLista;
  final String producto;
  final DateTime proximaFecha;
  final double baseFontSize;
  final Color borde;
  final Color colorTexto;

  const _TarjetaResumen({
    required this.esPrestamo,
    required this.esAlquiler,
    required this.fmt,
    required this.fmtFecha,
    required this.totalPagado,
    required this.pagoInteres,
    required this.abonoCapital,
    required this.saldoAnterior,
    required this.saldoNuevo,
    required this.moraActual,
    required this.productosLista,
    required this.producto,
    required this.proximaFecha,
    required this.baseFontSize,
    required this.borde,
    required this.colorTexto,
  });

  Color get _accentColor => esPrestamo
      ? const Color(0xFF1565C0)
      : (esAlquiler ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32));

  Color get _borderColor => esPrestamo
      ? const Color(0xFF64B5F6)
      : (esAlquiler ? const Color(0xFFFFCC80) : const Color(0xFF81C784));

  Color get _shadowColor => esPrestamo
      ? const Color(0xFF1565C0)
      : (esAlquiler ? const Color(0xFFFF9800) : const Color(0xFF2E7D32));

  IconData get _icono => esPrestamo
      ? Icons.receipt_long_rounded
      : (esAlquiler ? Icons.home_work_rounded : Icons.shopping_bag_rounded);

  String get _titulo => esPrestamo
      ? 'Distribución del pago'
      : (esAlquiler ? 'Resumen del alquiler' : 'Resumen del producto');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _shadowColor.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Icon(_icono, color: _accentColor, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: baseFontSize + 0.5,
                    color: _accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Préstamo ──────────────────────────────────────────────────
          if (esPrestamo) ...[
            _fila('Monto entregado', fmt(totalPagado)),
            _fila('Interés cobrado', fmt(pagoInteres)),
            _fila('Abono a capital', fmt(abonoCapital)),
            const Divider(height: 14, color: Color(0xFFE5E7EB)),
            _fila('Saldo anterior', fmt(saldoAnterior)),
            _fila('Nuevo saldo', fmt(saldoNuevo),
                valorColor: const Color(0xFF16A34A)),
          ]

          // ── Alquiler ──────────────────────────────────────────────────
          else if (esAlquiler) ...[
            _fila('Monto entregado', fmt(totalPagado)),
            _fila(
              'Mes pagado',
              DateFormat('MMMM yyyy', 'es_ES')
                  .format(DateTime.now().toLocal())
                  .capitalize(),
            ),
            _fila('Próximo pago', fmtFecha(proximaFecha)),
          ]

          // ── Producto ──────────────────────────────────────────────────
          else ...[
              _fila('Monto entregado', fmt(totalPagado)),
              if (moraActual > 0)
                _fila('Mora cobrada', fmt(moraActual),
                    valorColor: const Color(0xFFDC2626)),
              if (productosLista.isNotEmpty)
                _fila(
                  'Productos',
                  productosLista
                      .map((p) =>
                  p is Map ? p['nombre'].toString() : p.toString())
                      .take(4)
                      .join(' / ')
                      .capitalize(),
                )
              else if (producto.isNotEmpty)
                _fila('Producto', producto.capitalize()),
              _fila('Próxima fecha', fmtFecha(proximaFecha)),
              const Divider(height: 14, color: Color(0xFFE5E7EB)),
              _fila('Saldo anterior', fmt(saldoAnterior)),
              _fila('Nuevo saldo', fmt(saldoNuevo),
                  valorColor: const Color(0xFF16A34A)),
            ],
        ],
      ),
    );
  }

  Widget _fila(String label, String valor, {Color? valorColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: TextStyle(
                fontSize: baseFontSize - 0.5,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 5,
            child: Text(
              valor,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: baseFontSize,
                fontWeight: FontWeight.w700,
                color: valorColor ?? const Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Extension ───────────────────────────────────────────────────────────────
extension StringCasing on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}