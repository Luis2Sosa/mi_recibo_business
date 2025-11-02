// lib/ui/perfil_prestamista/alquiler_estadistica.dart
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
  State<AlquilerEstadisticaScreen> createState() => _AlquilerEstadisticaScreenState();
}

class _AlquilerEstadisticaScreenState extends State<AlquilerEstadisticaScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> ultimosMovimientos = [];
  int clientesActivos = 0;
  double promedioPorCliente = 0;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosSecundarios();
  }

  // ===================== 🔹 CARGAR CLIENTES Y PAGOS DE ALQUILER 🔹 =====================
  Future<void> _cargarDatosSecundarios() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final clientesSnap = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .where('tipo', isEqualTo: 'alquiler')
          .where('estado', whereIn: ['activo', 'al_dia'])
          .get();

      clientesActivos = clientesSnap.docs.length;

      // 🔹 Últimos pagos de clientes de tipo alquiler
      List<Map<String, dynamic>> pagos = [];
      for (final cliente in clientesSnap.docs) {
        final pagosSnap = await cliente.reference
            .collection('pagos')
            .orderBy('fecha', descending: true)
            .limit(3)
            .get();
        for (final p in pagosSnap.docs) {
          final d = p.data();
          pagos.add({
            'monto': (d['totalPagado'] ?? 0).toDouble(),
            'fecha': (d['fecha'] is Timestamp)
                ? (d['fecha'] as Timestamp).toDate()
                : DateTime.now(),
          });
        }
      }

      pagos.sort((a, b) => b['fecha'].compareTo(a['fecha']));
      ultimosMovimientos = pagos.take(3).toList();

      setState(() => cargando = false);
    } catch (e) {
      debugPrint("❌ Error cargando clientes/pagos (alquiler): $e");
      setState(() => cargando = false);
    }
  }

  // ===================== 🔹 FORMATO MONEDA 🔹 =====================
  String _fmt(num valor) {
    final f = NumberFormat.currency(locale: 'es_DO', symbol: '\$', decimalDigits: 0);
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
            ? const Center(child: CircularProgressIndicator(color: Colors.orange))
            : StreamBuilder<Map<String, dynamic>?>(
          stream: EstadisticasTotalesService.listenSummary(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.orange));
            }

            final data = snapshot.data ?? {};
            final totalAlquilado =
            (data['totalCapitalPrestado'] ?? 0).toDouble();
            final totalPendiente =
            (data['totalCapitalPendiente'] ?? 0).toDouble();
            final totalRecuperado =
            (data['totalCapitalRecuperado'] ?? 0).toDouble();

            promedioPorCliente =
            clientesActivos > 0 ? totalAlquilado / clientesActivos : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                            colors: [Color(0xFFFFD700), Color(0xFFF59E0B)],
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
                      const Color(0xFFF59E0B)),
                  const SizedBox(height: 10),
                  _tile("Clientes activos", "$clientesActivos",
                      const Color(0xFFFFE066)),
                  const SizedBox(height: 10),
                  _tile("Promedio por cliente", _fmt(promedioPorCliente),
                      const Color(0xFFFF8C00)),

                  const SizedBox(height: 20),

                  // ======== GRÁFICO Y MENSAJE ========
                  _alertaConGrafico(totalAlquilado, totalRecuperado, totalPendiente),

                  const SizedBox(height: 20),

                  // ======== ÚLTIMOS MOVIMIENTOS ========
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "🔄 Últimos movimientos",
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFF59E0B),
                            Color(0xFFFFC107),
                            Color(0xFFFFE066)
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
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
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

  // ================= GRÁFICO Y MENSAJE =================
  Widget _alertaConGrafico(double total, double recuperado, double pendiente) {
    String mensaje;
    IconData icono;
    Color color;

    if (total == 0) {
      mensaje = "Todavía no tienes alquileres activos.\nAgrega uno nuevo y empieza a generar ingresos.";
      icono = Icons.lightbulb_outline_rounded;
      color = Colors.amberAccent;
    } else if (pendiente <= 0) {
      mensaje = "Todos los alquileres han sido cobrados. 🏆";
      icono = Icons.check_circle_outline_rounded;
      color = Colors.lightGreenAccent;
    } else {
      mensaje = "Tu flujo de alquileres es estable. 💸 ¡Sigue así!";
      icono = Icons.trending_up_rounded;
      color = Colors.orangeAccent;
    }

    final progreso = total > 0 ? (recuperado / total) * 100 : 0.0;

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
                  child: Icon(icono, color: color, size: 26),
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
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 0),
                        FlSpot(1, progreso),
                      ],
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.4),
                            color.withOpacity(0.0)
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= MOVIMIENTOS =================
  Widget _movimientosCard() {
    if (ultimosMovimientos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.25)),
        ),
        child: const Text(
          "No hay movimientos recientes.",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: ultimosMovimientos.map((m) {
        final fecha = DateFormat('dd/MM/yyyy').format(m['fecha']);
        final monto = _fmt(m['monto']);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.1),
            border: Border.all(color: Colors.white.withOpacity(.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: const [
                Icon(Icons.arrow_downward,
                    color: Colors.orangeAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  "Pago",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
              ]),
              Row(children: [
                Text(
                  monto,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  fecha,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ]),
            ],
          ),
        );
      }).toList(),
    );
  }
}
