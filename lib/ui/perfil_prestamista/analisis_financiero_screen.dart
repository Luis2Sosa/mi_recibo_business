import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';

class AnalisisFinancieroScreen extends StatefulWidget {
  final dynamic docPrest;
  const AnalisisFinancieroScreen({super.key, required this.docPrest});

  @override
  State<AnalisisFinancieroScreen> createState() =>
      _AnalisisFinancieroScreenState();
}

class _AnalisisFinancieroScreenState extends State<AnalisisFinancieroScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _glowController;
  late AnimationController _fadeController;
  late AnimationController _chartController;
  double _progress = 0;
  String _mensajeActual = "Analizando tus métricas...";

  final List<String> _mensajes = [
    "Analizando tu rendimiento financiero...",
    "Optimizando tus métricas de crecimiento...",
    "Procesando tus ingresos y flujos...",
    "Preparando tu Potenciador Premium..."
  ];

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(() {
      setState(() {
        _progress = _progressController.value * 100;
      });
    });
    _progressController.forward();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28), // lento y elegante
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    int index = 0;
    Timer.periodic(const Duration(milliseconds: 1300), (timer) {
      if (!mounted) return;
      setState(() => _mensajeActual = _mensajes[index % _mensajes.length]);
      index++;
      if (_progress >= 100) timer.cancel();
    });

    Future.delayed(const Duration(milliseconds: 1800), () async {
      await _fadeController.forward();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 900),
            pageBuilder: (_, __, ___) =>
                PremiumBoostsScreen(docPrest: widget.docPrest),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    _chartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = (_glowController.value * 8);

    return Scaffold(
      backgroundColor: const Color(0xFF07111E),
      body: Stack(
        children: [
          // 🌌 Fondo animado que cubre toda la pantalla
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _chartController,
              builder: (_, __) => CustomPaint(
                size: Size.infinite,
                painter: _FinancialChartPainter(_chartController.value),
              ),
            ),
          ),

          // ✨ Degradado de profundidad premium
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF07111E).withOpacity(0.88),
                    const Color(0xFF07111E).withOpacity(0.70),
                    const Color(0xFF07111E).withOpacity(0.88),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // 🎯 Tarjeta central premium
          Center(
            child: FadeTransition(
              opacity: Tween(begin: 1.0, end: 0.0).animate(_fadeController),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 38),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2C50), Color(0xFF2A237E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 45,
                      offset: const Offset(0, 25),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono dinámico con resplandor profesional
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, __) => Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withOpacity(0.35 + _glowController.value * 0.3),
                              blurRadius: 25 + glow,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_graph_rounded,
                            size: 70, color: Color(0xFF00E5FF)),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Analizando tus estadísticas financieras...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _mensajeActual,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(.75),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Barra de progreso con brillo elegante
                    Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 10,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          height: 10,
                          width: (MediaQuery.of(context).size.width * 0.7) *
                              (_progress / 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00E5FF),
                                Color(0xFF76FF03),
                                Color(0xFFFFD700),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withOpacity(0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Text(
                      '${_progress.toInt()}%',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 20),

                    AnimatedOpacity(
                      opacity: _progress >= 90 ? 1 : 0,
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        '✨ Preparando análisis detallado...',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFFD700),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 📊 Fondo financiero animado cubriendo toda la pantalla
class _FinancialChartPainter extends CustomPainter {
  final double progress;
  final Paint _paintLine = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2
    ..strokeCap = StrokeCap.round;

  _FinancialChartPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final colores = [
      const Color(0xFF00E5FF),
      const Color(0xFF76FF03),
      const Color(0xFFFFD700),
    ];
    final waveHeight = 65.0; // amplitud más visible
    final speed = progress * 2 * pi;

    for (int i = 0; i < 4; i++) {
      final path = Path();
      final baseY = size.height * (0.15 + i * 0.25);
      final color = colores[i % colores.length].withOpacity(0.3);

      for (double x = 0; x <= size.width; x++) {
        final y = baseY +
            sin((x / size.width * 3.2 * pi) + speed + (i * 1.6)) * waveHeight;
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      _paintLine.shader = LinearGradient(
        colors: [color.withOpacity(0.6), color.withOpacity(0.05)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(path, _paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
