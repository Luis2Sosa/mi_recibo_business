// 📂 lib/ui/perfil_prestamista/ganancia_clientes_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum GananciaTipo { prestamo, producto, alquiler, todos }

class GananciaClientesScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  final GananciaTipo tipo;

  const GananciaClientesScreen({
    super.key,
    required this.docPrest,
    this.tipo = GananciaTipo.todos,
  });

  @override
  State<GananciaClientesScreen> createState() =>
      _GananciaClientesScreenState();
}

class _GananciaClientesScreenState extends State<GananciaClientesScreen> {
  late Future<List<_ClienteGanancia>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarGanancias();
  }

  // ===================== 🎨 COLORES PREMIUM =====================
  Color get _colorFondo {
    switch (widget.tipo) {
      case GananciaTipo.prestamo:
        return const Color(0xFF081021);
      case GananciaTipo.producto:
        return const Color(0xFF0C1F17);
      case GananciaTipo.alquiler:
        return const Color(0xFF1E1407);
      case GananciaTipo.todos:
        return const Color(0xFF0F172A);
    }
  }

  LinearGradient get _gradiente {
    switch (widget.tipo) {
      case GananciaTipo.prestamo:
        return const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GananciaTipo.producto:
        return const LinearGradient(
          colors: [Color(0xFF00C853), Color(0xFF69F0AE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GananciaTipo.alquiler:
        return const LinearGradient(
          colors: [Color(0xFFFFA000), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case GananciaTipo.todos:
        return const LinearGradient(
          colors: [Color(0xFF1E1E1E), Color(0xFF2C2C2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color get _accent {
    switch (widget.tipo) {
      case GananciaTipo.prestamo:
        return const Color(0xFF42A5F5);
      case GananciaTipo.producto:
        return const Color(0xFF00E676);
      case GananciaTipo.alquiler:
        return const Color(0xFFFFCA28);
      case GananciaTipo.todos:
        return Colors.amberAccent;
    }
  }

  // ===================== 🔹 CARGAR GANANCIAS =====================
  Future<List<_ClienteGanancia>> _cargarGanancias() async {
    Query<Map<String, dynamic>> query = widget.docPrest.collection('clientes');

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
      final saldo = (data['saldoActual'] ?? 0) as num;
      if (saldo <= 0) continue;

      final pagos = await c.reference.collection('pagos').get();
      num ganancia = 0;
      num totalPagos = 0;
      num pagadoCapital = 0;

      for (final p in pagos.docs) {
        final m = p.data();
        ganancia += (m['pagoInteres'] ?? 0) as num;
        totalPagos += (m['totalPagado'] ?? 0) as num;
        pagadoCapital += (m['pagoCapital'] ?? 0) as num;
      }

      if (ganancia == 0) {
        final capitalHistoricoConsumido = saldo + pagadoCapital;
        ganancia = totalPagos - capitalHistoricoConsumido;
        if (ganancia < 0) ganancia = 0;
      }

      final nombre =
      '${(data['nombre'] ?? '').toString()} ${(data['apellido'] ?? '').toString()}'
          .trim();
      final display =
      nombre.isEmpty ? (data['telefono'] ?? 'Cliente') : nombre;

      rows.add(_ClienteGanancia(
        id: c.id,
        nombre: display,
        ganancia: ganancia.toInt(),
        saldo: saldo.toInt(),
        totalPagado: totalPagos.toInt(),
        totalHistorico: (saldo + pagadoCapital).toInt(),
      ));
    }

    rows.sort((a, b) => b.ganancia.compareTo(a.ganancia));
    return rows;
  }

  // ===================== 🧱 CONSTRUCCIÓN =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _colorFondo,
      body: SafeArea(
        child: FutureBuilder<List<_ClienteGanancia>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            }

            final list = snap.data ?? [];
            if (list.isEmpty) return _empty();

            final visibles = list.take(1).toList();
            final bloqueados = list.skip(1).toList();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _encabezado(),
                    const SizedBox(height: 20),
                    const Text(
                      "💰 Ganancias por cliente",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18),
                    ),
                    const SizedBox(height: 12),
                    ...visibles.map((e) => _card(e, bloqueado: false)),
                    const SizedBox(height: 18),
                    if (bloqueados.isNotEmpty) _premiumBanner(),
                    ...bloqueados.map((e) => _card(e, bloqueado: true)),
                    const SizedBox(height: 35),
                    _botonFinal(),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ===================== 🔹 UI SECCIONES =====================
  Widget _encabezado() {
    final icono = {
      GananciaTipo.prestamo: Icons.account_balance_wallet_rounded,
      GananciaTipo.producto: Icons.inventory_2_rounded,
      GananciaTipo.alquiler: Icons.home_work_rounded,
      GananciaTipo.todos: Icons.pie_chart_rounded,
    }[widget.tipo]!;

    final titulo = {
      GananciaTipo.prestamo: "Rendimiento préstamo",
      GananciaTipo.producto: "Rendimiento productos",
      GananciaTipo.alquiler: "Rendimiento alquiler",
      GananciaTipo.todos: "Rendimiento general",
    }[widget.tipo]!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icono, color: _accent, size: 30),
            const SizedBox(width: 10),
            Text(
              titulo,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text("LIVE",
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _card(_ClienteGanancia e, {bool bloqueado = false}) {
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.nombre,
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text("Ganancia: \$${e.ganancia}",
                    style: TextStyle(
                        color: _accent, fontWeight: FontWeight.w700)),
                Text("Saldo: \$${e.saldo}",
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded, color: Colors.white54)
        ],
      ),
    );

    if (!bloqueado) return card;

    // 🔒 Borroso oscuro premium
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: Opacity(opacity: 0.25, child: card),
            ),
          ),
        ),
        const Icon(Icons.lock_outline_rounded,
            color: Colors.white70, size: 28),
      ],
    );
  }

  Widget _premiumBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: _gradiente,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            "Desbloquea Mi Recibo Premium 🔒",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            "Accede a todas las ganancias completas de tus clientes.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.white70, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _botonFinal() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: _gradiente,
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Center(
          child: Text(
            "Volver al resumen",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _empty() => const Center(
    child: Padding(
      padding: EdgeInsets.all(50),
      child: Text(
        "No hay clientes activos con ganancias.",
        style: TextStyle(color: Colors.white70, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

// ===================== 📦 MODELO =====================
class _ClienteGanancia {
  final String id;
  final String nombre;
  final int ganancia;
  final int saldo;
  final int totalPagado;
  final int totalHistorico;

  _ClienteGanancia({
    required this.id,
    required this.nombre,
    required this.ganancia,
    required this.saldo,
    required this.totalPagado,
    required this.totalHistorico,
  });
}
