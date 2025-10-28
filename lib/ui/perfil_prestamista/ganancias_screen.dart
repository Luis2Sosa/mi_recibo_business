import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui'; // 👈 importante para el desenfoque


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
  bool _reiniciarGrafico = false;
  List<int> pagosMes = [];
  List<String> pagosMesLabels = [];

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
    _loadGananciasMensuales();
  }

  Future<void> _loadGananciasMensuales() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final db = FirebaseFirestore.instance;

    try {
      final categorias = ['prestamo', 'producto', 'alquiler'];
      final now = DateTime.now();
      final mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

      final monthsList = List.generate(12, (i) {
        final m = now.month - 11 + i;
        final y = now.year + (m <= 0 ? -1 : 0);
        final mesCorregido = (m <= 0) ? m + 12 : m;
        return DateTime(y, mesCorregido, 1);
      });

      final Map<String, int> porMes = {
        for (final m in monthsList) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0
      };

      for (final cat in categorias) {
        final ref = db
            .collection('prestamistas')
            .doc(user.uid)
            .collection('estadisticas')
            .doc(cat);

        final doc = await ref.get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final historico = data['historialGanancias'] as Map<String, dynamic>?;

          if (historico != null) {
            historico.forEach((k, v) {
              if (porMes.containsKey(k)) {
                porMes[k] = (porMes[k] ?? 0) + (v is int ? v : 0);
              }
            });
          }
        }
      }

      pagosMes = [];
      pagosMesLabels = [];

      for (final m in monthsList) {
        final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
        pagosMes.add(porMes[key] ?? 0);
        pagosMesLabels.add(mesesTxt[m.month - 1]);
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error cargando ganancias mensuales: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _rd(int v) {
    final f = NumberFormat.decimalPattern('es');
    final formatted = f.format(v);
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

    if (mounted) {
      setState(() {
        _displayedTotal = 0;
        _reiniciarGrafico = true;
      });
    }
  }

  void _mostrarBannerConfirmacion() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          GestureDetector(
            onTap: () => entry.remove(),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.95, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              builder: (context, scale, _) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.75),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.1), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 35,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFD4A017),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 15,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Confirmar acción',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '¿Seguro que deseas borrar todas las ganancias totales?',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 15.5,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor:
                                  Colors.white.withOpacity(0.08),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 18),
                                ),
                                onPressed: () => entry.remove(),
                                child: Text(
                                  'Cancelar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 6,
                                  backgroundColor: const Color(0xFFDC2626),
                                  shadowColor: Colors.redAccent.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 18),
                                ),
                                onPressed: () async {
                                  entry.remove();
                                  await _borrarGananciasTotales();
                                },
                                child: Text(
                                  'Sí, borrar',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    overlay.insert(entry);
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
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
              if (snap.connectionState == ConnectionState.active) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _loadGananciasMensuales();
                });
              }

              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              int ganPrestamo = 0,
                  ganProducto = 0,
                  ganAlquiler = 0;
              for (var doc in snap.data!) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                if (doc.id == 'prestamo') ganPrestamo = data['gananciaNeta'] ?? 0;
                if (doc.id == 'producto') ganProducto = data['gananciaNeta'] ?? 0;
                if (doc.id == 'alquiler') ganAlquiler = data['gananciaNeta'] ?? 0;
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  children: [
                    // PANEL SUPERIOR
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF0F172A),
                            Color(0xFF1E3A8A),
                            Color(0xFF312E81),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
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
                            shaderCallback: (r) => const LinearGradient(
                              colors: [Color(0xFF00FFD1), Color(0xFF00B8FF)],
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
                            padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.25)),
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

                    Row(
                      children: [
                        Expanded(child: _kpi('Préstamos', ganPrestamo, Colors.blueAccent)),
                        const SizedBox(width: 10),
                        Expanded(child: _kpi('Productos', ganProducto, Colors.tealAccent)),
                        const SizedBox(width: 10),
                        Expanded(child: _kpi('Alquiler', ganAlquiler, Colors.orangeAccent)),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // =================== NUEVO GRÁFICO ===================
                    _WavesChart(),

                    const SizedBox(height: 10),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Actualizado en tiempo real',
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 35),
                    _premiumCard(),

                    const SizedBox(height: 35),
                    ElevatedButton.icon(
                      onPressed: _mostrarBannerConfirmacion,
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
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1117), Color(0xFF1E2746), Color(0xFF16213E)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00FFFF).withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF00FFFF).withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Text("\$${_rd(value)}",
              style: GoogleFonts.poppins(
                  color: color, fontWeight: FontWeight.w800, fontSize: 17)),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1B2C50),
              Color(0xFF263B80),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.25),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD700).withOpacity(0.15),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
                color: Color(0xFFFFD700),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
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
                color: Colors.white.withOpacity(0.9),
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.touch_app_rounded, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Toca para ver',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
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

// ================== NUEVO GRÁFICO DE GANANCIAS ==================
class _WavesChart extends StatelessWidget {
  const _WavesChart();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 230,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1B2C50), Color(0xFF263B80)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prestamistas')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('historial_pagos')
            .orderBy('fecha', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            // 🔸 Si no hay pagos → gráfico plano
            return const Center(
              child: Text(
                'Sin pagos registrados aún',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            );
          }

          // 🔹 Procesar datos Firestore → totales por categoría
          final List<Map<String, dynamic>> dataList = snapshot.data!.docs
              .map((e) => e.data() as Map<String, dynamic>)
              .toList();

          final Map<String, List<double>> porMes = {
            'prestamo': List.filled(12, 0),
            'producto': List.filled(12, 0),
            'alquiler': List.filled(12, 0),
          };

          for (var data in dataList) {
            final ts = data['fecha'];
            final cat = (data['categoria'] ?? '').toString().toLowerCase();
            final monto = (data['ganancia'] ?? data['totalPagado'] ?? 0);
            final valor = (monto is int) ? monto.toDouble() : (monto as double? ?? 0);
            if (ts is Timestamp) {
              final fecha = ts.toDate();
              final mesIdx = (fecha.month - 1).clamp(0, 11);
              if (cat.contains('prestamo')) porMes['prestamo']![mesIdx] += valor;
              if (cat.contains('producto')) porMes['producto']![mesIdx] += valor;
              if (cat.contains('alquiler')) porMes['alquiler']![mesIdx] += valor;
            }
          }

          final meses = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

          // ✅ Calcular maxY solo con las categorías activas
          final List<double> valoresActivos = [];
          porMes.forEach((key, lista) {
            if (lista.any((v) => v > 0)) valoresActivos.addAll(lista);
          });

          double maxY = valoresActivos.isEmpty
              ? 1000
              : valoresActivos.reduce((a, b) => a > b ? a : b) * 1.3;

// ✅ Mostrar solo líneas con valores reales
          return LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.white.withOpacity(0.06),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxY / 5,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) => Text(
                      '\$${value ~/ 1000}k',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < meses.length) {
                        return Text(
                          meses[idx],
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 11,
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                if (porMes['prestamo']!.any((v) => v > 0))
                  _lineaSuave(porMes['prestamo']!, const Color(0xFF2563EB)), // azul préstamos
                if (porMes['producto']!.any((v) => v > 0))
                  _lineaSuave(porMes['producto']!, const Color(0xFF10B981)), // verde productos
                if (porMes['alquiler']!.any((v) => v > 0))
                  _lineaSuave(porMes['alquiler']!, const Color(0xFFF59E0B)), // dorada alquiler
              ],
            ),
          );

        },
      ),
    );
  }

  LineChartBarData _lineaSuave(List<double> datos, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
          radius: 3.5,
          color: Colors.white,
          strokeWidth: 2.5,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.25),
            color.withOpacity(0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      spots: [
        for (int i = 0; i < datos.length; i++)
          FlSpot(i.toDouble(), datos[i]),
      ],
    );
  }
}
