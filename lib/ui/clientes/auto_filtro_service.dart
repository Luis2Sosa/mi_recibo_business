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

    // Contadores por sección
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

    FiltroClientes _tipoDe(Map<String, dynamic> data) {
      final p = (data['producto'] as String?)?.trim() ?? '';
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

      // saldoActual como int seguro (soporta posible typo 'salvoActual')
      final dynamic rawSaldo = data['salvoActual'] ?? data['saldoActual'] ?? 0;
      final int saldoActual = (rawSaldo is int) ? rawSaldo : int.tryParse('$rawSaldo') ?? 0;

      if (saldoActual <= 0) continue; // ignorar saldados

      final filtro = _tipoDe(data);

      // Todo con saldo > 0 cuenta como activo
      activos[filtro] = (activos[filtro] ?? 0) + 1;

      // proximaFecha a DateTime (si no hay fecha válida, no se considera "urgente")
      final rawPF = data['proximaFecha'];
      DateTime? prox;
      if (rawPF is Timestamp) {
        prox = rawPF.toDate();
      } else if (rawPF is String) {
        prox = DateTime.tryParse(rawPF);
      }

      if (prox == null) {
        // Sin fecha válida: no sumar a urgentes
        continue;
      }

      final dd = _diasHasta(prox);

      // Urgente = vencido (dd<0) o dd==0 (hoy) o dd==1..2 (pronto)
      if (dd <= 2) {
        urgentes[filtro] = (urgentes[filtro] ?? 0) + 1;
      }
    }

    // 1) Priorizar por URGENTES
    final totalUrgentes = urgentes.values.fold<int>(0, (a, b) => a + b);
    if (totalUrgentes > 0) {
      return _maxConEmpate(
        mapa: urgentes,
        preferencia: preferenciaActual,
        desempateSecundario: activos, // si empata en urgentes, mirar activos
      );
    }

    // 2) Si no hay urgentes, ir por MÁS ACTIVOS
    final totalActivos = activos.values.fold<int>(0, (a, b) => a + b);
    if (totalActivos > 0) {
      return _maxConEmpate(
        mapa: activos,
        preferencia: preferenciaActual,
      );
    }

    // 3) Nada: preferencia o default
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