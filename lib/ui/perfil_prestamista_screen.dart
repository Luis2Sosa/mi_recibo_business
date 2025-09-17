import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';

class PerfilPrestamistaScreen extends StatefulWidget {
  const PerfilPrestamistaScreen({super.key});
  @override
  State<PerfilPrestamistaScreen> createState() => _PerfilPrestamistaScreenState();
}

class _Brand {
  static const gradientTop = Color(0xFF2458D6);
  static const gradientBottom = Color(0xFF0A9A76);
  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF22C55E);
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF475569);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFF8FAFC);
}

class _PerfilPrestamistaScreenState extends State<PerfilPrestamistaScreen> {
  // Logo independiente
  static const double _logoTop = -50;
  static const double _logoHeight = 350;
  static const double _gapBelowLogo = -60;

  // pestaña activa: 0 Perfil, 1 Estadísticas
  int _tabIndex = 1; // si quieres abrir en Perfil, pon 0

  // Datos del perfil
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _empresaCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  // Seguridad
  bool _pinEnabled = false;
  bool _biometriaEnabled = false;

  // Respaldo
  bool _backupEnabled = false;
  DateTime? _lastBackupAt;

  // Notificaciones
  bool _notifEnabled = true;
  TimeOfDay _notifHour = const TimeOfDay(hour: 8, minute: 0);

  // =================== DATOS ESTADÍSTICA ===================
  int totalPrestado = 0;
  int totalRecuperado = 0;
  int totalPendiente = 0;
  final List<int> pagosMes = [];
  int clientesAlDia = 0;
  int clientesPagando = 0;
  int clientesVencidos = 0;

  bool get _hasData {
    return totalPrestado > 0 ||
        totalRecuperado > 0 ||
        totalPendiente > 0 ||
        pagosMes.isNotEmpty ||
        (clientesAlDia + clientesPagando + clientesVencidos) > 0;
  }

  String _fmtRD(int v) {
    if (v <= 0) return 'RD\$0';
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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _empresaCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  // ======= FALTANTE (ahora incluido): pedir PIN =======
  Future<String?> _pedirPin({bool confirmar = false}) async {
    final ctrl = TextField(
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      decoration: const InputDecoration(
        labelText: 'PIN (4 dígitos)',
        border: OutlineInputBorder(),
        counterText: '',
      ),
    );
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(confirmar ? 'Confirma tu PIN' : 'Crea un PIN'),
        content: StatefulBuilder(
          builder: (context, setSt) {
            return TextField(
              onChanged: (t) => value = t.trim(),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'PIN (4 dígitos)',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, value), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showBanner(String texto, {Color color = _Brand.success, IconData icon = Icons.check_circle}) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(snack);
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtDateTime(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}  ${_two(d.hour)}:${_two(d.minute)}';

  @override
  Widget build(BuildContext context) {
    final contentTop = _logoTop + _logoHeight + _gapBelowLogo;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_Brand.gradientTop, _Brand.gradientBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Logo
              Positioned(
                top: _logoTop, left: 0, right: 0,
                child: Center(
                  child: Image.asset('assets/images/logoB.png', height: _logoHeight, fit: BoxFit.contain),
                ),
              ),

              // Tarjeta grande
              Padding(
                padding: EdgeInsets.only(top: contentTop),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 20, offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tabs 50/50
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Row(
                                children: [
                                  Expanded(child: _tabChip(label: 'Perfil', selected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0))),
                                  const SizedBox(width: 10),
                                  Expanded(child: _tabChip(label: 'Estadísticas', selected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_tabIndex == 0) _perfilContent() else _statsContent(),

                            const SizedBox(height: 16),

                            // Salir
                            SizedBox(
                              width: double.infinity, height: 52,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.red, width: 1.5),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () {
                                  Navigator.pushAndRemoveUntil(
                                    context,
                                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                                        (route) => false,
                                  );
                                },
                                child: const Text('Salir', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
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

  // ------------------ PERFIL ------------------
  Widget _perfilContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(
          child: Column(
            children: [
              _input('Nombre completo (Nombre y Apellido)', _nombreCtrl),
              const SizedBox(height: 12),
              _input('Teléfono (obligatorio)', _telefonoCtrl, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _input('Empresa (opcional)', _empresaCtrl),
              const SizedBox(height: 12),
              _input('Dirección (opcional)', _direccionCtrl),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Brand.primary, foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () {
                    if (_nombreCtrl.text.trim().isEmpty || _telefonoCtrl.text.trim().isEmpty) {
                      _showBanner('Completa nombre completo y teléfono', color: const Color(0xFFE11D48), icon: Icons.error_outline);
                      return;
                    }
                    _showBanner('Perfil actualizado ✅');
                  },
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Seguridad'),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bloquear con PIN'),
                value: _pinEnabled,
                onChanged: (v) async {
                  if (v) {
                    final pin = await _pedirPin();
                    if (pin != null && pin.length == 4) {
                      setState(() => _pinEnabled = true);
                      _showBanner('PIN activado ✅');
                    } else {
                      _showBanner('PIN no establecido', color: const Color(0xFFE11D48), icon: Icons.error_outline);
                    }
                  } else {
                    final pin = await _pedirPin(confirmar: true);
                    if (pin != null && pin.length == 4) {
                      setState(() => _pinEnabled = false);
                      _showBanner('PIN desactivado');
                    } else {
                      _showBanner('Acción cancelada', color: const Color(0xFFE11D48), icon: Icons.error_outline);
                    }
                  }
                },
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar huella / biometría'),
                value: _biometriaEnabled,
                onChanged: (v) {
                  setState(() => _biometriaEnabled = v);
                  _showBanner(v ? 'Biometría activada ✅' : 'Biometría desactivada');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Respaldo en la nube'),
              const SizedBox(height: 6),
              Text(
                _backupEnabled
                    ? 'Respaldo: Activado · Última copia: ${_lastBackupAt == null ? '—' : _fmtDateTime(_lastBackupAt!)}'
                    : 'Respaldo: Desactivado',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        if (_backupEnabled) {
                          _showBanner('El respaldo ya está activado');
                        } else {
                          setState(() {
                            _backupEnabled = true;
                            _lastBackupAt = DateTime.now();
                          });
                          _showBanner('Respaldo activado ✅');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _Brand.primary),
                        foregroundColor: _Brand.primary,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Activar respaldo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _backupEnabled
                          ? () {
                        setState(() => _lastBackupAt = DateTime.now());
                        _showBanner('Copia realizada ✅');
                      }
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _backupEnabled ? _Brand.primary : Colors.grey.shade300),
                        foregroundColor: _backupEnabled ? _Brand.primary : Colors.grey,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Hacer copia ahora'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _backupEnabled
                      ? () {
                    setState(() {
                      _backupEnabled = false;
                      _lastBackupAt = null;
                    });
                    _showBanner('Respaldo desactivado');
                  }
                      : null,
                  child: const Text('Desactivar respaldo'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Notificaciones'),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recordatorios de vencimientos'),
                value: _notifEnabled,
                onChanged: (v) {
                  setState(() => _notifEnabled = v);
                  _showBanner(v ? 'Recordatorios activados ✅' : 'Recordatorios desactivados');
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Resumen diario: ${_two(_notifHour.hour)}:${_two(_notifHour.minute)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final p = await showTimePicker(context: context, initialTime: _notifHour);
                      if (p != null) setState(() => _notifHour = p);
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('Cambiar hora'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _Brand.primary),
                      foregroundColor: _Brand.primary,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------ ESTADÍSTICAS ------------------
  Widget _statsContent() {
    final prestado = _fmtRD(totalPrestado);
    final recuperado = _fmtRD(totalRecuperado);
    final pendiente = _fmtRD(totalPendiente);
    final recRate = (_hasData && totalPrestado > 0)
        ? '${(totalRecuperado * 100 / totalPrestado).toStringAsFixed(0)}%'
        : '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            _kpi('Total prestado', prestado),
            _kpi('Total recuperado', recuperado),
            _kpi('Total pendiente', pendiente),
            _kpi('Recuperación', recRate),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          child: Row(
            children: [
              Expanded(
                child: _chartBlock(
                  title: 'Pagos recibidos por mes',
                  child: pagosMes.isEmpty ? _emptyChart()
                      : _barChart(values: pagosMes, labels: const ['Ene','Feb','Mar']),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _chartBlock(
                  title: 'Distribución de clientes',
                  child: (clientesAlDia + clientesPagando + clientesVencidos == 0)
                      ? _emptyChart()
                      : Column(
                    children: [
                      _donutChart(segments: [
                        _Segment(color: Colors.green, value: clientesAlDia),
                        _Segment(color: _Brand.primary, value: clientesPagando),
                        _Segment(color: Colors.red, value: clientesVencidos),
                      ]),
                      const SizedBox(height: 8),
                      _legend(const [
                        _Legend('Al día', Colors.green),
                        _Legend('Vencidos', Colors.red),
                        _Legend('Pagando', _Brand.primary),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            children: const [
              _kvRow('Cliente con más deuda', '—'),
              SizedBox(height: 10),
              _kvRow('Promedio de interés cobrado', '—'),
              SizedBox(height: 10),
              _kvRow('Próximo vencimiento', '—'),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Helpers UI ----------
  Widget _tabChip({required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              textStyle: TextStyle(
                color: selected ? _Brand.ink : Colors.white,
                fontWeight: FontWeight.w700, fontSize: 15.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Brand.card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }

  Widget _input(String label, TextEditingController ctrl, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label, filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _Brand.ink));

  Widget _kpi(String title, String value) {
    return SizedBox(
      width: 380,
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: _Brand.inkDim)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _Brand.ink)),
          ],
        ),
      ),
    );
  }

  Widget _chartBlock({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _Brand.cardSoft, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _emptyChart() {
    return Container(
      height: 160, alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: const Text('Sin datos aún', style: TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w600)),
    );
  }

  Widget _barChart({required List<int> values, required List<String> labels}) {
    if (values.isEmpty) return _emptyChart();
    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 999999.0);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final h = (values[i] / maxV) * 120;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(height: h, width: 28, decoration: BoxDecoration(color: _Brand.primary, borderRadius: BorderRadius.circular(8))),
                const SizedBox(height: 8),
                Text(labels[i], style: const TextStyle(color: _Brand.inkDim)),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _donutChart({required List<_Segment> segments}) {
    final total = segments.fold<int>(0, (p, s) => p + s.value);
    if (total == 0) return _emptyChart();
    return SizedBox(height: 170, child: CustomPaint(painter: _DonutPainter(segments)));
  }
}

// Donut helpers
class _Segment {
  final Color color; final int value;
  const _Segment({required this.color, required this.value});
}

class _DonutPainter extends CustomPainter {
  final List<_Segment> segments;
  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = (Offset.zero & size).center;
    final radius = size.shortestSide * 0.42;
    final total = segments.fold<int>(0, (p, s) => p + s.value);
    if (total == 0) return;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round;

    double startDeg = -90;
    for (final s in segments) {
      final sweepDeg = 360 * (s.value / total);
      stroke.color = s.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), _r(startDeg), _r(sweepDeg), false, stroke);
      startDeg += sweepDeg;
    }
    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - 18, inner);
  }

  double _r(double deg) => deg * 3.1415926535 / 180.0;
  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.segments != segments;
}

class _Legend {
  final String label; final Color color;
  const _Legend(this.label, this.color);
}

Widget _legend(List<_Legend> items) {
  return Wrap(
    spacing: 16, runSpacing: 8, alignment: WrapAlignment.center,
    children: items.map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(e.label, style: const TextStyle(color: _Brand.inkDim)),
    ])).toList(),
  );
}

class _kvRow extends StatelessWidget {
  final String k; final String v;
  const _kvRow(this.k, this.v);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: _Brand.inkDim))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w800, color: _Brand.ink)),
      ],
    );
  }
}