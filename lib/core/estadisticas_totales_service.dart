// lib/core/estadisticas_totales_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio de lectura / escritura de estadísticas:
/// - /prestamistas/{id}/metrics/(summary|evergreen)
/// - /prestamistas/{id}/stats/{prestamo|producto|alquiler}
/// - /prestamistas/{id}/stats/{cat}/mensual/{YYYY-MM}
class EstadisticasTotalesService {
  static final _db = FirebaseFirestore.instance;

  // ================== Rutas base ==================
  static DocumentReference<Map<String, dynamic>> _summaryDoc(String prestamistaId) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('metrics').doc('summary');

  static DocumentReference<Map<String, dynamic>> _evergreenDoc(String prestamistaId) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('metrics').doc('evergreen');

  static DocumentReference<Map<String, dynamic>> _catDoc(String prestamistaId, String cat) =>
      _db.collection('prestamistas').doc(prestamistaId).collection('stats').doc(cat);

  static DocumentReference<Map<String, dynamic>> _catMonthDoc(
      String prestamistaId,
      String cat,
      String ym,
      ) =>
      _catDoc(prestamistaId, cat).collection('mensual').doc(ym);

  // ================== Bootstrap seguro ==================
  /// Crea los documentos si no existen (no pisa nada).
  static Future<void> ensureStructure(String prestamistaId) async {
    // metrics
    await _summaryDoc(prestamistaId).set({
      'lifetimeRecuperado': 0,
      'lifetimeGanancia': 0,
      'lifetimePagosSum': 0,
      'lifetimePagosCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _evergreenDoc(prestamistaId).set({
      'everRecuperado': 0,
      'everGananciaInteres': 0,
      'everPagosSum': 0,
      'everPagosCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // categorías
    for (final cat in const ['prestamo', 'producto', 'alquiler']) {
      await _catDoc(prestamistaId, cat).set({
        'pendienteCobro': 0,
        'gananciaNeta': 0,
        'activos': 0,
        'finalizados': 0,
        'lifetimePagosSum': 0,
        'lifetimePagosCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ================== Summary ==================
  static Stream<Map<String, dynamic>?> listenSummary(String prestamistaId) =>
      _summaryDoc(prestamistaId).snapshots().map((s) => s.data());

  static Future<Map<String, dynamic>?> readSummary(String prestamistaId) async =>
      (await _summaryDoc(prestamistaId).get()).data();

  // ================== Categoría (CRUD mínimo) ==================
  /// cat: 'prestamo' | 'producto' | 'alquiler'
  static Stream<Map<String, dynamic>?> listenCategoria(String prestamistaId, String cat) =>
      _catDoc(prestamistaId, cat).snapshots().map((s) => s.data());

  static Future<Map<String, dynamic>?> readCategoria(String prestamistaId, String cat) async =>
      (await _catDoc(prestamistaId, cat).get()).data();

  static Future<void> ensureCategoria(String prestamistaId, String cat) async {
    await _catDoc(prestamistaId, cat).set({
      'pendienteCobro': 0,
      'gananciaNeta': 0,
      'activos': 0,
      'finalizados': 0,
      'lifetimePagosSum': 0,
      'lifetimePagosCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Aplica incrementos a campos de la categoría.
  static Future<void> adjustCategoria(
      String prestamistaId,
      String cat, {
        int? activosDelta,
        int? finalizadosDelta,
        int? pendienteCobroDelta,
        int? gananciaNetaDelta,
        int? pagosSumDelta,
        int? pagosCountDelta,
      }) async {
    await ensureCategoria(prestamistaId, cat);
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (activosDelta != null) data['activos'] = FieldValue.increment(activosDelta);
    if (finalizadosDelta != null) data['finalizados'] = FieldValue.increment(finalizadosDelta);
    if (pendienteCobroDelta != null) data['pendienteCobro'] = FieldValue.increment(pendienteCobroDelta);
    if (gananciaNetaDelta != null) data['gananciaNeta'] = FieldValue.increment(gananciaNetaDelta);
    if (pagosSumDelta != null) data['lifetimePagosSum'] = FieldValue.increment(pagosSumDelta);
    if (pagosCountDelta != null) data['lifetimePagosCount'] = FieldValue.increment(pagosCountDelta);
    await _catDoc(prestamistaId, cat).set(data, SetOptions(merge: true));
  }

  // ================== Serie mensual (para gráficas) ==================
  /// Devuelve lista [{ym, sum}] de los últimos [meses] (default 6)
  /// usando /stats/{cat}/mensual/{YYYY-MM}.
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
      final snap = await _catMonthDoc(prestamistaId, cat, ym).get();
      out.add({'ym': ym, 'sum': (snap.data() ?? const {})['sum'] ?? 0});
    }
    return out;
  }

  /// Incrementa el bucket mensual (para cuando se registra un pago).
  static Future<void> bumpMensual(
  String prestamistaId,
  String cat,
  String ym,
  int monto,
) async {
await ensureCategoria(prestamistaId, cat);
await _catMonthDoc(prestamistaId, cat, ym).set({
'sum': FieldValue.increment(monto),
'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));
}
}