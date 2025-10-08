import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Formato moneda automático

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

  // =======================
  // Helpers
  // =======================

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  // ✅ moneda automática según país del dispositivo
  String _rd(num v) {
    final format = NumberFormat.simpleCurrency(
      locale: Intl.getCurrentLocale(),
    );
    return format.format(v);
  }

  DateTime _parseFecha(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }

  TextStyle get _titleStyle => GoogleFonts.playfairDisplay(
    textStyle: const TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
    ),
  );

  @override
  Widget build(BuildContext context) {
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
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
        .orderBy('fecha', descending: true)
        .limit(300);

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
              Positioned(
                top: _logoTop,
                left: 0,
                right: 0,
                child: const IgnorePointer(
                  child: Center(
                    child: Image(
                      image: AssetImage('assets/images/logoB.png'),
                      height: _logoHeight,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                top: _contentTop,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + safeBottom),
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
                                Center(child: Text('Historial de Pagos', style: _titleStyle)),
                                const SizedBox(height: 12),
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
                                        Expanded(
                                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                            stream: pagosQuery.snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const _LoadingList();
                                              }
                                              if (snapshot.hasError) {
                                                return _ErrorState(
                                                  onRetry: () => {},
                                                );
                                              }

                                              final docs = snapshot.data?.docs ?? [];
                                              if (docs.isEmpty) {
                                                return const _EmptyState();
                                              }

                                              num sumInteres = 0;
                                              num sumCapital = 0;
                                              for (final e in docs) {
                                                final d = e.data();
                                                sumInteres += (d['pagoInteres'] as num?)?.toInt() ?? 0;
                                                sumCapital += (d['pagoCapital'] as num?)?.toInt() ?? 0;
                                              }

                                              return Column(
                                                children: [
                                                  Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: _ChipStat(
                                                            label: 'Intereses',
                                                            value: _rd(sumInteres),
                                                            color: const Color(0xFF22C55E),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: _ChipStat(
                                                            label: 'Capital',
                                                            value: _rd(sumCapital),
                                                            color: const Color(0xFF2563EB),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                                  Expanded(
                                                    child: ListView.separated(
                                                      key: const PageStorageKey('historialPagosList'),
                                                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                                      itemCount: docs.length,
                                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                      itemBuilder: (context, i) {
                                                        final doc = docs[i];
                                                        final d = doc.data();
                                                        final fecha = _parseFecha(d['fecha']);
                                                        final pagoInteres =
                                                            (d['pagoInteres'] as num?)?.toInt() ?? 0;
                                                        final pagoCapital =
                                                            (d['pagoCapital'] as num?)?.toInt() ?? 0;
                                                        final totalPagado = (d['totalPagado'] as num?)?.toInt() ??
                                                            (pagoInteres + pagoCapital);
                                                        final saldoAnterior =
                                                            (d['saldoAnterior'] as num?)?.toInt() ?? 0;
                                                        final saldoNuevo =
                                                            (d['saldoNuevo'] as num?)?.toInt() ?? saldoAnterior;

                                                        final bool fechaPendiente =
                                                            d['fecha'] == null || d['fecha'] is! Timestamp;

                                                        return _PagoCard(
                                                          key: ValueKey(doc.id),
                                                          fecha: _fmtFecha(fecha),
                                                          fechaPendiente: fechaPendiente,
                                                          total: totalPagado,
                                                          capital: pagoCapital,
                                                          interes: pagoInteres,
                                                          saldoAntes: saldoAnterior,
                                                          saldoDespues: saldoNuevo,
                                                          rd: _rd,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
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
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
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

// =======================
// Widgets auxiliares
// =======================

class _ChipStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ChipStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 8),
            const Text(
              'No hay pagos registrados todavía',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF64748B), fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando registres un pago, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade600),
            const SizedBox(height: 8),
            const Text(
              'Error al cargar pagos',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF991B1B), fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2563EB),
                side: const BorderSide(color: Color(0xFF2563EB)),
                shape: const StadiumBorder(),
              ),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Container(height: 16, color: const Color(0xFFE5E7EB)),
                const SizedBox(height: 8),
                Container(height: 14, color: const Color(0xFFEFF1F3)),
                const SizedBox(height: 6),
                Container(height: 14, color: const Color(0xFFEFF1F3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PagoCard extends StatelessWidget {
  final String fecha;
  final bool fechaPendiente;
  final int total;
  final int capital;
  final int interes;
  final int saldoAntes;
  final int saldoDespues;
  final String Function(num) rd;

  const _PagoCard({
    super.key,
    required this.fecha,
    required this.fechaPendiente,
    required this.total,
    required this.capital,
    required this.interes,
    required this.saldoAntes,
    required this.saldoDespues,
    required this.rd,
  });

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF2563EB);
    const verde = Color(0xFF22C55E);
    final rojo = Colors.red.shade600;
    const ink = Color(0xFF0F172A);

    final bool saldoBaja = saldoDespues <= saldoAntes;
    final Color colorAntes = saldoAntes > 0 ? rojo : verde;
    final Color colorDespues = saldoDespues == 0
        ? verde
        : (saldoBaja ? ink : rojo);

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            fecha,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          if (fechaPendiente) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3C7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Color(0xFFFDE68A)),
                              ),
                              child: const Text(
                                'pendiente de servidor',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF92400E),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
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
                Row(
                  children: [
                    const Text(
                      'I: ',
                      style: TextStyle(
                        color: verde,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rd(interes),
                      style: const TextStyle(
                        color: verde,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'C: ',
                      style: TextStyle(
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
