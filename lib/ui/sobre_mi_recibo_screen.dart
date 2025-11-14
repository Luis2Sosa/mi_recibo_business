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

                  const SizedBox(height: 25),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _intro(),
                  ),

                  const SizedBox(height: 30),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _sectionTitle("Soy Negocio"),
                  ),

                  const SizedBox(height: 12),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _haloCard(
                      context,
                      color: const Color(0xFF2563EB),
                      icon: Icons.request_quote_rounded,
                      title: "Préstamos",
                      bullets: const [
                        "Controla préstamos personales, intereses y fechas de cobro.",
                        "Registra abonos y genera recibos profesionales.",
                        "Recibe recordatorios automáticos y controla cada cliente.",
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: _haloCard(
                      context,
                      color: const Color(0xFF22C55E),
                      icon: Icons.shopping_bag_rounded,
                      title: "Venta de productos fiados o alquiler de equipos",
                      bullets: const [
                        "Control total de ventas fiadas y pagos pendientes.",
                        "Administra alquileres de vehículos o artículos por días.",
                        "Alertas automáticas y recibos profesionales.",
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: _haloCard(
                      context,
                      color: const Color(0xFFF59E0B),
                      icon: Icons.house_rounded,
                      title: "Alquiler de inmuebles",
                      bullets: const [
                        "Casas, locales o habitaciones con cobros mensuales.",
                        "Historial completo de pagos y recibos.",
                        "Control de fechas de vencimiento con recordatorios.",
                      ],
                    ),
                  ),

                  const SizedBox(height: 35),
                  FadeInUp(
                    delay: const Duration(milliseconds: 700),
                    child: const _BenefitsBlock(),
                  ),

                  const SizedBox(height: 35),
                  FadeInUp(
                    delay: const Duration(milliseconds: 850),
                    child: const _PremiumPanel(),
                  ),

                  const SizedBox(height: 50),
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
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Center(
      child: Container(
        width: isWeb ? 900 : double.infinity,
        padding: const EdgeInsets.all(22),
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
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: isWeb ? 18 : 15.5,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: isWeb ? 30 : 22, // 👈 WEB MÁS GRANDE, MÓVIL IGUAL
        ),
      ),
    );
  }


  // TARJETA CON AJUSTE DEL ICONO MÁS ABAJO 👇
  Widget _haloCard(
      BuildContext context, {
        required Color color,
        required IconData icon,
        required String title,
        required List<String> bullets,
      }) {
    final isWeb = MediaQuery.of(context).size.width > 600;
    final bg = color.withOpacity(.25);
    final border = color.withOpacity(.55);
    final chipBg = color.withOpacity(.22);

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment:
        isWeb ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            textAlign: isWeb ? TextAlign.center : TextAlign.left,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 19,
            ),
          ),

          const SizedBox(height: 12),

          for (final b in bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
              isWeb ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: chipBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: border.withOpacity(.5)),
                  ),
                  child: Icon(Icons.check_rounded, size: 14, color: color),
                ),
                const SizedBox(width: 10),

                SizedBox(
                  width: isWeb ? 500 : MediaQuery.of(context).size.width * 0.65,
                  child: Text(
                    b,
                    textAlign: isWeb ? TextAlign.center : TextAlign.left,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          // ⭐ AJUSTE DEL ICONO (más abajo)
          const SizedBox(height: 12),

          Align(
            alignment: isWeb ? Alignment.center : Alignment.centerRight,
            child: Container(
              width: 46,
              height: 46,
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
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// =================== BENEFICIOS ===================
class _BenefitsBlock extends StatelessWidget {
  const _BenefitsBlock();

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment:
        isWeb ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: const [
          _BenefitRow(
            icon: Icons.verified_rounded,
            text: 'Recibos elegantes y consistentes, listos para enviar por WhatsApp.',
          ),
          SizedBox(height: 10),

          _BenefitRow(
            icon: Icons.alarm_rounded,
            text: 'Recordatorios automáticos de vencimientos según tipo de negocio.',
          ),
          SizedBox(height: 10),

          _BenefitRow(
            icon: Icons.analytics_rounded,
            text: 'Panel de control con métricas visuales y claras.',
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
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Row(
      mainAxisAlignment:
      isWeb ? MainAxisAlignment.center : MainAxisAlignment.start,
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
        const SizedBox(width: 12),

        SizedBox(
          width: isWeb ? 600 : MediaQuery.of(context).size.width * 0.65,
          child: Text(
            text,
            textAlign: isWeb ? TextAlign.center : TextAlign.left,
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
      'Más que un recibo: la herramienta que organiza y profesionaliza tu negocio.',
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

// =================== PREMIUM ===================
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

          // ICONO PREMIUM
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

          const SizedBox(height: 30),

          // BENEFICIOS CORREGIDOS (más separados y verticales)
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _benefit(
                icon: Icons.bar_chart_rounded,
                color: Color(0xFF2563EB),
                text: 'Consulta tus ganancias totales y por categoría.',
              ),
              const SizedBox(height: 18),

              _benefit(
                icon: Icons.auto_awesome_rounded,
                color: Color(0xFF10B981),
                text: 'Accede al Potenciador Premium con estrategias y lecturas diarias.',
              ),
              const SizedBox(height: 18),

              _benefit(
                icon: Icons.shield_rounded,
                color: Color(0xFF8B5CF6),
                text: 'App sin anuncios y soporte técnico prioritario.',
              ),
            ],
          ),

          const SizedBox(height: 28),

          Text(
            'Convierte la gestión diaria en crecimiento real con herramientas profesionales.',
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
      mainAxisAlignment: MainAxisAlignment.center,
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
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
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
