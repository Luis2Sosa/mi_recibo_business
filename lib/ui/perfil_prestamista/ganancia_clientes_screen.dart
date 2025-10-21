import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/app_frame.dart';

enum GananciaTipo { prestamo, producto, alquiler, todos }

class GananciaClientesScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;

  /// Filtro de categoría para esta pantalla:
  /// - prestamo: solo clientes de préstamos
  /// - producto: solo clientes de productos/fiados
  /// - alquiler: solo clientes de alquiler/renta
  /// - todos: sin filtro (comportamiento global)
  final GananciaTipo tipo;

  const GananciaClientesScreen({
    super.key,
    required this.docPrest,
    this.tipo = GananciaTipo.todos,
  });

  @override
  State<GananciaClientesScreen> createState() => _GananciaClientesScreenState();
}

class _GananciaClientesScreenState extends State<GananciaClientesScreen> {
  late Future<List<_ClienteGanancia>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarGanancias();
  }

  // ---------- Heurísticas por categoría ----------
  bool _esPrestamo(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
    final producto = (m['producto'] ?? '').toString().trim().toLowerCase();
    final esAlquilerNombre = producto.contains('alquiler') || producto.contains('renta');
    if (esAlquilerNombre || tipo == 'alquiler') return false;
    // Préstamo: tipo explícito o sin nombre de producto
    return tipo == 'prestamo' || producto.isEmpty;
  }

  bool _esProducto(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
    final producto = (m['producto'] ?? '').toString().trim().toLowerCase();
    final esAlquilerNombre = producto.contains('alquiler') || producto.contains('renta');
    if (tipo == 'alquiler' || esAlquilerNombre) return false;
    // Producto/fiado. Evita clasificar préstamos como producto
    return tipo == 'producto' || tipo == 'fiado' || (producto.isNotEmpty && tipo != 'prestamo');
  }

  bool _esAlquiler(Map<String, dynamic> m) {
    final tipo = (m['tipo'] ?? '').toString().toLowerCase().trim();
    final producto = (m['producto'] ?? '').toString().toLowerCase().trim();
    return tipo == 'alquiler' || producto.contains('alquiler') || producto.contains('renta');
  }

  bool _matchCategoria(Map<String, dynamic> m) {
    switch (widget.tipo) {
      case GananciaTipo.prestamo:
        return _esPrestamo(m);
      case GananciaTipo.producto:
        return _esProducto(m);
      case GananciaTipo.alquiler:
        return _esAlquiler(m);
      case GananciaTipo.todos:
        return true;
    }
  }

  Future<List<_ClienteGanancia>> _cargarGanancias() async {
    Query<Map<String, dynamic>> query = widget.docPrest.collection('clientes');

    // 🔹 Aplica filtro directo según el tipo de pantalla
    if (widget.tipo == GananciaTipo.producto) {
      query = query.where('tipo', whereIn: ['producto', 'fiado']);
    } else if (widget.tipo == GananciaTipo.prestamo) {
      query = query.where('tipo', isEqualTo: 'prestamo');
    } else if (widget.tipo == GananciaTipo.alquiler) {
      query = query.where('tipo', isEqualTo: 'alquiler');
    }

    final cs = await query.get();


    final List<_ClienteGanancia> rows = [];
    for (final c in cs.docs) {
      final data = c.data();

      // ----- FILTRO por categoría -----
      if (!_matchCategoria(data)) continue;

      final int saldo = (data['saldoActual'] ?? 0) as int;
      if (saldo <= 0) continue; // Solo clientes activos (con saldo)

      final String productoTxt = (data['producto'] ?? '').toString().trim();

      final pagos = await c.reference.collection('pagos').get();
      int ganancia = 0;
      int totalPagos = 0;
      int pagadoCapital = 0;

      for (final p in pagos.docs) {
        final m = p.data();
        ganancia += (m['pagoInteres'] ?? 0) as int;
        totalPagos += (m['totalPagado'] ?? 0) as int;
        pagadoCapital += (m['pagoCapital'] ?? 0) as int;
      }

      // Para PRODUCTOS (cuando no hay intereses), usar margen aprox:
      // ganancia ≈ totalPagado - (saldo + pagadoCapital). Clamp a 0 si negativo.
      if (ganancia == 0 && _esProducto(data)) {
        final capitalHistoricoConsumido = saldo + pagadoCapital;
        ganancia = totalPagos - capitalHistoricoConsumido;
        if (ganancia < 0) ganancia = 0;
      }

      // Para ALQUILER (cuando no hay intereses), mismo fallback de margen:
      if (ganancia == 0 && _esAlquiler(data)) {
        final capitalHistoricoConsumido = saldo + pagadoCapital;
        ganancia = totalPagos - capitalHistoricoConsumido;
        if (ganancia < 0) ganancia = 0;
      }

      final int totalHistorico = saldo + pagadoCapital;

      final nombre = '${(data['nombre'] ?? '').toString().trim()} '
          '${(data['apellido'] ?? '').toString().trim()}'.trim();
      final display = nombre.isEmpty ? (data['telefono'] ?? 'Cliente') : nombre;

      rows.add(_ClienteGanancia(
        id: c.id,
        nombre: display,
        ganancia: ganancia,
        saldo: saldo,
        totalPagado: totalPagos,
        totalHistorico: totalHistorico,
      ));
    }

    rows.sort((a, b) => b.ganancia.compareTo(a.ganancia));
    return rows;
  }

  String _rd(int v) {
    if (v <= 0) return '\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write(',');
        c = 0;
      }
    }
    return '\$${b.toString().split('').reversed.join()}';
  }

  String _titulo() {
    switch (widget.tipo) {
      case GananciaTipo.prestamo:
        return 'Ganancia por cliente — Préstamos';
      case GananciaTipo.producto:
        return 'Ganancia por cliente — Productos';
      case GananciaTipo.alquiler:
        return 'Ganancia por cliente — Alquiler';
      case GananciaTipo.todos:
        return 'Ganancia por cliente';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: HeaderBar(title: _titulo()),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: FutureBuilder<List<_ClienteGanancia>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return _loading();
                final list = snap.data ?? const <_ClienteGanancia>[];
                if (list.isEmpty) return _empty();
                final total = list.fold<int>(0, (p, e) => p + e.ganancia);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _resumen(total, list.length),
                    const SizedBox(height: 12),
                    Expanded(child: _lista(list)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumen(int total, int n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12, offset: const Offset(0, 5))],
        border: Border.all(color: const Color(0xFFE1E8F5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ganancia total (activos)',
                    style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(_rd(total),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.gradBottom)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E8F5)),
            ),
            child: Text('$n clientes',
                style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.gradTop)),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<_ClienteGanancia> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = list[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EEF8)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          it.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _Colors.ink,
                              height: 2,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _textoMonto('Total histórico:', _rd(it.totalHistorico), AppTheme.gradTop),
                  const SizedBox(height: 6),
                  _textoMonto('Pendiente:', _rd(it.saldo), it.saldo > 0 ? Colors.red : Colors.green),
                  const SizedBox(height: 6),
                  _textoMonto('Pagado:', _rd(it.totalPagado), const Color(0xFF2F9655)),
                ]),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Ganancia',
                      style: TextStyle(fontSize: 16, color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                  Text(_rd(it.ganancia),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.gradBottom)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _textoMonto(String label, String valor, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
        children: [TextSpan(text: '$label '), TextSpan(text: valor, style: TextStyle(color: color))],
      ),
    );
  }

  Widget _loading() => const Center(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        SizedBox(width: 10),
        Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _empty() {
    String msg = 'No hay clientes activos con ganancias';
    switch (widget.tipo) {
      case GananciaTipo.prestamo:
        msg = 'No hay clientes activos de PRÉSTAMOS con ganancias';
        break;
      case GananciaTipo.producto:
        msg = 'No hay clientes activos de PRODUCTOS con ganancias';
        break;
      case GananciaTipo.alquiler:
        msg = 'No hay clientes activos de ALQUILER con ganancias';
        break;
      case GananciaTipo.todos:
        break;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
        child: Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, color: Color(0xFF9CA3AF), size: 60),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _Colors.inkDim,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClienteGanancia {
  final String id;
  final String nombre;
  final int ganancia;
  final int saldo;
  final int totalPagado;
  final int totalHistorico; // saldo + pagadoCapital

  _ClienteGanancia({
    required this.id,
    required this.nombre,
    required this.ganancia,
    required this.saldo,
    required this.totalPagado,
    required this.totalHistorico,
  });
}

// HeaderBar local (público) para esta pantalla
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

class _Colors {
  static const ink = Color(0xFF111827);
  static const inkDim = Color(0xFF6B7280);
}