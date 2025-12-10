import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui';

import 'analisis_financiero_screen.dart'; // 👈 importante para el desenfoque


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

// Banner premium elegante con blur y sin líneas amarillas
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.9, end: 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, scale, _) {
                return Transform.scale(
                  scale: scale,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF22C55E), // ✅ verde éxito (se nota más sobre el fondo oscuro)
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Ganancias totales reiniciadas correctamente',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF22C55E), // ✅ mismo verde, coherente y elegante
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

// Mostrar de inmediato y quitar tras 3 segundos
    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry.remove();
    });



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

    // Controlador que escucha el botón atrás
    entry = OverlayEntry(
      builder: (context) {
        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            entry.remove(); // 🔹 Se quita cuando el usuario da atrás
          },
          child: Stack(
            children: [
              // Fondo oscuro con blur
              GestureDetector(
                onTap: () => entry.remove(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withOpacity(0.55)),
                ),
              ),

              // Banner premium
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.92, end: 1),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  builder: (context, scale, _) {
                    return Transform.scale(
                      scale: scale,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.85,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF0F172A).withOpacity(0.90),
                              const Color(0xFF1E3A8A).withOpacity(0.85),
                              const Color(0xFF2B2D91).withOpacity(0.82),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            width: 1.3,
                            color: const Color(0xFFFFD700).withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withOpacity(0.25),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ícono dorado
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD700), Color(0xFFFFB347)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.yellowAccent.withOpacity(0.35),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: Colors.white,
                                size: 46,
                              ),
                            ),

                            const SizedBox(height: 22),
                            Text(
                              'Confirmar reinicio de ganancias',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 19.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Esta acción reiniciará tus ganancias totales acumuladas en todas las categorías. '
                                  'No se eliminarán clientes ni pagos registrados. Solo se pondrán a cero los montos acumulados.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Botones
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: Colors.white.withOpacity(0.07),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.15),
                                          width: 1.2,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 18),
                                    ),
                                    onPressed: () => entry.remove(),
                                    child: Text(
                                      'Cancelar',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      elevation: 8,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 18),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      backgroundColor: const Color(0xFFFFD700),
                                      shadowColor:
                                      const Color(0xFFFFD700).withOpacity(0.4),
                                    ),
                                    onPressed: () async {
                                      entry.remove();
                                      await _borrarGananciasTotales();
                                    },
                                    child: Text(
                                      'Sí, reiniciar',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w800,
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
      },
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
        automaticallyImplyLeading: false,   // 👈 IMPORTANTE
        centerTitle: true,                   // 👈 CENTRADO
        title: Text(
          'Ganancias Totales',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 20,                    // 🔥 un poquito más grande
            letterSpacing: 0.3,              // 🔥 más elegante
          ),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(), // ✅ SCROLL PROFESIONAL ANDROID

                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                          child: Column(

                          mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // PANEL SUPERIOR — NUEVO DISEÑO PREMIUM MINIMALISTA
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),

                                  // 🎨 Fondo sobrio y elegante
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFF101C3D),
                                      Color(0xFF182A5C),
                                    ],
                                  ),

                                  // 🎨 Borde suave profesional
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1.2,
                                  ),

                                  // 🎨 Sombra premium suave
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.40),
                                      blurRadius: 20,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),

                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 📌 Título
                                    Text(
                                      'Balance Total',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    // 📌 MONTO con degradado premium
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFF00E7D6), // Turquesa premium
                                          Color(0xFF00A8FF), // Azul financiero
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ).createShader(bounds),
                                      blendMode: BlendMode.srcIn,
                                      child: Text(
                                        "\$${_rd(_displayedTotal)}",
                                        style: GoogleFonts.poppins(
                                          fontSize: 48,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white, // requerido para el ShaderMask
                                          letterSpacing: -1,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // 📌 Chip “En crecimiento” minimalista
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.10),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.20)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.trending_up_rounded,
                                              color: Colors.greenAccent, size: 18),
                                          SizedBox(width: 5),
                                          Text(
                                            'En crecimiento',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),


                              const SizedBox(height: 25),

                              // KPIs
                              Row(
                                children: [
                                  Expanded(
                                      child: _kpi('Préstamos', ganPrestamo, Colors.blueAccent)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _kpi('Productos', ganProducto, Colors.tealAccent)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _kpi('Alquiler', ganAlquiler, Colors.orangeAccent)),
                                ],
                              ),

                              const SizedBox(height: 30),

                              // PREMIUM CARD
                              _premiumCard(),

                              const SizedBox(height: 35),

                              // BOTÓN DISCRETO PREMIUM
                              Builder(
                                builder: (context) {
                                  final h = MediaQuery.of(context).size.height;
                                  final esPequeno = h < 750; // 👈 mismo criterio que usas arriba

                                  return Transform.translate(
                                    offset: Offset(0, esPequeno ? -22 : 0), // ✅ SUBE SOLO EN PEQUEÑOS
                                    child: ElevatedButton.icon(
                                      onPressed: _mostrarBannerConfirmacion,
                                      icon: const Icon(Icons.delete_outline_rounded,
                                          color: Colors.white70, size: 18),
                                      label: const Text('Borrar ganancias totales'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white.withOpacity(0.08),
                                        foregroundColor: Colors.white70,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 12),
                                        textStyle: const TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 13),
                                        elevation: 0,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  'Esta acción es irreversible. Los datos se borrarán de forma permanente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
            builder: (_) => AnalisisFinancieroScreen(docPrest: widget.docPrest),
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
              'Descubre tu poder financiero diario\ncon estrategias premium para crecer más cada día.',
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFF00E5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.35),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Entrar al Potenciador',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
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
