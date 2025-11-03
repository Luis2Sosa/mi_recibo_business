// lib/ui/perfil_prestamista/alquiler_estadistica.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/estadisticas_totales_service.dart';
import 'ganancia_clientes_screen.dart';

class AlquilerEstadisticaScreen extends StatefulWidget {
  const AlquilerEstadisticaScreen({super.key});

  @override
  State<AlquilerEstadisticaScreen> createState() =>
      _AlquilerEstadisticaScreenState();
}

class _AlquilerEstadisticaScreenState
    extends State<AlquilerEstadisticaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> ultimosMovimientos = [];
  int clientesActivos = 0;
  double promedioPorCliente = 0;
  double totalAlquilado = 0;
  List<FlSpot> graficoData = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosAlquiler();
  }

  // ===================== 🔹 CARGAR CLIENTES Y PAGOS REALES (ALQUILER) 🔹 =====================
  Future<void> _cargarDatosAlquiler() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // ✅ Leer total alquilado directamente desde metrics/summary
      final summaryRef = FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      final summaryDoc = await summaryRef.get();

      final totalAlquiladoFirestore = double.tryParse(
        (summaryDoc.data()?['totalCapitalAlquilado'] ?? 0).toString(),
      ) ?? 0.0;

      final db = FirebaseFirestore.instance;
      final clientesSnap = await db
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .get();

      double sumaAlquilado = 0;
      int activos = 0;
      final List<Map<String, dynamic>> pagos = [];

      for (final c in clientesSnap.docs) {
        final data = c.data();
        final tipo = (data['tipo'] ?? '').toString().toLowerCase();
        final estado = (data['estado'] ?? '').toString().toLowerCase();

        // ✅ Solo tipo alquiler
        if (tipo != 'alquiler') continue;

        final esValido = estado.contains('activo') ||
            estado.contains('al_dia') ||
            estado.contains('al día') ||
            estado.contains('saldado') ||
            estado.isEmpty;

        if (!esValido) continue;

        activos++;

        final capital = ((data['capitalInicial'] ?? 0) as num).toDouble();
        sumaAlquilado += capital;

        // 🔹 Pagos recientes
        final pagosSnap = await c.reference
            .collection('pagos')
            .orderBy('fecha', descending: true)
            .limit(6)
            .get();

        for (final p in pagosSnap.docs) {
          final d = p.data();
          final nombre = (data['nombre'] ?? '').toString();
          final primerNombre =
          nombre.split(' ').isNotEmpty ? nombre.split(' ')[0] : nombre;

          pagos.add({
            'monto': ((d['totalPagado'] ?? d['pago'] ?? 0) as num).toDouble(),
            'fecha': (d['fecha'] is Timestamp)
                ? (d['fecha'] as Timestamp).toDate()
                : DateTime.now(),
            'descripcion': 'Pago de $primerNombre',
          });
        }

        // 🔸 Si no hay pagos, mostrar registro de creación
        if (pagosSnap.docs.isEmpty && data['createdAt'] != null) {
          final nombre = (data['nombre'] ?? '').toString();
          final primerNombre =
          nombre.split(' ').isNotEmpty ? nombre.split(' ')[0] : nombre;
          pagos.add({
            'monto': 0,
            'fecha': (data['createdAt'] as Timestamp).toDate(),
            'descripcion': 'Cliente $primerNombre agregado',
            'esNuevo': true,
          });
        }
      }

      pagos.sort((a, b) => b['fecha'].compareTo(a['fecha']));
      ultimosMovimientos = pagos.take(3).toList();

      // 🔹 Datos para gráfico
      final serie = pagos.take(6).toList();
      final puntos = <FlSpot>[];
      double x = 0;
      for (final e in serie) {
        x += 1;
        puntos.add(FlSpot(x, ((e['monto'] ?? 0) as num).toDouble()));
      }

      if (puntos.isEmpty) {
        puntos.add(const FlSpot(1, 0));
        puntos.add(FlSpot(2, sumaAlquilado));
      }

      setState(() {
        clientesActivos = activos;

        // 🔹 El total alquilado viene del resumen (igual que productos)
        totalAlquilado = totalAlquiladoFirestore;

        // 🔹 Promedio por cliente
        promedioPorCliente = activos > 0 ? (sumaAlquilado / activos) : 0;

        graficoData = puntos;
        cargando = false;
      });

      debugPrint("✅ Total alquilado: $totalAlquilado");
      debugPrint("✅ Clientes activos: $clientesActivos");
      debugPrint("✅ Promedio: $promedioPorCliente");
    } catch (e) {
      debugPrint("❌ Error cargando alquileres: $e");
      setState(() => cargando = false);
    }
  }




  // ===================== 🔹 FORMATO MONEDA 🔹 =====================
  String _fmt(num valor) {
    final f =
    NumberFormat.currency(locale: 'es_DO', symbol: '\$', decimalDigits: 0);
    return f.format(valor);
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF281E14),
        body: Center(
          child: Text("Inicia sesión para ver tus estadísticas",
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF281E14),
      body: SafeArea(
        child: cargando
            ? const Center(
            child: CircularProgressIndicator(color: Colors.amberAccent))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ======== ENCABEZADO ========
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "🏠 Rendimiento alquiler",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFD700),
                            Color(0xFFF59E0B)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: const Text(
                        "LIVE",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ======== TARJETAS KPI ========
                _tile("Total alquilado", _fmt(totalAlquilado),
                    const Color(0xFFFFD700)),
                const SizedBox(height: 10),
                _tile("Clientes activos", "$clientesActivos",
                    const Color(0xFFFBBF24)),
                const SizedBox(height: 10),
                _tile("Promedio por cliente", _fmt(promedioPorCliente),
                    const Color(0xFFFFA500)),

                const SizedBox(height: 20),
                _graficoCard(),
                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "🧾 Últimos movimientos",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _movimientosCard(),
                const SizedBox(height: 20),

                // ======== BOTÓN FINAL ========
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GananciaClientesScreen(
                          docPrest: FirebaseFirestore.instance
                              .collection('prestamistas')
                              .doc(uid),
                          tipo: GananciaTipo.alquiler,
                        ),
                      ),
                    );
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF59E0B),
                            Color(0xFFFFC107),
                            Color(0xFFFFE066),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orangeAccent.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_graph_rounded,
                              color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            "Ver ganancias por cliente",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= TARJETA KPI =================
  Widget _tile(String titulo, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.12), Colors.white.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Icon(Icons.circle, color: color, size: 10),
            const SizedBox(width: 10),
            Text(
              titulo,
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ]),
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ================= GRÁFICO =================
  Widget _graficoCard() {
    final tieneAlquileres = totalAlquilado > 0 && clientesActivos > 0;
    final Color color =
    tieneAlquileres ? Colors.amberAccent : Colors.orangeAccent;
    final String mensaje = tieneAlquileres
        ? "Flujo de pagos reciente. 💸"
        : "Todavía no tienes alquileres activos.\nAgrega uno y empieza a generar ingresos.";

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          border: Border.all(color: Colors.white.withOpacity(.25)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tieneAlquileres
                        ? Icons.trending_up_rounded
                        : Icons.lightbulb_outline_rounded,
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    mensaje,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      fontSize: 14.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _AnimatedGrowthBackgroundVisible(totalAlquilado),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MOVIMIENTOS =================
  Widget _movimientosCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ultimosMovimientos.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.25)),
              ),
              child: const Text(
                "No hay movimientos recientes.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          )
        else
          ...ultimosMovimientos.take(3).map((m) {
            final fecha = DateFormat('dd/MM/yyyy').format(m['fecha']);
            final monto = _fmt(m['monto']);
            final esNuevo = m['esNuevo'] == true;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white.withOpacity(0.1),
                border: Border.all(color: Colors.white.withOpacity(.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orangeAccent.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        esNuevo
                            ? Icons.person_add_alt_1_rounded
                            : Icons.arrow_downward_rounded,
                        color:
                        esNuevo ? Colors.amberAccent : Colors.orangeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        m['descripcion'] ??
                            (esNuevo ? "Cliente agregado" : "Pago"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!esNuevo) ...[
                        Text(
                          monto,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        fecha,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

// ======================================================
// 🌊 ANIMACIÓN SUAVE DE CRECIMIENTO (DORADO)
// ======================================================
class _AnimatedGrowthBackground extends StatefulWidget {
  final double cambio;
  const _AnimatedGrowthBackground(this.cambio);

  @override
  State<_AnimatedGrowthBackground> createState() =>
      _AnimatedGrowthBackgroundState();
}

class _AnimatedGrowthBackgroundState
    extends State<_AnimatedGrowthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
    AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double elevacion = sin(_controller.value * pi) * 8;
        return CustomPaint(
          painter: _WavePainter(
              progress: _controller.value,
              cambio: widget.cambio,
              elevacion: elevacion),
          child: Container(
            height: 160,
            width: double.infinity,
            color: Colors.transparent,
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final double cambio;
  final double elevacion;

  _WavePainter(
      {required this.progress, required this.cambio, this.elevacion = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final midY = size.height / 2;
    const amplitude = 10.0;
    const frequency = 1.3;

    final Color colorBase = const Color(0xFFFFC107);

    for (double x = 0; x <= size.width; x++) {
      final y = midY -
          (sin(x / size.width * pi) * elevacion) +
          sin((x / size.width * frequency * 2 * pi) +
              (progress * 2 * pi)) *
              amplitude;
      if (x == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          colorBase.withOpacity(0.3),
          colorBase.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = colorBase.withOpacity(0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AnimatedGrowthBackgroundVisible extends StatelessWidget {
  final double cambio;
  const _AnimatedGrowthBackgroundVisible(this.cambio);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: _AnimatedGrowthBackground(cambio),
    );
  }
}
