// lib/ui/premium/pantalla_bienvenida_premium.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mi_recibo/ui/perfil_prestamista/ganancias_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PantallaBienvenidaPremium extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const PantallaBienvenidaPremium({super.key, required this.docPrest});

  @override
  State<PantallaBienvenidaPremium> createState() =>
      _PantallaBienvenidaPremiumState();
}

class _PantallaBienvenidaPremiumState extends State<PantallaBienvenidaPremium>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _progress = 0;
  bool _mostrarBoton = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Control de partículas suaves
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Simula progreso real
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (_progress < 1.0) {
        setState(() {
          _progress += 0.01;
        });
      } else {
        setState(() {
          _mostrarBoton = true;
        });
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0A0F1F), // 🌌 FONDO FIJO GALÁXIA
      body: Stack(
        children: [
          // ✨ Partículas flotando lentas
          AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: _GalaxyPainter(progress: _controller.value),
                size: Size.infinite,
              );
            },
          ),

          // 🌟 Contenido central
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🔸 Ícono Premium central
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E1E1E), Color(0xFF2E2E2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.workspace_premium_rounded,
                          color: Colors.white, size: 60),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 🏆 Título
                  Text(
                    'Bienvenido a Mi Recibo Premium',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✨ Subtítulo
                  Text(
                    'Disfruta de un entorno sin anuncios, acceso total a tus estadísticas y estrategias financieras exclusivas.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 50),

                  // 💫 Tarjeta con progreso
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF202540), Color(0xFF2D1C50)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_graph_rounded,
                                color: Colors.lightBlueAccent, size: 22),
                            SizedBox(width: 6),
                            Text(
                              "Analizando tus estadísticas financieras...",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: LinearProgressIndicator(
                            value: _progress,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFFFFD700)),
                            backgroundColor: Colors.white.withOpacity(0.1),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  // 🔘 Botón aparece al 100%
                  AnimatedOpacity(
                    opacity: _mostrarBoton ? 1 : 0,
                    duration: const Duration(milliseconds: 800),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                GananciasScreen(docPrest: widget.docPrest),
                          ),
                        );
                      },
                      child: Container(
                        width: width * 0.7,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(45),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD700),
                              Color(0xFFF4C10F),
                              Color(0xFFE0AA3E),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          'Continuar',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================================
// 🌌 PINTOR GALÁCTICO DE PARTÍCULAS PREMIUM (FONDO FIJO)
// ==========================================================
class _GalaxyPainter extends CustomPainter {
  final double progress;
  _GalaxyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = Random(42);

    for (int i = 0; i < 90; i++) {
      final x = random.nextDouble() * size.width;
      final y = (random.nextDouble() * size.height +
          (sin(progress * pi * 2 + i) * 40)) %
          size.height;
      final radius = random.nextDouble() * 2.2 + 0.8;

      final color = [
        Colors.white,
        Colors.lightBlueAccent,
        Colors.amberAccent,
        Colors.blue.shade100
      ][i % 4]
          .withOpacity(0.3 + random.nextDouble() * 0.4);

      paint.color = color;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) => true;
}
