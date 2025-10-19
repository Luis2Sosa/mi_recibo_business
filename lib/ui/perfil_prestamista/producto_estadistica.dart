// lib/ui/perfil_prestamista/producto_estadistica.dart
// Mini-dashboard de PRODUCTOS: KPIs, top productos (barra) y CTA a “Ganancia por cliente”.
// Look premium + bloque para anuncio (placeholder) listo para conectar google_mobile_ads.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/widgets/app_frame.dart';              // AppGradientBackground + AppFrame
import 'package:mi_recibo/ui/theme/app_theme.dart' show AppTheme;  // gradientes y tema
import 'package:mi_recibo/ui/widgets/bar_chart.dart';              // SimpleBarChart
import 'package:mi_recibo/ui/perfil_prestamista/ganancia_clientes_screen.dart';

// Moneda local (RD$ especial + locale del dispositivo)
import 'package:mi_recibo/ui/widgets/widgets_shared.dart' as util show monedaLocal;

class ProductoEstadisticaScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const ProductoEstadisticaScreen({super.key, required this.docPrest});

  @override
  State<ProductoEstadisticaScreen> createState() => _ProductoEstadisticaScreenState();
}

class _ProductoEstadisticaScreenState extends State<ProductoEstadisticaScreen> {
  late Future<_ResumenProductos> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarResumenProductos();
  }

  // ==================== CARGA Y AGREGACIÓN (solo PRODUCTOS) ====================
  Future<_ResumenProductos> _cargarResumenProductos() async {
    int totalInvertido = 0;       // suma capitalInicial en productos
    int ingresos = 0;             // sum(totalPagado)
    int gananciaNeta = 0;         // ingresos - capital histórico consumido
    int clientesActivos = 0;      // saldoActual > 0

    int sumGanancias = 0;         // para margen promedio
    int sumCapitalBase = 0;

    final Map<String, int> movimientoPorProducto = {}; // top productos por cobros

    final cs = await widget.docPrest.collection('clientes').get();
    for (final c in cs.docs) {
      final m = c.data();
      final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
      final producto = (m['producto'] ?? '').toString().trim();

      // Heurística de "producto": tipo producto/fiado o tener nombre de producto
      final bool esProducto = tipo == 'producto' || tipo == 'fiado' || producto.isNotEmpty;
      if (!esProducto) continue;

      final int saldo = (m['saldoActual'] ?? 0) as int;
      final int capitalInicial = (m['capitalInicial'] ?? 0) as int;

      // Pagos (limitados por seguridad/rendimiento)
      final pagos = await c.reference.collection('pagos').limit(250).get();
      int totalPagadoCliente = 0;
      int pagadoCapitalCliente = 0;

      for (final p in pagos.docs) {
        final d = p.data();
        totalPagadoCliente += (d['totalPagado'] ?? 0) as int;
        pagadoCapitalCliente += (d['pagoCapital'] ?? 0) as int;
      }

      final int capitalHistoricoConsumido = saldo + pagadoCapitalCliente;

      totalInvertido += capitalInicial;
      ingresos += totalPagadoCliente;

      final int gananciaCliente = totalPagadoCliente - capitalHistoricoConsumido;
      gananciaNeta += gananciaCliente;

      if (saldo > 0) clientesActivos++;

      if (producto.isNotEmpty) {
        movimientoPorProducto[producto] =
            (movimientoPorProducto[producto] ?? 0) + totalPagadoCliente;
      }

      sumGanancias += gananciaCliente.clamp(0, 1 << 31);
      sumCapitalBase += capitalHistoricoConsumido.clamp(0, 1 << 31);
    }

    final double margenPromedio =
    (sumCapitalBase > 0) ? (sumGanancias * 100.0 / sumCapitalBase) : 0.0;

    // Top 6 productos por monto cobrado
    final entries = movimientoPorProducto.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(6).toList();

    final labelsTop = top.map((e) => _acorta(e.key)).toList();
    final valuesTop = top.map((e) => e.value).toList();

    return _ResumenProductos(
      totalInvertido: totalInvertido,
      ingresos: ingresos,
      gananciaNeta: gananciaNeta,
      clientesActivos: clientesActivos,
      margenPromedio: margenPromedio,
      labelsTop: labelsTop,
      valuesTop: valuesTop,
    );
  }

  // ==================== HELPERS ====================
  String _rd(int v) => util.monedaLocal(v);
  String _pct(double x) => '${x.toStringAsFixed(1)}%';

  String _acorta(String s, {int max = 12}) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max - 1)}…';
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
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                children: [
                  _hint(),

                  const SizedBox(height: 12),

                  // ===== KPIs (4) =====
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.55,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: [
                      _kpi('Total invertido', _rd(data.totalInvertido),
                          bg: const Color(0xFFE5E7EB), accent: _BrandX.ink),
                      _kpi('Ingresos por ventas/fiados', _rd(data.ingresos),
                          bg: const Color(0xFFDCFCE7), accent: const Color(0xFF16A34A)),
                      _kpi('Ganancia neta', _rd(data.gananciaNeta),
                          bg: const Color(0xFFEDE9FE), accent: const Color(0xFF6D28D9)),
                      _kpi('Clientes activos', '${data.clientesActivos}',
                          bg: const Color(0xFFF2F6FD), accent: AppTheme.gradTop),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Margen + estados =====
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Margen promedio', _pct(data.margenPromedio)),
                        _divider(),
                        const _kvIcon(
                          label: 'Estados sugeridos',
                          value: '🟩 En stock  •  🟨 En tránsito  •  🟥 Agotado',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== Top productos por movimiento =====
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

                  const SizedBox(height: 12),

                  // ===== Panel Premium con anuncio (placeholder) =====
                  _premiumAdPanel(),

                  const SizedBox(height: 16),

                  // ===== CTA a ganancia por cliente =====
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // FUTURO: pasar flag para filtrar solo clientes con productos si haces una vista dedicada
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
              'Revisa el top por movimiento. Toca para ver clientes con productos pendientes.',
              style: TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  // ===== Panel Premium (Glass + Degradado) con CTA de anuncio =====
  Widget _premiumAdPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gradTop.withOpacity(0.98),
            AppTheme.gradBottom.withOpacity(0.98),
          ],
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
            'Desbloquea un tip de inventario y una métrica adicional viendo un anuncio corto.',
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
    final demoTip = 'Mejora rotación: aplica “2x1” en productos lentos y libera capital inmovilizado.';
    final demoMetric = 'Rotación (últimos 30 días): 1.4x';
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

  Widget _emptyCard(String txt) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: Center(
        child: Text(txt, style: const TextStyle(fontWeight: FontWeight.w800, color: _BrandX.inkDim)),
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
            child: Text(value,
                maxLines: 1,
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent)),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: TextStyle(color: _BrandX.inkDim))),
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
}

// ==================== TIPOS ====================
class _ResumenProductos {
  final int totalInvertido;
  final int ingresos;
  final int gananciaNeta;
  final int clientesActivos;
  final double margenPromedio;

  final List<String> labelsTop;
  final List<int> valuesTop;

  _ResumenProductos({
    required this.totalInvertido,
    required this.ingresos,
    required this.gananciaNeta,
    required this.clientesActivos,
    required this.margenPromedio,
    required this.labelsTop,
    required this.valuesTop,
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
