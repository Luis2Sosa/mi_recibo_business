import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PagoFormScreen extends StatefulWidget {
  final int saldoAnterior;      // RD$
  final double tasaInteres;     // %
  final String periodo;         // Mensual | Quincenal
  final DateTime proximaFecha;  // sugerida (solo referencia visual, no se usa automática)

  const PagoFormScreen({
    super.key,
    required this.saldoAnterior,
    required this.tasaInteres,
    required this.periodo,
    required this.proximaFecha,
  });

  @override
  State<PagoFormScreen> createState() => _PagoFormScreenState();
}

class _PagoFormScreenState extends State<PagoFormScreen> {
  // Logo (decoración al fondo)
  static const double _logoTop = -20;
  static const double _logoHeight = 350;

  final _interesCtrl = TextEditingController();
  final _capitalCtrl = TextEditingController();

  // ⬇️ Fecha SIEMPRE manual: arranca null
  DateTime? _proxima;

  int _pagoInteres = 0;
  int _pagoCapital = 0;

  int get _interesMax =>
      (widget.saldoAnterior * (widget.tasaInteres / 100)).round();

  int get _totalPagado => _pagoInteres + _pagoCapital;
  int get _saldoNuevo {
    final n = widget.saldoAnterior - _pagoCapital;
    return n < 0 ? 0 : n;
  }

  @override
  void initState() {
    super.initState();
    // _proxima = widget.proximaFecha;  // ❌ ya no: fecha debe elegirse manual
    _proxima = null;

    // Interés sugerido
    _interesCtrl.text = _interesMax.toString();
    _pagoInteres = _interesMax;

    _interesCtrl.addListener(_recalcular);
    _capitalCtrl.addListener(_recalcular);
  }

  void _recalcular() {
    setState(() {
      _pagoInteres =
          int.tryParse(_interesCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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

  // ======== Validaciones (lógica intacta) ========
  String? get _errorInteres {
    if (_pagoInteres < 0) return 'No puede ser negativo';
    if (_pagoInteres > _interesMax) {
      return 'Máximo ${_rd(_interesMax)}';
    }
    return null;
  }

  String? get _errorCapital {
    if (_pagoCapital <= 0) return 'Requerido: ingresa capital > 0';
    if (_pagoCapital > widget.saldoAnterior) {
      return 'Máximo ${_rd(widget.saldoAnterior)}';
    }
    return null;
  }

  bool get _formOk => _errorInteres == null && _errorCapital == null;

  // ======== Utilidades visuales (sin tocar cálculos) ========
  String _rd(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return 'RD\$${buf.toString().split('').reversed.join()}';
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  // (Se deja por compatibilidad aunque ya no se usa para continuar)
  DateTime _autoNext(String periodo, DateTime base) {
    return base.add(Duration(days: periodo == 'Quincenal' ? 15 : 30));
  }

  @override
  Widget build(BuildContext context) {
    // Levantar la tarjeta con el teclado (misma idea, más suave)
    final kb = MediaQuery.of(context).viewInsets.bottom;
    const double baseDown = 300;
    final double lift = kb > 0 ? (kb.clamp(0, 340)).toDouble() : 0;
    double translateY = baseDown - lift * 0.8;
    const double minY = 16;
    if (translateY < minY) translateY = minY;

    // ⚙️ Alto disponible para evitar overflow visual (clave del fix)
    final screenH = MediaQuery.of(context).size.height;
    final availableHeight = (screenH - translateY - 24).clamp(220.0, screenH);

    final double bottomPad = kb > 0 ? kb + 24 : 0;

    final brandBlue = const Color(0xFF2563EB);
    final glassWhite = Colors.white.withOpacity(0.12);

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              // === LOGO (fondo) ===
              Positioned(
                top: _logoTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
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

              // === MARCO (sobre el logo) ===
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox( // ⬅️ Limita el alto máximo del marco
                        height: availableHeight,
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
                              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.only(bottom: bottomPad),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Center(
                                      child: Text(
                                        'Registrar Pago',
                                        style: GoogleFonts.playfair(
                                          textStyle: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w700,
                                            fontStyle: FontStyle.italic,
                                            letterSpacing: 0.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // === Tarjeta blanca ===
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: const Color(0xFFE9EEF5),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _resumen(
                                            'Saldo anterior',
                                            _rd(widget.saldoAnterior),
                                          ),
                                          const SizedBox(height: 10),
                                          _resumen(
                                            'Interés ${widget.periodo.toLowerCase()}',
                                            _rd(_interesMax),
                                          ),
                                          const SizedBox(height: 12),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: _campoValidado(
                                                  label: 'Pago interés (RD\$)',
                                                  controller: _interesCtrl,
                                                  errorText: _errorInteres,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _campoValidado(
                                                  label: 'Pago capital (RD\$)',
                                                  controller: _capitalCtrl,
                                                  errorText: _errorCapital,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          _resumen('Total pagado', _rd(_totalPagado)),
                                          const SizedBox(height: 6),
                                          _resumen('Saldo nuevo', _rd(_saldoNuevo)),
                                          const SizedBox(height: 12),

                                          // ====== FECHA (manual obligatoria) ======
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF7F8FA),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: _proxima == null
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFFE5E7EB),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _proxima == null
                                                            ? 'Próxima fecha: (selecciona)'
                                                            : 'Próxima fecha: ${_fmtFecha(_proxima!)}',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          color: _proxima == null
                                                              ? const Color(0xFFEF4444)
                                                              : const Color(0xFF374151),
                                                          fontWeight: _proxima == null
                                                              ? FontWeight.w700
                                                              : FontWeight.w400,
                                                        ),
                                                      ),
                                                      if (_proxima == null)
                                                        const SizedBox(height: 4),
                                                      if (_proxima == null)
                                                        const Text(
                                                          'Debes elegir una fecha de pago',
                                                          style: TextStyle(
                                                            fontSize: 12.5,
                                                            color: Color(0xFFEF4444),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                TextButton.icon(
                                                  icon: const Icon(Icons.date_range),
                                                  label: const Text('Elegir fecha'),
                                                  onPressed: (_pagoCapital <= widget.saldoAnterior)
                                                      ? () async {
                                                    final hoy = DateTime.now();
                                                    final sel = await showDatePicker(
                                                      context: context,
                                                      initialDate: hoy,
                                                      firstDate: DateTime(hoy.year - 1),
                                                      lastDate: DateTime(hoy.year + 5),
                                                    );
                                                    if (sel != null) {
                                                      setState(() => _proxima = sel);
                                                    }
                                                  }
                                                      : null,
                                                  style: TextButton.styleFrom(
                                                    foregroundColor: const Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // === CONTINUAR ===
                                          SizedBox(
                                            width: double.infinity,
                                            height: 54,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF2563EB),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: const StadiumBorder(),
                                                textStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              onPressed: (_formOk && _proxima != null)
                                                  ? () {
                                                Navigator.pop(context, {
                                                  'pagoInteres': _pagoInteres,
                                                  'pagoCapital': _pagoCapital,
                                                  'totalPagado': _totalPagado,
                                                  'saldoAnterior': widget.saldoAnterior,
                                                  'saldoNuevo': _saldoNuevo,
                                                  // 👇 siempre manual
                                                  'proximaFecha': _proxima,
                                                });
                                              }
                                                  : null, // 🔒 bloqueado si no hay fecha
                                              child: const Text('Continuar'),
                                            ),
                                          ),

                                          const SizedBox(height: 12),

                                          // === ATRÁS ===
                                          SizedBox(
                                            width: double.infinity,
                                            height: 54,
                                            child: OutlinedButton(
                                              onPressed: () => Navigator.pop(context),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(color: Color(0xFF2563EB)),
                                                foregroundColor: const Color(0xFF2563EB),
                                                shape: const StadiumBorder(),
                                                textStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
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

  // ===== Widgets auxiliares (premium, sin tocar lógica) =====
  Widget _campoValidado({
    required String label,
    required TextEditingController controller,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
      const TextInputType.numberWithOptions(decimal: false, signed: false),
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