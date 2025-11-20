import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Sincroniza pagos creados en modo offline (pendienteSync=true)
/// cuando regresa la conectividad.
class SyncOfflineService {
  SyncOfflineService._();
  static final SyncOfflineService instance = SyncOfflineService._();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  StreamSubscription<User?>? _authSub;
  bool _syncing = false;

  void start() {
    // Escucha cambios de sesión
    _authSub ??=
        FirebaseAuth.instance.authStateChanges().listen((_) async {
          final hasNet = await _hasConnectivity();
          if (hasNet) _trySync();
        });

    // 🔥 NUEVO MANEJO DE CONECTIVIDAD (compatibilidad 2024+)
    _connSub ??= Connectivity().onConnectivityChanged.listen(
          (List<ConnectivityResult> results) {
        if (results.isNotEmpty &&
            (results.contains(ConnectivityResult.mobile) ||
                results.contains(ConnectivityResult.wifi))) {
          _trySync();
        }
      },
    );

    // Primer intento al arrancar
    _trySync();
  }

  Future<bool> _hasConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    return results.any(
          (r) =>
      r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi,
    );
  }

  Future<void> _trySync() async {
    if (_syncing) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ok = await _hasConnectivity();
    if (!ok) return;

    _syncing = true;
    try {
      await _syncPending(uid);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncPending(String uid) async {
    final db = FirebaseFirestore.instance;

    // 1) Traer clientes del usuario desde cache
    final clientesSnap = await db
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .get(const GetOptions(source: Source.cache));

    for (final clienteDoc in clientesSnap.docs) {
      final clienteRef = clienteDoc.reference;

      // 2) Pagos pendientes
      final pagosPendSnap = await clienteRef
          .collection('pagos')
          .where('pendienteSync', isEqualTo: true)
          .get(const GetOptions(source: Source.cache));

      if (pagosPendSnap.docs.isEmpty) continue;

      for (final p in pagosPendSnap.docs) {
        final data = p.data();

        final int saldoNuevo = (data['saldoNuevo'] ?? 0) is int
            ? data['saldoNuevo'] as int
            : 0;
        final int pagoCapital = (data['pagoCapital'] ?? 0) is int
            ? data['pagoCapital'] as int
            : 0;
        final int pagoInteres = (data['pagoInteres'] ?? 0) is int
            ? data['pagoInteres'] as int
            : 0;

        final Timestamp? proxTs = data['proximaFecha'] as Timestamp?;
        final DateTime proximaFecha =
            proxTs?.toDate() ?? DateTime.now();

        // 3) Aplicar cambios con transacción
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(clienteRef);
          final current =
          (snap.data()?['nextReciboCliente'] ?? 0) as int;
          final next = current + 1;

          final updates = <String, dynamic>{
            'saldoActual': saldoNuevo,
            'proximaFecha': Timestamp.fromDate(proximaFecha),
            'updatedAt': FieldValue.serverTimestamp(),
            'nextReciboCliente': next,
            'saldado': saldoNuevo <= 0,
            'estado':
            saldoNuevo <= 0 ? 'saldado' : 'al_dia',
            'venceEl': (saldoNuevo <= 0)
                ? FieldValue.delete()
                : Timestamp.fromDate(proximaFecha),
          };

          tx.set(clienteRef, updates, SetOptions(merge: true));

          tx.update(p.reference, {'pendienteSync': false});
        });

        // 4) Métricas globales
        try {
          final metricsRef = db
              .collection('prestamistas')
              .doc(uid)
              .collection('metrics')
              .doc('summary');

          await metricsRef.set({
            'lifetimeRecuperado':
            FieldValue.increment(pagoCapital),
            'lifetimeGanancia':
            FieldValue.increment(pagoInteres),
            'lifetimePagosSum': FieldValue.increment(
              (data['totalPagado'] ?? 0) as int,
            ),
            'lifetimePagosCount':
            FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {
          // no interrumpir sync
        }
      }
    }
  }

  Future<void> dispose() async {
    await _connSub?.cancel();
    _connSub = null;
    await _authSub?.cancel();
    _authSub = null;
  }
}
