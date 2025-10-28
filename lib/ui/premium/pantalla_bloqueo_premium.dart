// lib/ui/premium/pantalla_bloqueo_premium.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mi_recibo/ui/perfil_prestamista/ganancias_screen.dart';

class PantallaBloqueoPremium extends StatelessWidget {
  const PantallaBloqueoPremium({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0E1630), // azul oscuro
              Color(0xFF1C2C63), // azul intermedio
              Color(0xFF342B70), // violeta elegante
              Color(0xFF241C3A), // base gris púrpura
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 45),

                // 💎 Ícono Premium profesional
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFF5C400)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD700).withOpacity(0.5),
                        blurRadius: 25,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
                ),

                const SizedBox(height: 32),

                // 🏷️ Título
                Text(
                  'Contenido Premium Bloqueado',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 23,
                    letterSpacing: 0.4,
                  ),
                ),

                const SizedBox(height: 16),

                // Descripción
                Text(
                  'Desbloquea las funciones exclusivas de Mi Recibo Business Premium:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.6,
                  ),
                ),

                const SizedBox(height: 35),

                // 🧾 Lista de beneficios
                Column(
                  children: [
                    _beneficio(
                      icon: Icons.show_chart_rounded,
                      texto: 'Ver tus ganancias totales y gráficas avanzadas en tiempo real',
                    ),
                    _beneficio(
                      icon: Icons.lightbulb_rounded,
                      texto: 'Acceder al Potenciador Premium con estrategias y consejos diarios',
                    ),
                    _beneficio(
                      icon: Icons.block_flipped,
                      texto: 'Sin anuncios y con soporte prioritario',
                    ),
                  ],
                ),

                const Spacer(),

                // 🔓 Botón Premium
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GananciasScreen(
                          docPrest: FirebaseFirestore.instance
                              .collection('prestamistas')
                              .doc(FirebaseAuth.instance.currentUser?.uid),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00D8FF), Color(0xFF0078FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Activar Premium – US\$1.99/mes',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // Texto inferior (visible y nítido)
                Text(
                  'Convierte tu gestión en un verdadero negocio con Mi Recibo Business Premium 💼',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13.2,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 6),
                Text(
                  'Puedes cancelar en cualquier momento desde Google Play.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    height: 1.3,
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

  // === Beneficio corporativo ===
  Widget _beneficio({required IconData icon, required String texto}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFF5C400)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14.8,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}