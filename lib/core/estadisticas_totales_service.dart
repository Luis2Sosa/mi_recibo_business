import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio global de estadísticas (capital + sincronización real)
/// Versión completa y estable con historial mensual automático.
class EstadisticasTotalesService {
  static final _db = FirebaseFirestore.instance;

  // ================== RUTAS BASE ==================
  static DocumentReference<Map<String, dynamic>> _summaryDoc(String prestamistaId) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('metrics').doc('summary');

  static DocumentReference<Map<String, dynamic>> _catDoc(String prestamistaId, String cat) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('estadisticas').doc(cat);

  static DocumentReference<Map<String, dynamic>> _totalesDoc(String prestamistaId) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('estadisticas').doc('totales');

  // ================== ESTRUCTURA BASE ==================
  static Future<void> ensureStructure(String prestamistaId) async {
    final docRef = _summaryDoc(prestamistaId);
    final snap = await docRef.get();

    // ✅ Solo crea el documento si no existe
    if (!snap.exists) {
      await docRef.set({
        'totalCapitalPrestado': 0,
        'totalCapitalRecuperado': 0,
        'totalCapitalPendiente': 0,
        'totalGanancia': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // ✅ Crea las categorías solo si no existen
    for (final cat in const ['prestamo', 'producto', 'alquiler']) {
      final catRef = _catDoc(prestamistaId, cat);
      final catSnap = await catRef.get();
      if (!catSnap.exists) {
        await catRef.set({
          'capitalPrestado': 0,
          'capitalRecuperado': 0,
          'capitalPendiente': 0,
          'gananciaNeta': 0,
          'activos': 0,
          'finalizados': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    // ✅ Crea el documento de totales si no existe
    final totRef = _totalesDoc(prestamistaId);
    final totSnap = await totRef.get();
    if (!totSnap.exists) {
      await totRef.set({
        'totalGanancia': 0,
        'totalCapitalRecuperado': 0,
        'totalCapitalPrestado': 0,
        'totalRecuperado': 0,
        'gananciaAlquiler': 0,
        'gananciaPrestamo': 0,
        'gananciaProducto': 0,
        'historialGanancias': {},
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ================== LECTURA ==================
  static Stream<Map<String, dynamic>?> listenSummary(String prestamistaId) =>
      _summaryDoc(prestamistaId).snapshots().map((s) => s.data());

  static Future<Map<String, dynamic>?> readSummary(String prestamistaId) async =>
      (await _summaryDoc(prestamistaId).get()).data();

  // ================== CATEGORÍAS ==================
  static Future<void> ensureCategoria(String prestamistaId, String cat) async {
    final ref = _catDoc(prestamistaId, cat);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'capitalPrestado': 0,
        'capitalRecuperado': 0,
        'capitalPendiente': 0,
        'gananciaNeta': 0,
        'activos': 0,
        'finalizados': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// ================== AJUSTES CON PROTECCIÓN ==================
  static Future<void> adjustCategoria(
      String prestamistaId,
      String cat, {
        int? capitalPrestadoDelta,
        int? capitalRecuperadoDelta,
        int? capitalPendienteDelta,
        int? gananciaNetaDelta,
        int? activosDelta,
        int? finalizadosDelta,
      }) async {
    await ensureCategoria(prestamistaId, cat);

    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

    if (capitalPrestadoDelta != null) {
      data['capitalPrestado'] = FieldValue.increment(capitalPrestadoDelta);
    }

    // 🚫 Nunca restar capital recuperado automáticamente
    if (capitalRecuperadoDelta != null && capitalRecuperadoDelta > 0) {
      data['capitalRecuperado'] = FieldValue.increment(capitalRecuperadoDelta);
    }

    if (capitalPendienteDelta != null) {
      data['capitalPendiente'] = FieldValue.increment(capitalPendienteDelta);
    }

    if (gananciaNetaDelta != null) {
      data['gananciaNeta'] = FieldValue.increment(gananciaNetaDelta);
    }

    if (activosDelta != null) {
      data['activos'] = FieldValue.increment(activosDelta);
    }

    if (finalizadosDelta != null) {
      data['finalizados'] = FieldValue.increment(finalizadosDelta);
    }

    await _catDoc(prestamistaId, cat).set(data, SetOptions(merge: true));
  }

  // ================== ACTUALIZACIONES ==================

  /// 🔹 Nuevo cliente
  static Future<void> actualizarPorNuevoCliente(
      String prestamistaId, {
        required String tipo,
        required int capitalInicial,
      }) async {
    await ensureStructure(prestamistaId);
    await adjustCategoria(
      prestamistaId,
      tipo,
      capitalPrestadoDelta: capitalInicial,
      capitalPendienteDelta: capitalInicial,
      activosDelta: 1,
    );

    await _summaryDoc(prestamistaId).set({
      'totalCapitalPrestado': FieldValue.increment(capitalInicial),
      'totalCapitalPendiente': FieldValue.increment(capitalInicial),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await actualizarHistorialMensual(prestamistaId);
  }

  /// 🔹 Pago de capital (versión segura)
  static Future<void> registrarPagoCapital(
      String prestamistaId, {
        required String tipo,
        required int montoCapital,
      }) async {
    await adjustCategoria(
      prestamistaId,
      tipo,
      capitalRecuperadoDelta: montoCapital,
      capitalPendienteDelta: -montoCapital,
    );

    await _summaryDoc(prestamistaId).set({
      'totalCapitalRecuperado': FieldValue.increment(montoCapital),
      'totalCapitalPendiente': FieldValue.increment(-montoCapital),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await actualizarHistorialMensual(prestamistaId);
  }

  /// 🔹 Eliminar capital recuperado manualmente
  static Future<void> eliminarCapitalRecuperadoManual(
      String prestamistaId, int monto) async {
    await _summaryDoc(prestamistaId).set({
      'totalCapitalRecuperado': FieldValue.increment(-monto),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await actualizarHistorialMensual(prestamistaId);
  }

  /// 🔹 Sincronizar resumen según clientes reales
  static Future<void> sincronizarResumen(String prestamistaId) async {
    try {
      final clientesSnap = await _db
          .collection('prestamistas')
          .doc(prestamistaId)
          .collection('clientes')
          .get();

      num totalPrestado = 0;
      num totalPendiente = 0;
      num totalRecuperado = 0;

      for (final c in clientesSnap.docs) {
        final d = c.data();
        final tipo = (d['tipo'] ?? '').toString().toLowerCase();
        final estado = (d['estado'] ?? '').toString().toLowerCase();

        final esPrestamo = tipo.contains('prest') ||
            tipo.contains('cred') ||
            tipo.contains('fiado') ||
            tipo.isEmpty;
        if (!esPrestamo) continue;

        final capitalInicial = (d['capitalInicial'] ?? d['capital'] ?? 0) as num;
        final saldoActual = (d['saldoActual'] ?? 0) as num;

        totalPrestado += capitalInicial;
        totalPendiente += saldoActual;
        totalRecuperado += (capitalInicial - saldoActual);
      }

      await _summaryDoc(prestamistaId).set({
        'totalCapitalPrestado': totalPrestado,
        'totalCapitalPendiente': totalPendiente,
        'totalCapitalRecuperado': totalRecuperado,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Resumen sincronizado correctamente');
    } catch (e) {
      print('⚠️ Error sincronizando resumen: $e');
    }
  }

  /// 🔹 Cálculo directo de recuperación total
  static Future<double> calcularRecuperacionTotal(String prestamistaId) async {
    final data = await readSummary(prestamistaId);
    if (data == null) return 0.0;

    final totalPrestado = (data['totalCapitalPrestado'] ?? 0) as num;
    final totalRecuperado = (data['totalCapitalRecuperado'] ?? 0) as num;

    if (totalPrestado <= 0) return 0.0;
    return (totalRecuperado * 100.0) / totalPrestado;
  }

  /// 🔹 Stream en vivo del porcentaje de recuperación
  static Stream<double> listenRecuperacionTotal(String prestamistaId) {
    return _summaryDoc(prestamistaId).snapshots().map((s) {
      final d = s.data();
      if (d == null) return 0.0;
      final totalPrestado = (d['totalCapitalPrestado'] ?? 0) as num;
      final totalRecuperado = (d['totalCapitalRecuperado'] ?? 0) as num;
      if (totalPrestado <= 0) return 0.0;
      return (totalRecuperado * 100.0) / totalPrestado;
    });
  }

  // ================== HISTORIAL MENSUAL ==================
  static Future<void> actualizarHistorialMensual(String prestamistaId) async {
    try {
      final docTotales = _totalesDoc(prestamistaId);
      final snap = await docTotales.get();
      if (!snap.exists) return;

      final data = snap.data() ?? {};
      final gananciaTotal = (data['totalGanancia'] ?? 0) as num;

      final ahora = DateTime.now();
      final claveMes = '${ahora.year}-${ahora.month.toString().padLeft(2, '0')}';

      await docTotales.set({
        'historialGanancias': {
          claveMes: {'total': gananciaTotal}
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Historial mensual actualizado ($claveMes: $gananciaTotal)');
    } catch (e) {
      print('⚠️ Error al actualizar historial mensual: $e');
    }
  }
}
