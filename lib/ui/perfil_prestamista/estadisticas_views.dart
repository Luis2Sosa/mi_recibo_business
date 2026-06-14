import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mi_recibo/ui/premium/pantalla_bloqueo_premium.dart';

class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

/// ==== HISTÓRICO ====
class EstadisticasHistoricoView extends StatelessWidget {
  final int lifetimePrestado;
  final int lifetimeRecuperado;

  final String histPrimerPago;
  final String histUltimoPago;
  final String histMesTop;

  final VoidCallback onOpenGanancias;
  final VoidCallback onOpenGananciaClientes;
  final String Function(int) rd;

  final double? previousRecoveryPercent;

  final String mayorNombre;
  final int mayorSaldo;

  const EstadisticasHistoricoView({
    super.key,
    required this.lifetimePrestado,
    required this.lifetimeRecuperado,
    required this.histPrimerPago,
    required this.histUltimoPago,
    required this.histMesTop,
    required this.onOpenGanancias,
    required this.onOpenGananciaClientes,
    required this.rd,
    this.previousRecoveryPercent,
    required this.mayorNombre,
    required this.mayorSaldo,
  });

  @override
  Widget build(BuildContext context) {
    final double rawRate =
    lifetimePrestado > 0 ? (lifetimeRecuperado * 100 / lifetimePrestado) : 0.0;
    final double recRate = rawRate.clamp(0.0, 100.0);
    final int pendienteHist = math.max(lifetimePrestado - lifetimeRecuperado, 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            KPIPremiumCard(
              title: 'Ganancias totales',
              subtitle: 'Toca para ver',
              leading: Icons.trending_up_rounded,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PantallaBloqueoPremium(destino: 'totales'),
                  ),
                );
              },
            ),
            Builder(
              builder: (context) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) {
                  return _KPIFintechPremium(
                    title: 'Total capital recuperado',
                    value: rd(lifetimeRecuperado),
                    activo: lifetimeRecuperado > 0,
                    invertida: false,
                    colorBase: const Color(0xFF00C853),
                  );
                }

                final summaryRef = FirebaseFirestore.instance
                    .collection('prestamistas')
                    .doc(uid)
                    .collection('metrics')
                    .doc('summary');

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: summaryRef.snapshots(),
                  builder: (context, snap) {
                    int cr = lifetimeRecuperado;
                    final data = snap.data?.data();
                    if (data != null) {
                      final raw = data['totalCapitalRecuperado'];
                      if (raw is num) cr = raw.round();
                    }

                    return _KPIFintechPremium(
                      title: 'Total capital recuperado',
                      value: rd(cr),
                      activo: cr > 0,
                      invertida: false,
                      colorBase: const Color(0xFF00C853),
                    );
                  },
                );
              },
            ),
            _KPIFintechPremium(
              title: 'Total capital pendiente',
              value: rd(pendienteHist),
              activo: pendienteHist > 0,
              invertida: true,
              colorBase: const Color(0xFF8B0000),
            ),
            RecoveryFillCard(
              percent: recRate,
              previousPercent: previousRecoveryPercent ?? recRate,
            ),
          ],
        ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xA62B2F3A), Color(0xA63B4250)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 5, offset: const Offset(0, 3))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cliente con mayor deuda',
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w600, fontSize: 14.5, letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      mayorNombre.isNotEmpty ? mayorNombre : '—',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 21,
                        letterSpacing: 0.5,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 1))],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                      ),
                      child: Text(
                        'Saldo: ${rd(mayorSaldo)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(left: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD66B), size: 24),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.38),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.55)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 12, offset: const Offset(0, 5))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Resumen histórico', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _miniStatBalanced(icon: Icons.calendar_today_rounded, label: 'Primer pago', value: histPrimerPago),
                  const SizedBox(width: 10),
                  _miniStatBalanced(icon: Icons.payments_rounded, label: 'Último pago', value: histUltimoPago),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniStatBalanced(icon: Icons.trending_up_rounded, label: 'Mes con más cobros', value: histMesTop),
                  const SizedBox(width: 10),
                  _miniStatBalanced(
                    icon: Icons.water_drop_rounded,
                    label: 'Recuperación histórica',
                    value: lifetimePrestado > 0 ? '${recRate.toStringAsFixed(0)}%' : '—',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ===== KPI "tarjeta vasija" =====
class RecoveryFillCard extends StatefulWidget {
  final double percent;
  final double previousPercent;

  const RecoveryFillCard({
    super.key,
    required this.percent,
    required this.previousPercent,
  });

  @override
  State<RecoveryFillCard> createState() => _RecoveryFillCardState();
}

class _RecoveryFillCardState extends State<RecoveryFillCard>
    with TickerProviderStateMixin {
  late AnimationController _fillCtrl;
  late AnimationController _waveCtrl;
  late AnimationController _tapCtrl;
  late Animation<double> _level;

  @override
  void initState() {
    super.initState();
    final from = (widget.previousPercent.clamp(0, 100)) / 100.0;
    final to = (widget.percent.clamp(0, 100)) / 100.0;

    _fillCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _level = CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: from, end: to));
    _fillCtrl.forward();

    _waveCtrl = AnimationController.unbounded(vsync: this)
      ..animateWith(_LinearWaveSimulation(speed: 1.0));

    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: .98,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void didUpdateWidget(covariant RecoveryFillCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final to = (widget.percent.clamp(0, 100)) / 100.0;
    final from = _level.value;
    _level = CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: from, end: to));
    _fillCtrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _fillCtrl.dispose();
    _waveCtrl.dispose();
    _tapCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.percent.clamp(0, 100);
    final pctText = pct.toStringAsFixed(0);

    final bool good = pct >= 50;
    final Color water = good ? const Color(0xFF16A34A) : const Color(0xFFE11D48);
    final List<Color> cardGrad = const [Color(0xFF2C2F3A), Color(0xFF3E4452)];
    final Color pctFill = good ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return GestureDetector(
      onTap: () {
        _tapCtrl..reverse(from: 1.0)..forward();
      },
      child: ScaleTransition(
        scale: _tapCtrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              // FIX: SizedBox.expand() garantiza que CustomPaint siempre tenga
              // constraints finitas dentro del Stack → nunca pinta área 0×0.
              // Sin este fix, en algunos Android el fondo de agua queda invisible.
              SizedBox.expand(
                child: CustomPaint(
                  painter: _FullCardWaterPainter(
                    levelListenable: _level,
                    waveListenable: _waveCtrl,
                    cardGradient: cardGrad,
                    waterColor: water,
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
                  boxShadow: [BoxShadow(color: water.withOpacity(.18), blurRadius: 22, offset: const Offset(0, 8))],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        'Recuperación total',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1))],
                        ),
                      ),
                    ),
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Stack(
                          children: [
                            Text(
                              '$pctText%',
                              style: GoogleFonts.inter(
                                textStyle: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 4
                                    ..color = Colors.black,
                                ),
                              ),
                            ),
                            Text(
                              '$pctText%',
                              style: GoogleFonts.inter(
                                textStyle: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: pctFill),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinta la tarjeta completa con fondo premium y agua llenando desde abajo
class _FullCardWaterPainter extends CustomPainter {
  final Animation<double> levelListenable;
  final Animation<double> waveListenable;
  final List<Color> cardGradient;
  final Color waterColor;

  _FullCardWaterPainter({
    required this.levelListenable,
    required this.waveListenable,
    required this.cardGradient,
    required this.waterColor,
  }) : super(repaint: Listenable.merge([levelListenable, waveListenable]));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bg = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: cardGradient,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final level = levelListenable.value.clamp(0.0, 1.0);
    final waterTop = h * (1 - level);

    final t = waveListenable.value;
    final amp1 = 8.0;
    final amp2 = 5.0;
    const double omega1 = 2.2;
    const double omega2 = 1.6;
    final phase1 = t * omega1;
    final phase2 = -t * omega2;

    Paint waterPaint(double opacityTop, double opacityBottom) {
      return Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [waterColor.withOpacity(opacityTop), waterColor.withOpacity(opacityBottom)],
        ).createShader(Rect.fromLTWH(0, waterTop - 10, w, h - waterTop + 10));
    }

    Path makeWave(double phase, double amp, double y0, double w, double h) {
      final double wavelength = w;
      final double startX = -wavelength;
      final double endX = w + wavelength;

      final p = Path()..moveTo(startX, h);
      double y(double x) => y0 + math.sin((x / wavelength * 2 * math.pi) + phase) * amp;

      p.lineTo(startX, y(startX));
      for (double x = startX; x <= endX; x += 2) {
        p.lineTo(x, y(x));
      }
      p.lineTo(endX, h);
      p.close();
      return p;
    }

    final Path backWave = makeWave(phase2, amp2, waterTop - 4, w, h);
    final Path frontWave = makeWave(phase1, amp1, waterTop, w, h);

    canvas.drawPath(backWave, waterPaint(.25, .65));
    canvas.drawPath(frontWave, waterPaint(.40, .85));

    final edge = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final edgePath = Path();
    for (double x = 0; x <= w; x += 4) {
      final y = waterTop + math.sin((x / w * 2 * math.pi) + phase1) * amp1;
      if (x == 0) edgePath.moveTo(x, y); else edgePath.lineTo(x, y);
    }
    canvas.drawPath(edgePath, edge);
  }

  @override
  bool shouldRepaint(covariant _FullCardWaterPainter old) => true;
}

Widget _kpiGlass({
  required String title,
  required String value,
  required List<Color> gradient,
  required Color accent,
  required Color shadow,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
      boxShadow: [BoxShadow(color: shadow.withOpacity(.18), blurRadius: 20, offset: const Offset(0, 8))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 22,
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(textStyle: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(value, textAlign: TextAlign.center, maxLines: 1,
                  style: GoogleFonts.inter(textStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent))),
            ),
          ),
        ),
      ],
    ),
  );
}

class KPIPremiumCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData leading;
  final VoidCallback onTap;

  const KPIPremiumCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.onTap,
  });

  @override
  State<KPIPremiumCard> createState() => _KPIPremiumCardState();
}

class _KPIPremiumCardState extends State<KPIPremiumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shineCtrl;

  @override
  void initState() {
    super.initState();
    // Brillo premium: el barrido dura 600ms, luego pausa ~2.5s antes de repetir.
    // Simulamos la pausa haciendo que la animación dure 3.1s en total pero
    // el brillo solo es visible durante la primera fracción del ciclo (pos < 1.2).
    // Resultado: barrido rápido y elegante, pausa larga → efecto Apple/Samsung.
    _shineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3100),
    )..repeat();
  }

  @override
  void dispose() {
    _shineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedBuilder(
        animation: _shineCtrl,
        builder: (context, child) {
          final double t = _shineCtrl.value;
          // El barrido ocurre solo en el primer 20% del ciclo (≈600ms),
          // el resto (≈2.5s) es pausa invisible → efecto premium con respiro.
          final double pos = (t * 12.0) - 1.2;

          return Container(
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1E2A78), Color(0xFF431F91)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(.15), width: 1.4),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                if (t > 0 && t < 1)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: ShaderMask(
                        shaderCallback: (rect) {
                          return LinearGradient(
                            begin: Alignment(-1.5 + pos, -1),
                            end: Alignment(1.5 + pos, 1),
                            colors: [Colors.transparent, Colors.white.withOpacity(0.9), Colors.transparent],
                            stops: const [0.35, 0.5, 0.65],
                          ).createShader(rect);
                        },
                        blendMode: BlendMode.overlay,
                        child: Container(color: Colors.white.withOpacity(0.05)),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.leading, color: Colors.white, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 0.3),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.touch_app_rounded, size: 14, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text(widget.subtitle, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.96),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 14, offset: const Offset(0, 6))],
      border: Border.all(color: const Color(0xFFE1E8F5)),
    ),
    child: child,
  );
}

Widget _divider() => Container(height: 1.2, color: _BrandX.divider, margin: const EdgeInsets.symmetric(vertical: 10));

Widget _kv(String k, String v) {
  return Row(
    children: [
      Expanded(child: Text(k, style: const TextStyle(color: _BrandX.inkDim))),
      Flexible(
        child: Align(
          alignment: Alignment.center,
          child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink)),
        ),
      ),
    ],
  );
}

class PremiumDeleteCard extends StatelessWidget {
  final VoidCallback? onTap;
  const PremiumDeleteCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.gradTop.withOpacity(.95), AppTheme.gradBottom.withOpacity(.95)],
        ),
        boxShadow: [BoxShadow(color: AppTheme.gradTop.withOpacity(.25), blurRadius: 16, offset: const Offset(0, 6))],
        border: Border.all(color: Colors.white.withOpacity(.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.15),
                  border: Border.all(color: Colors.white.withOpacity(.45), width: 1.2),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Borrar histórico',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Elimina solo los acumulados históricos. No borra clientes ni pagos.',
            style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : onTap,
              icon: const Icon(Icons.shield_moon_outlined, size: 18),
              label: const Text('Borrar histórico'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE11D48),
                disabledBackgroundColor: Colors.white.withOpacity(.6),
                disabledForegroundColor: const Color(0xFFEF9AA9),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinearWaveSimulation extends Simulation {
  final double speed;
  _LinearWaveSimulation({this.speed = 2.0});
  @override
  double x(double time) => speed * time;
  @override
  double dx(double time) => speed;
  @override
  bool isDone(double time) => false;
}

Widget _miniStatBalanced({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent.shade700, size: 18),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(color: Colors.black, fontSize: 14.5, fontWeight: FontWeight.w900)),
        ],
      ),
    ),
  );
}

class _KPIFintechPremium extends StatefulWidget {
  final String title;
  final String value;
  final bool activo;
  final bool invertida;
  final Color colorBase;

  const _KPIFintechPremium({
    required this.title,
    required this.value,
    required this.activo,
    required this.invertida,
    required this.colorBase,
  });

  @override
  State<_KPIFintechPremium> createState() => _KPIFintechPremiumState();
}

class _KPIFintechPremiumState extends State<_KPIFintechPremium>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox.expand(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _KPIBackgroundFintechPainter(
                    anim: _ctrl.value,
                    activo: widget.activo,
                    invertida: widget.invertida,
                    colorBase: widget.colorBase,
                  ),
                );
              },
            ),
          ),

          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 6,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 2),

                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.value,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KPIBackgroundFintechPainter extends CustomPainter {
  final double anim;
  final bool activo;
  final bool invertida;
  final Color colorBase;

  _KPIBackgroundFintechPainter({
    required this.anim,
    required this.activo,
    required this.invertida,
    required this.colorBase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final gradient = Paint()
      ..shader = LinearGradient(
        colors: [colorBase.withOpacity(0.95), colorBase.withOpacity(0.75)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(18)), gradient);

    if (!activo) return;

    final path = Path();
    final curvePaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    const steps = 30;
    final amplitude = invertida ? -8.0 : 8.0;
    final baseY = h * 0.6;

    for (int i = 0; i <= steps; i++) {
      final x = w * (i / steps);
      final y = baseY + math.sin((i / steps * 2 * math.pi) + anim * 2 * math.pi) * amplitude;
      if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
    }
    canvas.drawPath(path, curvePaint);

    final double cycle = (anim % 1.0);
    final double lightOffset = (cycle * 3.4) - 1.7;

    double smoothOpacity(double x) {
      if (x < 0.15) return x / 0.15;
      if (x > 0.85) return (1.0 - x) / 0.15;
      return 1.0;
    }

    final double fade = smoothOpacity(cycle);
    final lightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(-1.7 + lightOffset, -1.7),
        end: Alignment(1.7 + lightOffset, 1.7),
        colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.18 * fade), Colors.white.withOpacity(0.0)],
        stops: const [0.3, 0.5, 0.7],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), const Radius.circular(18)), lightPaint);
  }

  @override
  bool shouldRepaint(covariant _KPIBackgroundFintechPainter oldDelegate) => true;
}