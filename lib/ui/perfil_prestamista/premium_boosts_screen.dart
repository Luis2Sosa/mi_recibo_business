import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/ui/widgets/app_frame.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';

/// Header simple (mismo diseño del app) para que este archivo sea independiente.
class HeaderBar extends StatelessWidget {
  final String title;
  const HeaderBar({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(
              AppTheme.gradTop.withOpacity(.9),
            ),
            shape: MaterialStateProperty.all(const CircleBorder()),
            padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}

/// ===== Pantalla: Potenciadores Pro (contenido que rota diario) =====
class PremiumBoostsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const PremiumBoostsScreen({super.key, required this.docPrest});

  @override
  State<PremiumBoostsScreen> createState() => _PremiumBoostsScreenState();
}

class _PremiumBoostsScreenState extends State<PremiumBoostsScreen> {
  // Tips (fallback locales). Ahora son listas normales para poder reemplazarlas con Firestore.
  List<String> _qedu = [
    'Sube la tasa sólo a clientes puntuales (riesgo bajo).',
    'Reinvierte los intereses en préstamos pequeños.',
    'Ofrece 2% de descuento por pago adelantado.',
    'Automatiza recordatorios 72/24/6h antes del vencimiento.',
    'Segmenta por riesgo y asigna tasas por perfil.',
  ];
  List<String> _finance = [
    'Nunca prestes >10% de tu capital a un solo cliente.',
    'Mantén 15% de liquidez para imprevistos.',
    'Prioriza recuperar capital antes que maximizar interés.',
    'Evita renovar con clientes atrasados.',
    'Registra cada pago el mismo día.',
  ];

  int _qIndex = 0, _fIndex = 0;
  bool _loading = true;

  // Serie mini-chart (últimos 6 meses)
  List<int> _vals = [];
  List<String> _labs = [];

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  /// Orquestación con timeouts y manejo de errores para que nunca se quede cargando.
  Future<void> _initAll() async {
    try {
      await _loadTipsFromFirestore().timeout(const Duration(seconds: 6));
    } catch (_) {
      // Si falla Firestore, usamos los fallbacks locales.
    }

    try {
      await _rotateDailyIndices().timeout(const Duration(seconds: 4));
    } catch (_) {
      // Si algo falla, deja índices seguros
      _qIndex = 0;
      _fIndex = 0;
    }

    try {
      await _loadMiniStats().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Si falla, deja gráfico vacío (se verá "Sin datos")
      _vals = const [];
      _labs = const [];
    }

    if (mounted) setState(() => _loading = false);
  }

  /// Lee QEDU/CONSEJO desde Firestore y reemplaza las listas locales si hay datos.
  Future<void> _loadTipsFromFirestore() async {
    try {
      final col = FirebaseFirestore.instance
          .collection('config')
          .doc('(default)')
          .collection('potenciador_contenido');

      final qs = await col.where('activo', isEqualTo: true).get();

      final List<String> qeduDb = [];
      final List<String> finDb = [];

      for (final d in qs.docs) {
        final m = d.data();
        final tipo = (m['tipo'] ?? '').toString().toUpperCase().trim();
        final contenido = (m['contenido'] ?? '').toString().trim();
        if (contenido.isEmpty) continue;

        if (tipo == 'QEDU') qeduDb.add(contenido);
        if (tipo == 'CONSEJO' || tipo == 'FIN' || tipo == 'FINANCE') finDb.add(contenido);
      }

      if (qeduDb.isNotEmpty) _qedu = qeduDb;
      if (finDb.isNotEmpty) _finance = finDb;

      // Mantener índices dentro de rango si venían guardados
      if (_qedu.isNotEmpty) _qIndex = _qIndex % _qedu.length;
      if (_finance.isNotEmpty) _fIndex = _fIndex % _finance.length;
    } catch (_) {
      // Deja fallbacks locales
    }
  }

  /// Rota 1 tip por día y persiste en Firestore
  Future<void> _rotateDailyIndices() async {
    try {
      final dailyRef = widget.docPrest.collection('metrics').doc('daily');
      final snap = await dailyRef.get();
      final data = snap.data() ?? {};
      final last = (data['lastDate'] ?? '') as String;

      final now = DateTime.now();
      final todayKey = '${now.year}-${now.month}-${now.day}';

      int q = (data['qeduIndex'] ?? 0) as int;
      int f = (data['financeIndex'] ?? 0) as int;

      if (last != todayKey) {
        if (_qedu.isNotEmpty) q = (q + 1) % _qedu.length;
        if (_finance.isNotEmpty) f = (f + 1) % _finance.length;
        await dailyRef.set(
          {'qeduIndex': q, 'financeIndex': f, 'lastDate': todayKey},
          SetOptions(merge: true),
        );
      }

      if (_qedu.isNotEmpty) _qIndex = q % _qedu.length;
      if (_finance.isNotEmpty) _fIndex = f % _finance.length;
    } catch (_) {
      // deja índices en 0 si algo falla
      _qIndex = 0;
      _fIndex = 0;
    }
  }

  // Mini estadística: suma de pagos por mes (últimos 6 meses)
  Future<void> _loadMiniStats() async {
    try {
      const mesesTxt = [
        'Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'
      ];
      final now = DateTime.now();
      final months =
      List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));

      final Map<String, int> porMes = {
        for (final m in months)
          '${m.year}-${m.month.toString().padLeft(2, '0')}': 0
      };

      final cs = await widget.docPrest.collection('clientes').get();

      // Para no bloquear si hay muchos pagos, limitamos por cliente.
      for (final c in cs.docs) {
        final pagos = await c.reference.collection('pagos').limit(200).get();
        for (final p in pagos.docs) {
          final mp = p.data();
          final ts = mp['fecha'];
          final total = (mp['totalPagado'] ?? 0);
          if (ts is Timestamp && total is num) {
            final d = ts.toDate();
            final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
            if (porMes.containsKey(key)) {
              porMes[key] = (porMes[key] ?? 0) + total.toInt();
            }
          }
        }
      }

      _vals = [];
      _labs = [];
      for (final m in months) {
        _labs.add(mesesTxt[m.month - 1]);
        _vals.add(porMes['${m.year}-${m.month.toString().padLeft(2, '0')}'] ?? 0);
      }
    } catch (_) {
      _vals = const [];
      _labs = const [];
    }
  }

  String _rd(int v) {
    if (v <= 0) return '\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) { b.write('.'); c = 0; }
    }
    return '\$${b.toString().split('').reversed.join()}';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const HeaderBar(title: 'Potenciadores Pro'),
          child: _loading
              ? const Center(
            child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
              : Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: Column(
              children: [
                _proBadgeGlass(),
                const SizedBox(height: 10),
                // SIN SCROLL
                Expanded(
                  child: Column(
                    children: [
                      Expanded(flex: 9, child: _cardQEDU()),
                      const SizedBox(height: 8),
                      Expanded(flex: 12, child: _cardChart()),
                      const SizedBox(height: 8),
                      Expanded(flex: 9, child: _cardFinance()),
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

  // --- Colores y tipografía ---
  static const _ink = Color(0xFF0F172A);
  static const _inkDim = Color(0xFF6B7A90);
  static const _panelStroke = Color(0x33FFFFFF);
  static const _panelTint = Color(0x7FFFFFFF); // blanco con opacidad (glass)
  static const _panelBg = Color(0x11FFFFFF);

  // ======== BANNER GLASS (transparente + blur + borde degradado) ========
  Widget _proBadgeGlass() {
    return _GlassWrap(
      borderRadius: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            width: 1.2,
            color: _panelStroke,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _panelTint.withOpacity(.60),
              _panelTint.withOpacity(.38),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.20),
                border: Border.all(color: Colors.white.withOpacity(.45)),
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Contenido premium desbloqueado',
                maxLines: 2,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: .2,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(.45)),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: .4,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ======== CARD GLASS (transparente + blur + borde sutil) ========
  Widget _glassCard({
    required IconData leading,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
    Widget? trailingChip,
    bool fill = true,
  }) {
    return _GlassWrap(
      borderRadius: 22,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(width: 1, color: _panelStroke),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _panelTint.withOpacity(.80),
              _panelTint.withOpacity(.60),
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
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
                    color: _panelBg,
                    border: Border.all(color: const Color(0x2AFFFFFF)),
                  ),
                  child: Icon(leading, color: AppTheme.gradTop),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: _ink)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: _inkDim)),
                    ],
                  ),
                ),
                if (trailingChip != null) trailingChip,
              ],
            ),
            const SizedBox(height: 8),
            if (fill) Expanded(child: child) else child,
            if (footer != null) ...[
              const SizedBox(height: 6),
              DefaultTextStyle(
                style:
                const TextStyle(color: _inkDim, fontWeight: FontWeight.w700),
                child: footer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipHoy() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF).withOpacity(.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE7FF)),
      ),
      child: const Text(
        'HOY',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF3559D2),
        ),
      ),
    );
  }

  Widget _chipPro() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF).withOpacity(.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE7FF)),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: Color(0xFF3559D2),
        ),
      ),
    );
  }

  // ======== CARDS ========
  Widget _cardQEDU() {
    final text = _qedu.isEmpty ? '' : _qedu[_qIndex];
    return _glassCard(
      leading: Icons.bolt_rounded,
      title: 'QEDU del día',
      subtitle: 'Cómo mejorar tu rendimiento',
      trailingChip: _chipHoy(),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
      ),
      footer: const Text('Se actualiza cada día'),
    );
  }

  Widget _cardFinance() {
    final text = _finance.isEmpty ? '' : _finance[_fIndex];
    return _glassCard(
      leading: Icons.account_balance_wallet_rounded,
      title: 'Consejo financiero',
      subtitle: 'Gestión de riesgo y capital',
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
      ),
      footer: const Text('Nuevo consejo cada día'),
    );
  }

  Widget _cardChart() {
    final int total = _vals.fold(0, (p, v) => p + v);
    return _glassCard(
      leading: Icons.insights_rounded,
      title: 'Estadística avanzada',
      subtitle: 'Pagos últimos 6 meses',
      trailingChip: _chipPro(),
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _miniBarFlex(values: _vals, labels: _labs)),
            const SizedBox(height: 6),
            Text(
              'Total recibido: ${_rd(total)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
          ],
        ),
      ),
      footer: const Text('Tendencia mensual agregada'),
    );
  }

  // ======== MINI BAR CHART (panel translúcido + líneas guía) ========
  Widget _miniBarFlex({required List<int> values, required List<String> labels}) {
    return LayoutBuilder(builder: (context, cs) {
      if (values.isEmpty) {
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _panelBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: const Text('Sin datos',
              style: TextStyle(color: _inkDim, fontWeight: FontWeight.w700)),
        );
      }

      final double maxV =
      values.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 999999.0);
      final double barW =
      (cs.maxWidth / (values.length * 2)).clamp(14.0, 24.0).toDouble();
      final double barsH =
      (cs.maxHeight - 28.0).clamp(60.0, cs.maxHeight).toDouble();

      return Column(
        children: [
          SizedBox(
            height: barsH,
            child: _GlassWrap(
              borderRadius: 14,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                  gradient: LinearGradient(
                    colors: [
                      _panelTint.withOpacity(.50),
                      _panelTint.withOpacity(.35),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(values.length, (i) {
                            final double bh =
                                (values[i] / maxV) * (barsH - 14.0);
                            return Container(
                              width: barW,
                              height: bh,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppTheme.gradTop.withOpacity(.95),
                                    AppTheme.gradTop.withOpacity(.70),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gradTop.withOpacity(.18),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              labels.length,
                  (i) => SizedBox(
                width: barW + 8.0,
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _inkDim),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Wrapper reutilizable para efecto GLASS (blur + transparencia controlada)
class _GlassWrap extends StatelessWidget {
  final double borderRadius;
  final Widget child;
  const _GlassWrap({required this.borderRadius, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: child,
      ),
    );
  }
}

/// Líneas guía sutiles (se ven a través del glass)
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = 1.0;
    const int lines = 4;
    final double gap = size.height / (lines + 1);
    for (int i = 1; i <= lines; i++) {
      final double y = gap * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
