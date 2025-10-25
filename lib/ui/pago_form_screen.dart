import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // 🌍 formato de moneda automático

class PagoFormScreen extends StatefulWidget {
  final int saldoAnterior; // RD$
  final double tasaInteres; // %
  final String periodo; // Mensual | Quincenal
  final DateTime proximaFecha; // sugerida (solo referencia visual, no se usa automática)
  // ✅ NUEVO: true = es préstamo (muestra interés); false = producto/alquiler (sin interés)
  final bool esPrestamo;
  // ✅ OPCIONALES (para la barra premium). No rompen llamadas existentes.
  final String nombreCliente; // se muestra a la izquierda (puede ir vacío)
  final String producto; // texto libre para detectar arriendo o producto (puede ir vacío)
  // 👇 Monto de mora vigente al momento de cobrar (solo productos/alquiler)
  final int moraActual;
  final bool autoFecha; // 👈 NUEVO: controla si la fecha es automática

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
  });

  @override
  State<PagoFormScreen> createState() => _PagoFormScreenState();
}

class _PagoFormScreenState extends State<PagoFormScreen> {
  static const double _logoTop = -80;
  static const double _logoHeight = 350;

  final _interesCtrl = TextEditingController();
  final _capitalCtrl = TextEditingController();

  DateTime? _proxima;
  late DateTime _baseProximaLocal; // fecha base normalizada (local + 12:00)
  int _pagoInteres = 0;
  int _pagoCapital = 0;
  bool _btnContinuarBusy = false;

  int get _interesMax =>
      widget.esPrestamo ? (widget.saldoAnterior * (widget.tasaInteres / 100)).round() : 0;

  int get _totalPagado {
    final base = _pagoCapital + (widget.esPrestamo ? _pagoInteres : 0);
    // 👇 si no es préstamo (producto/alquiler), trata la mora como interés
    final moraComoInteres = (!widget.esPrestamo && widget.moraActual > 0) ? widget.moraActual : 0;
    return base + moraComoInteres;
  }

  int get _saldoNuevo {
    final n = widget.saldoAnterior - _pagoCapital;
    return n < 0 ? 0 : n;
  }

  // ✅ Interés del próximo pago: solo si es préstamo
  int get _interesProximo =>
      widget.esPrestamo ? (_saldoNuevo * (widget.tasaInteres / 100)).round() : 0;

  int get _saldoNuevoConInteres => _saldoNuevo + _interesProximo;

  @override
  void initState() {
    super.initState();
    _proxima = null;
    _baseProximaLocal = _atNoon(widget.proximaFecha.toLocal());

    if (widget.esPrestamo) {
      _interesCtrl.text = _interesMax.toString();
      _pagoInteres = _interesMax;
    } else {
      _interesCtrl.text = '0';
      _pagoInteres = 0;
    }

    // 🔹 Si es alquiler, llenar el campo automáticamente con el saldo pendiente
    if (!widget.esPrestamo && _esArriendoDesdeTexto(widget.producto)) {
      _capitalCtrl.text = widget.saldoAnterior.toString();
      _pagoCapital = widget.saldoAnterior;
    }


    _interesCtrl.addListener(_recalcular);
    _capitalCtrl.addListener(_recalcular);
  }

  void _recalcular() {
    setState(() {
      _pagoInteres = widget.esPrestamo
          ? int.tryParse(_interesCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
          : 0;
      _pagoCapital =
          int.tryParse(_capitalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    });
  }

  @override
  void dispose() {
    _interesCtrl.dispose();
    _capitalCtrl.dispose();
    super.dispose();
  }

  String? get _errorInteres {
    if (!widget.esPrestamo) return null;
    if (_pagoInteres < 0) return 'No puede ser negativo';
    if (_pagoInteres > _interesMax) {
      return 'Máximo ${_formatCurrency(_interesMax)}';
    }
    return null;
  }

  String? get _errorCapital {
    if (_pagoCapital <= 0) return 'Requerido: ingresa capital > 0';
    if (_pagoCapital > widget.saldoAnterior) {
      return 'Máximo ${_formatCurrency(widget.saldoAnterior)}';
    }
    return null;
  }

  bool get _formOk => _errorInteres == null && _errorCapital == null;

  /// 🌍 Formatea según la configuración regional del dispositivo automáticamente
  String _formatCurrency(int v) {
    final f = NumberFormat.currency(
      locale: Intl.getCurrentLocale(),
      symbol: NumberFormat.simpleCurrency(locale: Intl.getCurrentLocale()).currencySymbol,
      decimalDigits: 0,
    );
    return f.format(v);
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  /// Suma 1 mes conservando el “día” original cuando sea posible.
  /// Si el próximo mes no tiene ese día (ej. 31→febrero), cae al último día del mes.
  DateTime _addOneMonthSameDay(DateTime d) {
    final nextMonth = DateTime(d.year, d.month + 1, 1);
    final lastDayNextMonth = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
    final day = d.day.clamp(1, lastDayNextMonth);
    return DateTime(nextMonth.year, nextMonth.month, day, 12); // anclado a 12:00
  }

  /// ✅ Nuevo comportamiento real:
  /// - Arriendo → siempre +30 días desde la fecha guardada.
  /// - Producto → 15 o 30 días según periodo.
  /// - Préstamo → 15 o 30 días según periodo.
  /// Todo parte desde la fecha base (no desde hoy).
  DateTime _calcNextDate(DateTime base) {
    final esArriendo = _esArriendoDesdeTexto(widget.producto);

    int deltaDias;
    if (esArriendo) {
      deltaDias = 30;
    } else if (widget.esPrestamo) {
      deltaDias = widget.periodo.toLowerCase() == 'quincenal' ? 15 : 30;
    } else {
      deltaDias = widget.periodo.toLowerCase().contains('15') ||
          widget.periodo.toLowerCase().contains('quin')
          ? 15
          : 30;
    }

    // Suma desde la fecha base guardada (no desde hoy)
    final next = _atNoon(base.add(Duration(days: deltaDias)));
    return next;
  }

  // === Helper para detectar ARRIENDO por texto ===
  bool _esArriendoDesdeTexto(String? p) {
    if (p == null) return false;
    final t = p.toLowerCase().trim();
    if (t.isEmpty) return false;
    return t.contains('alquiler') ||
        t.contains('arriendo') ||
        t.contains('renta') ||
        t.contains('casa') ||
        t.contains('apartamento');
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final bool tecladoAbierto = kb > 0.0;

    print('[PagoFormScreen] base local: $_baseProximaLocal');

    final double baseDown = widget.esPrestamo ? 180.0 : 220.0;
    final double translateY = tecladoAbierto ? 1.0 : (baseDown + 20.0);

    final size = MediaQuery.of(context).size;
    final double usableH = size.height - (tecladoAbierto ? kb : 0.0) - 8.0;
    final double maxCardH = tecladoAbierto ? 500.0 : 580.0;
    final double availableHeight = usableH.clamp(260.0, maxCardH);
    final double adjustedHeight =
    widget.esPrestamo ? availableHeight + 30.0 : availableHeight;
    final double bottomPad = tecladoAbierto ? 12.0 : 0.0;

    final scrollPhysics = tecladoAbierto
        ? const ClampingScrollPhysics()
        : const NeverScrollableScrollPhysics();

    final double extraBottomSafe = 0.0;

    final glassWhite = Colors.white.withOpacity(0.12);
    final esArriendo = _esArriendoDesdeTexto(widget.producto);
    final String tipoLabel =
    widget.esPrestamo ? 'Préstamo' : (esArriendo ? 'Arriendo' : 'Producto');

    // === Configuración de color dinámico de la tarjeta de cliente ===
    final tipo = tipoLabel.toLowerCase();
    final bool esAlquiler = tipo.contains('alquiler') ||
        tipo.contains('arriendo') ||
        tipo.contains('renta');
    final bool esProducto = tipo.contains('producto');
    final bool esPrestamo =
        tipo.contains('prestamo') || tipo.contains('cliente');

    final gradiente = esAlquiler
        ? const [Color(0xFFFFE0B2), Color(0xFFFFB74D)] // naranja
        : esProducto
        ? const [Color(0xFFC8E6C9), Color(0xFF81C784)] // verde
        : const [Color(0xFFBBDEFB), Color(0xFF64B5F6)]; // azul

    final borde = esAlquiler
        ? const Color(0xFFFF9800)
        : esProducto
        ? const Color(0xFF2E7D32)
        : const Color(0xFF1E3A8A);

    final colorTexto = esAlquiler
        ? const Color(0xFF4E342E)
        : esProducto
        ? const Color(0xFF065F46)
        : const Color(0xFF0D47A1);

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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: _logoTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: tecladoAbierto ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Image.asset(
                        'assets/images/logoB.png',
                        height: _logoHeight,
                        fit: BoxFit.contain,
                        color: Colors.white.withOpacity(0.0),
                        colorBlendMode: BlendMode.srcATop,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: adjustedHeight,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: glassWhite,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  14, 14, 14, 0),
                              child: SingleChildScrollView(
                                physics: scrollPhysics,
                                padding:
                                EdgeInsets.only(bottom: bottomPad),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                        'Registrar Pago',
                                        style: GoogleFonts.playfairDisplay(
                                          textStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            fontStyle:
                                            FontStyle.italic,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // CUADRO PRINCIPAL
                                    Container(
                                      clipBehavior: Clip.antiAlias,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                        BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withOpacity(0.06),
                                            blurRadius: 12,
                                            offset:
                                            const Offset(0, 6),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: const Color(
                                              0xFFE9EEF5),
                                        ),
                                      ),
                                      padding: EdgeInsets.fromLTRB(
                                          14, 14, 14,
                                          14 + extraBottomSafe),
                                      child: Column(
                                        mainAxisSize:
                                        MainAxisSize.min,
                                        children: [
                                          // Tarjeta superior con color dinámico
                                          Container(
                                            padding:
                                            const EdgeInsets
                                                .symmetric(
                                                horizontal: 14,
                                                vertical: 12),
                                            decoration:
                                            BoxDecoration(
                                              gradient:
                                              LinearGradient(
                                                colors: gradiente,
                                                begin: Alignment
                                                    .topLeft,
                                                end: Alignment
                                                    .bottomRight,
                                              ),
                                              borderRadius:
                                              BorderRadius
                                                  .circular(14),
                                              border: Border.all(
                                                  color: borde,
                                                  width: 1.5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: borde
                                                      .withOpacity(
                                                      0.35),
                                                  blurRadius: 10,
                                                  offset:
                                                  const Offset(
                                                      0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    (widget
                                                        .nombreCliente)
                                                        .trim()
                                                        .isEmpty
                                                        ? 'Cliente'
                                                        : widget
                                                        .nombreCliente,
                                                    maxLines: 1,
                                                    overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                    style:
                                                    GoogleFonts
                                                        .inter(
                                                      fontSize: 16,
                                                      fontWeight:
                                                      FontWeight
                                                          .w800,
                                                      color:
                                                      colorTexto,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: 8),
                                                Container(
                                                  padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                      horizontal:
                                                      10,
                                                      vertical:
                                                      6),
                                                  decoration:
                                                  BoxDecoration(
                                                    color: Colors
                                                        .white
                                                        .withOpacity(
                                                        0.9),
                                                    borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                        999),
                                                    border: Border.all(
                                                        color:
                                                        borde),
                                                  ),
                                                  child: Text(
                                                    tipoLabel,
                                                    style:
                                                    TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                      FontWeight
                                                          .w900,
                                                      color:
                                                      colorTexto,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(
                                              height: 12),
                                          _resumen(
                                              'Saldo anterior',
                                              _formatCurrency(widget
                                                  .saldoAnterior)),
                                          const SizedBox(
                                              height: 10),
                                          if (!widget.esPrestamo &&
                                              widget.moraActual > 0)
                                            ...[
                                              _resumen(
                                                  'Mora vigente',
                                                  _formatCurrency(widget
                                                      .moraActual)),
                                              const SizedBox(
                                                  height: 10),
                                            ],
                                          if (widget.esPrestamo)
                                            ...[
                                              _resumen(
                                                  'Interés ${widget.periodo.toLowerCase()}',
                                                  _formatCurrency(
                                                      _interesMax)),
                                              const SizedBox(
                                                  height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child:
                                                    _campoValidado(
                                                      label:
                                                      'Pago interés',
                                                      controller:
                                                      _interesCtrl,
                                                      errorText:
                                                      _errorInteres,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      width: 10),
                                                  Expanded(
                                                    child:
                                                    _campoValidado(
                                                      label:
                                                      'Pago capital',
                                                      controller:
                                                      _capitalCtrl,
                                                      errorText:
                                                      _errorCapital,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ]
                                          else
                                            ...[
                                              _campoValidado(
                                                label:
                                                'Pago capital',
                                                controller:
                                                _capitalCtrl,
                                                errorText:
                                                _errorCapital,
                                              ),
                                            ],
                                          const SizedBox(
                                              height: 12),
                                          _resumen(
                                              'Total pagado',
                                              _formatCurrency(
                                                  _totalPagado)),
                                          const SizedBox(
                                              height: 6),
                                          _resumen(
                                              'Saldo nuevo',
                                              _formatCurrency(
                                                  _saldoNuevoConInteres)),
                                          const SizedBox(
                                              height: 12),
                                          const SizedBox(
                                              height: 16),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 54,
                                            child: ElevatedButton(
                                              style: ElevatedButton
                                                  .styleFrom(
                                                backgroundColor:
                                                const Color(
                                                    0xFF2563EB),
                                                foregroundColor:
                                                Colors.white,
                                                elevation: 0,
                                                shape:
                                                const StadiumBorder(),
                                                textStyle:
                                                const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.w800,
                                                ),
                                              ),
                                              onPressed: (_formOk &&
                                                  (widget.autoFecha ||
                                                      _proxima !=
                                                          null) &&
                                                  !_btnContinuarBusy)
                                                  ? () async {
                                                HapticFeedback
                                                    .lightImpact();
                                                FocusScope.of(
                                                    context)
                                                    .unfocus();
                                                setState(() =>
                                                _btnContinuarBusy =
                                                true);
                                                final DateTime
                                                proximaOut =
                                                widget.autoFecha
                                                    ? _calcNextDate(
                                                    _baseProximaLocal)
                                                    : _proxima!;

                                                Navigator.pop(
                                                    context, {
                                                  'pagoInteres': widget.esPrestamo
                                                      ? _pagoInteres
                                                      : 0,
                                                  'pagoCapital':
                                                  _pagoCapital,
                                                  'totalPagado':
                                                  _totalPagado,
                                                  'moraCobrada': (!widget
                                                      .esPrestamo &&
                                                      widget.moraActual >
                                                          0)
                                                      ? widget
                                                      .moraActual
                                                      : 0,
                                                  'saldoAnterior':
                                                  widget
                                                      .saldoAnterior,
                                                  'saldoNuevo':
                                                  _saldoNuevo,
                                                  'proximaFecha':
                                                  proximaOut,
                                                });
                                                if (mounted)
                                                  setState(() =>
                                                  _btnContinuarBusy =
                                                  false);
                                              }
                                                  : null,
                                              child: const Text(
                                                  'Continuar'),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 54,
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  Navigator.pop(
                                                      context),
                                              style: OutlinedButton
                                                  .styleFrom(
                                                side: const BorderSide(
                                                    color: Color(
                                                        0xFF2563EB)),
                                                foregroundColor:
                                                const Color(
                                                    0xFF2563EB),
                                                shape:
                                                const StadiumBorder(),
                                                textStyle:
                                                const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                  FontWeight.w800,
                                                ),
                                              ),
                                              child: const Text('Atrás'),
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
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _campoValidado({
    required String label,
    required TextEditingController controller,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false, signed: false),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontSize: 16,
        fontFeatures: [FontFeature.tabularFigures()],
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _resumen(String l, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(
            l,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF374151),
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ],
    );
  }
}