// lib/ui/perfil_prestamista/alquiler_estadistica.dart
// Mini-dashboard de ALQUILER: KPIs, ocupación, vencimientos y gráfico últimos 6 meses + CTA.
// Look premium + bloque para anuncio (placeholder) listo para conectar google_mobile_ads.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/widgets/app_frame.dart'; // AppGradientBackground + AppFrame
import 'package:mi_recibo/ui/theme/app_theme.dart' show AppTheme;
import 'package:mi_recibo/ui/perfil_prestamista/ganancia_clientes_screen.dart';

// Formateo de moneda local (RD$ especial; resto por locale del dispositivo)
import 'package:mi_recibo/ui/widgets/widgets_shared.dart' as util show monedaLocal;

import '../widgets/bar_chart.dart';

class AlquilerEstadisticaScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const AlquilerEstadisticaScreen({super.key, required this.docPrest});

  @override
  State<AlquilerEstadisticaScreen> createState() => _AlquilerEstadisticaScreenState();
}

class _AlquilerEstadisticaScreenState extends State<AlquilerEstadisticaScreen> {
  late Future<_ResumenAlquiler> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarResumenAlquiler();
  }

  // ==================== CARGA Y AGREGACIÓN (solo ALQUILER) ====================
  Future<_ResumenAlquiler> _cargarResumenAlquiler() async {
    // Ventana: últimos 6 meses para gráfico
    const mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
    final Map<String, int> pagosPorMes = { for (final m in months) '${m.year}-${_two(m.month)}': 0 };

    // KPIs
    int activos = 0;             // contratos de alquiler con saldo > 0
    int inactivos = 0;           // contratos de alquiler saldo == 0
    int ingresosMes = 0;         // sum(totalPagado) últimos 30 días (solo alquiler)
    int gananciaNeta = 0;        // sum(pagoInteres) como proxy; si 0, usamos (total - capital)
    int vencidos = 0;            // proximaFecha < hoy
    int porVencer = 0;           // proximaFecha dentro de 7 días

    final limiteMes = now.subtract(const Duration(days: 30));

    final cs = await widget.docPrest.collection('clientes').get();
    for (final c in cs.docs) {
      final m = c.data();
      final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
      final producto = (m['producto'] ?? '').toString().trim();

      // Heurística de alquiler: tipo == 'alquiler' o producto tiene pista (alquiler/renta)
      final esAlquiler = tipo == 'alquiler' ||
          producto.toLowerCase().contains('alquiler') ||
          producto.toLowerCase().contains('renta');

      if (!esAlquiler) continue;

      final int saldo = (m['saldoActual'] ?? 0) as int;
      final int capitalInicial = (m['capitalInicial'] ?? 0) as int;

      if (saldo > 0) activos++; else inactivos++;

      // Vencimientos
      final pf = m['proximaFecha'];
      if (pf is Timestamp) {
        final d = pf.toDate();
        if (d.isBefore(now) && saldo > 0) vencidos++;
        if (!d.isBefore(now) && d.difference(now).inDays <= 7 && saldo > 0) porVencer++;
      }

      // Pagos (límite defensivo)
      final pagos = await c.reference.collection('pagos').limit(250).get();
      int totalPagadoCliente = 0;
      int interesCliente = 0;
      int pagadoCapitalCliente = 0;

      for (final p in pagos.docs) {
        final d = p.data();
        final tp = (d['totalPagado'] ?? 0) as int;
        final pi = (d['pagoInteres'] ?? 0) as int;
        final pc = (d['pagoCapital'] ?? 0) as int;

        totalPagadoCliente += tp;
        interesCliente += pi;
        pagadoCapitalCliente += pc;

        // Ingresos últimos 30 días
        final ts = d['fecha'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          if (!dt.isBefore(limiteMes)) ingresosMes += tp;

          // Serie mensual
          final key = '${dt.year}-${_two(dt.month)}';
          if (pagosPorMes.containsKey(key)) {
            pagosPorMes[key] = (pagosPorMes[key] ?? 0) + tp;
          }
        }
      }

      // Ganancia neta: si no hay interes registrado, fallback a (total - capital histórico)
      int g = interesCliente;
      if (g == 0) {
        final capitalHistorico = saldo + pagadoCapitalCliente;
        g = (totalPagadoCliente - capitalHistorico);
        if (g < 0) g = 0;
      }
      gananciaNeta += g;
    }

    final totalContratos = activos + inactivos;
    final ocupacion = totalContratos > 0 ? (activos * 100.0 / totalContratos) : 0.0;

    final values = <int>[];
    final labels = <String>[];
    for (final m in months) {
      labels.add(mesesTxt[m.month - 1]);
      values.add(pagosPorMes['${m.year}-${_two(m.month)}'] ?? 0);
    }

    return _ResumenAlquiler(
      activos: activos,
      ingresosMes: ingresosMes,
      gananciaNeta: gananciaNeta,
      vencidos: vencidos,
      porVencer: porVencer,
      ocupacion: ocupacion,
      labels: labels,
      values: values,
    );
  }

  // ==================== HELPERS ====================
  String _two(int n) => n.toString().padLeft(2, '0');
  String _rd(int v) => util.monedaLocal(v);
  String _pct(double x) => '${x.toStringAsFixed(1)}%';

  // ==================== UI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const _HeaderBar(title: 'Resumen de Alquiler'),
          child: FutureBuilder<_ResumenAlquiler>(
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
              if (data == null) return _emptyCard('Sin datos de alquiler');

              final totalSerie = data.values.fold<int>(0, (p, v) => p + v);

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                  _hint(),
                  const SizedBox(height: 12),

                  // ===== KPIs premium (4) =====
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _kpi('Activos alquilados', '${data.activos}',
                          bg: const Color(0xFFE5E7EB), accent: _BrandX.ink),
                      _kpi('Ingresos últimos 30 días', _rd(data.ingresosMes),
                          bg: const Color(0xFFDCFCE7), accent: const Color(0xFF16A34A)),
                      _kpi('Ganancia neta', _rd(data.gananciaNeta),
                          bg: const Color(0xFFEDE9FE), accent: const Color(0xFF6D28D9)),
                      _kpi('Tasa de ocupación', _pct(data.ocupacion),
                          bg: const Color(0xFFF2F6FD), accent: AppTheme.gradTop),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Estados sugeridos =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _kvIcon(label: 'Estados sugeridos',
                            value: '📆 En curso  •  ⏰ Por vencer  •  🚫 Finalizado'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Vencidos / Por vencer + gráfico =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.event_note_rounded, color: _BrandX.inkDim),
                            SizedBox(width: 8),
                            Text('Vencimientos y tendencia',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _BrandX.ink)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _pill('Vencidos', '${data.vencidos}', const Color(0xFFE11D48)),
                            const SizedBox(width: 8),
                            _pill('Por vencer (7d)', '${data.porVencer}', const Color(0xFFEA580C)),
                          ],
                        ),
                        const SizedBox(height: 10),
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

                  const SizedBox(height: 12),

                  // ===== Panel Premium con anuncio (placeholder) =====
                  _premiumAdPanel(),

                  const SizedBox(height: 16),

                  // ===== CTA =====
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: en el futuro, filtrar lista solo a contratos de ALQUILER
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GananciaClientesScreen(docPrest: widget.docPrest),
                          ),
                        );
                      },
                      icon: const Icon(Icons.people_alt_rounded),
                      label: const Text('Ver detalles de clientes', style: TextStyle(fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gradTop,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
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

  // ==================== UI HELPERS ====================
  Widget _hint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E8F5)),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, color: _BrandX.inkDim, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Monitorea vencidos y por vencer. Revisa la ocupación y la tendencia mensual.',
              style: TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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

  Widget _divider() => Container(
    height: 1.2,
    color: _BrandX.divider,
    margin: const EdgeInsets.symmetric(vertical: 12),
  );

  Widget _kpi(String title, String value, {required Color bg, required Color accent}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String txt) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w800, color: _BrandX.inkDim)),
      ),
    );
  }

  static Widget _pill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // Par título/valor con ícono sutil
  // (se usa para “Estados sugeridos”)
  // Ejemplo: _kvIcon(label: 'Estados sugeridos', value: '📆 …')
  static const TextStyle _kvLabel = TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700);
  static const TextStyle _kvValue = TextStyle(color: _BrandX.ink, fontWeight: FontWeight.w900);

  // ===== Panel Premium (Glass + Degradado) con CTA de anuncio =====
  Widget _premiumAdPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.gradTop.withOpacity(0.98), AppTheme.gradBottom.withOpacity(0.98)],
        ),
        boxShadow: [
          BoxShadow(color: AppTheme.gradTop.withOpacity(.28), blurRadius: 22, offset: const Offset(0, 10)),
        ],
        border: Border.all(color: Colors.white.withOpacity(.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.18),
                  border: Border.all(color: Colors.white.withOpacity(.55), width: 1.2),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Contenido Premium',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: .3),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('PRO', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Desbloquea una métrica avanzada y un consejo de ocupación viendo un anuncio corto.',
            style: TextStyle(color: Colors.white.withOpacity(.95), fontWeight: FontWeight.w600, height: 1.35),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _showPremiumAd,
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('Ver contenido PRO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.gradTop,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder del anuncio premium. Aquí conectarás google_mobile_ads.
  Future<void> _showPremiumAd() async {
    if (!mounted) return;
    final demoTip = 'Incrementa ocupación: aplica descuento del 5% por contrato de 3+ meses.';
    final demoMetric = 'Ocupación media 90 días: 74%';
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [AppTheme.gradTop.withOpacity(.06), AppTheme.gradBottom.withOpacity(.06)]),
            border: Border.all(color: const Color(0xFFE7EEF8)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: const [
                Icon(Icons.workspace_premium_rounded, color: Color(0xFF2458D6)),
                SizedBox(width: 8),
                Text('Contenido PRO desbloqueado', style: TextStyle(fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7EEF8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF0A9A76)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(demoTip, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFEF4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7F2C9)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insights_rounded, color: Color(0xFF6D28D9)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(demoMetric, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(c),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.gradTop,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 2,
                  ),
                  child: const Text('Listo'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TIPOS ====================
class _ResumenAlquiler {
  final int activos;
  final int ingresosMes;
  final int gananciaNeta;
  final int vencidos;
  final int porVencer;
  final double ocupacion;

  final List<String> labels;
  final List<int> values;

  _ResumenAlquiler({
    required this.activos,
    required this.ingresosMes,
    required this.gananciaNeta,
    required this.vencidos,
    required this.porVencer,
    required this.ocupacion,
    required this.labels,
    required this.values,
  });
}

// ==================== HEADER LOCAL ====================
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
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ],
    );
  }
}

// ==================== PALETA LOCAL ====================
class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

// ==================== Par título/valor con ícono (sutil) ====================
class _kvIcon extends StatelessWidget {
  final String label;
  final String value;
  const _kvIcon({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700))),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink),
            ),
          ),
        ),
      ],
    );
  }
}
