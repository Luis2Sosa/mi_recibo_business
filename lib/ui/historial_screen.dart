
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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
    const double _logoTop = -90;
    const double _logoHeight = 350;
    const double _contentTop = 135;

    final uid = FirebaseAuth.instance.currentUser?.uid;

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
    final Color chipBgLeft = colorMain.withOpacity(_esPrestamo ? 0.06 : 0.08);
    final Color chipBorderLeft = colorMain.withOpacity(0.18);

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
                                                  Text(
                                                    nombreCliente,
                                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(icono, color: colorIcono, size: 18),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          subtitulo,
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                            color: Color(0xFF0F172A),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                        const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                        Expanded(
                                          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                            stream: pagosRef.snapshots(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const _LoadingList();
                                              }
                                              if (snapshot.hasError) {
                                                return _ErrorState(onRetry: () {});
                                              }

                                              final raw = snapshot.data?.docs ?? [];

                                              if (raw.isEmpty) {
                                                return const _EmptyState();
                                              }

                                              // Ordenar local por fecha (o createdAt si existe) descendente
                                              final docs = [...raw]..sort((a, b) {
                                                final ad = a.data();
                                                final bd = b.data();
                                                final af = _parseFecha(ad['fecha'] ?? ad['createdAt']);
                                                final bf = _parseFecha(bd['fecha'] ?? bd['createdAt']);
                                                return bf.compareTo(af);
                                              });

                                              num sumInteres = 0;
                                              num sumCapital = 0;

                                              // === Normalización de campos por pago ===
                                              List<_PagoNorm> pagos = [];
                                              for (final e in docs) {
                                                final d = e.data();

                                                // Candidatos comunes en tus colecciones
                                                final numCapital = (d['pagoCapital'] ??
                                                    d['capital'] ??
                                                    d['abonoCapital'] ??
                                                    d['abono'] ??
                                                    d['pago'] ??
                                                    0) as num;
                                                final int capital = numCapital.toInt();

                                                final num? numTotalMaybe = (d['totalPagado'] ??
                                                    d['monto'] ??
                                                    d['pago']) as num?;
                                                int? totalMaybe = numTotalMaybe?.toInt();

                                                final num? numInteres = (d['pagoInteres'] ?? d['interes']) as num?;
                                                int interes = (numInteres ?? 0).toInt();


                                                if (totalMaybe == null) {
                                                  // si no hay total explícito, suma capital+interés
                                                  totalMaybe = capital + interes;
                                                } else {
                                                  // si hay total pero no hay interés, calcúlalo
                                                  if (interes == 0 && totalMaybe > capital) {
                                                    interes = totalMaybe - capital;
                                                  }
                                                }

                                                // evita negativos por inconsistencias
                                                if (interes < 0) interes = 0;

                                                sumInteres += interes;
                                                sumCapital += capital;

                                                pagos.add(
                                                  _PagoNorm(
                                                    id: e.id,
                                                    data: d,
                                                    total: totalMaybe,
                                                    interes: interes,
                                                    capital: capital,
                                                  ),
                                                );
                                              }

                                              // Header de stats, según tipo
                                              Widget stats() {
                                                if (_esPrestamo) {
                                                  return Padding(
                                                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: _ChipStat(
                                                            label: 'Intereses',
                                                            value: _rd(sumInteres),
                                                            bg: chipBgLeft,
                                                            border: chipBorderLeft,
                                                            valueColor: const Color(0xFF22C55E),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: _ChipStat(
                                                            label: 'Capital',
                                                            value: _rd(sumCapital),
                                                            bg: const Color(0xFFF5F8FF),
                                                            border: const Color(0xFFDDE7FF),
                                                            valueColor: const Color(0xFF2563EB),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                // Producto / Alquiler → solo capital
                                                return Padding(
                                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                                                  child: _ChipStat(
                                                    label: 'Capital',
                                                    value: _rd(sumCapital),
                                                    bg: chipBgLeft,
                                                    border: chipBorderLeft,
                                                    valueColor: colorMain,
                                                  ),
                                                );
                                              }

                                              return Column(
                                                children: [
                                                  stats(),
                                                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                                                  Expanded(
                                                    child: ListView.separated(
                                                      key: const PageStorageKey('historialPagosList'),
                                                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                                      itemCount: pagos.length,
                                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                                      itemBuilder: (context, i) {
                                                        final p = pagos[i];
                                                        final d = p.data;
                                                        final fecha = _parseFecha(d['fecha'] ?? d['createdAt']);

                                                        final saldoAnterior =
                                                            (d['saldoAnterior'] as num?)?.toInt() ?? 0;
                                                        final saldoNuevo =
                                                            (d['saldoNuevo'] as num?)?.toInt() ?? saldoAnterior;

                                                        final bool fechaPendiente =
                                                            (d['fecha'] == null && d['createdAt'] == null) ||
                                                                (d['fecha'] != null && d['fecha'] is! Timestamp);

                                                        // Estética HALO suave por tipo
                                                        return _PagoCardPremium(
                                                          key: ValueKey(p.id),
                                                          fecha: _fmtFecha(fecha),
                                                          fechaPendiente: fechaPendiente,
                                                          total: p.total,
                                                          capital: p.capital,
                                                          interes: p.interes,
                                                          saldoAntes: saldoAnterior,
                                                          saldoDespues: saldoNuevo,
                                                          rd: _rd,
                                                          // estilo
                                                          showInteres: _esPrestamo && p.interes > 0, // solo préstamo y si hay interés
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

class _PagoCardPremium extends StatelessWidget {
  final String fecha;
  final bool fechaPendiente;
  final int total;
  final int capital;
  final int interes; // se oculta si showInteres=false
  final int saldoAntes;
  final int saldoDespues;
  final String Function(num) rd;

  final bool showInteres;
  final Color tint;   // fondo suave
  final Color border; // borde suave
  final Color accent; // color de marca por tipo
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
    final verde = const Color(0xFF22C55E);
    final azul = const Color(0xFF2563EB);
    final rojo = Colors.red.shade600;
    const ink = Color(0xFF0F172A);

    final bool saldoBaja = saldoDespues <= saldoAntes;
    final Color colorAntes = saldoAntes > 0 ? rojo : verde;
    final Color colorDespues = saldoDespues == 0 ? verde : (saldoBaja ? ink : rojo);

    return Container(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.22)),
            ),
            alignment: Alignment.center,
            child: Icon(leadingIcon, color: accent, size: 20),
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
                                border: Border.all(color: const Color(0xFFFDE68A)),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: accent, // usa color del tipo
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Interés (solo préstamos, solo si > 0)
                if (showInteres) ...[
                  Row(
                    children: [
                      const Text(
                        'Interés: ',
                        style: TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        rd(interes),
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],

                // Capital (siempre)
                Row(
                  children: [
                    Text(
                      'Capital: ',
                      style: TextStyle(
                        color: azul,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rd(capital),
                      style: TextStyle(
                        color: azul,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Saldo (oculto si es alquiler)
                if (leadingIcon != Icons.house_rounded) ...[
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}