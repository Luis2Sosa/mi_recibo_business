import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';
import 'package:fl_chart/fl_chart.dart';


class GananciasScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const GananciasScreen({super.key, required this.docPrest});

  @override
  State<GananciasScreen> createState() => _GananciasScreenState();
}

class _GananciasScreenState extends State<GananciasScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _displayedTotal = 0;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _rd(int v) {
    final f = NumberFormat.decimalPattern('es'); // base española
    final formatted = f.format(v);
    // Reemplaza el punto (.) por coma (,)
    return formatted.replaceAll('.', ',');
  }


  Future<void> _borrarGananciasTotales() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final db = FirebaseFirestore.instance;
    const categorias = ['prestamo', 'producto', 'alquiler'];
    for (final cat in categorias) {
      await db
          .collection('prestamistas')
          .doc(user.uid)
          .collection('estadisticas')
          .doc(cat)
          .set({'gananciaNeta': 0}, SetOptions(merge: true));
    }
    await db
        .collection('prestamistas')
        .doc(user.uid)
        .collection('estadisticas')
        .doc('totales')
        .set({'totalGanancia': 0}, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ganancias totales reiniciadas correctamente 💎')));
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const SizedBox();

    final db = FirebaseFirestore.instance;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ganancias Totales',
          style: TextStyle(
              fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1E2A78), Color(0xFF431F91)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<DocumentSnapshot>>(
            stream: db
                .collection('prestamistas')
                .doc(user.uid)
                .collection('estadisticas')
                .where(FieldPath.documentId,
                whereIn: ['prestamo', 'producto', 'alquiler'])
                .snapshots()
                .map((q) => q.docs),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              int ganPrestamo = 0,
                  ganProducto = 0,
                  ganAlquiler = 0;
              for (var doc in snap.data!) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                if (doc.id == 'prestamo')
                  ganPrestamo = data['gananciaNeta'] ?? 0;
                if (doc.id == 'producto')
                  ganProducto = data['gananciaNeta'] ?? 0;
                if (doc.id == 'alquiler')
                  ganAlquiler = data['gananciaNeta'] ?? 0;
              }

              final total = ganPrestamo + ganProducto + ganAlquiler;

              if (_displayedTotal != total) {
                Timer.periodic(const Duration(milliseconds: 30), (timer) {
                  setState(() {
                    if (_displayedTotal < total) {
                      _displayedTotal +=
                          ((total - _displayedTotal) / 6).ceil();
                    } else {
                      _displayedTotal = total;
                      timer.cancel();
                    }
                  });
                });
              }

              return FadeTransition(
                opacity: _fadeAnim,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  children: [
                    // PANEL SUPERIOR — estilo premium transparente (glass)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(color: Colors.white.withOpacity(
                            0.12), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Balance Total',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ShaderMask(
                            shaderCallback: (r) =>
                                const LinearGradient(
                                  colors: [
                                    Color(0xFF00FFD1),
                                    Color(0xFF00B8FF)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(r),
                            child: Text(
                              "\$${_rd(_displayedTotal)}",
                              style: GoogleFonts.poppins(
                                fontSize: 56,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.trending_up_rounded,
                                    color: Colors.greenAccent, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'En crecimiento',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // MINI KPIs TIPO TRADING
                    Row(
                      children: [
                        Expanded(
                            child: _kpi(
                                'Préstamos', ganPrestamo, Colors.blueAccent)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _kpi(
                                'Productos', ganProducto, Colors.tealAccent)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _kpi(
                                'Alquiler', ganAlquiler, Colors.orangeAccent)),
                      ],
                    ),

                    const SizedBox(height: 30),
                    // ================== GRÁFICO PREMIUM ANIMADO Y ADICTIVO ==================
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(color: Colors.white.withOpacity(
                            0.12), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.25)),
                                ),
                                child: const Icon(
                                  Icons.insights_rounded,
                                  color: Color(0xFF00E5FF),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gráfico de ganancias',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Evolución visual de ingresos recientes',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withOpacity(.75),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E5FF).withOpacity(
                                      0.85),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 200,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(seconds: 8),
                              // 🐍 más lenta, fluida
                              curve: Curves.easeInOutSine,
                              // movimiento orgánico
                              onEnd: () {
                                // 🔁 ciclo infinito con variación ligera
                                Future.delayed(const Duration(seconds: 2), () {
                                  (context as Element).markNeedsBuild();
                                });
                              },
                              builder: (context, animValue, child) {
                                final glow = (0.5 + 0.5 * sin(animValue * 3.14))
                                    .clamp(0.3, 1.0);
                                return Stack(
                                  children: [
                                    // Fondo premium con líneas diagonales y transparencia
                                    CustomPaint(
                                      painter: _GridBackgroundPainter(),
                                      size: const Size(
                                          double.infinity, double.infinity),
                                    ),

                                    // Línea principal con degradado dinámico
                                    LineChart(
                                      LineChartData(
                                        minY: 0,
                                        maxY: 4,
                                        gridData: const FlGridData(show: false),
                                        titlesData: const FlTitlesData(
                                            show: false),
                                        borderData: FlBorderData(show: false),
                                        lineBarsData: [
                                          LineChartBarData(
                                            isCurved: true,
                                            curveSmoothness: 0.55,
                                            barWidth: 4,
                                            isStrokeCapRound: true,
                                            gradient: LinearGradient(
                                              colors: [
                                                const Color(0xFF00E5FF)
                                                    .withOpacity(
                                                    0.8 + 0.2 * glow),
                                                const Color(0xFF00FF88)
                                                    .withOpacity(
                                                    0.8 + 0.2 * glow),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            belowBarData: BarAreaData(
                                              show: true,
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF00E5FF)
                                                      .withOpacity(0.25 * glow),
                                                  const Color(0xFF00FF88)
                                                      .withOpacity(0.05),
                                                ],
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                              ),
                                            ),
                                            dotData: FlDotData(
                                              show: true,
                                              getDotPainter: (spot, _, __,
                                                  ___) =>
                                                  FlDotCirclePainter(
                                                    radius: 4 + 2 * glow,
                                                    color: Colors.white
                                                        .withOpacity(0.9),
                                                    strokeWidth: 0,
                                                    strokeColor: Colors
                                                        .transparent,
                                                  ),
                                            ),
                                            spots: [
                                              FlSpot(0, 1.4 +
                                                  0.6 * sin(animValue * 3.14)),
                                              FlSpot(1,
                                                  2.3 * animValue + 0.5 * glow),
                                              FlSpot(2, 1.7 + 0.6 * animValue),
                                              FlSpot(3, 3.0 * animValue),
                                              FlSpot(4, 2.6 + 0.4 * glow),
                                              FlSpot(5, 3.3 * animValue),
                                              FlSpot(6, 2.5 +
                                                  0.7 * sin(animValue * 3.14)),
                                            ],
                                          ),
                                        ],
                                        lineTouchData: LineTouchData(
                                          enabled: true,
                                          touchTooltipData: LineTouchTooltipData(
                                            tooltipRoundedRadius: 12,
                                            getTooltipColor: (_) =>
                                            const Color(0xFF101C3D),
                                            tooltipPadding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 12, vertical: 8),
                                            getTooltipItems: (spots) =>
                                                spots.map((spot) {
                                                  return LineTooltipItem(
                                                    '\$${(spot.y * 5000)
                                                        .toStringAsFixed(0)}',
                                                    const TextStyle(
                                                      color: Color(0xFF00E5FF),
                                                      fontWeight: FontWeight
                                                          .bold,
                                                      fontSize: 15,
                                                    ),
                                                  );
                                                }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Actualizado en tiempo real',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),


                    const SizedBox(height: 35),
                    _premiumCard(),

                    const SizedBox(height: 35),
                    ElevatedButton.icon(
                      onPressed: _borrarGananciasTotales,
                      icon: const Icon(Icons.delete_forever_rounded,
                          color: Colors.white, size: 24),
                      label: const Text('Borrar ganancias totales'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 36, vertical: 18),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 16),
                        shadowColor: Colors.redAccent.withOpacity(.4),
                        elevation: 10,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _kpi(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text("\$${_rd(value)}",
              style: GoogleFonts.poppins(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 17)),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _premiumCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PremiumBoostsScreen(docPrest: widget.docPrest),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Potenciador Premium',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Accede a estrategias avanzadas\npara optimizar tus ganancias diarias.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(.9),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.touch_app_rounded,
                      color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Toca para ver',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

  class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00C2FF), Color(0xFF00FFA3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.25, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.6),
      Offset(size.width * 0.75, size.height * 0.4),
      Offset(size.width, size.height * 0.6),
    ];
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5A6ACF).withOpacity(0.08)
      ..strokeWidth = 1;

    // Líneas diagonales elegantes arriba a la izquierda
    for (double i = 0; i < size.width; i += 25) {
      canvas.drawLine(Offset(i, 0), Offset(0, i), paint);
    }

    // Líneas horizontales suaves
    for (double y = size.height * 0.2; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
