import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // 👈 formato RD$

class HistorialScreen extends StatelessWidget {
  final String idCliente;
  final String nombreCliente;
  final String? producto; // opcional

  const HistorialScreen({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
    this.producto,
  });

  // ===== Helpers =====
  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  String _rd(int v) {
    return NumberFormat.currency(
      locale: 'es_DO',
      symbol: 'RD\$',
      decimalDigits: 0,
    ).format(v);
  }

  @override
  Widget build(BuildContext context) {
    // Misma composición (logo + marco + tarjeta con lista scrollable)
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

    // 👇 espacio seguro inferior para que el botón nunca quede tapado
    final double safeBottom = MediaQuery.of(context).padding.bottom;

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
              // Logo decorativo
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

              // Marco translúcido
              Positioned.fill(
                top: _contentTop,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + safeBottom), // 👈 safe bottom
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
                                // Título
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

                                // Tarjeta blanca con cabecera + lista
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
                                        // Cabecera
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nombreCliente,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
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

                                        // Lista (solo esta parte hace scroll)
                                        Expanded(
                                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                            stream: pagosQuery.snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const Center(child: CircularProgressIndicator());
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
                                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                itemBuilder: (context, i) {
                                                  final d = docs[i].data();
                                                  final ts = d['fecha'];
                                                  final fecha = ts is Timestamp ? ts.toDate() : DateTime.now();

                                                  final pagoInteres = (d['pagoInteres'] as num?)?.toInt() ?? 0;
                                                  final pagoCapital = (d['pagoCapital'] as num?)?.toInt() ?? 0;
                                                  final totalPagado = (d['totalPagado'] as num?)?.toInt()
                                                      ?? (pagoInteres + pagoCapital);
                                                  final saldoAnterior = (d['saldoAnterior'] as num?)?.toInt() ?? 0;
                                                  final saldoNuevo = (d['saldoNuevo'] as num?)?.toInt() ?? saldoAnterior;

                                                  return _PagoCard(
                                                    fecha: _fmtFecha(fecha),
                                                    total: totalPagado,
                                                    capital: pagoCapital,
                                                    interes: pagoInteres,
                                                    saldoAntes: saldoAnterior,
                                                    saldoDespues: saldoNuevo,
                                                    rd: _rd, // 👈 usamos el formateador RD$
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

                                // Botón Volver (fijo)
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                      shape: const StadiumBorder(),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
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

// ===== Ítem de pago “premium” con colores como en Detalles =====
class _PagoCard extends StatelessWidget {
  final String fecha;
  final int total;
  final int capital;
  final int interes;
  final int saldoAntes;
  final int saldoDespues;
  final String Function(int) rd;

  const _PagoCard({
    required this.fecha,
    required this.total,
    required this.capital,
    required this.interes,
    required this.saldoAntes,
    required this.saldoDespues,
    required this.rd,
  });

  @override
  Widget build(BuildContext context) {
    // Colores consistentes con Detalles del cliente
    const azul = Color(0xFF2563EB);
    const verde = Color(0xFF22C55E);
    final rojo = Colors.red.shade600;
    final ink = const Color(0xFF0F172A);

    // Lógica de colores de saldo
    final bool saldoBaja = saldoDespues <= saldoAntes;
    final Color colorAntes = saldoAntes > 0 ? rojo : verde;
    final Color colorDespues = saldoDespues == 0
        ? verde
        : (saldoBaja ? ink : rojo); // si subió raro → rojo, si bajó → negro elegante

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.event_note, color: azul, size: 20),
          ),
          const SizedBox(width: 12),

          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila principal: fecha + total (azul)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fecha,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Text(
                      rd(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: azul,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Detalles secundarios con color: Interés (verde), Capital (azul)
                Row(
                  children: [
                    Text(
                      'I: ',
                      style: TextStyle(
                        color: verde,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rd(interes),
                      style: TextStyle(
                        color: verde,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'C: ',
                      style: const TextStyle(
                        color: azul,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rd(capital),
                      style: const TextStyle(
                        color: azul,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Saldos con colores (antes rojo si debía, después verde si quedó en 0)
                Row(
                  children: [
                    Text(
                      'Saldo: ',
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      rd(saldoAntes),
                      style: TextStyle(
                        color: colorAntes,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '  →  ',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      rd(saldoDespues),
                      style: TextStyle(
                        color: colorDespues,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
