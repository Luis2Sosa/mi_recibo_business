import 'package:cloud_firestore/cloud_firestore.dart';

class EstadisticasTotalesService {
  static final _db = FirebaseFirestore.instance;

  /// /prestamistas/{prestamistaId}/estadisticas/totales
  static DocumentReference<Map<String, dynamic>> _doc(String prestamistaId) {
    return _db
        .collection('prestamistas')
        .doc(prestamistaId)
        .collection('estadisticas')
        .doc('totales');
  }

  /// Asegura que exista el doc con valores por defecto (no pisa nada).
  static Future<void> ensureExists(String prestamistaId) async {
    await _doc(prestamistaId).set({
      'totalRecuperado': 0,
      'totalPendiente': 0,
      'totalPrestado': 0,
    }, SetOptions(merge: true));
  }

  // -------------------------------
  //  TOTAL RECUPERADO (PERSISTENTE)
  // -------------------------------
  static Future<void> aumentarRecuperado(String prestamistaId, num monto) async {
    await ensureExists(prestamistaId);
    await _doc(prestamistaId).update({
      'totalRecuperado': FieldValue.increment(monto),
    });
  }

  static Future<void> disminuirRecuperado(String prestamistaId, num monto) async {
    await ensureExists(prestamistaId);
    await _doc(prestamistaId).update({
      'totalRecuperado': FieldValue.increment(-monto),
    });
  }

  static Future<void> aumentarPrestado(String prestamistaId, num monto) async {
    await ensureExists(prestamistaId);
    await _doc(prestamistaId).update({
      'totalPrestado': FieldValue.increment(monto),
    });
  }

  static Future<void> ajustarPendiente(String prestamistaId, num delta) async {
    await ensureExists(prestamistaId);
    await _doc(prestamistaId).update({
      'totalPendiente': FieldValue.increment(delta),
    });
  }

  static Stream<Map<String, dynamic>?> escucharTotales(String prestamistaId) {
    return _doc(prestamistaId)
        .snapshots()
        .map((snap) => snap.data());
  }

  static Future<Map<String, dynamic>?> leerTotales(String prestamistaId) async {
    final s = await _doc(prestamistaId).get();
    return s.data();
  }
}