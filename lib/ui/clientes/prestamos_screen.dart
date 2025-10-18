// lib/clientes/prestamos_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'clientes_shared.dart';

class PrestamosScreen extends StatelessWidget {
  final String search;
  final bool resaltarVencimientos;
  final void Function(Cliente c, String codigoCorto) onTapCliente;
  final void Function(Cliente c) onLongPressCliente;

  const PrestamosScreen({
    super.key,
    required this.search,
    required this.resaltarVencimientos,
    required this.onTapCliente,
    required this.onLongPressCliente,
  });

  int _diasHasta(DateTime d) {
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  EstadoVenc _estadoDe(Cliente c) {
    final d = _diasHasta(c.proximaFecha);
    if (d < 0) return EstadoVenc.vencido;
    if (d == 0) return EstadoVenc.hoy;
    if (d <= 2) return EstadoVenc.pronto;
    return EstadoVenc.alDia;
  }

  bool _esSaldado(Cliente c) => c.saldoActual <= 0;

  int _compareClientes(Cliente a, Cliente b) {
    final sa = _esSaldado(a);
    final sb = _esSaldado(b);
    if (sa != sb) return sa ? 1 : -1; // saldados al final
    final fa = a.proximaFecha;
    final fb = b.proximaFecha;
    if (fa != fb) return fa.compareTo(fb);
    return a.nombreCompleto.compareTo(b.nombreCompleto);
  }

  String _codigoDesdeId(String docId) {
    final base = docId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cut = base.length >= 6 ? base.substring(0, 6) : base.padRight(6, '0');
    return 'CL-${cut.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: Text('No hay sesión', style: TextStyle(color: Colors.white)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .orderBy('proximaFecha')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)),
          );
        }

        final docs = snap.data?.docs ?? [];
        final lista = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final codigoGuardado = (data['codigo'] as String?)?.trim();
          final codigoVisible = (codigoGuardado != null && codigoGuardado.isNotEmpty)
              ? codigoGuardado
              : _codigoDesdeId(d.id);
          return Cliente(
            id: d.id,
            codigo: codigoVisible,
            nombre: (data['nombre'] ?? '') as String,
            apellido: (data['apellido'] ?? '') as String,
            telefono: (data['telefono'] ?? '') as String,
            direccion: data['direccion'] as String?,
            producto: (data['producto'] as String?)?.trim(),
            capitalInicial: (data['capitalInicial'] ?? 0) as int,
            // tolerante con posible typo 'salvoActual'
            saldoActual: (data['salvoActual'] ?? data['saldoActual'] ?? 0) as int,
            tasaInteres: (data['tasaInteres'] ?? 0.0).toDouble(),
            periodo: (data['periodo'] ?? 'Mensual') as String,
            proximaFecha: (data['proximaFecha'] is Timestamp)
                ? (data['proximaFecha'] as Timestamp).toDate()
                : DateTime.now(),

            mora: (data['mora'] is Map)
                ? Map<String, dynamic>.from(data['mora'] as Map)
                : null,

          );
        }).toList();

        final q = search.toLowerCase();
        final filtered = lista.where((c) {
          final prod = (c.producto ?? '').trim().toLowerCase();
          final isPrestamo = prod.isEmpty; // préstamo => sin producto
          final match = c.codigo.toLowerCase().contains(q) ||
              c.nombreCompleto.toLowerCase().contains(q) ||
              c.telefono.contains(q);
          return isPrestamo && match;
        }).toList()
          ..sort(_compareClientes);

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No hay préstamos', style: TextStyle(color: Colors.white)),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final c = filtered[i];
            final estado = _estadoDe(c);
            final codigoCorto = 'CL-${(i + 1).toString().padLeft(4, '0')}';
            return GestureDetector(
              onTap: () => onTapCliente(c, codigoCorto),
              onLongPress: () => onLongPressCliente(c),
              child: ClienteCard(
                cliente: c,
                estado: estado,
                diasHasta: _diasHasta(c.proximaFecha),
                resaltar: resaltarVencimientos,
                codigoCorto: codigoCorto,
              ),
            );
          },
        );
      },
    );
  }
}