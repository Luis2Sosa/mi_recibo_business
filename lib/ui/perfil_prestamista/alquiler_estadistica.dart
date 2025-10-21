// lib/ui/perfil_prestamista/alquiler_estadistica.dart
// Resumen de ALQUILER (alineado al dominio):
// - Héroe: Ocupación actual (círculo de agua).
// - KPIs: Ganancias de alquiler (tap), Activos alquilados, Pendiente de cobro (alquiler), Por vencer (7 d).
// - Estados de contratos.
// - Tendencia: Pagos últimos 6 meses.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/widgets/app_frame.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart' show AppTheme;
import 'package:mi_recibo/ui/widgets/widgets_shared.dart' as util show monedaLocal;
import 'package:mi_recibo/ui/perfil_prestamista/ganancias_alquiler_screen.dart';
import 'package:mi_recibo/core/estadisticas_totales_service.dart';

import '../widgets/bar_chart.dart';

class AlquilerEstadisticaScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const AlquilerEstadisticaScreen({super.key, required this.docPrest});

  @override
  State<AlquilerEstadisticaScreen> createState() => _AlquilerEstadisticaScreenState();
}

class _AlquilerEstadisticaScreenState extends State<AlquilerEstadisticaScreen>
    with TickerProviderStateMixin {
  late Future<_ResumenAlquiler> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarResumenAlquiler();
  }

  // ==================== CARGA Y AGREGACIÓN (solo ALQUILER) ====================
  Future<_ResumenAlquiler> _cargarResumenAlquiler() async {
    final prestamistaId = widget.docPrest.id;

    // Asegura estructura inicial sin borrar nada existente
    await EstadisticasTotalesService.ensureStructure(prestamistaId);

    // Leer KPIs desde Firestore (colección stats/alquiler)
    final cat = await EstadisticasTotalesService.readCategoria(prestamistaId, 'alquiler');
    final activos = (cat?['activos'] ?? 0) as int;
    final finalizados = (cat?['finalizados'] ?? 0) as int;
    final pendiente = (cat?['pendienteCobro'] ?? 0) as int;
    final gananciaNeta = (cat?['gananciaNeta'] ?? 0) as int;

    // Leer serie mensual para la gráfica
    final serie = await EstadisticasTotalesService.readSerieMensual(prestamistaId, 'alquiler', meses: 6);
    final labels = <String>[];
    final values = <int>[];

    const mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    for (final e in serie) {
      final ym = (e['ym'] as String? ?? '');
      final parts = ym.split('-');
      final m = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
      labels.add(mesesTxt[m - 1]);
      values.add((e['sum'] ?? 0) as int);
    }

    // Leer estados en vivo (vencidos y por vencer)
    int vencidos = 0;
    int porVencer = 0;
    final now = DateTime.now();
    final limite7 = now.add(const Duration(days: 7));

    final cs = await widget.docPrest
        .collection('clientes')
        .where('tipo', isEqualTo: 'alquiler') // 🔹 Solo clientes de alquiler
        .get();

    for (final c in cs.docs) {
      final m = c.data();
      final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
      final producto = (m['producto'] ?? '').toString().toLowerCase();
      final esAlq = tipo == 'alquiler' || producto.contains('alquiler') || producto.contains('renta');
      if (!esAlq) continue;

      final saldo = (m['saldoActual'] ?? 0) as int;
      if (saldo <= 0) continue;

      final pf = m['proximaFecha'];
      if (pf is Timestamp) {
        final d = pf.toDate();
        if (d.isBefore(now)) {
          vencidos++;
        } else if (!d.isBefore(now) && !d.isAfter(limite7)) {
          porVencer++;
        }
      }
    }

    // Cálculo de ocupación
    final totalContratos = activos + finalizados;
    final ocupacion = totalContratos > 0 ? (activos * 100.0 / totalContratos) : 0.0;

    return _ResumenAlquiler(
      activos: activos,
      finalizados: finalizados,
      pendienteCobro: pendiente,
      gananciaNeta: gananciaNeta,
      vencidos: vencidos,
      porVencer: porVencer,
      ocupacion: ocupacion,
      labels: labels,
      values: values,
    );
  }

  // ==================== HELPERS ====================
  String _two(int n) => n.toString().padLeft(2, '0');
  String _rd(int v) => '\$${v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
  String _pct(double x) => '${x.toStringAsFixed(x >= 100 ? 0 : 1)}%';

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const _HeaderBar(title: 'Resumen de Alquiler'),
          child: FutureBuilder<_ResumenAlquiler>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      SizedBox(width: 10),
                      Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }

              final data = snap.data;
              if (data == null) return _emptyCard('Sin datos de alquiler');

              final totalSerie = data.values.fold<int>(0, (p, v) => p + v);

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 16),
                children: [
                  // ===== HÉROE: Ocupación actual =====
                  _heroOcupacion(pct: data.ocupacion),
                  const SizedBox(height: 12),

                  // ===== KPIs =====
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.52,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _kpiPremiumTap(
                        title: 'Ganancias de alquiler',
                        subtitle: 'Toca para ver',
                        leading: Icons.people_alt_rounded,
                        leadingSize: 32,
                        gradient: const [Color(0xFFDFFCEF), Color(0xFFC5F5FF)],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GananciasAlquilerScreen(docPrest: widget.docPrest),
                            ),
                          );
                        },
                      ),
                      _kpiSmart(
                        title: 'Activos alquilados',
                        display: '${data.activos}',
                        accent: AppTheme.gradTop,
                        bg: const Color(0xFFF2F6FD),
                      ),
                      _kpiSmart(
                        title: 'Pendiente de cobro (alquiler)',
                        display: _rd(data.pendienteCobro),
                        accent: const Color(0xFF16A34A),
                        bg: const Color(0xFFDCFCE7),
                      ),
                      _kpiSmart(
                        title: 'Rentabilidad actual',
                        display: '${(data.gananciaNeta > 0 && data.pendienteCobro > 0)
                            ? ((data.gananciaNeta / (data.gananciaNeta + data.pendienteCobro)) * 100).toStringAsFixed(1)
                            : '0'}%',
                        accent: const Color(0xFF0EA5E9),
                        bg: const Color(0xFFE0F2FE),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Estados de contratos =====
                  _estadosCard(
                    enCurso: data.activos,
                    porVencer: data.porVencer,
                    vencidos: data.vencidos,
                    finalizados: data.finalizados,
                  ),

                  const SizedBox(height: 12),

                  // ===== Tendencia 6 meses =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.stacked_bar_chart_rounded, color: _BrandX.inkDim),
                            SizedBox(width: 8),
                            Text('Pagos últimos 6 meses',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SimpleBarChart(
                          values: data.values,
                          labels: data.labels,
                          yTickFormatter: (v) => _rd(v),
                        ),
                        const SizedBox(height: 8),
                        Text('Total: ${_rd(totalSerie)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== HÉROE Ocupación (agua + chip) ====================
  Widget _heroOcupacion({required double pct}) {
    final bool up = pct >= 50.0;
    final Color water = up ? const Color(0xFF16A34A) : const Color(0xFFE11D48);
    final double clamped = pct.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.gradTop.withOpacity(.98), AppTheme.gradBottom.withOpacity(.98)],
        ),
        boxShadow: [BoxShadow(color: AppTheme.gradTop.withOpacity(.28), blurRadius: 24, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.white.withOpacity(.35), width: 1.2),
      ),
      child: Row(
        children: [
          SizedBox(width: 160, height: 160, child: _WaterCircle(targetPercent: clamped, waterColor: water)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ocupación actual',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Contratos activos',
                    style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(.65)),
                    ),
                    child: Text(
                      'Ocupación ${_pct(clamped)}',
                      style: TextStyle(
                        color: up ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Estados (filas anchas) ====================
  Widget _estadosCard({
    required int enCurso,
    required int porVencer,
    required int vencidos,
    required int finalizados,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.event_note_rounded, color: _BrandX.inkDim),
            SizedBox(width: 8),
            Text('Estados de contratos',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
          ]),
          const SizedBox(height: 12),
          _estadoRow(Icons.check_circle, 'En curso', enCurso, const Color(0xFF22C55E)),
          const SizedBox(height: 10),
          _estadoRow(Icons.pending_actions, 'Por vencer (7 d)', porVencer, const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _estadoRow(Icons.error_rounded, 'Vencidos', vencidos, const Color(0xFFEF4444)),
          const SizedBox(height: 10),
          _estadoRow(Icons.pause_circle, 'Finalizados', finalizados, const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  Widget _estadoRow(IconData icon, String label, int count, Color dotColor) {
    final badgeColor = count > 0 ? dotColor.withOpacity(.12) : const Color(0xFFF6F8FD);
    final badgeBorder = count > 0 ? dotColor.withOpacity(.35) : const Color(0xFFE1E8F5);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: _BrandX.inkDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeBorder),
            ),
            child: Text('$count',
                style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ==================== UI HELPERS ====================
  Widget _kpiSmart({
    required String title,
    required String display,
    required Color accent,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 14, height: 1.1),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w900, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiPremiumTap({
    required String title,
    required String subtitle,
    required IconData leading,
    double leadingSize = 32,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(leading, size: leadingSize, color: AppTheme.gradTop),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BrandX.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: .2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE1E8F5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.touch_app_rounded, size: 16, color: _BrandX.inkDim),
                      SizedBox(width: 6),
                      Text('Toca para ver', style: TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink)),
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

  Widget _emptyCard(String txt) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w800, color: _BrandX.inkDim)),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 14, offset: const Offset(0, 6))],
        border: Border.all(color: const Color(0xFFE1E8F5)),
      ),
      child: child,
    );
  }
}

// ==================== TIPOS ====================
class _ResumenAlquiler {
  final int activos;
  final int finalizados;
  final int pendienteCobro;
  final int gananciaNeta;
  final int vencidos;
  final int porVencer;
  final double ocupacion;

  final List<String> labels;
  final List<int> values;

  _ResumenAlquiler({
    required this.activos,
    required this.finalizados,
    required this.pendienteCobro,
    required this.gananciaNeta,
    required this.vencidos,
    required this.porVencer,
    required this.ocupacion,
    required this.labels,
    required this.values,
  });
}

// ==================== HEADER ====================
class _HeaderBar extends StatelessWidget {
  final String title;
  const _HeaderBar({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(AppTheme.gradTop.withOpacity(.9)),
            shape: MaterialStateProperty.all(const CircleBorder()),
            padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ],
    );
  }
}

// ==================== PALETA ====================
class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

// ==================== WATER CIRCLE ====================
class _WaterCircle extends StatefulWidget {
  final double targetPercent; // 0..100
  final Color waterColor;
  const _WaterCircle({required this.targetPercent, required this.waterColor});

  @override
  State<_WaterCircle> createState() => _WaterCircleState();
}

class _WaterCircleState extends State<_WaterCircle> with TickerProviderStateMixin {
  late AnimationController _levelCtrl;
  late Animation<double> _level;
  late AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    final to = (widget.targetPercent.clamp(0, 100)) / 100.0;

    _levelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _level = CurvedAnimation(parent: _levelCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: 0.0, end: to));
    _levelCtrl.forward();

    _waveCtrl = AnimationController.unbounded(vsync: this)
      ..animateWith(_LinearWaveSimulation(speed: 1.2));
  }

  @override
  void didUpdateWidget(covariant _WaterCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final to = (widget.targetPercent.clamp(0, 100)) / 100.0;
    _level = CurvedAnimation(parent: _levelCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: _level.value, end: to));
    _levelCtrl..reset()..forward();
  }

  @override
  void dispose() {
    _levelCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pctText = widget.targetPercent.clamp(0, 100).toStringAsFixed(0);
    final water = widget.waterColor;

    return ClipOval(
      child: CustomPaint(
        painter: _WaterCirclePainter(levelListenable: _level, waveListenable: _waveCtrl, waterColor: water),
        child: Center(
          child: Stack(
            children: [
              Text(
                '$pctText%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = Colors.black,
                ),
              ),
              Text(
                '$pctText%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: water,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaterCirclePainter extends CustomPainter {
  final Animation<double> levelListenable; // 0..1
  final Animation<double> waveListenable;  // fase
  final Color waterColor;

  _WaterCirclePainter({
    required this.levelListenable,
    required this.waveListenable,
    required this.waterColor,
  }) : super(repaint: Listenable.merge([levelListenable, waveListenable]));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    final bg = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, bg);

    final border = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, border);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final level = levelListenable.value.clamp(0.0, 1.0);
    final waterTop = h * (1 - level);

    final t = waveListenable.value;
    const omega1 = 2.2;
    const omega2 = 1.4;
    final phase1 = t * omega1;
    final phase2 = -t * omega2;
    const amp1 = 8.0;
    const amp2 = 5.0;

    Paint waterPaint(double o1, double o2) => Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [waterColor.withOpacity(o1), waterColor.withOpacity(o2)],
      ).createShader(Rect.fromLTWH(0, waterTop - 10, w, h - waterTop + 10));

    Path wave(double phase, double amp, double y0) {
      final path = Path()..moveTo(0, h);
      double y(double x) => y0 + math.sin((x / w * 2 * math.pi) + phase) * amp;
      path.lineTo(0, y(0));
      for (double x = 0; x <= w; x += 2) {
        path.lineTo(x, y(x));
      }
      path.lineTo(w, h);
      path.close();
      return path;
    }

    final back = wave(phase2, amp2, waterTop - 4);
    final front = wave(phase1, amp1, waterTop);

    canvas.drawPath(back, waterPaint(.25, .65));
    canvas.drawPath(front, waterPaint(.4, .85));

    final edge = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final edgePath = Path();
    for (double x = 0; x <= w; x += 4) {
      final y = waterTop + math.sin((x / w * 2 * math.pi) + phase1) * amp1;
      if (x == 0) {
        edgePath.moveTo(x, y);
      } else {
        edgePath.lineTo(x, y);
      }
    }
    canvas.drawPath(edgePath, edge);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterCirclePainter oldDelegate) => true;
}

class _LinearWaveSimulation extends Simulation {
  final double speed; // rad/s
  _LinearWaveSimulation({this.speed = 1.2});
  @override
  double x(double time) => speed * time;
  @override
  double dx(double time) => speed;
  @override
  bool isDone(double time) => false;
}