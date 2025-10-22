import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio global de estadísticas (solo capital)
/// Versión estable: no borra totales y suma todas las categorías correctamente.
class EstadisticasTotalesService {
  static final _db = FirebaseFirestore.instance;

  // ================== RUTAS BASE ==================
  static DocumentReference<Map<String, dynamic>> _summaryDoc(String prestamistaId) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('metrics').doc('summary');

  static DocumentReference<Map<String, dynamic>> _catDoc(String prestamistaId, String cat) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('estadisticas').doc(cat);

  // ================== ESTRUCTURA BASE ==================
  static Future<void> ensureStructure(String prestamistaId) async {
    final docRef = _summaryDoc(prestamistaId);
    final snap = await docRef.get();

    // ✅ Solo crea el documento si no existe, nunca lo reinicia
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

    // 🚫 Nunca permitir restar capital recuperado automáticamente
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
  }

  /// 🔹 Pago de capital (versión segura)
  static Future<void> registrarPagoCapital(
      String prestamistaId, {
        required String tipo,
        required int montoCapital,
      }) async {
    // ✅ No llamar ensureStructure aquí
    // ✅ Sumar sin borrar totales anteriores

    await adjustCategoria(
      prestamistaId,
      tipo,
      capitalRecuperadoDelta: montoCapital,
      capitalPendienteDelta: -montoCapital,
    );

    // ✅ Se actualizan los totales globales sin sobrescribir
    await _summaryDoc(prestamistaId).set({
      'totalCapitalRecuperado': FieldValue.increment(montoCapital),
      'totalCapitalPendiente': FieldValue.increment(-montoCapital),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 🔹 Botón manual para eliminar capital recuperado
  static Future<void> eliminarCapitalRecuperadoManual(
      String prestamistaId,
      int monto,
      ) async {
    // ✅ Solo resta, sin tocar otros campos
    await _summaryDoc(prestamistaId).set({
      'totalCapitalRecuperado': FieldValue.increment(-monto),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 🔹 Cálculo directo de recuperación total (global)
  static Future<double> calcularRecuperacionTotal(String prestamistaId) async {
    final data = await readSummary(prestamistaId);
    if (data == null) return 0.0;

    final totalPrestado = (data['totalCapitalPrestado'] ?? 0) as int;
    final totalRecuperado = (data['totalCapitalRecuperado'] ?? 0) as int;

    if (totalPrestado <= 0) return 0.0;
    return (totalRecuperado * 100.0) / totalPrestado;
  }

  /// 🔹 Stream en vivo del porcentaje de recuperación
  static Stream<double> listenRecuperacionTotal(String prestamistaId) {
    return _summaryDoc(prestamistaId).snapshots().map((s) {
      final d = s.data();
      if (d == null) return 0.0;
      final totalPrestado = (d['totalCapitalPrestado'] ?? 0) as int;
      final totalRecuperado = (d['totalCapitalRecuperado'] ?? 0) as int;
      if (totalPrestado <= 0) return 0.0;
      return (totalRecuperado * 100.0) / totalPrestado;
    });
  }

  // ================== MÉTODOS COMPATIBLES CON LAS PANTALLAS ANTIGUAS ==================

  /// Devuelve los datos básicos de una categoría (alquiler, préstamo, producto)
  static Future<Map<String, dynamic>> headCategoria(String prestamistaId, String cat) async {
    final snap = await _db
        .collection('prestamistas')
        .doc(prestamistaId)
        .collection('estadisticas')
        .doc(cat)
        .get();
    return snap.data() ?? {};
  }

  /// Devuelve una serie mensual (para las gráficas)
  static Future<List<Map<String, dynamic>>> readSerieMensual(
      String prestamistaId,
      String cat, {
        int meses = 6,
      }) async {
    final now = DateTime.now();
    final yms = List.generate(meses, (i) {
      final d = DateTime(now.year, now.month - (meses - 1 - i), 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    final out = <Map<String, dynamic>>[];
    for (final ym in yms) {
      final snap = await _db
          .collection('prestamistas')
          .doc(prestamistaId)
          .collection('estadisticas')
          .doc(cat)
          .collection('mensual')
          .doc(ym)
          .get();
      out.add({'ym': ym, 'sum': (snap.data() ?? const {})['sum'] ?? 0});
    }
    return out;
  }

  /// 🔹 Reinicia solo las ganancias (sin tocar capital recuperado)
  static Future<void> resetGananciasTotales(String prestamistaId) async {
    // 1️⃣ Reinicia SOLO la ganancia, nunca el capital recuperado
    await _summaryDoc(prestamistaId).set({
      'totalGanancia': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 🔹 También en el documento "totales", preserva totalCapitalRecuperado
    await _db
        .collection('prestamistas')
        .doc(prestamistaId)
        .collection('estadisticas')
        .doc('totales')
        .set({
      'totalGanancia': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2️⃣ Resetear solo la ganancia por categoría, sin tocar capitalRecuperado
    for (final cat in const ['prestamo', 'producto', 'alquiler']) {
      await _catDoc(prestamistaId, cat).set({
        'gananciaNeta': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
