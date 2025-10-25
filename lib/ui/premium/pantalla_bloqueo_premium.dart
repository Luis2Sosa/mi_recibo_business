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
            colors: [Color(0xFF0D1B2A), Color(0xFF1E2A78), Color(0xFF431F91)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // ✨ Ícono Premium
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFFFD700),
                    size: 70,
                  ),
                ),

                const SizedBox(height: 25),

                // Título
                Text(
                  'Contenido Premium Bloqueado',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),

                const SizedBox(height: 14),

                // Descripción
                Text(
                  'Suscríbete a Mi Recibo Business Premium para acceder a:',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 30),

                // Lista de beneficios
                Column(
                  children: [
                    _beneficio('📈 Ver tus ganancias totales y gráficas en tiempo real'),
                    _beneficio('💡 Acceder al Potenciador Premium con consejos diarios'),
                    _beneficio('🔒 Sin anuncios y con prioridad de soporte'),
                  ],
                ),

                const Spacer(),

                // Botón Premium
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
                        colors: [Color(0xFF00FFD1), Color(0xFF00B8FF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Text(
                      'Activar Premium – US\$2/mes',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        color: Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Texto inferior
                Text(
                  'Mejora tu experiencia y desbloquea todo el poder de Mi Recibo Business 💎',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 35),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _beneficio(String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
