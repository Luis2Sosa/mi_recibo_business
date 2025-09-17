import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PagoFormScreen extends StatefulWidget {
  final int saldoAnterior;      // RD$
  final double tasaInteres;     // %
  final String periodo;         // Mensual | Quincenal
  final DateTime proximaFecha;  // sugerida

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
  // Logo (solo decoración, queda detrás del marco)
  static const double _logoTop = -20;
  static const double _logoHeight = 350;

  final _interesCtrl = TextEditingController();
  final _capitalCtrl = TextEditingController();
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
    _proxima = widget.proximaFecha;

    // Interés sugerido
    _interesCtrl.text = _interesMax.toString();
    _pagoInteres = _interesMax;

    _interesCtrl.addListener(_recalcular);
    _capitalCtrl.addListener(_recalcular);
  }

  void _recalcular() {
    setState(() {
      _pagoInteres =
          int.tryParse(_interesCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
              0;
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

  // ======== Validaciones ========
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

  // ======== Utilidades visuales ========
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

  DateTime _autoNext(String periodo, DateTime base) {
    return base.add(Duration(days: periodo == 'Quincenal' ? 15 : 30));
  }

  @override
  Widget build(BuildContext context) {
    // ——— Posición del marco ———
    final kb = MediaQuery.of(context).viewInsets.bottom; // alto teclado
    const double baseDown = 300;
    final double lift = kb > 0 ? (kb.clamp(0, 340)).toDouble() : 0;
    double translateY = baseDown - lift * 0.8;
    const double minY = 16;
    if (translateY < minY) translateY = minY;

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
              // === LOGO (al fondo) ===
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
                    ),
                  ),
                ),
              ),

              // === MARCO (encima del logo) ===
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, translateY),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
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
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
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
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _resumen(
                                          'Saldo anterior', _rd(widget.saldoAnterior)),
                                      const SizedBox(height: 10),
                                      _resumen(
                                          'Interés ${widget.periodo.toLowerCase()}',
                                          _rd(_interesMax)),
                                      const SizedBox(height: 10),

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
                                      const SizedBox(height: 10),

                                      _resumen('Total pagado', _rd(_totalPagado)),
                                      const SizedBox(height: 6),
                                      _resumen('Saldo nuevo', _rd(_saldoNuevo)),
                                      const SizedBox(height: 12),

                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _proxima == null
                                                  ? 'Próxima fecha: (automática)'
                                                  : 'Próxima fecha: ${_fmtFecha(_proxima!)}',
                                            ),
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.date_range),
                                            label: const Text('Elegir fecha'),
                                            onPressed: () async {
                                              final hoy = DateTime.now();
                                              final sel = await showDatePicker(
                                                context: context,
                                                initialDate: _proxima ?? hoy,
                                                firstDate: DateTime(hoy.year - 1),
                                                lastDate: DateTime(hoy.year + 5),
                                              );
                                              if (sel != null) setState(() => _proxima = sel);
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // === CONTINUAR ===
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            textStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          onPressed: _formOk
                                              ? () {
                                            Navigator.pop(context, {
                                              'pagoInteres': _pagoInteres,
                                              'pagoCapital': _pagoCapital,
                                              'totalPagado': _totalPagado,
                                              'saldoAnterior':
                                              widget.saldoAnterior,
                                              'saldoNuevo': _saldoNuevo,
                                              'proximaFecha': _proxima ??
                                                  _autoNext(widget.periodo,
                                                      widget.proximaFecha),
                                            });
                                          }
                                              : null, // 🔒 Deshabilitado si hay error
                                          child: const Text('Continuar'),
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // === ATRÁS ===
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: Color(0xFF2563EB)),
                                            foregroundColor:
                                            const Color(0xFF2563EB),
                                            shape: const StadiumBorder(),
                                            textStyle: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
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
            ],
          ),
        ),
      ),
    );
  }

  // ===== Widgets auxiliares =====
  Widget _campoValidado({
    required String label,
    required TextEditingController controller,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        errorText: errorText, // 🔴 muestra mensaje en rojo
      ),
    );
  }

  Widget _resumen(String l, String v) {
    return Row(
      children: [
        Expanded(child: Text(l, style: const TextStyle(fontSize: 16))),
        Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}