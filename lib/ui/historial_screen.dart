import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistorialScreen extends StatelessWidget {
  final String idCliente;
  final String nombreCliente;
  final String? producto; // 👈 para mostrar el producto si existe

  const HistorialScreen({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
    this.producto,
  });

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  String _rd(int v) {
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) { b.write('.'); c = 0; }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    // Misma composición de las demás pantallas
    const double _logoTop = -90;
    const double _logoHeight = 350;
    const double _contentTop = 135;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'Sesión expirada. Inicia sesión de nuevo.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final pagosQuery = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(idCliente)
        .collection('pagos')
        .orderBy('fecha', descending: true);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ===== Logo decorativo (no toca el contenido) =====
              const Positioned(
                top: _logoTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Image(
                      image: AssetImage('assets/images/logoB.png'),
                      height: _logoHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // ===== Marco translúcido a altura completa =====
              Positioned.fill(
                top: _contentTop,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // ===== Título (FIJO) =====
                                Center(
                                  child: Text(
                                    'Historial de Pagos',
                                    style: GoogleFonts.playfair(
                                      textStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // ===== Tarjeta blanca que contiene cabecera + LISTA con scroll =====
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Cabecera de la tarjeta (nombre + producto)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nombreCliente,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              if ((producto ?? '').trim().isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.local_offer,
                                                        color: Color(0xFF2563EB), size: 18),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        (producto ?? '').trim(),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          color: Color(0xFF0F172A),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                                        // ===== LISTA con scroll (solo esta parte se desplaza) =====
                                        Expanded(
                                          child: StreamBuilder<QuerySnapshot>(
                                            stream: pagosQuery.snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const Center(
                                                  child: CircularProgressIndicator(),
                                                );
                                              }
                                              if (snapshot.hasError) {
                                                return Center(
                                                  child: Text(
                                                    'Error al cargar pagos',
                                                    style: TextStyle(
                                                      color: Colors.red.shade700,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                );
                                              }

                                              final docs = snapshot.data?.docs ?? [];
                                              if (docs.isEmpty) {
                                                return Center(
                                                  child: Text(
                                                    'No hay pagos registrados todavía',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                );
                                              }

                                              return ListView.separated(
                                                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                                itemCount: docs.length,
                                                separatorBuilder: (_, __) =>
                                                const Divider(height: 16),
                                                itemBuilder: (context, i) {
                                                  final d = docs[i].data()
                                                  as Map<String, dynamic>? ??
                                                      {};
                                                  final ts = d['fecha'];
                                                  final fecha = ts is Timestamp
                                                      ? ts.toDate()
                                                      : DateTime.now();

                                                  final pagoInteres =
                                                      (d['pagoInteres'] as num?)?.toInt() ?? 0;
                                                  final pagoCapital =
                                                      (d['pagoCapital'] as num?)?.toInt() ?? 0;
                                                  final totalPagado =
                                                      (d['totalPagado'] as num?)?.toInt() ??
                                                          (pagoInteres + pagoCapital);
                                                  final saldoAnterior =
                                                      (d['saldoAnterior'] as num?)?.toInt() ?? 0;
                                                  final saldoNuevo =
                                                      (d['saldoNuevo'] as num?)?.toInt() ??
                                                          saldoAnterior;

                                                  return Row(
                                                    crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                        width: 36,
                                                        height: 36,
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFFEFF6FF),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        alignment: Alignment.center,
                                                        child: const Icon(
                                                          Icons.event_note,
                                                          color: Color(0xFF2563EB),
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  _fmtFecha(fecha),
                                                                  style: const TextStyle(
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                                const Text('   ·   '),
                                                                Text(
                                                                  'Total: ${_rd(totalPagado)}',
                                                                  style: const TextStyle(
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'Interés: ${_rd(pagoInteres)}   ·   Capital: ${_rd(pagoCapital)}',
                                                              style: const TextStyle(
                                                                  color: Colors.black87),
                                                            ),
                                                            Text(
                                                              'Saldo: ${_rd(saldoAnterior)} → ${_rd(saldoNuevo)}',
                                                              style: const TextStyle(
                                                                  color: Colors.black87),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ===== Botón fijo =====
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,                 // ✅ fondo blanco
                                  foregroundColor: const Color(0xFF2563EB),      // ✅ texto azul
                                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.5), // ✅ borde azul
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                ),
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Volver'),

                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}