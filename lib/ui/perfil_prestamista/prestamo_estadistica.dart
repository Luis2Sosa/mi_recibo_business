import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/ads/ads_manager.dart';
import '../../core/estadisticas_totales_service.dart';
import 'ganancia_prestamo_screen.dart';

class PanelPrestamosScreen extends StatefulWidget {



  const PanelPrestamosScreen({super.key});


  @override
  State<PanelPrestamosScreen> createState() => _PanelPrestamosScreenState();
}


class _PanelPrestamosScreenState extends State<PanelPrestamosScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> ultimosMovimientos = [];
  int clientesActivos = 0;
  double promedioPorCliente = 0;
  double totalPrestado = 0;
  List<FlSpot> graficoData = [];

  bool cargando = true;

  @override
  void initState() {
    super.initState();

    // 🚀 Esperar a que el Scaffold exista antes de llamar anuncios
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = context;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          AdsManager.showEveryFiveEntries(ctx, 'PanelPrestamos');
        }
      });
    });

    _cargarDatosSecundarios();
  }



  // ===================== 🔹 CARGAR CLIENTES Y PAGOS REALES (PRÉSTAMOS) 🔹 =====================
  Future<void> _cargarDatosSecundarios() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      // ✅ Leer total prestado de metrics/summary (seguro contra int/double)
      final summaryRef = FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      final summaryDoc = await summaryRef.get();
      final totalPrestadoFirestore = double.tryParse(
        (summaryDoc.data()?['totalCapitalPrestado'] ?? 0).toString(),
      ) ?? 0.0;

      final db = FirebaseFirestore.instance;
      final clientesSnap = await db
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .get();

      double sumaPrestado = 0;
      int activos = 0;

      // 🔹 Lista temporal para todos los movimientos
      final List<Map<String, dynamic>> movimientos = [];

      for (final c in clientesSnap.docs) {
        final data = c.data();
        final tipo = (data['tipo'] ?? '').toString().toLowerCase();
        final estado = (data['estado'] ?? '').toString().toLowerCase();

        // ✅ Solo prestamos
        if (tipo != 'prestamo') continue;

        // ✅ Solo clientes activos o al día
        final esValido = estado.contains('activo') ||
            estado.contains('al_dia') ||
            estado.contains('al día') ||
            estado.isEmpty;
        if (!esValido) continue;

        activos++;

        // ✅ Cálculo de capital prestado
        final capitalInicial =
            double.tryParse((data['capitalInicial'] ?? 0).toString()) ?? 0.0;
        final saldoActual =
            double.tryParse((data['saldoActual'] ?? 0).toString()) ?? 0.0;
        final capital = capitalInicial > 0 ? capitalInicial : saldoActual;

        sumaPrestado += capital;

        // 🔹 Pagos recientes (máximo 6)
        final pagosSnap = await c.reference
            .collection('pagos')
            .orderBy('fecha', descending: true)
            .limit(6)
            .get();

        // 🔹 Siempre agregar el registro del cliente agregado (aunque tenga pagos)
        if (data['createdAt'] != null) {
          final nombre = (data['nombre'] ?? '').toString();
          final primerNombre =
          nombre.split(' ').isNotEmpty ? nombre.split(' ')[0] : nombre;
          movimientos.add({
            'monto': 0,
            'fecha': (data['createdAt'] as Timestamp).toDate(),
            'descripcion': 'Cliente $primerNombre agregado',
            'esNuevo': true,
          });
        }

        // 🔹 Luego agregar los pagos (si existen)
        if (pagosSnap.docs.isNotEmpty) {
          for (final p in pagosSnap.docs) {
            final d = p.data();
            final nombre = (data['nombre'] ?? '').toString();
            final primerNombre =
            nombre.split(' ').isNotEmpty ? nombre.split(' ')[0] : nombre;

            movimientos.add({
              'monto': ((d['totalPagado'] ?? d['pago'] ?? 0) as num).toDouble(),
              'fecha': (d['fecha'] is Timestamp)
                  ? (d['fecha'] as Timestamp).toDate()
                  : DateTime.now(),
              'descripcion': 'Pago de $primerNombre',
              'esNuevo': false,
            });
          }
        }
      }

      // 🔹 Ordenar cronológicamente (más recientes arriba)
      movimientos.sort((a, b) => b['fecha'].compareTo(a['fecha']));

      // 🔹 Tomar solo los 3 más recientes
      ultimosMovimientos = movimientos.take(3).toList();

      // 🔹 Tomar los 3 más recientes, pero permitir rotación del cliente agregado
      ultimosMovimientos = [];

      for (final mov in movimientos) {
        // agregamos en orden descendente (ya están ordenados)
        ultimosMovimientos.add(mov);
        if (ultimosMovimientos.length >= 3) break;
      }


      // 🔹 Datos para gráfico
      final serie = movimientos.take(6).toList();
      final puntos = <FlSpot>[];
      double x = 0;
      for (final e in serie) {
        x += 1;
        puntos.add(FlSpot(x, ((e['monto'] ?? 0) as num).toDouble()));
      }

      if (puntos.isEmpty) {
        puntos.add(const FlSpot(1, 0));
        puntos.add(FlSpot(2, sumaPrestado));
      }

      // ✅ Actualizar estado
      setState(() {
        clientesActivos = activos;
        totalPrestado = totalPrestadoFirestore;
        promedioPorCliente = activos > 0 ? (sumaPrestado / activos) : 0;
        graficoData = puntos;
        cargando = false;
      });

      debugPrint("✅ Total préstamos: $totalPrestado");
      debugPrint("✅ Clientes activos: $clientesActivos");
      debugPrint("✅ Promedio: $promedioPorCliente");
    } catch (e) {
      debugPrint("❌ Error cargando préstamos reales: $e");
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
        backgroundColor: Color(0xFF081633),
        body: Center(
          child: Text("Inicia sesión para ver tus estadísticas",
              style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF081633),
      body: SafeArea(
        bottom: false, // 👈 evita el overflow por la barra del sistema
        child: cargando
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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

                _tile("Total prestado", _fmt(totalPrestado), const Color(0xFF38BDF8)),
                const SizedBox(height: 10),
                _tile("Clientes activos", "$clientesActivos", const Color(0xFF38BDF8)),
                const SizedBox(height: 10),
                _tile("Promedio por cliente", _fmt(promedioPorCliente), const Color(0xFF38BDF8)),


                const SizedBox(height: 20),
                _graficoCard(),
                const SizedBox(height: 20),

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

                GestureDetector(
                  onTap: () {
                    final uid = _auth.currentUser!.uid;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GananciaPrestamoScreen(
                          docPrest: FirebaseFirestore.instance
                              .collection('prestamistas')
                              .doc(uid),
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
                            Color(0xFF00E5FF),
                            Color(0xFF007CF0),
                            Color(0xFF4318FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [

                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.auto_graph_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text(
                            "Ver ganancias por cliente",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black54, // 👈 sombra sutil que mejora el contraste
                                ),
                              ],
                            ),
                          ),

                        ],
                      ),
                    ),
                  ),

                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
      ),
      )
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
  Widget _graficoCard() {
    final tienePrestamos = totalPrestado > 0 && clientesActivos > 0;
    final Color color = tienePrestamos ? Colors.lightBlueAccent : Colors.amberAccent;
    final String mensaje = tienePrestamos
        ? "Flujo de pagos reciente. 💸"
        : "Todavía no tienes préstamos activos.\nAgrega uno y empieza a generar ganancias.";

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
                    tienePrestamos
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
            // 🌊 Nuevo gráfico animado de onda
            SizedBox(
              height: 160,
              width: double.infinity,
              child: _AnimatedGrowthBackgroundVisible(totalPrestado),
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
        // 🔸 Si no hay movimientos
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
        // 🔸 Mostrar las 3 tarjetas dinámicas
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
                    color: Colors.blueAccent.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 🔹 Lado izquierdo: icono y descripción
                  Row(
                    children: [
                      Icon(
                        esNuevo
                            ? Icons.person_add_alt_1_rounded
                            : Icons.arrow_downward_rounded,
                        color: esNuevo
                            ? Colors.amberAccent
                            : Colors.lightGreenAccent,
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

                  // 🔹 Lado derecho: monto (solo si no es cliente nuevo) y fecha
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
// 🌊 ANIMACIÓN SUAVE DE CRECIMIENTO (SERPIENTE REAL)
// ======================================================
class _AnimatedGrowthBackground extends StatefulWidget {
  final double cambio;
  const _AnimatedGrowthBackground(this.cambio);

  @override
  State<_AnimatedGrowthBackground> createState() =>
      _AnimatedGrowthBackgroundState();
}

class _AnimatedGrowthBackgroundState extends State<_AnimatedGrowthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // 🐍 control continuo de la "serpiente"
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // más natural
    )..repeat();
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
        // 🐍 elevación suave (sube y baja tipo respiración)
        final double elevacion = sin(_controller.value * pi) * 8;

        return CustomPaint(
          painter: _WavePainter(
            progress: _controller.value,
            cambio: widget.cambio,
            elevacion: elevacion, // 👈 aquí pasa la elevación
          ),
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

// ======================================================
// 🎨 PINTOR DE ONDA (SERPIENTE VIVA)
// ======================================================
class _WavePainter extends CustomPainter {
  final double progress;
  final double cambio;
  final double elevacion; // 🆕 controla la subida

  _WavePainter({
    required this.progress,
    required this.cambio,
    this.elevacion = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final midY = size.height / 2;
    const amplitude = 10.0;
    const frequency = 1.3;

    final Color colorBase = cambio > 0
        ? const Color(0xFF00E676)
        : cambio < 0
        ? const Color(0xFFFF5252)
        : const Color(0xFF64B5F6);

    // 🐍 la serpiente sube y baja desde la izquierda
    for (double x = 0; x <= size.width; x++) {
      final y = midY -
          (sin(x / size.width * pi) * elevacion) + // movimiento serpiente
          sin((x / size.width * frequency * 2 * pi) + (progress * 2 * pi)) *
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

// ======================================================
// 💫 ENVOLTORIO SIMPLE PARA BORDES REDONDEADOS
// ======================================================
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


