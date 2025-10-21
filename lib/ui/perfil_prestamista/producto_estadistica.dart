// lib/ui/perfil_prestamista/producto_estadistica.dart
// Dashboard de PRODUCTOS (centrado en clientes con productos):
// - Héroe: Índice de cumplimiento (% clientes al día) con círculo de agua (verde/rojo).
// - KPIs centrados: Ganancia por clientes (TAP), Clientes activos, Productos circulando, Total invertido.
// - Estados de clientes (Al día / 1–7d / 8–30d / 30+d / Inact.) con filas amplias y contador coloreado.
// - Top productos por movimiento (barra) con estado vacío.
// - Sin panel premium ni CTA extra. Moneda: "$ 5,800" (LATAM, sin decimales).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/widgets/app_frame.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/bar_chart.dart';
import 'package:mi_recibo/ui/perfil_prestamista/ganancias_productos_screen.dart';
import 'package:mi_recibo/core/estadisticas_totales_service.dart';


class ProductoEstadisticaScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const ProductoEstadisticaScreen({super.key, required this.docPrest});

  @override
  State<ProductoEstadisticaScreen> createState() => _ProductoEstadisticaScreenState();
}

class _ProductoEstadisticaScreenState extends State<ProductoEstadisticaScreen>
    with TickerProviderStateMixin {
  late Future<_ResumenProductos> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarResumenProductos();
  }

  // ==================== CARGA Y AGREGACIÓN (solo PRODUCTOS) ====================
  Future<_ResumenProductos> _cargarResumenProductos() async {
    final now = DateTime.now();

    int totalInvertido = 0;     // capitalInicial declarado en clientes de productos
    int ingresos = 0;           // sum(totalPagado) — no se muestra como KPI
    int clientesActivos = 0;    // saldoActual > 0

    // Estados de clientes por morosidad
    int alDia = 0, atraso1a7 = 0, atraso8a30 = 0, atrasoMas30 = 0, inactivos = 0;

    // Top productos por movimiento y set para productos activos
    final Map<String, int> movimientoPorProducto = {};
    final Set<String> productosActivos = {};

    final cs = await widget.docPrest
        .collection('clientes')
        .where('tipo', whereIn: ['producto', 'fiado']) // 🔹 filtra solo productos o fiados
        .get();

    for (final c in cs.docs) {
      final m = c.data();
      final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
      final producto = (m['producto'] ?? '').toString().trim();

      // Heurística de "producto"
      final esProducto = tipo == 'producto' || tipo == 'fiado' || producto.isNotEmpty;
      if (!esProducto) continue;

      final int saldo = (m['saldoActual'] ?? 0) as int;
      final int capitalInicial = (m['capitalInicial'] ?? 0) as int;

      final pagos = await c.reference.collection('pagos').limit(250).get();
      int totalPagadoCliente = 0;
      int pagadoCapitalCliente = 0;
      for (final p in pagos.docs) {
        final d = p.data();
        totalPagadoCliente += (d['totalPagado'] ?? 0) as int;
        pagadoCapitalCliente += (d['pagoCapital'] ?? 0) as int;
      }

      totalInvertido += capitalInicial;
      ingresos += totalPagadoCliente;

      if (saldo > 0) {
        clientesActivos++;
        if (producto.isNotEmpty) productosActivos.add(producto);

        // Estados por fecha de pago
        final pf = m['proximaFecha'];
        if (pf is Timestamp) {
          final d = pf.toDate();
          final dias = now.difference(d).inDays;
          if (dias <= 0) {
            alDia++;
          } else if (dias <= 7) {
            atraso1a7++;
          } else if (dias <= 30) {
            atraso8a30++;
          } else {
            atrasoMas30++;
          }
        } else {
          // Sin fecha -> tratamos como al día
          alDia++;
        }
      } else {
        inactivos++;
      }

      if (producto.isNotEmpty) {
        movimientoPorProducto[producto] =
            (movimientoPorProducto[producto] ?? 0) + totalPagadoCliente;
      }
    }

    // Top 6 productos
    final entries = movimientoPorProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();
    final labelsTop = top.map((e) => _acorta(e.key)).toList();
    final valuesTop = top.map((e) => e.value).toList();

    // Índice de cumplimiento: % de clientes con productos que están al día (sobre activos)
    final activos = alDia + atraso1a7 + atraso8a30 + atrasoMas30;
    final cumplimiento = (activos > 0) ? (alDia * 100.0 / activos) : 0.0;

    return _ResumenProductos(
      totalInvertido: totalInvertido,
      ingresos: ingresos,
      clientesActivos: clientesActivos,
      productosCirculando: productosActivos.length,
      cumplimientoPct: cumplimiento.clamp(0, 100),
      labelsTop: labelsTop,
      valuesTop: valuesTop,
      alDia: alDia,
      atraso1a7: atraso1a7,
      atraso8a30: atraso8a30,
      atrasoMas30: atrasoMas30,
      inactivos: inactivos,
    );
  }

  // ==================== HELPERS ====================
  String _acorta(String s, {int max = 12}) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
  }

  // Moneda LATAM, sin decimales, separador de miles por coma. Ej: 5800 => "$ 5,800"
  String _rd(int v) => '\$ ${_fmtMiles(v)}';
  String _fmtMiles(int v) {
    final s = v.abs().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - 1 - i;
      b.write(s[idx]);
      if ((i + 1) % 3 == 0 && idx != 0) b.write(',');
    }
    final core = b.toString().split('').reversed.join();
    return v < 0 ? '-$core' : core;
  }

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const _HeaderBar(title: 'Resumen de Productos'),
          child: FutureBuilder<_ResumenProductos>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      SizedBox(width: 10),
                      Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }

              final data = snap.data;
              if (data == null) return _emptyCard('Sin datos de productos');

              final totalTop = data.valuesTop.fold<int>(0, (p, v) => p + v);

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
                children: [
                  // ===== HÉROE: Cumplimiento con agua + chip compacto =====
                  _heroCumplimiento(pct: data.cumplimientoPct),
                  const SizedBox(height: 12),

                  // ===== KPIs (centrados) =====
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    // MÁS ALTO para evitar overflow en “Productos circulando”
                    childAspectRatio: 1.52,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _kpiPremiumTap(
                        title: 'Ganancia por clientes',
                        subtitle: 'Toca para ver',
                        leading: Icons.people_alt_rounded,
                        leadingSize: 32,
                        gradient: const [Color(0xFFDFFCEF), Color(0xFFC5F5FF)],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GananciasProductoScreen(
                                docPrest: widget.docPrest,
                              ),
                            ),
                          );
                        },
                      ),
                      _kpiSmart(
                        title: 'Clientes activos',
                        display: '${data.clientesActivos}',
                        accent: AppTheme.gradTop,
                        bg: const Color(0xFFF2F6FD),
                      ),
                      _kpiSmart(
                        title: 'Productos circulando',
                        display: '${data.productosCirculando}',
                        accent: const Color(0xFF0EA5E9),
                        bg: const Color(0xFFE0F2FE),
                      ),
                      _kpiSmart(
                        title: 'Total invertido',
                        display: _rd(data.totalInvertido),
                        accent: _BrandX.ink,
                        bg: const Color(0xFFF1F5F9),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Estados de clientes (ANCHO y con contador coloreado) =====
                  _estadosCard(
                    alDia: data.alDia,
                    atraso1a7: data.atraso1a7,
                    atraso8a30: data.atraso8a30,
                    atrasoMas30: data.atrasoMas30,
                    inactivos: data.inactivos,
                  ),

                  const SizedBox(height: 12),

                  // ===== Top productos =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.stacked_bar_chart_rounded, color: _BrandX.inkDim),
                            SizedBox(width: 8),
                            Text('Productos con más movimiento',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (data.valuesTop.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FAFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE7EEF8)),
                            ),
                            child: const Text(
                              'Aún no hay movimiento suficiente.',
                              style: TextStyle(fontWeight: FontWeight.w700, color: _BrandX.inkDim),
                            ),
                          )
                        else
                          SimpleBarChart(
                            values: data.valuesTop,
                            labels: data.labelsTop,
                            yTickFormatter: (v) => _rd(v),
                          ),
                        const SizedBox(height: 8),
                        Text('Total: ${_rd(totalTop)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==================== HÉROE Cumplimiento (agua + chip) ====================
  Widget _heroCumplimiento({required double pct}) {
    final bool up = pct >= 50.0;
    final Color water = up ? const Color(0xFF16A34A) : const Color(0xFFE11D48);
    final double clamped = pct.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.gradTop.withOpacity(.98), AppTheme.gradBottom.withOpacity(.98)],
        ),
        boxShadow: [BoxShadow(color: AppTheme.gradTop.withOpacity(.28), blurRadius: 24, offset: const Offset(0, 10))],
        border: Border.all(color: Colors.white.withOpacity(.35), width: 1.2),
      ),
      child: Row(
        children: [
          SizedBox(width: 160, height: 160, child: _WaterCircle(targetPercent: clamped, waterColor: water)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Índice de cumplimiento',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 6),
                Text('Clientes al día',
                    style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(.65)),
                    ),
                    child: Text(
                      'Al día ${clamped.toStringAsFixed(clamped >= 100 ? 0 : 1)}%',
                      style: TextStyle(
                        color: up ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                        fontWeight: FontWeight.w900,
                      ),
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

  // ==================== Estados de clientes (filas anchas, legibles) ====================
  Widget _estadosCard({
    required int alDia,
    required int atraso1a7,
    required int atraso8a30,
    required int atrasoMas30,
    required int inactivos,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.group_rounded, color: _BrandX.inkDim),
            SizedBox(width: 8),
            Text('Estados de clientes',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
          ]),
          const SizedBox(height: 12),

          _estadoRow(Icons.check_circle,   'Al día',                      alDia,       const Color(0xFF16A34A)),
          const SizedBox(height: 10),
          _estadoRow(Icons.pending_actions,'Atraso leve (1–7 d)',         atraso1a7,   const Color(0xFFF59E0B)),
          const SizedBox(height: 10),
          _estadoRow(Icons.schedule,       'Atraso medio (8–30 d)',       atraso8a30,  const Color(0xFFF97316)),
          const SizedBox(height: 10),
          _estadoRow(Icons.error_rounded,  'Atraso fuerte (30+ d)',       atrasoMas30, const Color(0xFFEF4444)),
          const SizedBox(height: 10),
          _estadoRow(Icons.pause_circle,   'Inactivos',                   inactivos,   const Color(0xFF9CA3AF)),
        ],
      ),
    );
  }

  Widget _estadoRow(IconData icon, String label, int count, Color dotColor) {
    final bool has = count > 0;
    final Color badgeText = has ? dotColor : _BrandX.inkDim;
    final Color badgeBg   = has ? dotColor.withOpacity(.12) : const Color(0xFFF6F8FD);
    final Color badgeBd   = has ? dotColor.withOpacity(.35) : const Color(0xFFE1E8F5);

    return Container(
      height: 52, // alto cómodo para leer
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Punto de color + ícono
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: _BrandX.inkDim),
          const SizedBox(width: 10),

          // Etiqueta — NUNCA se recorta
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink, fontSize: 15),
            ),
          ),

          // Contador — badge visible y coloreado si hay >0
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: badgeBd),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontWeight: FontWeight.w900, color: badgeText, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== UI HELPERS ====================
  Widget _kpiSmart({
    required String title,
    required String display,
    required Color accent,
    required Color bg,
  }) {
    return Container(
      // menos padding vertical para evitar overflows en teléfonos pequeños
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 14, height: 1.1),
          ),
          const SizedBox(height: 8),
          // FittedBox ya evita cortes; bajamos un poco el tamaño base
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, height: 1.0, fontWeight: FontWeight.w900, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiPremiumTap({
    required String title,
    required String subtitle,
    required IconData leading,
    double leadingSize = 32,
    required List<Color> gradient,
    required VoidCallback onTap,
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
                Icon(leading, size: leadingSize, color: AppTheme.gradTop),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _BrandX.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: .2,
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
                    children: const [
                      Icon(Icons.touch_app_rounded, size: 16, color: _BrandX.inkDim),
                      SizedBox(width: 6),
                      Text('Toca para ver', style: TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink)),
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

  Widget _emptyCard(String t) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.96),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EEF8)),
    ),
    child: Center(
        child:
        Text(t, style: const TextStyle(fontWeight: FontWeight.w800, color: _BrandX.inkDim))),
  );

  Widget _card({required Widget child}) => Container(
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

// ==================== TIPOS ====================
class _ResumenProductos {
  final int totalInvertido;
  final int ingresos;        // no se muestra; útil para cálculos
  final int clientesActivos;
  final int productosCirculando;
  final double cumplimientoPct;

  final List<String> labelsTop;
  final List<int> valuesTop;

  // Estados de clientes
  final int alDia, atraso1a7, atraso8a30, atrasoMas30, inactivos;

  _ResumenProductos({
    required this.totalInvertido,
    required this.ingresos,
    required this.clientesActivos,
    required this.productosCirculando,
    required this.cumplimientoPct,
    required this.labelsTop,
    required this.valuesTop,
    required this.alDia,
    required this.atraso1a7,
    required this.atraso8a30,
    required this.atrasoMas30,
    required this.inactivos,
  });
}

// ==================== HEADER ====================
class _HeaderBar extends StatelessWidget {
  final String title;
  const _HeaderBar({required this.title});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(AppTheme.gradTop.withOpacity(.9)),
            shape: MaterialStateProperty.all(const CircleBorder()),
            padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ],
    );
  }
}

// ==================== PALETA ====================
class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

// ==================== WATER CIRCLE (igual al de préstamos) ====================
class _WaterCircle extends StatefulWidget {
  final double targetPercent; // 0..100
  final Color waterColor;
  const _WaterCircle({required this.targetPercent, required this.waterColor});

  @override
  State<_WaterCircle> createState() => _WaterCircleState();
}

class _WaterCircleState extends State<_WaterCircle> with TickerProviderStateMixin {
  late AnimationController _levelCtrl; // anima el nivel 0→target
  late Animation<double> _level;
  late AnimationController _waveCtrl;  // fase infinita

  @override
  void initState() {
    super.initState();
    final to = (widget.targetPercent.clamp(0, 100)) / 100.0;

    _levelCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _level = CurvedAnimation(parent: _levelCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: 0.0, end: to));
    _levelCtrl.forward();

    _waveCtrl = AnimationController.unbounded(vsync: this)
      ..animateWith(_LinearWaveSimulation(speed: 1.2)); // rad/seg
  }

  @override
  void didUpdateWidget(covariant _WaterCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final to = (widget.targetPercent.clamp(0, 100)) / 100.0;
    _level = CurvedAnimation(parent: _levelCtrl, curve: Curves.easeOutCubic)
        .drive(Tween<double>(begin: _level.value, end: to));
    _levelCtrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _levelCtrl.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pctText = widget.targetPercent.clamp(0, 100).toStringAsFixed(0);
    final water = widget.waterColor;

    return ClipOval(
      child: CustomPaint(
        painter: _WaterCirclePainter(levelListenable: _level, waveListenable: _waveCtrl, waterColor: water),
        child: Center(
          child: Stack(
            children: [
              Text(
                '$pctText%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 3
                    ..color = Colors.black,
                ),
              ),
              Text(
                '$pctText%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: water,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaterCirclePainter extends CustomPainter {
  final Animation<double> levelListenable; // 0..1
  final Animation<double> waveListenable;  // fase
  final Color waterColor;

  _WaterCirclePainter({
    required this.levelListenable,
    required this.waveListenable,
    required this.waterColor,
  }) : super(repaint: Listenable.merge([levelListenable, waveListenable]));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    final bg = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, bg);

    final border = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, border);

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    final level = levelListenable.value.clamp(0.0, 1.0);
    final waterTop = h * (1 - level);

    final t = waveListenable.value;
    const omega1 = 2.2;
    const omega2 = 1.4;
    final phase1 = t * omega1;
    final phase2 = -t * omega2;
    const amp1 = 8.0;
    const amp2 = 5.0;

    Paint waterPaint(double o1, double o2) => Paint()
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [waterColor.withOpacity(o1), waterColor.withOpacity(o2)],
      ).createShader(Rect.fromLTWH(0, waterTop - 10, w, h - waterTop + 10));

    Path wave(double phase, double amp, double y0) {
      final path = Path()..moveTo(0, h);
      double y(double x) => y0 + math.sin((x / w * 2 * math.pi) + phase) * amp;
      path.lineTo(0, y(0));
      for (double x = 0; x <= w; x += 2) {
        path.lineTo(x, y(x));
      }
      path.lineTo(w, h);
      path.close();
      return path;
    }

    final back = wave(phase2, amp2, waterTop - 4);
    final front = wave(phase1, amp1, waterTop);

    canvas.drawPath(back, waterPaint(.25, .65));
    canvas.drawPath(front, waterPaint(.4, .85));

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

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WaterCirclePainter oldDelegate) => true;
}

class _LinearWaveSimulation extends Simulation {
  final double speed; // rad/s
  _LinearWaveSimulation({this.speed = 1.2});
  @override
  double x(double time) => speed * time;
  @override
  double dx(double time) => speed;
  @override
  bool isDone(double time) => false;
}