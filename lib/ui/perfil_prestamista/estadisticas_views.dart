import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

/// ==== ACTUAL ====
class EstadisticasActualView extends StatelessWidget {
  final int totalPrestado;
  final int totalRecuperado;
  final int totalPendiente;

  final String mayorNombre;
  final int mayorSaldo;
  final String promInteres;
  final String proximoVenc;

  final String Function(int) rd;

  const EstadisticasActualView({
    super.key,
    required this.totalPrestado,
    required this.totalRecuperado,
    required this.totalPendiente,
    required this.mayorNombre,
    required this.mayorSaldo,
    required this.promInteres,
    required this.proximoVenc,
    required this.rd,
  });

  @override
  Widget build(BuildContext context) {
    // Sin KPIs aquí para evitar duplicados
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _kv('Cliente con mayor saldo', (mayorSaldo >= 0) ? mayorNombre : '—'),
              _divider(),
              _kv('Saldo más alto', (mayorSaldo >= 0) ? rd(mayorSaldo) : '—'),
              _divider(),
              _kv('Promedio interés', promInteres.isNotEmpty ? promInteres : '—'),
              _divider(),
              _kv('Próximo vencimiento', proximoVenc.isNotEmpty ? proximoVenc : '—'),
            ],
          ),
        ),
      ],
    );
  }
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

  /// Para flecha de tendencia en Recuperación (opcional).
  final double? previousRecoveryPercent;

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
  });

  @override
  Widget build(BuildContext context) {
    final double rawRate =
    lifetimePrestado > 0 ? (lifetimeRecuperado * 100 / lifetimePrestado) : 0.0;
    final double recRate = rawRate.clamp(0.0, 100.0); // 0–100
    final int pendienteHist = math.max(
        lifetimePrestado - lifetimeRecuperado, 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // === ÚNICO GRID DE KPIs (4) ===
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            // 1️⃣ Ganancias totales
            _kpiPremium(
              title: 'Ganancias totales',
              subtitle: 'Toca para ver',
              leading: Icons.trending_up_rounded,
              onTap: onOpenGanancias,
              gradient: const [Color(0xFFDFFCEF), Color(0xFFC5F5FF)],
            ),

            // 2️⃣ Total capital recuperado
            Builder(
              builder: (context) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) {
                  // Sin auth: usa el valor que llega por props
                  return _kpiGlass(
                    title: 'Total capital recuperado',
                    value: rd(lifetimeRecuperado),
                    gradient: const [Color(0xFFE9FFF2), Color(0xFFD6FFF3)],
                    accent: const Color(0xFF16A34A),
                    shadow: const Color(0xFF16A34A),
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
                    int cr = lifetimeRecuperado; // fallback local
                    final data = snap.data?.data();
                    if (data != null) {final raw = data['totalCapitalRecuperado'];
                    if (raw is num) cr = raw.round();
                    }

                    return _kpiGlass(
                      title: 'Total capital recuperado',
                      value: rd(cr),
                      gradient: const [Color(0xFFE9FFF2), Color(0xFFD6FFF3)],
                      accent: const Color(0xFF16A34A),
                      shadow: const Color(0xFF16A34A),
                    );
                  },
                );
              },
            ),

            // 3️⃣ Total capital pendiente
            _kpiGlass(
              title: 'Total capital pendiente',
              value: rd(pendienteHist),
              gradient: pendienteHist > 0
                  ? const [Color(0xFFFFEFF2), Color(0xFFFFE8EC)] // rojo suave
                  : const [Color(0xFFE9FFF2), Color(0xFFD6FFF3)],
              // verde éxito
              accent: pendienteHist > 0
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
              shadow: pendienteHist > 0
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF16A34A),
            ),


            // 4️⃣ Recuperación — tarjeta vasija (agua roja <50, verde >=50)
            RecoveryFillCard(
              percent: recRate,
              previousPercent: previousRecoveryPercent ?? recRate,
            ),
          ],
        ),

        const SizedBox(height: 20),

        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _kv('Primer pago registrado', histPrimerPago),
              _divider(),
              _kv('Último pago registrado', histUltimoPago),
              _divider(),
              _kv('Mes con más cobros', histMesTop),
              _divider(),
              _kv('Recuperación histórica',
                  lifetimePrestado > 0
                      ? '${recRate.toStringAsFixed(0)}%'
                      : '—'),
            ],
          ),
        ),
      ],
    );
  }
}
  /// ===== KPI “tarjeta vasija” (llena toda la tarjeta) =====
class RecoveryFillCard extends StatefulWidget {
  final double percent;        // 0–100
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
  late AnimationController _fillCtrl; // anima el nivel (0..1)
  late AnimationController _waveCtrl; // olas
  late AnimationController _tapCtrl;  // micro-pulso
  late Animation<double> _level;      // 0..1

  @override
  void initState() {
    super.initState();
    final from = (widget.previousPercent.clamp(0, 100)) / 100.0;
    final to = (widget.percent.clamp(0, 100)) / 100.0;

    _fillCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _level = CurvedAnimation(parent: _fillCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: from, end: to));
    _fillCtrl.forward();

    // Fase continua: nunca resetea, no hay “corte” visible en el loop.
    _waveCtrl = AnimationController.unbounded(vsync: this)
      ..animateWith(_LinearWaveSimulation(speed: 1.0)); // radianes/segundo aprox.

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

    // Agua: roja <50, verde >=50
    final bool good = pct >= 50;
    final Color water = good ? const Color(0xFF16A34A) : const Color(0xFFE11D48);
    final List<Color> cardGrad = const [Color(0xFFEAF7EE), Color(0xFFDFF2E8)];

    // Porcentaje: verde/rojo con borde negro (stroke)
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
              // Fondo y agua
              CustomPaint(
                painter: _FullCardWaterPainter(
                  levelListenable: _level,
                  waveListenable: _waveCtrl,
                  cardGradient: cardGrad,
                  waterColor: water,
                ),
                child: const SizedBox.expand(),
              ),

              // Borde + sombra premium
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: water.withOpacity(.18),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // ← evita overflow
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fila superior: solo el título centrado
                    Center(
                      child: Text(
                        'Recuperación total',
                        style: GoogleFonts.inter(
                          textStyle: const TextStyle(
                            color: _BrandX.inkDim,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    // % centrado con borde negro y relleno verde/rojo
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
                                textStyle: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  color: pctFill,
                                ),
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

  // Flecha siempre visible: ↑ si >=50, ↓ si <50 (mismo estilo que Ganancias)
  Widget _trendChipAlways({required bool good}) {
    final icon = good ? Icons.trending_up : Icons.trending_down;
    final color = good ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(.80),
        border: Border.all(color: Colors.white, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

/// Pinta la tarjeta completa con fondo premium y agua llenando desde abajo
class _FullCardWaterPainter extends CustomPainter {
  final Animation<double> levelListenable; // 0..1
  final Animation<double> waveListenable;  // 0..1
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

    // Fondo premium
    final bg = Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: cardGradient,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    // Nivel de agua (0..1)
    final level = levelListenable.value.clamp(0.0, 1.0);
    final waterTop = h * (1 - level);

    // Fase continua (viene del controller unbounded)
    final t = waveListenable.value;
    final amp1 = 8.0;
    final amp2 = 5.0;
    // Frecuencias fijas: movimiento uniforme (sin depender del nivel)
    const double omega1 = 2.2;
    const double omega2 = 1.6;
    final phase1 = t * omega1;
    final phase2 = -t * omega2;

    Paint _waterPaint(double opacityTop, double opacityBottom) {
      return Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            waterColor.withOpacity(opacityTop),
            waterColor.withOpacity(opacityBottom),
          ],
        ).createShader(Rect.fromLTWH(0, waterTop - 10, w, h - waterTop + 10));
    }

    // === Onda extendida para eliminar el "corte" (overdraw) ===
    Path _wave(double phase, double amp, double y0, double w, double h) {
      final double wavelength = w;     // 1 período = ancho del card
      final double startX = -wavelength;      // empieza fuera de la izquierda
      final double endX   = w + wavelength;   // termina fuera de la derecha

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

    // Construimos olas (trasera y delantera)
    final Path backWave  = _wave(phase2, amp2, waterTop - 4, w, h);
    final Path frontWave = _wave(phase1, amp1, waterTop, w, h);

    final Paint backPaint  = _waterPaint(.25, .65);
    final Paint frontPaint = _waterPaint(.40, .85);

    // Dibuja primero la ola de atrás y luego la delantera (profundidad correcta)
    canvas.drawPath(backWave, backPaint);
    canvas.drawPath(frontWave, frontPaint);

    // Highlight del borde del agua (sobre la ola delantera)
    final edge = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final edgePath = Path();
    for (double x = 0; x <= w; x += 4) {
      final y = waterTop + math.sin((x / w * 2 * math.pi) + phase1) * amp1;
      if (x == 0) {
        edgePath.moveTo(x, y);
      } else {
        edgePath.lineTo(x, y);
      }
    }
    canvas.drawPath(edgePath, edge);
  }

  @override
  bool shouldRepaint(covariant _FullCardWaterPainter old) => true;
}

/// ====== UI Helpers ======
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
              style: GoogleFonts.inter(
                textStyle: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: GoogleFonts.inter(
                  textStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _kpiPremium({
  required String title,
  required String subtitle,
  required IconData leading,
  required VoidCallback onTap,
  required List<Color> gradient,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leading, size: 18, color: AppTheme.gradTop),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  textStyle: const TextStyle(
                    color: _BrandX.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE1E8F5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 14, color: _BrandX.inkDim),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.gradTop, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink),
          ),
        ),
      ),
    ],
  );
}

/// ===== Card premium público =====
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
          colors: [
            AppTheme.gradTop.withOpacity(.95),
            AppTheme.gradBottom.withOpacity(.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gradTop.withOpacity(.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
                  style: GoogleFonts.inter(
                    textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
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
  final double speed; // rad/s
  _LinearWaveSimulation({this.speed = 2.0});
  @override
  double x(double time) => speed * time; // fase crece linealmente
  @override
  double dx(double time) => speed;
  @override
  bool isDone(double time) => false;
}