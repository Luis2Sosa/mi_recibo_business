// 📂 lib/ui/premium/pantalla_bloqueo_premium.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mi_recibo/core/premium_service.dart';
import 'package:mi_recibo/ui/premium/pantalla_bienvenida_premium.dart';
import '../perfil_prestamista/ganancias_screen.dart';

class PantallaBloqueoPremium extends StatefulWidget {
  final String destino;

  const PantallaBloqueoPremium({
    super.key,
    required this.destino,
  });

  @override
  State<PantallaBloqueoPremium> createState() => _PantallaBloqueoPremiumState();
}

class _PantallaBloqueoPremiumState extends State<PantallaBloqueoPremium> {
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _verificarPremium();
  }

  /// 🔹 Verifica si el usuario ya es Premium al abrir la pantalla
  Future<void> _verificarPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final activo = await PremiumService().esPremiumActivo(uid);
    if (!mounted) return;

    if (activo) {
      // 🚀 Ya tiene Premium → ir directo a Ganancias
      final docRef =
      FirebaseFirestore.instance.collection('prestamistas').doc(uid);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => GananciasScreen(docPrest: docRef),
          ),
        );
      });
    } else {
      // ❌ No tiene Premium → mostrar pantalla normal
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.amber),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B0E18), // oscuro profesional
              Color(0xFF141826), // gris azulado mate
              Color(0xFF1B2133), // tono intermedio
              Color(0xFF10131C), // base metálica
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // 🌟 Ícono Premium
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF1F1F1F),
                        Color(0xFF2C2C2C),
                        Color(0xFF3A3A3A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Color(0xFFE0B85A),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 🪙 Título y subtítulo
                Text(
                  'Mi Recibo Premium',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu acceso al siguiente nivel financiero',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 15.2,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 38),

                // 📋 Beneficios Premium
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _beneficio(
                      icon: Icons.account_balance_wallet_rounded,
                      color: const Color(0xFF60A5FA),
                      texto:
                      'Consulta tus ganancias totales y divididas por categoría: préstamos, productos y alquileres.',
                    ),
                    _beneficio(
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF34D399),
                      texto:
                      'Accede al Potenciador Premium con estrategias financieras únicas cada día.',
                    ),
                    _beneficio(
                      icon: Icons.shield_rounded,
                      color: const Color(0xFFA78BFA),
                      texto:
                      'Disfruta de una experiencia sin anuncios y con soporte técnico prioritario.',
                    ),
                  ],
                ),

                const Spacer(),

                // 🔘 Botón Premium
                GestureDetector(
                  onTap: () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                    final uid = FirebaseAuth.instance.currentUser!.uid;

                    // 🔹 Verifica si ya es Premium
                    final yaPremium = await PremiumService().esPremiumActivo(uid);

                    if (yaPremium) {
                      final docRef = FirebaseFirestore.instance
                          .collection('prestamistas')
                          .doc(uid);

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GananciasScreen(docPrest: docRef),
                        ),
                      );
                      return;
                    }

                    // 🟡 Activar Premium
                    await PremiumService().activarPremium(context);

                    final docRef = FirebaseFirestore.instance
                        .collection('prestamistas')
                        .doc(uid);

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaBienvenidaPremium(
                          docPrest: docRef,
                          destino: widget.destino,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(45),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      'Desbloquear por US\$0.99',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                // 💼 Frase aspiracional
                Text(
                  'Convierte tu gestión en un verdadero negocio 💼',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13.6,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Acceso seguro, simple y cancelable en cualquier momento.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === Beneficio visual sobrio ===
  Widget _beneficio({
    required IconData icon,
    required String texto,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.92),
                fontSize: 14.6,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
