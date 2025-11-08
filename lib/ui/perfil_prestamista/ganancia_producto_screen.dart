// 📂 lib/ui/perfil_prestamista/ganancia_producto_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/ui/premium/pantalla_bloqueo_premium.dart';
import 'package:mi_recibo/core/premium_service.dart';


class GananciaProductoScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;

  const GananciaProductoScreen({super.key, required this.docPrest});

  @override
  State<GananciaProductoScreen> createState() =>
      _GananciaProductoScreenState();
}

class _GananciaProductoScreenState extends State<GananciaProductoScreen> {
  late Future<List<_ClienteGanancia>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarGanancias();
  }

  // 🎨 Paleta premium verde jade
  Color get _colorFondo => const Color(0xFF062A1C);
  Color get _accent => const Color(0xFF00E676);

  LinearGradient get _gradiente => const LinearGradient(
    colors: [Color(0xFF003D2E), Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ===================== 🔹 CARGAR GANANCIAS =====================
  Future<List<_ClienteGanancia>> _cargarGanancias() async {
    final query = widget.docPrest
        .collection('clientes')
        .where('tipo', whereIn: ['producto', 'fiado']);

    final cs = await query.get();
    final List<_ClienteGanancia> rows = [];

    for (final c in cs.docs) {
      final data = c.data();
      final saldo = (data['saldoActual'] ?? 0) as num;
      if (saldo <= 0) continue;

      num ganancia = (data['ganancia'] ?? data['gananciaTotal'] ?? 0) as num;


      final nombre =
      '${(data['nombre'] ?? '').toString()} ${(data['apellido'] ?? '').toString()}'
          .trim();

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
    return FutureBuilder<bool>(
      future: PremiumService().esPremiumActivo(widget.docPrest.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),
          );
        }

        final esPremium = snapshot.data ?? false;


        // ✅ Si tiene Premium, mostrar la pantalla normal
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

// ✅ Si el usuario es Premium, mostrar todas las tarjetas completas
                if (esPremium) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    child: Column(
                      children: [
                        _encabezado(),
                        const SizedBox(height: 25),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "💰 Ganancias por producto",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 10),
                            physics: const BouncingScrollPhysics(),
                            itemCount: list.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _card(list[i], false), // 👈 sin bloqueo
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _botonFinal(),
                        const SizedBox(height: 25),
                      ],
                    ),
                  );
                }

// 🚫 Si NO es Premium, mantener el diseño bloqueado
                final visibles = list.take(1).toList();
                final bloqueados = list.skip(1).toList();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    children: [
                      _encabezado(),
                      const SizedBox(height: 25),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "💰 Ganancias por producto",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 🟢 Cliente visible
                      ...visibles.map((e) => _card(e, false)),

                      const SizedBox(height: 25),

                      if (bloqueados.isNotEmpty) _premiumEncabezado(),
                      const SizedBox(height: 15),

                      if (bloqueados.isNotEmpty)
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 10),
                            physics: const BouncingScrollPhysics(),
                            itemCount: bloqueados.length,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _card(bloqueados[i], true),
                            ),
                          ),
                        )
                      else
                        const Spacer(),

                      const SizedBox(height: 20),
                      _botonFinal(),
                      const SizedBox(height: 25),
                    ],
                  ),
                );

              },
            ),
          ),
        );
      },
    );
  }


  // ===================== 🔹 ENCABEZADO =====================
  Widget _encabezado() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2_rounded, color: _accent, size: 30),
            const SizedBox(width: 10),
            Text(
              "Rendimiento productos",
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
            color: _accent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _accent.withOpacity(0.4),
                blurRadius: 10,
              )
            ],
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

  // ===================== 🔹 BANNER PREMIUM =====================
  Widget _premiumEncabezado() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const PantallaBloqueoPremium(destino: 'ganancia_producto'),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: _accent.withOpacity(0.9), size: 34),
          const SizedBox(height: 8),
          Text(
            "Desbloquea Mi Recibo Premium",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Accede a todas las ganancias completas de tus productos y fiados.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ===================== 🔹 TARJETA CLIENTE =====================
  Widget _card(_ClienteGanancia e, bool bloqueado) {
    final baseCard = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF003D2E).withOpacity(0.9),
            const Color(0xFF007E56).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del cliente
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                e.nombre,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.inventory_2_rounded, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: Colors.white.withOpacity(0.1), thickness: 1),
          const SizedBox(height: 10),

          // Datos
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Text(
                "Ganancia total: \$${e.ganancia}",
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.savings_rounded,
                  color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                "Saldo actual: \$${e.saldo}",
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.trending_up_rounded,
                  color: Colors.white38, size: 18),
              SizedBox(width: 8),
              Text(
                "Rendimiento estable",
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!bloqueado) return baseCard;

    // 🔒 Tarjeta bloqueada (blur verde jade premium)
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
          const PantallaBloqueoPremium(destino: 'ganancia_producto'),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: 0.2, child: baseCard),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.transparent,
                      Colors.black.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.25),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.lock_outline_rounded,
                  color: Colors.white70, size: 26),
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
        "No hay productos activos con ganancias.",
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
