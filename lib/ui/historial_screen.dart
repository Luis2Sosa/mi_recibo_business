
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/premium_service.dart';


class HistorialScreen extends StatelessWidget {
  final String idCliente;
  final String nombreCliente;
  final String? producto; // opcional (decide estilo: préstamo/producto/alquiler)

  const HistorialScreen({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
    this.producto,
  });

  // =======================
  // Helpers
  // =======================

  bool get _esPrestamo {
    final p = (producto ?? '').trim().toLowerCase();
    if (p.isEmpty) return true; // vacío = préstamo clásico
    return p.contains('prest') || p.contains('crédito') || p.contains('credito') || p.contains('loan');
  }

  bool get _esAlquiler {
    final p = (producto ?? '').trim().toLowerCase();
    return p.contains('alqui') ||
        p.contains('arriendo') ||
        p.contains('renta') ||
        p.contains('casa') ||
        p.contains('apart');
  }

  bool get _esProducto => !_esPrestamo && !_esAlquiler;

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  // moneda automática según país del dispositivo
  String _rd(num v) {
    final format = NumberFormat.simpleCurrency(locale: Intl.getCurrentLocale());
    return format.format(v);
  }

  DateTime _parseFecha(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0); // muy vieja para ordenar
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
    const double _logoTop = -100;
    const double _logoHeight = 350;
    const double _contentTop = 135;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final premiumService = PremiumService(); // ✅ instancia única para toda la pantalla


    if (uid == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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

    // 📌 NO usamos orderBy para no perder pagos que no tengan 'fecha'.
    final pagosRef = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(idCliente)
        .collection('pagos');

    final double safeBottom = MediaQuery.of(context).padding.bottom;

    // Paleta HALO suave por tipo
    final Color colorMain = _esPrestamo
        ? const Color(0xFF2563EB) // azul
        : (_esAlquiler ? const Color(0xFFF59E0B) : const Color(0xFF22C55E)); // naranja : verde

    final Color cardTint = colorMain.withOpacity(0.08);
    final Color cardBorder = colorMain.withOpacity(0.22);


    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                                        // Encabezado (cliente + subtítulo por tipo)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                                          child: Builder(
                                            builder: (_) {
                                              final p = (producto ?? '').trim();
                                              final lower = p.toLowerCase();

                                              final bool esAlquiler = lower.contains('alquiler') ||
                                                  lower.contains('arriendo') ||
                                                  lower.contains('renta') ||
                                                  lower.contains('casa') ||
                                                  lower.contains('apart');

                                              final bool esPrestamo = p.isEmpty ||
                                                  lower.contains('prest') ||
                                                  lower.contains('crédit') ||
                                                  lower.contains('credit') ||
                                                  lower.contains('loan');

                                              final String subtitulo = esPrestamo ? 'Préstamo' : p;

                                              final IconData icono = esAlquiler
                                                  ? Icons.house_rounded
                                                  : (esPrestamo ? Icons.request_quote_rounded : Icons.shopping_bag_rounded);

                                              final Color colorIcono = esAlquiler
                                                  ? const Color(0xFFF59E0B)   // naranja alquiler
                                                  : (esPrestamo ? const Color(0xFF2563EB) : const Color(0xFF22C55E)); // azul préstamo / verde producto

                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const SizedBox(height: 6),
                                                  Center(
                                                    child: Column(
                                                      children: [
                                                        Text(
                                                          nombreCliente,
                                                          style: const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.w900,
                                                            color: Color(0xFF0F172A),
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(
                                                              _esPrestamo
                                                                  ? Icons.request_quote_rounded
                                                                  : _esAlquiler
                                                                  ? Icons.house_rounded
                                                                  : Icons.shopping_bag_rounded,
                                                              color: _esPrestamo
                                                                  ? const Color(0xFF2563EB)
                                                                  : _esAlquiler
                                                                  ? const Color(0xFFF59E0B)
                                                                  : const Color(0xFF16A34A),
                                                              size: 18,
                                                            ),
                                                            const SizedBox(width: 5),
                                                            Text(
                                                              _esPrestamo
                                                                  ? 'Préstamo'
                                                                  : _esAlquiler
                                                                  ? 'Alquiler'
                                                                  : 'Producto',
                                                              style: TextStyle(
                                                                fontSize: 14,
                                                                color: _esPrestamo
                                                                    ? const Color(0xFF2563EB)
                                                                    : _esAlquiler
                                                                    ? const Color(0xFFF59E0B)
                                                                    : const Color(0xFF16A34A),
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 12),
                                                        Container(
                                                          height: 1.3,
                                                          width: 180,
                                                          color: Colors.black.withOpacity(0.08),
                                                        ),
                                                        const SizedBox(height: 12),
                                                      ],
                                                    ),
                                                  ),



                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const Divider(height: 1, color: Color(0xFFE5E7EB)),

                                        Expanded(
                                          child: StreamBuilder<User?>(
                                            stream: FirebaseAuth.instance.authStateChanges(),
                                            builder: (context, userSnap) {
                                              if (!userSnap.hasData) {
                                                return const Center(
                                                  child: CircularProgressIndicator(color: Colors.blueAccent),
                                                );
                                              }

                                              final uid = userSnap.data!.uid;

                                              return StreamBuilder<bool>(
                                                stream: premiumService.streamEstadoPremium(uid),



                                                builder: (context, premiumSnap) {
                                                  if (!premiumSnap.hasData) {
                                                    return const Center(
                                                      child: CircularProgressIndicator(color: Colors.blueAccent),
                                                    );
                                                  }

                                                  final esPremium = premiumSnap.data ?? false;

                                                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                                    stream: pagosRef.snapshots(),
                                                    builder: (context, snapshot) {
                                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                                        return const _LoadingList();
                                                      }
                                                      if (snapshot.hasError) {
                                                        return _ErrorState(onRetry: () {});
                                                      }

                                                      final raw = snapshot.data?.docs ?? [];
                                                      if (raw.isEmpty) return const _EmptyState();

                                                      // Ordenar por fecha descendente
                                                      final docs = [...raw]..sort((a, b) {
                                                        final ad = a.data();
                                                        final bd = b.data();
                                                        final af = _parseFecha(ad['fecha'] ?? ad['createdAt']);
                                                        final bf = _parseFecha(bd['fecha'] ?? bd['createdAt']);
                                                        return bf.compareTo(af);
                                                      });

                                                      List<_PagoNorm> pagos = [];
                                                      for (final e in docs) {
                                                        final d = e.data();
                                                        final capital = (d['pagoCapital'] ?? d['capital'] ?? d['abono'] ?? 0) as num;
                                                        final interes = (d['pagoInteres'] ?? d['interes'] ?? 0) as num;
                                                        final total = (d['totalPagado'] ?? capital + interes) as num;
                                                        pagos.add(_PagoNorm(
                                                          id: e.id,
                                                          data: d,
                                                          total: total.toInt(),
                                                          interes: interes.toInt(),
                                                          capital: capital.toInt(),
                                                        ));
                                                      }

                                                      // ✅ Si el usuario es Premium
                                                      if (esPremium) {
                                                        return ListView.separated(
                                                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                                          itemCount: pagos.length,
                                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                          itemBuilder: (context, i) {
                                                            final p = pagos[i];
                                                            final d = p.data;
                                                            final fecha = _parseFecha(d['fecha'] ?? d['createdAt']);
                                                            final saldoAnterior = (d['saldoAnterior'] ?? 0) as num;
                                                            final saldoNuevo = (d['saldoNuevo'] ?? saldoAnterior) as num;
                                                            // ✅ Nuevos campos que vienen del recibo (distribución del pago)
                                                            final pagoInteres = (d['pagoInteres'] ?? 0) as num;
                                                            final pagoCapital = (d['pagoCapital'] ?? 0) as num;
                                                            final totalPagado = (d['totalPagado'] ?? 0) as num;
                                                            final moraCobrada = (d['moraCobrada'] ?? 0) as num;


                                                            return esPremium
                                                                ? _PagoCardDesbloqueada(
                                                              key: ValueKey(p.id),
                                                              fecha: _fmtFecha(fecha),
                                                              fechaPendiente: false,
                                                              total: p.total,
                                                              capital: p.capital,
                                                              interes: p.interes,
                                                              saldoAntes: saldoAnterior.toInt(),
                                                              saldoDespues: saldoNuevo.toInt(),
                                                              rd: _rd,
                                                              showInteres: _esPrestamo && p.interes > 0,
                                                              tint: cardTint,
                                                              border: cardBorder,
                                                              accent: colorMain,
                                                              leadingIcon: _esAlquiler
                                                                  ? Icons.house_rounded
                                                                  : (_esPrestamo
                                                                  ? Icons.request_quote_rounded
                                                                  : Icons.shopping_bag_rounded),
                                                            )
                                                                : _PagoCardPremium(
                                                              key: ValueKey(p.id),
                                                              fecha: _fmtFecha(fecha),
                                                              fechaPendiente: false,
                                                              total: p.total,
                                                              capital: p.capital,
                                                              interes: p.interes,
                                                              saldoAntes: saldoAnterior.toInt(),
                                                              saldoDespues: saldoNuevo.toInt(),
                                                              rd: _rd,
                                                              showInteres: _esPrestamo && p.interes > 0,
                                                              tint: cardTint,
                                                              border: cardBorder,
                                                              accent: colorMain,
                                                              leadingIcon: _esAlquiler
                                                                  ? Icons.house_rounded
                                                                  : (_esPrestamo
                                                                  ? Icons.request_quote_rounded
                                                                  : Icons.shopping_bag_rounded),
                                                            );


                                                          },
                                                        );
                                                      }

                                                      // 🚫 Si NO es Premium
                                                      return ListView.separated(
                                                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                                        itemCount: pagos.length,
                                                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                        itemBuilder: (context, i) {
                                                          final p = pagos[i];
                                                          final d = p.data;
                                                          final fecha = _parseFecha(d['fecha'] ?? d['createdAt']);
                                                          final saldoAnterior = (d['saldoAnterior'] ?? 0) as num;
                                                          final saldoNuevo = (d['saldoNuevo'] ?? saldoAnterior) as num;

                                                          return _PagoCardPremium(
                                                            key: ValueKey(p.id),
                                                            fecha: _fmtFecha(fecha),
                                                            fechaPendiente: false,
                                                            total: p.total,
                                                            capital: p.capital,
                                                            interes: p.interes,
                                                            saldoAntes: saldoAnterior.toInt(),
                                                            saldoDespues: saldoNuevo.toInt(),
                                                            rd: _rd,
                                                            showInteres: _esPrestamo && p.interes > 0,
                                                            tint: cardTint,
                                                            border: cardBorder,
                                                            accent: colorMain,
                                                            leadingIcon: _esAlquiler
                                                                ? Icons.house_rounded
                                                                : (_esPrestamo
                                                                ? Icons.request_quote_rounded
                                                                : Icons.shopping_bag_rounded),
                                                          );
                                                        },
                                                      );
                                                    },
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

// =======================
// Modelo interno para normalizar pago
// =======================

class _PagoNorm {
  final String id;
  final Map<String, dynamic> data;
  final int total;
  final int interes;
  final int capital;

  _PagoNorm({
    required this.id,
    required this.data,
    required this.total,
    required this.interes,
    required this.capital,
  });
}

// =======================
// Widgets auxiliares
// =======================

class _ChipStat extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color border;
  final Color valueColor;

  const _ChipStat({
    required this.label,
    required this.value,
    required this.bg,
    required this.border,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
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
                color: valueColor,
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

// =======================
// 🔒 Tarjeta Premium bloqueada (coherente con la desbloqueada)
// =======================
class _PagoCardPremium extends StatelessWidget {
  final String fecha;
  final bool fechaPendiente;
  final int total;
  final int capital;
  final int interes;
  final int saldoAntes;
  final int saldoDespues;
  final String Function(num) rd;
  final bool showInteres;
  final Color tint;
  final Color border;
  final Color accent;
  final IconData leadingIcon;

  const _PagoCardPremium({
    super.key,
    required this.fecha,
    required this.fechaPendiente,
    required this.total,
    required this.capital,
    required this.interes,
    required this.saldoAntes,
    required this.saldoDespues,
    required this.rd,
    required this.showInteres,
    required this.tint,
    required this.border,
    required this.accent,
    required this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    const Color verdePago = Color(0xFF22C55E);
    const Color azulCandado = Color(0xFF2563EB);
    const Color grisTexto = Color(0xFF475569);
    const Color negroElegante = Color(0xFF0F172A);

    // Gradiente tenue para borde premium bloqueado
    final gradient = LinearGradient(
      colors: [const Color(0xFF93C5FD), const Color(0xFFE0E7FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Fecha + icono con candado Premium
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.15)),
                    ),
                    alignment: Alignment.center,
                    child: Icon(leadingIcon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fecha,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: negroElegante,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),

              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: azulCandado.withOpacity(0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock, color: azulCandado, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Detalle Premium',
                      style: TextStyle(
                        color: azulCandado,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 💵 Pago realizado (verde)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payments_rounded, color: verdePago, size: 20),
              const SizedBox(width: 6),
              Text(
                'Pago realizado:',
                style: TextStyle(
                  color: grisTexto,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                rd(total),
                style: const TextStyle(
                  color: verdePago,
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 🔒 Bloque Premium coherente con el diseño desbloqueado
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, const Color(0xFFF1F5F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_outline,
                    color: azulCandado, size: 24),
                const SizedBox(height: 8),
                const Text(
                  'Ver detalles completos con el plan Premium',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 3,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




// =======================
// 💎 Tarjeta Premium desbloqueada (cálculos corregidos por Luis)
// =======================
class _PagoCardDesbloqueada extends StatelessWidget {
  final String fecha;
  final bool fechaPendiente;
  final int total;
  final int capital;
  final int interes;
  final int saldoAntes;
  final int saldoDespues;
  final String Function(num) rd;
  final bool showInteres;
  final Color tint;
  final Color border;
  final Color accent;
  final IconData leadingIcon;

  const _PagoCardDesbloqueada({
    super.key,
    required this.fecha,
    required this.fechaPendiente,
    required this.total,
    required this.capital,
    required this.interes,
    required this.saldoAntes,
    required this.saldoDespues,
    required this.rd,
    required this.showInteres,
    required this.tint,
    required this.border,
    required this.accent,
    required this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    const grisTexto = Color(0xFF334155);
    const negroElegante = Color(0xFF0F172A);
    final verde = const Color(0xFF22C55E);
    final azul = const Color(0xFF2563EB);
    final naranja = const Color(0xFFF59E0B);

    // Detectar tipo
    final bool esAlquiler = leadingIcon == Icons.house_rounded;
    final bool esPrestamo = leadingIcon == Icons.request_quote_rounded;
    final bool esProducto = !esAlquiler && !esPrestamo;

    // Cálculo general
    // ❌ Eliminar todo este bloque
// int saldoNuevo = saldoAntes;
// if (esPrestamo || esProducto) {
//   saldoNuevo = saldoAntes - capital;
//   if (saldoNuevo < 0) saldoNuevo = 0;
// }

// ✅ Usar directamente el saldo guardado en Firestore
    final int saldoNuevo = saldoDespues;


    // Gradiente visual
    final gradient = LinearGradient(
      colors: esPrestamo
          ? [const Color(0xFF2563EB), const Color(0xFF60A5FA)]
          : (esAlquiler
          ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
          : [const Color(0xFF16A34A), const Color(0xFF4ADE80)]),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.25),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Encabezado
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fecha,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: negroElegante,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded,
                        color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 💵 Pago actual
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pago actual:',
                style: TextStyle(
                  color: grisTexto,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => gradient.createShader(bounds),
                child: Text(
                  rd(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),

          // Mostrar interés solo si aplica
          if (showInteres && esPrestamo) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Interés:',
                    style: TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(
                  rd(interes),
                  style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          Divider(color: accent.withOpacity(0.25), thickness: 1),

          // 📊 Saldos
          const SizedBox(height: 8),

          if (!esAlquiler) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo anterior:',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                Text(
                  rd(saldoAntes),
                  style: TextStyle(
                      color: azul,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo nuevo:',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                Text(
                  rd(saldoNuevo),
                  style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5),
                ),
              ],
            ),
          ] else ...[
            // 🟧 Solo para alquiler
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Próximo pago:',
                    style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                Text(
                  'RD\$ ${rd(total)}',
                  style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        ],
      ),
    );
  }
}



