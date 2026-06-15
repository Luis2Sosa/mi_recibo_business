// 📄 lib/ui/sobre_mi_recibo_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';

class SobreMiReciboScreen extends StatefulWidget {
  const SobreMiReciboScreen({super.key});

  @override
  State<SobreMiReciboScreen> createState() => _SobreMiReciboScreenState();
}

class _SobreMiReciboScreenState extends State<SobreMiReciboScreen>
    with SingleTickerProviderStateMixin {

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
            colors: [Color(0xFF0D1B2A), Color(0xFF1A2E6E), Color(0xFF0D1B2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  const SizedBox(height: 10),

                  FadeInDown(
                    duration: const Duration(milliseconds: 600),
                    child: _header(),
                  ),

                  const SizedBox(height: 22),

                  FadeInUp(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 500),
                    child: _intro(),
                  ),

                  const SizedBox(height: 32),

                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _sectionLabel('¿Qué puedes gestionar?'),
                  ),

                  const SizedBox(height: 14),

                  FadeInUp(
                    delay: const Duration(milliseconds: 280),
                    child: _featureCard(
                      color: const Color(0xFF3B82F6),
                      icon: Icons.request_quote_rounded,
                      title: 'Préstamos',
                      bullets: const [
                        'Controla préstamos personales, intereses y fechas de cobro.',
                        'Registra abonos y genera recibos profesionales.',
                        'Seguimiento individual de cada cliente con historial completo.',
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  FadeInUp(
                    delay: const Duration(milliseconds: 340),
                    child: _featureCard(
                      color: const Color(0xFF22C55E),
                      icon: Icons.shopping_bag_rounded,
                      title: 'Productos y ventas fiadas',
                      bullets: const [
                        'Control total de ventas fiadas y pagos pendientes.',
                        'Registra múltiples productos por cliente.',
                        'Recibos automáticos y alertas de vencimiento.',
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _featureCard(
                      color: const Color(0xFFF59E0B),
                      icon: Icons.house_rounded,
                      title: 'Alquiler de inmuebles',
                      bullets: const [
                        'Casas, locales o habitaciones con cobros mensuales.',
                        'Historial completo de pagos por propiedad.',
                        'Control de vencimientos con recordatorios automáticos.',
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  FadeInUp(
                    delay: const Duration(milliseconds: 450),
                    child: _sectionLabel('¿Por qué Mi Recibo Business?'),
                  ),

                  const SizedBox(height: 14),

                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: _benefitsBlock(),
                  ),

                  const SizedBox(height: 32),

                  FadeInUp(
                    delay: const Duration(milliseconds: 560),
                    child: _sectionLabel('Plan Premium'),
                  ),

                  const SizedBox(height: 14),

                  FadeInUp(
                    delay: const Duration(milliseconds: 620),
                    child: const _PremiumPanel(),
                  ),

                  const SizedBox(height: 40),

                  FadeInUp(
                    delay: const Duration(milliseconds: 680),
                    child: _footer(),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Text(
            'PRESENTACIÓN',
            style: GoogleFonts.inter(
              color: Colors.white60,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Mi Recibo Business',
          textAlign: TextAlign.center,
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 30,
            height: 1.2,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La gestión que tu negocio merece',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.55),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.35)),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF60A5FA), size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Mi Recibo Business es una herramienta profesional diseñada para gestionar clientes, pagos y recibos con la máxima eficiencia. '
                'Controla préstamos, productos y alquileres, genera recibos automáticos y mantén un historial completo de cada cliente.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14.5,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF60A5FA), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La app no mueve dinero ni realiza transacciones bancarias.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF93C5FD),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3, height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _featureCard({
    required Color color,
    required IconData icon,
    required String title,
    required List<String> bullets,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.30)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...bullets.map((b) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    b,
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13.5,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _benefitsBlock() {
    final items = [
      (Icons.verified_rounded,   const Color(0xFF3B82F6), 'Recibos elegantes listos para compartir por WhatsApp al instante.'),
      (Icons.alarm_rounded,      const Color(0xFF22C55E), 'Recordatorios automáticos de vencimientos según el tipo de negocio.'),
      (Icons.analytics_rounded,  const Color(0xFFF59E0B), 'Panel de control con métricas claras de tu cartera de clientes.'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: items[i].$2.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: items[i].$2.withOpacity(0.25)),
                  ),
                  child: Icon(items[i].$1, color: items[i].$2, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      items[i].$3,
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (i < items.length - 1) ...[
              const SizedBox(height: 4),
              Divider(color: Colors.white.withOpacity(0.07), height: 20),
            ],
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              '"Más que un recibo: la herramienta que organiza y profesionaliza tu negocio."',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white.withOpacity(0.65),
                fontStyle: FontStyle.italic,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Divider(color: Colors.white.withOpacity(0.10)),
        const SizedBox(height: 16),
        Text(
          'Sosa Tech Lab',
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.65),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2025 · Todos los derechos reservados',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.30),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════
// PANEL PREMIUM
// ═══════════════════════════════════════════════════
class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE0B85A).withOpacity(0.40)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE0B85A).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F172A),
              border: Border.all(color: const Color(0xFFE0B85A), width: 1.5),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Color(0xFFE0B85A), size: 30),
          ),

          const SizedBox(height: 14),

          Text(
            'Mi Recibo Business Premium',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE0B85A).withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE0B85A).withOpacity(0.35)),
            ),
            child: Text(
              'Solo US\$0.99 al mes',
              style: GoogleFonts.inter(
                color: const Color(0xFFE0B85A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 22),
          Divider(color: Colors.white.withOpacity(0.07)),
          const SizedBox(height: 18),

          _benefit(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF3B82F6),
            text: 'Consulta tus ganancias totales y por categoría de negocio.',
          ),
          const SizedBox(height: 14),
          _benefit(
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF10B981),
            text: 'Potenciador Premium con estrategias y lecturas diarias para crecer.',
          ),
          const SizedBox(height: 14),
          _benefit(
            icon: Icons.shield_rounded,
            color: const Color(0xFF8B5CF6),
            text: 'Experiencia sin anuncios y soporte técnico prioritario.',
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.07)),
          const SizedBox(height: 14),

          Text(
            'Convierte la gestión diaria en crecimiento real\ncon herramientas profesionales.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _benefit({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.78),
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}