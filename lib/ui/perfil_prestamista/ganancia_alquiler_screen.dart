// 📂 lib/ui/perfil_prestamista/ganancia_alquiler_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/ui/premium/pantalla_bloqueo_premium.dart';

class GananciaAlquilerScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;

  const GananciaAlquilerScreen({super.key, required this.docPrest});

  @override
  State<GananciaAlquilerScreen> createState() => _GananciaAlquilerScreenState();
}

class _GananciaAlquilerScreenState extends State<GananciaAlquilerScreen> {
  late Future<List<_ClienteGanancia>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarGanancias();
  }

  // 🎨 Colores y estilo del módulo Alquiler
  Color get _colorFondo => const Color(0xFF2A1C09); // Marrón oscuro premium
  Color get _accent => const Color(0xFFFFD54F); // Dorado suave

  LinearGradient get _gradiente => const LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFFFD54F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===================== 🔹 CARGAR GANANCIAS =====================
  Future<List<_ClienteGanancia>> _cargarGanancias() async {
    Query<Map<String, dynamic>> query =
    widget.docPrest.collection('clientes').where('tipo', isEqualTo: 'alquiler');

    final cs = await query.get();
    final List<_ClienteGanancia> rows = [];

    for (final c in cs.docs) {
      final data = c.data();
      final saldo = (data['saldoActual'] ?? 0) as num;
      if (saldo <= 0) continue;

      final pagos = await c.reference.collection('pagos').get();
      num ganancia = 0;
      for (final p in pagos.docs) {
        ganancia += (p.data()['pagoInteres'] ?? 0) as num;
      }

      final nombre =
      '${(data['nombre'] ?? '').toString()} ${(data['apellido'] ?? '').toString()}'.trim();
      rows.add(_ClienteGanancia(
        id: c.id,
        nombre: nombre.isEmpty ? (data['telefono'] ?? 'Cliente') : nombre,
        ganancia: ganancia.toInt(),
        saldo: saldo.toInt(),
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
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }

            final list = snap.data ?? [];
            if (list.isEmpty) return _empty();

            final visibles = list.take(1).toList();
            final bloqueados = list.skip(1).toList();

            if (bloqueados.isEmpty && list.isNotEmpty) {
              bloqueados.add(list.first);
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _encabezado(),
                    const SizedBox(height: 25),
                    const Text(
                      "💰 Ganancias por alquiler",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 🔹 Cliente visible
                    ...visibles.map((e) => _card(context, e, false)),
                    const SizedBox(height: 18),

                    // 🔹 Banner Premium
                    if (bloqueados.isNotEmpty) _premiumBanner(context),

                    const SizedBox(height: 10),

                    // 🔹 Clientes bloqueados
                    ...bloqueados.map((e) => _card(context, e, true)),

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

  // ===================== 🔹 SECCIONES =====================
  Widget _encabezado() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.home_work_rounded, color: _accent, size: 30),
            const SizedBox(width: 10),
            Text(
              "Rendimiento alquileres",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            "LIVE",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ===================== 🔹 TARJETA CLIENTE =====================
  Widget _card(BuildContext context, _ClienteGanancia e, bool bloqueado) {
    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Ganancia: \$${e.ganancia}",
                  style: TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Saldo: \$${e.saldo}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded, color: Colors.white54),
        ],
      ),
    );

    if (!bloqueado) return card;

    // 🔒 Tarjeta bloqueada premium (oscura + borrosa)
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PantallaBloqueoPremium(destino: 'ganancia_alquiler'),
        ),
      ),
      child: Stack(
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
          const Icon(Icons.lock_outline_rounded, color: Colors.white70, size: 28),
        ],
      ),
    );
  }

  // ===================== 🔹 BANNER PREMIUM =====================
  Widget _premiumBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PantallaBloqueoPremium(destino: 'ganancia_alquiler'),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _gradiente,
        ),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              "Desbloquea Mi Recibo Premium",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Visualiza todas las ganancias detalladas de tus alquileres activos.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================== 🔹 BOTÓN FINAL =====================
  Widget _botonFinal() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
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
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  // ===================== 🔹 ESTADO VACÍO =====================
  Widget _empty() => const Center(
    child: Padding(
      padding: EdgeInsets.all(50),
      child: Text(
        "No hay alquileres activos con ganancias.",
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

  _ClienteGanancia({
    required this.id,
    required this.nombre,
    required this.ganancia,
    required this.saldo,
  });
}
