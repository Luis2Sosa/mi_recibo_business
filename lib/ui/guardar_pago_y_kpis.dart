// lib/ui/widgets/guardar_pago_y_kpis.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Guarda el pago y actualiza los totales reales en:
/// prestamistas/{id}/estadisticas/totales
Future<void> guardarPagoYActualizarKPIs({
  required DocumentReference<Map<String, dynamic>> docPrest,
  required DocumentReference<Map<String, dynamic>> clienteRef,
  required int pagoCapital,
  required int pagoInteres,
  required int totalPagado,
  required int moraCobrada,
  required int saldoAnterior,
  required DateTime proximaFecha,
}) async {
  int saldoNuevo = saldoAnterior - pagoCapital;
  if (saldoNuevo < 0) saldoNuevo = 0;

  // ==============================
  // LEER CLIENTE Y DETERMINAR CATEGORÍA
  // ==============================
  final cliSnap = await clienteRef.get();
  final m = cliSnap.data() ?? {};

  final prodTxt = (m['producto'] ?? '').toString().toLowerCase().trim();
  final tipoTxt = (m['tipo'] ?? '').toString().toLowerCase().trim();

  // Clasificación más precisa por prioridad:
  // 1. Si menciona "alquiler" o "renta" → alquiler
  // 2. Si menciona "producto" o el tipo está vacío → producto
  // 3. Si menciona "prestamo" → préstamo
  String categoria = 'prestamo';
  if (prodTxt.contains('alquiler') || prodTxt.contains('renta') || tipoTxt.contains('alquiler')) {
    categoria = 'alquiler';
  } else if (prodTxt.contains('producto') || tipoTxt.contains('producto') || tipoTxt.isEmpty) {
    categoria = 'producto';
  } else if (prodTxt.contains('prestamo') || tipoTxt.contains('prestamo')) {
    categoria = 'prestamo';
  }

  // ==============================
  // GANANCIA REAL DEL PAGO
  // ==============================
  // En préstamos: solo interés + mora
  // En productos: futura ganancia
  // En alquiler: todo el pago cuenta como ganancia
  int deltaGanancia = 0;
  switch (categoria) {
    case 'prestamo':
      deltaGanancia = pagoInteres + moraCobrada;
      break;
    case 'producto':
      deltaGanancia = moraCobrada > 0 ? moraCobrada : pagoInteres;
      break;
    case 'alquiler':
      deltaGanancia = totalPagado;
      break;
  }

  if (deltaGanancia < 0) deltaGanancia = 0;

  // ==============================
  // GUARDAR PAGO Y ACTUALIZAR CLIENTE
  // ==============================
  final batch = FirebaseFirestore.instance.batch();

  // 1️⃣ Registrar el pago dentro del cliente
  final pagosRef = clienteRef.collection('pagos').doc();
  batch.set(pagosRef, {
    'fecha': FieldValue.serverTimestamp(),
    'pagoInteres': pagoInteres,
    'pagoCapital': pagoCapital,
    'moraCobrada': moraCobrada,
    'totalPagado': totalPagado,
    'saldoAnterior': saldoAnterior,
    'saldoNuevo': saldoNuevo,
  });

  // 2️⃣ Actualizar cliente
  batch.set(clienteRef, {
    'saldoActual': saldoNuevo,
    'proximaFecha': Timestamp.fromDate(proximaFecha),
    'updatedAt': FieldValue.serverTimestamp(),
    'saldado': saldoNuevo <= 0,
    'estado': saldoNuevo <= 0 ? 'saldado' : 'al_dia',
  }, SetOptions(merge: true));

  await batch.commit();

  // ==============================
  // ACTUALIZAR ESTADÍSTICAS GLOBALES (Firestore)
  // ==============================
  final totalesRef = docPrest.collection('estadisticas').doc('totales');

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final snap = await tx.get(totalesRef);
    final data = snap.data() ?? {};

    // Leer totales actuales (con fallback 0)
    int totalPendiente = (data['totalPendiente'] ?? 0) as int;
    int totalPrestado = (data['totalPrestado'] ?? 0) as int;
    int totalRecuperado = (data['totalRecuperado'] ?? 0) as int;
    int gananciaPrestamo = (data['gananciaPrestamo'] ?? 0) as int;
    int gananciaProducto = (data['gananciaProducto'] ?? 0) as int;
    int gananciaAlquiler = (data['gananciaAlquiler'] ?? 0) as int;

    // ======================
    // ACTUALIZAR KPIs GLOBALES
    // ======================
    // Capital recuperado (solo capital)
    totalRecuperado += pagoCapital;

    // Capital pendiente (disminuye)
    totalPendiente -= pagoCapital;
    if (totalPendiente < 0) totalPendiente = 0;

    // Actualizar la ganancia según categoría
    switch (categoria) {
      case 'prestamo':
        gananciaPrestamo += deltaGanancia;
        break;
      case 'producto':
        gananciaProducto += deltaGanancia;
        break;
      case 'alquiler':
        gananciaAlquiler += deltaGanancia;
        break;
    }

    tx.set(totalesRef, {
      'totalPendiente': totalPendiente,
      'totalPrestado': totalPrestado,
      'totalRecuperado': totalRecuperado,
      'gananciaPrestamo': gananciaPrestamo,
      'gananciaProducto': gananciaProducto,
      'gananciaAlquiler': gananciaAlquiler,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });

  // ==============================
  // ACTUALIZAR ESTADÍSTICAS DE ALQUILER (si aplica)
  // ==============================
  if (categoria == 'alquiler') {
    final alquilerRef = docPrest.collection('estadisticas').doc('alquiler');
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(alquilerRef);
      final data = snap.data() ?? {};
      int activos = (data['activos'] ?? 0) as int;
      int pendienteCobro = (data['pendienteCobro'] ?? 0) as int;
      int ganancia = (data['ganancia'] ?? 0) as int;

      pendienteCobro -= pagoCapital;
      if (pendienteCobro < 0) pendienteCobro = 0;
      ganancia += totalPagado;

      tx.set(alquilerRef, {
        'activos': activos,
        'pendienteCobro': pendienteCobro,
        'ganancia': ganancia,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}