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
    return const Text(
      'Sobre Mi Recibo Business',
      textAlign: TextAlign.center,
      style: TextStyle(
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
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.16),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(.34)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.25),
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _IntroPitch(),
          SizedBox(height: 14),
          _SectionDivider(),
          SizedBox(height: 10),

          _SectionTitle('Rutas principales'),
          SizedBox(height: 10),

          _HaloCard(
            color: Color(0xFF2563EB), // Azul préstamo
            icon: Icons.request_quote_rounded,
            title: 'Préstamo',
            bullets: [
              'Controla saldo, intereses y fechas (mensual, quincenal, semanal o diario).',
              'Registra abonos y genera recibos profesionales listos para WhatsApp.',
              'Recordatorios automáticos y renovaciones para no perder el control.',
            ],
          ),
          SizedBox(height: 10),

          _HaloCard(
            color: Color(0xFF22C55E), // Verde productos fiados
            icon: Icons.shopping_bag_rounded,
            title: 'Productos (fiado) y alquiler corto',
            bullets: [
              'Vende a crédito y gestiona saldos por cliente.',
              'Alquila vehículos o equipos por días o semanas desde esta sección.',
              'Alertas de vencimiento y comprobantes listos para WhatsApp.',
            ],
          ),
          SizedBox(height: 10),

          _HaloCard(
            color: Color(0xFFF59E0B), // Naranja alquiler
            icon: Icons.house_rounded,
            title: 'Alquiler de inmuebles (mensual)',
            bullets: [
              'Casas, apartamentos, locales o habitaciones con ciclo mensual.',
              'Registra pagos y renueva automáticamente.',
              'Recordatorios y historial de cada inquilino.',
            ],
          ),

          SizedBox(height: 18),
          _SectionDivider(),
          SizedBox(height: 10),

          _SectionTitle('Para profesionales'),
          SizedBox(height: 10),

          _HaloCard(
            color: Color(0xFF111827),
            icon: Icons.build_rounded,
            title: 'Profesionales y oficios',
            bullets: [
              'Crea cotizaciones elegantes y genera recibos en segundos.',
              'Registra ingresos y gastos fácilmente desde tu móvil.',
              'Comunicación directa con clientes por WhatsApp.',
            ],
          ),

          SizedBox(height: 22),
          _BenefitsBlock(),
        ],
      ),
    );
  }
}

// =================== BLOQUES DE TEXTO ===================

class _IntroPitch extends StatelessWidget {
  const _IntroPitch();

  @override
  Widget build(BuildContext context) {
    return _HaloIntroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Mi Recibo Business organiza tu cartera de clientes para préstamos, productos fiados y alquileres. '
                'Genera recibos profesionales, envía recordatorios por WhatsApp y consulta historiales en segundos.\n\n'
                'Importante: la app NO mueve dinero; es una herramienta de control y seguimiento pensada para el día a día.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HaloIntroPanel extends StatelessWidget {
  final Widget child;
  const _HaloIntroPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(.34)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =================== SECCIÓN / DIVIDER ===================

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
        letterSpacing: .2,
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
            Colors.white.withOpacity(.16),
            Colors.white.withOpacity(.08),
            Colors.white.withOpacity(.16),
          ],
        ),
      ),
    );
  }
}

// =================== HALO CARD ===================

class _HaloCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final List<String> bullets;

  const _HaloCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(.30);
    final border = color.withOpacity(.55);
    final chipBg = color.withOpacity(.22);

    return _FadeSlideIn(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.15),
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
                  Container(
                    margin: const EdgeInsets.only(bottom: 8, right: 8),
                    padding: const EdgeInsets.only(bottom: 6),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE6ECF8), width: 1),
                      ),
                    ),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ),
                  for (final b in bullets) ...[
                    _BulletLine(text: b, accent: color, chipBg: chipBg),
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
                    color: color.withOpacity(.30),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color accent;
  final Color chipBg;

  const _BulletLine({
    required this.text,
    required this.accent,
    required this.chipBg,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: chipBg,
            shape: BoxShape.circle,
            border: Border.all(color: accent.withOpacity(.38)),
          ),
          child: Icon(Icons.check_rounded, size: 14, color: accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.44,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// =================== BENEFICIOS ===================

class _BenefitsBlock extends StatelessWidget {
  const _BenefitsBlock();

  @override
  Widget build(BuildContext context) {
    return _HaloIntroPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _BenefitRow(
            icon: Icons.verified_rounded,
            text: 'Recibos elegantes y consistentes con tu marca: compártelos por WhatsApp en un toque.',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.alarm_rounded,
            text: 'Recordatorios por tipo (préstamo, productos/fiado y alquiler) con mensajes claros.',
          ),
          SizedBox(height: 10),
          _BenefitRow(
            icon: Icons.analytics_rounded,
            text: 'Historial por cliente, control de renovaciones y métricas básicas.',
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
            style: const TextStyle(
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
      style: TextStyle(
        color: Colors.white.withOpacity(.95),
        fontStyle: FontStyle.italic,
        fontSize: 13.5,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

// =================== ANIMACIÓN ===================

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
