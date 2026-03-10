import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../core/premium_service.dart';

class HistorialScreen extends StatelessWidget {
  final String idCliente;
  final String nombreCliente;
  final String? producto;

  const HistorialScreen({
    super.key,
    required this.idCliente,
    required this.nombreCliente,
    this.producto,
  });

  // ─── Getters de tipo ─────────────────────────────────────────────────────
  bool get _esPrestamo {
    final p = (producto ?? '').trim().toLowerCase();
    if (p.isEmpty) return true;
    return p.contains('prest') ||
        p.contains('crédito') ||
        p.contains('credito') ||
        p.contains('loan');
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

  // ─── Helpers de formato ──────────────────────────────────────────────────
  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  String _rd(num v) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 0,
    ).format(v);
  }

  DateTime _parseFecha(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is DateTime) return ts;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  // ─── Colores por tipo ────────────────────────────────────────────────────
  Color get _colorMain => _esPrestamo
      ? const Color(0xFF2563EB)
      : (_esAlquiler ? const Color(0xFFF59E0B) : const Color(0xFF22C55E));

  IconData get _iconoTipo => _esAlquiler
      ? Icons.house_rounded
      : (_esPrestamo
      ? Icons.request_quote_rounded
      : Icons.shopping_bag_rounded);

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    // Tamaños adaptativos
    final double logoH = (screenH * 0.40).clamp(220.0, 360.0);
    final double logoTop = -(logoH * 0.28);
    final double contentTop = (screenH * 0.14).clamp(100.0, 150.0);
    final double hPad = (screenW * 0.04).clamp(12.0, 24.0);

    final Color cardTint = _colorMain.withOpacity(0.08);
    final Color cardBorder = _colorMain.withOpacity(0.22);

    if (uid == null) {
      return _SesionExpirada();
    }

    final pagosRef = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(idCliente)
        .collection('pagos');

    final premiumService = PremiumService();

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
          bottom: false,
          child: Stack(
            children: [
              // ── Logo de fondo ──────────────────────────────────────────
              Positioned(
                top: logoTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Image.asset(
                      'assets/images/logoB.png',
                      height: logoH,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // ── Contenido ──────────────────────────────────────────────
              Positioned.fill(
                top: contentTop,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      hPad, 0, hPad, botPad > 0 ? botPad : 12),
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
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            // Título
                            Text(
                              'Historial de Pagos',
                              style: GoogleFonts.playfairDisplay(
                                textStyle: TextStyle(
                                  color: Colors.white,
                                  fontSize: (screenW * 0.055).clamp(18.0, 24.0),
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tarjeta blanca principal
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
                                  children: [
                                    // Encabezado cliente
                                    _EncabezadoCliente(
                                      nombreCliente: nombreCliente,
                                      esPrestamo: _esPrestamo,
                                      esAlquiler: _esAlquiler,
                                      colorMain: _colorMain,
                                      iconoTipo: _iconoTipo,
                                      screenW: screenW,
                                    ),

                                    const Divider(
                                        height: 1,
                                        color: Color(0xFFE5E7EB)),

                                    // Lista de pagos
                                    Expanded(
                                      child: StreamBuilder<User?>(
                                        stream: FirebaseAuth.instance
                                            .authStateChanges(),
                                        builder: (context, userSnap) {
                                          if (!userSnap.hasData) {
                                            return const _LoadingList();
                                          }

                                          return StreamBuilder<bool>(
                                            stream: premiumService
                                                .streamEstadoPremium(
                                                userSnap.data!.uid),
                                            builder: (context, premiumSnap) {
                                              if (!premiumSnap.hasData) {
                                                return const _LoadingList();
                                              }
                                              final esPremium =
                                                  premiumSnap.data ?? false;

                                              return StreamBuilder<
                                                  QuerySnapshot<
                                                      Map<String, dynamic>>>(
                                                stream: pagosRef.snapshots(),
                                                builder: (context, snapshot) {
                                                  if (snapshot.connectionState ==
                                                      ConnectionState.waiting) {
                                                    return const _LoadingList();
                                                  }
                                                  if (snapshot.hasError) {
                                                    return const _ErrorState();
                                                  }

                                                  final raw =
                                                      snapshot.data?.docs ?? [];
                                                  if (raw.isEmpty) {
                                                    return _EmptyState(
                                                      onRegistrar: () =>
                                                          Navigator.pop(context),
                                                    );
                                                  }

                                                  // Ordenar por fecha desc
                                                  final docs = [...raw]..sort(
                                                          (a, b) {
                                                        final af = _parseFecha(
                                                            a.data()['fecha'] ??
                                                                a.data()[
                                                                'createdAt']);
                                                        final bf = _parseFecha(
                                                            b.data()['fecha'] ??
                                                                b.data()[
                                                                'createdAt']);
                                                        return bf.compareTo(af);
                                                      });

                                                  final pagos = docs.map((e) {
                                                    final d = e.data();
                                                    final capital = (d[
                                                    'pagoCapital'] ??
                                                        d['capital'] ??
                                                        d['abono'] ??
                                                        0)
                                                    as num;
                                                    final interes = (d[
                                                    'pagoInteres'] ??
                                                        d['interes'] ??
                                                        0)
                                                    as num;
                                                    final total = (d[
                                                    'totalPagado'] ??
                                                        capital + interes)
                                                    as num;
                                                    return _PagoNorm(
                                                      id: e.id,
                                                      data: d,
                                                      total: total.toInt(),
                                                      interes: interes.toInt(),
                                                      capital: capital.toInt(),
                                                    );
                                                  }).toList();

                                                  return ListView.separated(
                                                    padding: EdgeInsets.fromLTRB(
                                                        12,
                                                        12,
                                                        12,
                                                        12 +
                                                            (botPad > 0
                                                                ? botPad
                                                                : 0)),
                                                    itemCount: pagos.length,
                                                    separatorBuilder: (_, __) =>
                                                    const SizedBox(
                                                        height: 12),
                                                    itemBuilder: (context, i) {
                                                      final p = pagos[i];
                                                      final d = p.data;
                                                      final fecha = _parseFecha(
                                                          d['fecha'] ??
                                                              d['createdAt']);
                                                      final saldoAnterior =
                                                      (d['saldoAnterior'] ??
                                                          0)
                                                      as num;
                                                      final saldoNuevo =
                                                      (d['saldoNuevo'] ??
                                                          saldoAnterior)
                                                      as num;

                                                      // ✅ Un solo widget por estado premium
                                                      if (esPremium) {
                                                        return _PagoCardDesbloqueada(
                                                          key: ValueKey(p.id),
                                                          fecha: _fmtFecha(fecha),
                                                          total: p.total,
                                                          capital: p.capital,
                                                          interes: p.interes,
                                                          saldoAntes: saldoAnterior.toInt(),
                                                          saldoDespues: saldoNuevo.toInt(),
                                                          rd: _rd,
                                                          showInteres: _esPrestamo && p.interes > 0,
                                                          tint: cardTint,
                                                          border: cardBorder,
                                                          accent: _colorMain,
                                                          leadingIcon: _iconoTipo,
                                                          esAlquiler: _esAlquiler,
                                                          screenW: screenW,
                                                        );
                                                      } else {
                                                        return _PagoCardBloqueada(
                                                          key: ValueKey(p.id),
                                                          fecha: _fmtFecha(fecha),
                                                          total: p.total,
                                                          rd: _rd,
                                                          border: cardBorder,
                                                          accent: _colorMain,
                                                          leadingIcon: _iconoTipo,
                                                          screenW: screenW,
                                                        );
                                                      }
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
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Modelo interno ──────────────────────────────────────────────────────────
class _PagoNorm {
  final String id;
  final Map<String, dynamic> data;
  final int total;
  final int interes;
  final int capital;

  const _PagoNorm({
    required this.id,
    required this.data,
    required this.total,
    required this.interes,
    required this.capital,
  });
}

// ─── Encabezado cliente ──────────────────────────────────────────────────────
class _EncabezadoCliente extends StatelessWidget {
  final String nombreCliente;
  final bool esPrestamo;
  final bool esAlquiler;
  final Color colorMain;
  final IconData iconoTipo;
  final double screenW;

  const _EncabezadoCliente({
    required this.nombreCliente,
    required this.esPrestamo,
    required this.esAlquiler,
    required this.colorMain,
    required this.iconoTipo,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    final String tipoLabel = esPrestamo
        ? 'Préstamo'
        : (esAlquiler ? 'Alquiler' : 'Producto');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Text(
            nombreCliente,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (screenW * 0.052).clamp(16.0, 22.0),
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconoTipo, color: colorMain, size: 18),
              const SizedBox(width: 5),
              Text(
                tipoLabel,
                style: TextStyle(
                  fontSize: (screenW * 0.035).clamp(12.0, 15.0),
                  color: colorMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1.3,
            width: 160,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.08),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Estado vacío ────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback? onRegistrar;

  const _EmptyState({this.onRegistrar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long,
                size: 52, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            const Text(
              'No hay pagos registrados todavía',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Cuando registres un pago, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500),
            ),
            if (onRegistrar != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ir a registrar pago'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  shape: const StadiumBorder(),
                ),
                onPressed: onRegistrar,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Estado error ────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 10),
            const Text(
              'Error al cargar pagos',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF991B1B),
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Verifica tu conexión e intenta de nuevo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sesión expirada ─────────────────────────────────────────────────────────
class _SesionExpirada extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Sesión expirada.\nInicia sesión de nuevo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      shape: const StadiumBorder(),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading ─────────────────────────────────────────────────────────────────
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(
                    height: 12,
                    width: 140,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF1F3),
                        borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta BLOQUEADA (no premium) ─────────────────────────────────────────
class _PagoCardBloqueada extends StatelessWidget {
  final String fecha;
  final int total;
  final String Function(num) rd;
  final Color border;
  final Color accent;
  final IconData leadingIcon;
  final double screenW;

  const _PagoCardBloqueada({
    super.key,
    required this.fecha,
    required this.total,
    required this.rd,
    required this.border,
    required this.accent,
    required this.leadingIcon,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    const azulCandado = Color(0xFF2563EB);
    const verdePago = Color(0xFF22C55E);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado: fecha + badge Premium
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: accent.withOpacity(0.18)),
                    ),
                    child:
                    Icon(leadingIcon, color: accent, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fecha,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      fontSize:
                      (screenW * 0.038).clamp(13.0, 15.5),
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
                  border:
                  Border.all(color: azulCandado.withOpacity(0.25)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, color: azulCandado, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: azulCandado,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Monto visible
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payments_rounded,
                  color: verdePago, size: 19),
              const SizedBox(width: 6),
              Text(
                'Pago realizado:',
                style: TextStyle(
                  color: const Color(0xFF475569),
                  fontWeight: FontWeight.w700,
                  fontSize: (screenW * 0.036).clamp(13.0, 14.5),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                rd(total),
                style: TextStyle(
                  color: verdePago,
                  fontWeight: FontWeight.w900,
                  fontSize: (screenW * 0.04).clamp(14.0, 16.0),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bloque bloqueado
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF1F5F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_outline,
                    color: azulCandado, size: 22),
                const SizedBox(height: 6),
                Text(
                  'Ver detalles completos con el plan Premium',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                    fontSize: (screenW * 0.034).clamp(12.0, 14.0),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF93C5FD), Color(0xFFE0E7FF)],
                    ),
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

// ─── Tarjeta DESBLOQUEADA (premium) ─────────────────────────────────────────
class _PagoCardDesbloqueada extends StatelessWidget {
  final String fecha;
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
  final bool esAlquiler;
  final double screenW;

  const _PagoCardDesbloqueada({
    super.key,
    required this.fecha,
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
    required this.esAlquiler,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    const grisTexto = Color(0xFF334155);
    const negroElegante = Color(0xFF0F172A);
    const verde = Color(0xFF22C55E);
    const azul = Color(0xFF2563EB);
    const naranja = Color(0xFFF59E0B);

    final bool esPrestamo = leadingIcon == Icons.request_quote_rounded;
    final bool esProducto = !esAlquiler && !esPrestamo;

    final gradient = LinearGradient(
      colors: esPrestamo
          ? [const Color(0xFF2563EB), const Color(0xFF60A5FA)]
          : (esAlquiler
          ? [const Color(0xFFF59E0B), const Color(0xFFFBBF24)]
          : [const Color(0xFF16A34A), const Color(0xFF4ADE80)]),
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final double bodyFontSize = (screenW * 0.036).clamp(12.5, 14.5);
    final double totalFontSize = (screenW * 0.042).clamp(14.0, 17.0);
    final double fechaFontSize = (screenW * 0.038).clamp(13.0, 15.5);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.22),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ─────────────────────────────────────────────────
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
                          color: accent.withOpacity(0.38),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fecha,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: negroElegante,
                      fontSize: fechaFontSize,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded,
                        color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Total ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pago actual:',
                style: TextStyle(
                  color: grisTexto,
                  fontWeight: FontWeight.w700,
                  fontSize: bodyFontSize,
                ),
              ),
              ShaderMask(
                shaderCallback: (bounds) => gradient.createShader(bounds),
                child: Text(
                  rd(total),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: totalFontSize,
                  ),
                ),
              ),
            ],
          ),

          // ── Interés (solo préstamo) ────────────────────────────────────
          if (showInteres && esPrestamo) ...[
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Interés:',
                    style: TextStyle(
                        color: const Color(0xFF475569),
                        fontSize: bodyFontSize,
                        fontWeight: FontWeight.w600)),
                Text(
                  rd(interes),
                  style: TextStyle(
                      color: verde,
                      fontWeight: FontWeight.w800,
                      fontSize: bodyFontSize + 0.5),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),
          Divider(color: accent.withOpacity(0.22), thickness: 1),
          const SizedBox(height: 6),

          // ── Saldos ────────────────────────────────────────────────────
          if (!esAlquiler) ...[
            _filaDetalle('Saldo anterior:', rd(saldoAntes), azul,
                bodyFontSize),
            const SizedBox(height: 4),
            _filaDetalle('Saldo nuevo:', rd(saldoDespues), verde,
                bodyFontSize),
          ] else ...[
            _filaDetalle('Próximo pago:', rd(total), naranja,
                bodyFontSize),
          ],

          const SizedBox(height: 12),
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

  Widget _filaDetalle(
      String label, String value, Color valueColor, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: const Color(0xFF6B7280),
                fontSize: fontSize,
                fontWeight: FontWeight.w500)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w900,
                fontSize: fontSize)),
      ],
    );
  }
}