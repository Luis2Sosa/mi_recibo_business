// 📄 lib/ui/sobre_mi_recibo_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import 'dart:math';


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
            colors: [Color(0xFF0D1B2A), Color(0xFF1E2A78), Color(0xFF431F91)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [


                  const SizedBox(height: 18),
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: _header(),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _intro(),
                  ),
                  const SizedBox(height: 22),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _sectionTitle("Soy Negocio"),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _haloCard(
                      context,
                      color: const Color(0xFF2563EB),
                      icon: Icons.request_quote_rounded,
                      title: "Préstamos",
                      bullets: const [
                        "Controla préstamos personales, intereses y fechas de cobro (mensual, quincenal, semanal o diario).",
                        "Registra abonos y genera recibos profesionales listos para enviar por WhatsApp.",
                        "Recibe recordatorios automáticos y mantén el control de cada cliente.",
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: _haloCard(
                      context,
                      color: const Color(0xFF22C55E),
                      icon: Icons.shopping_bag_rounded,
                      title:
                      "Vende tus productos fiado o alquila vehículos y equipos fácilmente",
                      bullets: const [
                        "Registra ventas a crédito y controla saldos de pago por cliente.",
                        "Alquila vehículos, equipos o artículos por días o semanas con total control.",
                        "Genera recibos profesionales automáticos y alertas de vencimiento.",
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: _haloCard(
                      context,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.house_rounded,
                      title: "Alquiler de inmuebles (mensual)",
                      bullets: const [
                        "Gestiona casas, locales, apartamentos o habitaciones con cobros mensuales.",
                        "Registra pagos, genera recibos profesionales y renueva automáticamente.",
                        "Consulta historiales y controla fechas de vencimiento fácilmente.",
                      ],
                    ),
                  ),
                  const SizedBox(height: 25),
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: _sectionTitle("Soy Trabajador Independiente"),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    delay: const Duration(milliseconds: 800),
                    child: _haloCard(
                      context,
                      color: const Color(0xFF111827),
                      icon: Icons.engineering_rounded,
                      title: "Profesionales y oficios",
                      bullets: const [
                        "Crea cotizaciones elegantes y genera recibos en segundos.",
                        "Registra ingresos, gastos y controla tus cobros desde tu móvil.",
                        "Comunícate directamente con tus clientes por WhatsApp.",
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: const Duration(milliseconds: 900),
                    child: const _BenefitsBlock(),
                  ),
                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: const Duration(milliseconds: 1000),
                    child: const _PremiumPanel(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Center(
      child: Text(
        "Sobre Mi Recibo Business",
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 26,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        "Mi Recibo Business es una herramienta profesional diseñada para gestionar clientes, pagos y recibos con la máxima eficiencia. "
            "Permite controlar préstamos, productos y alquileres, generar recibos automáticos y mantener un historial completo de cada cliente.\n\n"
            "La aplicación no mueve dinero ni realiza transacciones bancarias: su propósito es ayudarte a llevar el control financiero de tu negocio y mostrar una imagen profesional ante tus clientes.",
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 15.5,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 20,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _haloCard(
      BuildContext context, {
        required Color color,
        required IconData icon,
        required String title,
        required List<String> bullets,
      }) {
    final bg = color.withOpacity(.25);
    final border = color.withOpacity(.55);
    final chipBg = color.withOpacity(.22);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17.5,
                  ),
                ),
                const SizedBox(height: 8),
                for (final b in bullets) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 3),
                        decoration: BoxDecoration(
                          color: chipBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: border.withOpacity(.5)),
                        ),
                        child: Icon(Icons.check_rounded, size: 14, color: color),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(.78)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(.3),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}

// =================== BLOQUE DE BENEFICIOS ===================
class _BenefitsBlock extends StatelessWidget {
  const _BenefitsBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _BenefitRow(
            icon: Icons.verified_rounded,
            text:
            'Recibos elegantes y consistentes con tu marca: compártelos por WhatsApp en un toque.',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.alarm_rounded,
            text:
            'Recordatorios automáticos por tipo (préstamo, productos/fiado y alquiler).',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.analytics_rounded,
            text:
            'Panel de control visual con métricas simples y efectivas.',
          ),
          SizedBox(height: 12),
          _FooterQuote(),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(child: Icon(icon, color: Colors.white, size: 18)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterQuote extends StatelessWidget {
  const _FooterQuote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Más que un recibo: la herramienta que organiza y profesionaliza tu trabajo diario.',
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        color: Colors.white.withOpacity(.95),
        fontStyle: FontStyle.italic,
        fontSize: 13.5,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// =================== BLOQUE PREMIUM ===================
class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0B85A), width: 2),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'Mi Recibo Business Premium',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Por solo US\$0.99 al mes',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Color(0xFFE0B85A),
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 22),
          _benefit(
            icon: Icons.bar_chart_rounded,
            color: Color(0xFF2563EB),
            text:
            'Consulta tus ganancias totales y divididas por categoría: préstamos, productos y alquileres.',
          ),
          const SizedBox(height: 14),
          _benefit(
            icon: Icons.auto_awesome_rounded,
            color: Color(0xFF10B981),
            text:
            'Accede al Potenciador Premium con estrategias financieras y lecturas diarias.',
          ),
          const SizedBox(height: 14),
          _benefit(
            icon: Icons.shield_rounded,
            color: Color(0xFF8B5CF6),
            text:
            'Disfruta de la app sin anuncios y con soporte técnico prioritario.',
          ),
          const SizedBox(height: 26),
          Text(
            'Convierte tu gestión diaria en crecimiento real con herramientas premium diseñadas para profesionales.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 13.5,
              height: 1.4,
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.92),
              fontSize: 14.2,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
