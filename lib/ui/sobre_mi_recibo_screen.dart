// lib/ui/sobre_mi_recibo_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SobreMiReciboScreen extends StatelessWidget {
  const SobreMiReciboScreen({super.key});

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
                  const SizedBox(height: 20),
                  _header(),
                  const SizedBox(height: 20),
                  _intro(),
                  const SizedBox(height: 16),
                  _sectionTitle("Rutas principales"),
                  const SizedBox(height: 10),
                  _haloCard(
                    context,
                    color: const Color(0xFF2563EB),
                    icon: Icons.request_quote_rounded,
                    title: "Préstamos",
                    bullets: const [
                      "Controla saldo, intereses y fechas (mensual, quincenal, semanal o diario).",
                      "Registra abonos y genera recibos profesionales listos para WhatsApp.",
                      "Recordatorios automáticos y renovaciones para no perder el control.",
                    ],
                  ),
                  const SizedBox(height: 10),
                  _haloCard(
                    context,
                    color: const Color(0xFF22C55E),
                    icon: Icons.shopping_bag_rounded,
                    title: "Productos (fiado) y alquiler corto",
                    bullets: const [
                      "Vende a crédito y gestiona saldos por cliente.",
                      "Alquila vehículos o equipos por días o semanas desde esta sección.",
                      "Alertas de vencimiento y comprobantes listos para WhatsApp.",
                    ],
                  ),
                  const SizedBox(height: 10),
                  _haloCard(
                    context,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.house_rounded,
                    title: "Alquiler de inmuebles (mensual)",
                    bullets: const [
                      "Casas, apartamentos, locales o habitaciones con ciclo mensual.",
                      "Registra pagos y renueva automáticamente.",
                      "Recordatorios y historial de cada inquilino.",
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle("Para profesionales"),
                  const SizedBox(height: 10),
                  _haloCard(
                    context,
                    color: const Color(0xFF111827),
                    icon: Icons.build_rounded,
                    title: "Profesionales y oficios",
                    bullets: const [
                      "Crea cotizaciones elegantes y genera recibos en segundos.",
                      "Registra ingresos y gastos fácilmente desde tu móvil.",
                      "Comunicación directa con clientes por WhatsApp.",
                    ],
                  ),
                  const SizedBox(height: 25),
                  const _BenefitsBlock(),
                  const SizedBox(height: 30),
                  const _PremiumPanel(),
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
        "Mi Recibo Business organiza tu cartera de clientes para préstamos, productos fiados y alquileres. "
            "Genera recibos profesionales, envía recordatorios por WhatsApp y consulta historiales en segundos.\n\n"
            "Importante: la app NO mueve dinero; es una herramienta de control y seguimiento pensada para el día a día.",
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
            'Recordatorios por tipo (préstamo, productos/fiado y alquiler) con mensajes claros.',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.analytics_rounded,
            text:
            'Historial por cliente, control de renovaciones y métricas básicas.',
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ícono dorado
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFFFD700),
              size: 48,
            ),
          ),

          const SizedBox(height: 14),

          // Título principal
          Text(
            'Mi Recibo Business Premium',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),

          const SizedBox(height: 10),

          // Texto mejorado
          Text(
            'Lleva tu gestión al siguiente nivel. Visualiza tus ganancias totales y '
                'métricas profesionales en tiempo real, sin interrupciones ni anuncios.\n\n'
                'Accede al Potenciador Premium con consejos exclusivos para hacer crecer tu negocio '
                'de forma clara, rápida y profesional.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(.9),
              fontSize: 14.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 22),

          // Botón con precio
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00FFD1), Color(0xFF00B8FF)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              ' Sin anuncios • Acceso total • US\$1.99/mes',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Frase final más llamativa
          Text(
            'Premium no es un extra, es la experiencia completa.\n'
                'Haz tu negocio más rentable, más claro y más tuyo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
