// lib/clientes/clientes_shared.dart

import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../adaptive_icons.dart';


/// =====================
/// ENUMS GLOBALES
/// =====================
enum FiltroClientes { prestamos, productos, alquiler }
enum EstadoVenc { vencido, hoy, pronto, alDia }

/// =====================
/// MODELO DE CLIENTE
/// =====================
class Cliente {
  final String id;
  final String codigo; // Ejemplo: CL-XXXX
  final String nombre;
  final String apellido;
  final String telefono;
  final String? direccion;
  final String? nota;
  final String? producto;
  final int capitalInicial;
  final int saldoActual;
  final double tasaInteres;
  final String periodo;
  final DateTime proximaFecha;
  final Map<String, dynamic>? mora; // 👈 NUEVO

  Cliente({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    this.direccion,
    this.nota,
    this.producto,
    required this.capitalInicial,
    required this.saldoActual,
    required this.tasaInteres,
    required this.periodo,
    required this.proximaFecha,
    this.mora,
  });

  String get nombreCompleto => '$nombre $apellido';

  /// ✅ Mora calculada localmente (sin internet)
  int get moraAcumulada {
    final cfg = mora;
    if (cfg == null) return 0;

    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(proximaFecha.year, proximaFecha.month, proximaFecha.day);
    final diasAtraso = a.difference(b).inDays;
    if (diasAtraso <= 0) return 0;

    final umbrales = (cfg['umbralesDias'] as List?)?.cast<int>() ?? const <int>[15, 30];
    if (umbrales.isEmpty) return 0;
    if (diasAtraso < umbrales.first) return 0;

    final String tipo = (cfg['tipo'] ?? 'porcentaje') as String;
    final double valor = (cfg['valor'] ?? 10).toDouble();
    final bool dobleEn30 = (cfg['dobleEn30'] ?? true) as bool;

    final int base = saldoActual > 0 ? saldoActual : capitalInicial;
    double monto = (tipo == 'fijo') ? valor : (base * (valor / 100.0));
    if (dobleEn30 && diasAtraso >= 30) monto *= 2;

    return monto.round();
  }
}

/// =====================
/// WIDGET CLIENTE CARD
/// =====================
class ClienteCard extends StatelessWidget {
  final Cliente cliente;
  final EstadoVenc estado;
  final int diasHasta;
  final bool resaltar;
  final String? codigoCorto;

  const ClienteCard({
    super.key,
    required this.cliente,
    required this.estado,
    required this.diasHasta,
    this.resaltar = true,
    this.codigoCorto,
  });

  String _moneda(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    final texto = buf.toString().split('').reversed.join().replaceAll('.', ',');
    return '\$$texto';
  }

  Color _headerColor() {
    if (cliente.saldoActual <= 0) return const Color(0xFFCBD5E1);
    switch (estado) {
      case EstadoVenc.vencido:
        return const Color(0xFFDC2626);
      case EstadoVenc.hoy:
        return const Color(0xFFFB923C);
      case EstadoVenc.pronto:
        return const Color(0xFFFACC15);
      case EstadoVenc.alDia:
        return const Color(0xFF22C55E);
    }
  }

  String _estadoTexto() {
    if (cliente.saldoActual <= 0) return 'Saldado';
    switch (estado) {
      case EstadoVenc.vencido:
        return 'Vencido';
      case EstadoVenc.hoy:
        return 'Vence hoy';
      case EstadoVenc.pronto:
        return diasHasta == 1 ? 'Vence mañana' : 'Vence en $diasHasta días';
      case EstadoVenc.alDia:
        return 'Al día';
    }
  }

  Widget _chip(
      String text, {
        EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        Color bg = const Color(0xFFF4F6FA),
        Color border = const Color(0xFFE5E7EB),
        Color fg = const Color(0xFF0F172A),
        double fs = 13,
        FontWeight fw = FontWeight.w800,
        IconData? icon,
        Color? iconColor,
      }) {
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fs,
              fontWeight: fw,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Detectar tipo de cliente por el campo producto
    final prod = (cliente.producto ?? '').trim().toLowerCase();
    final bool esAlquiler =
        prod.contains('alquiler') || prod.contains('arriendo') || prod.contains('renta');
    final bool esProducto = prod.isNotEmpty && !esAlquiler; // cualquier otro texto ≈ producto
    final bool esPrestamo = prod.isEmpty; // sin producto ⇒ préstamo

    // Interés solo aplica a préstamos
    final int interesPeriodo = esPrestamo
        ? (cliente.saldoActual * (cliente.tasaInteres / 100)).round()
        : 0;


    // Monto grande: SOLO capital (sin interés) para todos los tipos
    final int montoPrincipal = cliente.saldoActual;


    // Mora (solo para producto o alquiler)
    final bool tieneMora =
        cliente.saldoActual > 0 && (esProducto || esAlquiler) && cliente.moraAcumulada > 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // ======= ENCABEZADO =======
            Container(
              height: 36,
              color: _headerColor(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    codigoCorto ?? cliente.codigo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: .3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _estadoTexto(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                      letterSpacing: .3,
                    ),
                  ),
                ],
              ),
            ),

            // ======= CONTENIDO =======
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // 🧩 Ícono adaptativo según tipo
                      platformIcon(
                        context,
                        md: cliente.producto == null || cliente.producto!.trim().isEmpty
                            ? Icons.request_quote_rounded
                            : cliente.producto!.toLowerCase().contains('alqui') ||
                            cliente.producto!.toLowerCase().contains('renta') ||
                            cliente.producto!.toLowerCase().contains('casa') ||
                            cliente.producto!.toLowerCase().contains('apart')
                            ? Icons.house_rounded
                            : cliente.producto!.toLowerCase().contains('car') ||
                            cliente.producto!.toLowerCase().contains('vehic')
                            ? Icons.directions_car_rounded
                            : Icons.shopping_bag_rounded,
                        ios: cliente.producto == null || cliente.producto!.trim().isEmpty
                            ? CupertinoIcons.money_dollar_circle
                            : cliente.producto!.toLowerCase().contains('alqui') ||
                            cliente.producto!.toLowerCase().contains('renta') ||
                            cliente.producto!.toLowerCase().contains('casa') ||
                            cliente.producto!.toLowerCase().contains('apart')
                            ? CupertinoIcons.house_fill
                            : cliente.producto!.toLowerCase().contains('car') ||
                            cliente.producto!.toLowerCase().contains('vehic')
                            ? CupertinoIcons.car_detailed
                            : CupertinoIcons.bag_fill,

                        // 💡 Color dinámico según el módulo
                        color: colorForModule(cliente.producto ?? ''),
                        size: 26,
                      ),


                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          cliente.nombreCompleto,

                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      _chip(
                        _moneda(montoPrincipal),
                        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        bg: const Color(0xFFF4FAF7),
                        border: const Color(0xFFDDE7E1),
                        fg: const Color(0xFF065F46),
                        fs: 16,
                        fw: FontWeight.w900,
                        icon: Icons.request_quote_rounded,
                        iconColor: const Color(0xFF065F46),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      _chip(
                        cliente.telefono,
                        bg: Colors.white,
                        border: const Color(0xFFE5E7EB),
                        fg: const Color(0xFF334155),
                        fs: 13,
                        fw: FontWeight.w700,
                        icon: Icons.phone_rounded,
                        iconColor: const Color(0xFF334155),
                      ),
                      const Spacer(),
                      if (cliente.saldoActual > 0) // ocultar si ya está saldado
                        if (tieneMora)
                          _chip(
                            _moneda(cliente.moraAcumulada),
                            bg: const Color(0xFFFFF7ED),
                            border: const Color(0xFFFECACA),
                            fg: const Color(0xFFB91C1C),
                            fs: 13,
                            fw: FontWeight.w900,
                            icon: Icons.warning_amber_rounded,
                            iconColor: const Color(0xFFB91C1C),
                          )
                        else if (esPrestamo)
                          _chip(
                            _moneda(interesPeriodo),
                            bg: const Color(0xFFF1F5FF),
                            border: const Color(0xFFDCE7FF),
                            fg: const Color(0xFF1D4ED8),
                            fs: 13,
                            fw: FontWeight.w800,
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF1D4ED8),
                          )
                        else
                          _chip(
                            _moneda(0),
                            bg: const Color(0xFFF1F5FF),
                            border: const Color(0xFFE5E7EB),
                            fg: const Color(0xFF64748B),
                            fs: 13,
                            fw: FontWeight.w800,
                            icon: Icons.trending_up_rounded,
                            iconColor: const Color(0xFF64748B),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}