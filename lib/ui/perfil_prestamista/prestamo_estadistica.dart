// lib/ui/perfil_prestamista/prestamo_estadistica.dart
// Dash de PRÉSTAMOS (premium + estratégico) sin panel PRO ni botón externo.
// Novedad:
//   1) KPI “Ganancia por clientes” idéntico en lenguaje visual al KPI premium.
//      Va PRIMERO. TAP abre la lista solo de clientes de préstamo.
//   2) Héroe “Índice de recuperación” con círculo de AGUA animada (olas infinitas).
//      - Cae/sube desde 0 hasta el % real al entrar.
//      - Permanece animado todo el tiempo.
//      - Rojo si < 50%, Verde si ≥ 50%.
//   3) Formato moneda LATAM: sin decimales, separador de miles por coma. Ej: $ 5,800.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/widgets/app_frame.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/bar_chart.dart';
import 'package:mi_recibo/ui/perfil_prestamista/ganancias_prestamo_screen.dart';




class PrestamoEstadisticaScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const PrestamoEstadisticaScreen({super.key, required this.docPrest});

  @override
  State<PrestamoEstadisticaScreen> createState() => _PrestamoEstadisticaScreenState();
}

class _PrestamoEstadisticaScreenState extends State<PrestamoEstadisticaScreen>
    with TickerProviderStateMixin {
  late Future<_ResumenPrestamos> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarResumenPrestamos();
  }

  // ==================== CARGA Y AGREGACIÓN (solo PRÉSTAMOS) ====================
  Future<_ResumenPrestamos> _cargarResumenPrestamos() async {
    const mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
    final Map<String, int> pagosPorMes = { for (final m in months) '${m.year}-${_two(m.month)}': 0 };

    final last30Start = now.subtract(const Duration(days: 30));
    final prev30Start = now.subtract(const Duration(days: 60));

    int capitalTotalPrestado = 0;
    int totalRecuperado = 0;
    int gananciaInteres = 0;
    int clientesActivos = 0;
    int morosos = 0;
    int sumaDiasMora = 0;

    int cobrosUltimos30 = 0;
    int cobrosPrevios30 = 0;

    final List<_Moroso> topMorosos = [];

    final cs = await widget.docPrest.collection('clientes').get();

    for (final c in cs.docs) {
      final m = c.data();
      final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
      final producto = (m['producto'] ?? '').toString().trim();

      // Heurística: prestamos = tipo == 'prestamo' o producto vacío (legacy)
      final bool esPrestamo = tipo == 'prestamo' || producto.isEmpty;
      if (!esPrestamo) continue;

      final int saldo = (m['saldoActual'] ?? 0) as int;

      final pagos = await c.reference.collection('pagos').limit(250).get();
      int totalPagadoCliente = 0;
      int interesesCliente   = 0;
      int pagadoCapitalCliente = 0;

      for (final p in pagos.docs) {
        final d = p.data();
        final tp = (d['totalPagado'] ?? 0) as int;
        totalPagadoCliente += tp;
        interesesCliente   += (d['pagoInteres'] ?? 0) as int;
        pagadoCapitalCliente += (d['pagoCapital'] ?? 0) as int;

        final ts = d['fecha'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          final key = '${dt.year}-${_two(dt.month)}';
          if (pagosPorMes.containsKey(key)) {
            pagosPorMes[key] = (pagosPorMes[key] ?? 0) + tp;
          }
          if (dt.isAfter(last30Start)) {
            cobrosUltimos30 += tp;
          } else if (dt.isAfter(prev30Start) && dt.isBefore(last30Start)) {
            cobrosPrevios30 += tp;
          }
        }
      }

      final int capitalHistorico = saldo + pagadoCapitalCliente;
      capitalTotalPrestado += capitalHistorico;

      totalRecuperado += totalPagadoCliente;
      gananciaInteres += interesesCliente;

      if (saldo > 0) {
        clientesActivos++;
        final pf = m['proximaFecha'];
        if (pf is Timestamp) {
          final d = pf.toDate();
          if (d.isBefore(DateTime.now())) {
            final dias = DateTime.now().difference(d).inDays;
            morosos++;
            if (dias > 0) {
              sumaDiasMora += dias;
              final nombre = '${(m['nombre'] ?? '').toString().trim()} ${(m['apellido'] ?? '').toString().trim()}'.trim();
              final fallback = (m['telefono'] ?? 'Cliente').toString();
              topMorosos.add(_Moroso(
                nombre: nombre.isEmpty ? fallback : nombre,
                dias: dias,
                saldo: saldo,
              ));
            }
          }
        }
      }
    }

    topMorosos.sort((a, b) => b.dias.compareTo(a.dias));
    final mejores = topMorosos.take(3).toList();

    final promInteresEfectivo = (capitalTotalPrestado > 0)
        ? (gananciaInteres * 100.0 / capitalTotalPrestado)
        : 0.0;

    final values = <int>[];
    final labels = <String>[];
    for (final m in months) {
      labels.add(mesesTxt[m.month - 1]);
      values.add(pagosPorMes['${m.year}-${_two(m.month)}'] ?? 0);
    }

    final double recoveryIndex = (capitalTotalPrestado > 0)
        ? (totalRecuperado / capitalTotalPrestado) * 100.0
        : 0.0;

    final int delta30 = cobrosUltimos30 - cobrosPrevios30;
    final double deltaPct30 = cobrosPrevios30 > 0
        ? (delta30 * 100.0 / cobrosPrevios30)
        : (cobrosUltimos30 > 0 ? 100.0 : 0.0);

    return _ResumenPrestamos(
      capitalTotalPrestado: capitalTotalPrestado,
      totalRecuperado: totalRecuperado,
      gananciaInteres: gananciaInteres,
      clientesActivos: clientesActivos,
      promInteresEfectivo: promInteresEfectivo,
      morosos: morosos,
      promedioDiasMora: morosos > 0 ? (sumaDiasMora / morosos) : 0.0,
      labels: labels,
      values: values,
      recoveryIndex: recoveryIndex.clamp(0, 100).toDouble(), // 0–100 real
      cobrosUltimos30: cobrosUltimos30,
      deltaPct30: deltaPct30,
      topMorosos: mejores,
    );
  }

  // ==================== HELPERS ====================
  String _two(int n) => n.toString().padLeft(2, '0');
  String _pct(double x) => '${x.toStringAsFixed(1)}%';

  // Moneda LATAM, sin decimales y con separador de miles = coma. Ej: 5800 => "$ 5,800"
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
          header: const _HeaderBar(title: 'Resumen de Préstamos'),
          child: FutureBuilder<_ResumenPrestamos>(
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
              if (data == null) return _emptyCard('Sin datos de préstamos');

              final totalSerie = data.values.fold<int>(0, (p, v) => p + v);

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
                children: [
                  // ====== HERO: ÍNDICE DE RECUPERACIÓN con AGUA ======
                  _heroRecoveryWater(
                    index: data.recoveryIndex,
                    cobros30: _rd(data.cobrosUltimos30),
                    deltaPct30: data.deltaPct30,
                  ),
                  const SizedBox(height: 12),

                  // ===== KPIs (4) — PRIMERO: Ganancia por clientes (tap premium) =====
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      // 1) Ganancia por clientes (idéntico estilo a "Ganancias totales" premium, icono grande, SIN monto)
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
                              builder: (_) => GananciasPrestamoScreen(docPrest: widget.docPrest),
                            ),
                          );
                        },
                      ),

                      // 2) Capital prestado (rojo — dinero en la calle)
                      _kpiSmart(
                        title: 'Capital prestado',
                        value: data.capitalTotalPrestado,
                        display: _rd(data.capitalTotalPrestado),
                        bg: const Color(0xFFFDF3F3),
                        accent: const Color(0xFFB91C1C),
                      ),

                      // 3) Total recuperado (verde)
                      _kpiSmart(
                        title: 'Total recuperado',
                        value: data.totalRecuperado,
                        display: _rd(data.totalRecuperado),
                        bg: const Color(0xFFDCFCE7),
                        accent: const Color(0xFF16A34A),
                      ),

                      // 4) Clientes activos
                      _kpiSmart(
                        title: 'Clientes activos',
                        value: data.clientesActivos,
                        display: '${data.clientesActivos}',
                        bg: const Color(0xFFF2F6FD),
                        accent: AppTheme.gradTop,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Inteligencia =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: const [
                          Icon(Icons.percent_rounded, color: _BrandX.inkDim),
                          SizedBox(width: 8),
                          Text('Interés y mora',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
                        ]),
                        const SizedBox(height: 10),
                        _kv('Promedio interés aplicado', _pct(data.promInteresEfectivo)),
                        _divider(),
                        _kv('Clientes morosos', '${data.morosos}'),
                        _divider(),
                        _kv('Mora promedio (días)', data.morosos > 0 ? data.promedioDiasMora.toStringAsFixed(1) : '—'),
                        if (data.topMorosos.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text('Alertas (Top morosos)', style: TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          ...data.topMorosos.map((m) => _morosoTile(m)).toList(),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Serie 6 meses =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.insights_rounded, color: _BrandX.inkDim),
                            SizedBox(width: 8),
                            Text('Cobros últimos 6 meses',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SimpleBarChart(
                          values: data.values,
                          labels: data.labels,
                          yTickFormatter: (v) => _rd(v),
                        ),
                        const SizedBox(height: 8),
                        Text('Total: ${_rd(totalSerie)}',
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

  // ==================== HERO: AGUA EN CÍRCULO ====================
  Widget _heroRecoveryWater({
    required double index,
    required String cobros30,
    required double deltaPct30,
  }) {
    final bool up = index >= 50.0; // color según índice
    final Color water = up ? const Color(0xFF16A34A) : const Color(0xFFE11D48); // verde / rojo
    final Color trendColor = deltaPct30 >= 0 ? const Color(0xFF16A34A) : const Color(0xFFE11D48);
    final String trendTxt = '${deltaPct30 >= 0 ? '▲' : '▼'} ${deltaPct30.abs().toStringAsFixed(1)}% en 30d';
    final double clamped = index.clamp(0, 100);

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
          // — CÍRCULO GRANDE con agua
          SizedBox(
            width: 160,
            height: 160,
            child: _WaterCircle(targetPercent: clamped, waterColor: water),
          ),
          const SizedBox(width: 16),
          // — Texto y pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Índice de recuperación',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: .2),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cobrado últimos 30 días',
                  style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  cobros30,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 1))],
                  ),
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(.65)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(deltaPct30 >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                            color: trendColor, size: 22),
                        const SizedBox(width: 2),
                        Text(trendTxt, style: TextStyle(color: trendColor, fontWeight: FontWeight.w900)),
                      ],
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

  // KPI inteligente: centra si value == 0, alinea izquierda si > 0
  Widget _kpiSmart({
    required String title,
    required int value,
    required String display,
    required Color bg,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _BrandX.inkDim,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            display,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  // KPI Premium estilo “Ganancias Totales” con TAP (icono grande, sin monto)
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

  // ====== Helpers UI ======
  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(
            k,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
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

  Widget _morosoTile(_Moroso m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFAD4D4)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink)),
              const SizedBox(height: 2),
              Text('Saldo: ${_rd(m.saldo)}',
                  style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4E6),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: Text('${m.dias} d',
                style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String t) => Container(
    margin: const EdgeInsets.all(12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Center(
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _BrandX.inkDim))),
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

  Widget _divider() =>
      Container(height: 1.2, color: _BrandX.divider, margin: const EdgeInsets.symmetric(vertical: 12));
}

// ==================== TIPOS ====================
class _Moroso {
  final String nombre;
  final int dias;
  final int saldo;
  _Moroso({required this.nombre, required this.dias, required this.saldo});
}

class _ResumenPrestamos {
  final int capitalTotalPrestado;
  final int totalRecuperado;
  final int gananciaInteres;
  final int clientesActivos;
  final double promInteresEfectivo;
  final int morosos;
  final double promedioDiasMora;

  final List<String> labels;
  final List<int> values;
  final double recoveryIndex;
  final int cobrosUltimos30;
  final double deltaPct30;
  final List<_Moroso> topMorosos;

  _ResumenPrestamos({
    required this.capitalTotalPrestado,
    required this.totalRecuperado,
    required this.gananciaInteres,
    required this.clientesActivos,
    required this.promInteresEfectivo,
    required this.morosos,
    required this.promedioDiasMora,
    required this.labels,
    required this.values,
    required this.recoveryIndex,
    required this.cobrosUltimos30,
    required this.deltaPct30,
    required this.topMorosos,
  });
}

// ==================== HEADER & PALETA ====================
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
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

// ==================== WATER CIRCLE ====================
// Círculo que se llena con AGUA animada (olas infinitas), inicia en 0 y sube hasta targetPercent.
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
              // Stroke negro para el % (contorno), y encima relleno del color del agua
              Text(
                '$pctText%',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  foreground:  Paint()
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
    final center = Offset(w/2, h/2);
    final radius = math.min(w, h) / 2;

    // Fondo (vidrio suave)
    final bg = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFEFF6FF), Color(0xFFE0F2FE)],
      ).createShader(Offset.zero & size);
    canvas.drawCircle(center, radius, bg);

    // Borde exterior sutil
    final border = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withOpacity(.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, border);

    // Clip a círculo para no salirse
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Nivel
    final level = levelListenable.value.clamp(0.0, 1.0);
    final waterTop = h * (1 - level);

    // Fase de ondas
    final t = waveListenable.value;
    const omega1 = 2.2;
    const omega2 = 1.4;
    final phase1 = t * omega1;
    final phase2 = -t * omega2;
    const amp1 = 8.0;
    const amp2 = 5.0;

    // Pinturas
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

    // Highlight de cresta
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