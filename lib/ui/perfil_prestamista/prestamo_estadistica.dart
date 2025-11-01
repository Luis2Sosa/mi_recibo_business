import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'ganancia_clientes_screen.dart';

class PanelPrestamosScreen extends StatefulWidget {
  const PanelPrestamosScreen({super.key});

  @override
  State<PanelPrestamosScreen> createState() => _PanelPrestamosScreenState();
}

class _PanelPrestamosScreenState extends State<PanelPrestamosScreen> {
  double totalPrestado = 0;
  int clientesActivos = 0;
  double promedioPorCliente = 0;
  List<Map<String, dynamic>> ultimosMovimientos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // ===================== 🔹 CARGAR DATOS REALES 🔹 =====================
  Future<void> _cargarDatos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      double total = 0;
      int activos = 0;
      List<Map<String, dynamic>> movimientos = [];

      final clientesSnap = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .where('tipo', isEqualTo: 'prestamo') // 🔹 solo prestamos
          .where('estado', whereIn: ['activo', 'al_dia']) // 🔹 activos
          .get();

      for (final cliente in clientesSnap.docs) {
        final data = cliente.data();
        final saldo = (data['saldoActual'] ?? 0).toDouble();

        if (saldo > 0) {
          total += saldo;
          activos++;

          // 🔹 Últimos pagos (solo si existen)
          final pagosSnap = await cliente.reference
              .collection('pagos')
              .orderBy('fecha', descending: true)
              .limit(3)
              .get();

          for (final p in pagosSnap.docs) {
            final pData = p.data();
            if (pData.containsKey('totalPagado')) {
              movimientos.add({
                'tipo': 'Pago',
                'monto': (pData['totalPagado'] ?? 0).toDouble(),
                'fecha': (pData['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
              });
            }
          }
        }
      }

      movimientos.sort((a, b) => b['fecha'].compareTo(a['fecha']));
      final ultimos3 = movimientos.take(3).toList();

      setState(() {
        totalPrestado = total;
        clientesActivos = activos;
        promedioPorCliente = activos > 0 ? total / activos : 0;
        ultimosMovimientos = ultimos3;
        cargando = false;
      });
    } catch (e) {
      debugPrint("❌ Error cargando datos reales: $e");
      setState(() => cargando = false);
    }
  }

  // ===================== 🔹 FORMATO MONEDA 🔹 =====================
  String _fmt(num valor) {
    final f = NumberFormat.currency(
      locale: 'es_DO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return f.format(valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081633),
      body: SafeArea(
        child: cargando
            ? const Center(
            child: CircularProgressIndicator(color: Colors.white))
            : Padding(
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
                    "📊 Rendimiento préstamo",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00FFFF), Color(0xFF007CF0)],
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
              _tile("Total prestado", _fmt(totalPrestado),
                  const Color(0xFF00E5FF)),
              const SizedBox(height: 10),
              _tile("Clientes activos", "$clientesActivos",
                  const Color(0xFFFFD700)),
              const SizedBox(height: 10),
              _tile("Promedio por cliente", _fmt(promedioPorCliente),
                  const Color(0xFFFF8C00)),

              const SizedBox(height: 15),

              // ======== GRAFICO PREMIUM ========
              _alertaConGrafico(),

              const SizedBox(height: 10),

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

              const SizedBox(height: 15),

              // ======== BOTÓN FINAL ========
              GestureDetector(
                onTap: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GananciaClientesScreen(
                        docPrest: FirebaseFirestore.instance
                            .collection('prestamistas')
                            .doc(uid),
                        tipo: GananciaTipo.prestamo,
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
                        Color(0xFF00E5FF),
                        Color(0xFF007CF0),
                        Color(0xFF4318FF)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.4),
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
  Widget _alertaConGrafico() {
    String mensaje;
    IconData icono;
    Color color;

    if (clientesActivos == 0) {
      mensaje =
      "Todavía no tienes préstamos activos.\nAgrega uno nuevo y empieza a generar ganancias.";
      icono = Icons.lightbulb_outline_rounded;
      color = Colors.amberAccent;
    } else if (totalPrestado == 0) {
      mensaje = "Sin préstamos activos actualmente. 💤";
      icono = Icons.pause_circle_outline_rounded;
      color = Colors.grey;
    } else {
      mensaje = "Tu flujo de préstamos es estable. 💰 ¡Sigue así!";
      icono = Icons.trending_up_rounded;
      color = Colors.lightGreenAccent;
    }

    final puntos = ultimosMovimientos.isNotEmpty
        ? ultimosMovimientos.asMap().entries.map((e) {
      return FlSpot(
        e.key.toDouble(),
        (e.value['monto'] as num).toDouble(),
      );
    }).toList()
        : [const FlSpot(0, 0)];

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
                      spots: puntos,
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
        final tipo = m['tipo'];
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
              Row(children: [
                Icon(Icons.arrow_downward,
                    color: Colors.lightGreenAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  tipo,
                  style: const TextStyle(
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
                  style:
                  const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ]),
            ],
          ),
        );
      }).toList(),
    );
  }
}
