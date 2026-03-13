// lib/ui/clientes/auto_filtro_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'clientes_shared.dart'; // trae FiltroClientes


class AutoFiltroService {
  /// Reglas:
  /// 1) Si hay urgentes (vencidos, hoy, o en 1–2 días), ir a la sección con MÁS urgentes.
  /// 2) Si NO hay urgentes, ir a la sección con MÁS activos (saldo > 0).
  /// 3) Empates: usar preferenciaActual si aplica; si no, orden fijo: préstamos > productos > alquiler.
  static Future<FiltroClientes> elegirFiltroPreferido({
    FiltroClientes? preferenciaActual,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return preferenciaActual ?? FiltroClientes.prestamos;

    final qs = await FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .orderBy('proximaFecha')
        .get();

    if (qs.docs.isEmpty) return preferenciaActual ?? FiltroClientes.prestamos;

    final Map<FiltroClientes, int> urgentes = {
      FiltroClientes.prestamos: 0,
      FiltroClientes.productos: 0,
      FiltroClientes.alquiler: 0,
    };
    final Map<FiltroClientes, int> activos = {
      FiltroClientes.prestamos: 0,
      FiltroClientes.productos: 0,
      FiltroClientes.alquiler: 0,
    };

    bool _esArriendo(String? p) {
      final s = (p ?? '').toLowerCase().trim();
      if (s.isEmpty) return false;
      return s.contains('arri') ||
          s.contains('alqui') ||
          s.contains('renta') ||
          s.contains('rent') ||
          s.contains('lease') ||
          s.contains('casa') ||
          s.contains('apart') ||
          s.contains('estudio') ||
          s.contains('apartaestudio') ||
          s.contains('aparta estudio');
    }

    // FIX: consultar el campo 'tipo' primero, igual que en guardar_pago_y_actualizar_kpis.
    // Antes solo revisaba el campo 'producto' → si tipo='producto' pero producto='bolso',
    // 'bolso' no hacía match con _esArriendo y caía bien en .productos, pero si
    // producto estaba vacío y tipo='producto', caía en .prestamos incorrectamente.
    FiltroClientes _tipoDe(Map<String, dynamic> data) {
      final tipoField = (data['tipo'] ?? '').toString().toLowerCase().trim();
      final p = (data['producto'] as String?)?.trim() ?? '';

      // 1) Detectar por campo 'tipo' primero
      if (tipoField == 'alquiler' || tipoField == 'arriendo') {
        return FiltroClientes.alquiler;
      }
      if (tipoField == 'producto' || tipoField == 'fiado') {
        return FiltroClientes.productos;
      }
      if (tipoField == 'prestamo' || tipoField == 'préstamo') {
        return FiltroClientes.prestamos;
      }

      // 2) Fallback: inferir por texto del campo 'producto'
      if (_esArriendo(p)) return FiltroClientes.alquiler;
      if (p.isNotEmpty) return FiltroClientes.productos;
      return FiltroClientes.prestamos;
    }

    int _diasHasta(DateTime d) {
      final hoy = DateTime.now();
      final a = DateTime(hoy.year, hoy.month, hoy.day);
      final b = DateTime(d.year, d.month, d.day);
      return b.difference(a).inDays;
    }

    for (final d in qs.docs) {
      final data = d.data() as Map<String, dynamic>;

      final dynamic rawSaldo = data['salvoActual'] ?? data['saldoActual'] ?? 0;
      final int saldoActual = (rawSaldo is int) ? rawSaldo : int.tryParse('$rawSaldo') ?? 0;

      if (saldoActual <= 0) continue;

      final filtro = _tipoDe(data);

      activos[filtro] = (activos[filtro] ?? 0) + 1;

      final rawPF = data['proximaFecha'];
      DateTime? prox;
      if (rawPF is Timestamp) {
        prox = rawPF.toDate();
      } else if (rawPF is String) {
        prox = DateTime.tryParse(rawPF);
      }

      if (prox == null) continue;

      final dd = _diasHasta(prox);

      if (dd <= 2) {
        urgentes[filtro] = (urgentes[filtro] ?? 0) + 1;
      }
    }

    final totalUrgentes = urgentes.values.fold<int>(0, (a, b) => a + b);
    if (totalUrgentes > 0) {
      return _maxConEmpate(
        mapa: urgentes,
        preferencia: preferenciaActual,
        desempateSecundario: activos,
      );
    }

    final totalActivos = activos.values.fold<int>(0, (a, b) => a + b);
    if (totalActivos > 0) {
      return _maxConEmpate(
        mapa: activos,
        preferencia: preferenciaActual,
      );
    }

    return preferenciaActual ?? FiltroClientes.prestamos;
  }

  static FiltroClientes _maxConEmpate({
    required Map<FiltroClientes, int> mapa,
    FiltroClientes? preferencia,
    Map<FiltroClientes, int>? desempateSecundario,
  }) {
    final maxVal = mapa.values.isEmpty ? 0 : mapa.values.reduce((a, b) => a > b ? a : b);
    final candidatos = mapa.entries.where((e) => e.value == maxVal).map((e) => e.key).toList();

    if (candidatos.length == 1) return candidatos.first;

    if (desempateSecundario != null) {
      int best = -1;
      List<FiltroClientes> mejores = [];
      for (final c in candidatos) {
        final v = desempateSecundario[c] ?? 0;
        if (v > best) {
          best = v;
          mejores = [c];
        } else if (v == best) {
          mejores.add(c);
        }
      }
      if (mejores.length == 1) return mejores.first;
      return _preferOrDefault(mejores, preferencia);
    }

    return _preferOrDefault(candidatos, preferencia);
  }

  static FiltroClientes _preferOrDefault(
      List<FiltroClientes> candidatos,
      FiltroClientes? preferencia,
      ) {
    if (preferencia != null && candidatos.contains(preferencia)) {
      return preferencia;
    }
    const orden = [
      FiltroClientes.prestamos,
      FiltroClientes.productos,
      FiltroClientes.alquiler,
    ];
    for (final f in orden) {
      if (candidatos.contains(f)) return f;
    }
    return FiltroClientes.prestamos;
  }
}