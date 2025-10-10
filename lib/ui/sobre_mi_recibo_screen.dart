// lib/ui/sobre_mi_recibo_screen.dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'widgets/app_frame.dart';

class SobreMiReciboScreen extends StatelessWidget {
  const SobreMiReciboScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const _HeaderTitle(),
          child: const _Content(),
        ),
      ),
    );
  }
}

// =================== HEADER ===================

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Sobre Mi Recibo Business',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: .3,
        height: 1.1,
      ),
    );
  }
}

// =================== CONTENT ===================

class _Content extends StatelessWidget {
  const _Content();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        // Panel translúcido premium
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.10),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.22),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: const _ScrollableBody(),
      ),
    );
  }
}

class _ScrollableBody extends StatelessWidget {
  const _ScrollableBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _SectionTitle('Soy Negocio'),
          SizedBox(height: 6),

          // Prestamista / Fiador / Arrendador
          _PremiumInfoCard(
            delayMs: 0,
            icon: Icons.request_quote_rounded,
            title: 'Prestamista',
            description:
            'Gestiona préstamos con control de intereses, fechas de pago y renovaciones automáticas (mensual o quincenal). Envía recibos profesionales por WhatsApp y activa recordatorios inteligentes.',
          ),
          _PremiumInfoCard(
            delayMs: 80,
            icon: Icons.verified_user_rounded,
            title: 'Fiador',
            description:
            'Lleva el control de fiados de productos o servicios. Organiza tu cartera, visualiza saldos por cliente y recibe alertas de vencimientos con historial claro y exportable.',
          ),
          _PremiumInfoCard(
            delayMs: 160,
            icon: Icons.house_rounded,
            title: 'Arrendador',
            description:
            'Administra alquileres de casas, apartamentos o locales. Controla renovaciones, monitorea pagos y notifica a tus inquilinos con mensajes listos para enviar.',
          ),

          SizedBox(height: 18),
          _SectionDivider(),

          SizedBox(height: 8),
          _SectionTitle('Soy Trabajador Independiente'),
          SizedBox(height: 6),

          _PremiumInfoCard(
            delayMs: 0,
            icon: Icons.build_rounded,
            title: 'Profesionales y freelancers',
            description:
            'Reposteros, plomeros, albañiles, peluqueros y más: crea cotizaciones elegantes, genera recibos en segundos y registra ingresos/gastos para llevar tu contabilidad simple.',
          ),

          SizedBox(height: 24),
          _FooterQuote(),
        ],
      ),
    );
  }
}

// =================== SECTION ELEMENTS ===================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.1,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(.10),
            Colors.white.withOpacity(.04),
            Colors.white.withOpacity(.10),
          ],
        ),
      ),
    );
  }
}

class _FooterQuote extends StatelessWidget {
  const _FooterQuote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Más que un recibo, la herramienta inteligente que transforma tu trabajo.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(.85),
        fontStyle: FontStyle.italic,
        fontSize: 13.5,
        height: 1.3,
      ),
    );
  }
}

// =================== PREMIUM CARD ===================

class _PremiumInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int delayMs;

  const _PremiumInfoCard({
    required this.icon,
    required this.title,
    required this.description,
    this.delayMs = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _FadeSlideIn(
      delayMs: delayMs,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // Fondo con degradado MUY sutil para sensación premium
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(.96),
              Colors.white.withOpacity(.92),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8ECF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon chip circular con degradado corporativo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.gradTop, AppTheme.gradBottom],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.gradTop.withOpacity(.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título con subrayado sutil
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5EAF4), width: 1),
                      ),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        height: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.42,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w500,
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

// =================== ANIMACIÓN SUAVE ===================

class _FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const _FadeSlideIn({required this.child, this.delayMs = 0});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _opacity =
  CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  late final Animation<Offset> _offset =
  Tween(begin: const Offset(0, .06), end: Offset.zero)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}