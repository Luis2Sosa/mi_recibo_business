import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/core/estadisticas_totales_service.dart';

/// Guarda el pago y actualiza los KPIs globales sin sobrescribir totales.
/// Versión corregida y universal (suma préstamo, producto y alquiler).
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

  String categoria = 'prestamo';
  if (prodTxt.contains('alquiler') || prodTxt.contains('renta') ||
      tipoTxt.contains('alquiler')) {
    categoria = 'alquiler';
  } else if (prodTxt.contains('producto') || tipoTxt.contains('producto') ||
      tipoTxt.isEmpty) {
    categoria = 'producto';
  } else if (prodTxt.contains('prestamo') || tipoTxt.contains('prestamo')) {
    categoria = 'prestamo';
  }

  // ==============================
  // GANANCIA REAL DEL PAGO
  // ==============================
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
// ACTUALIZAR ESTADÍSTICAS GLOBALES (corregido y universal)
// ==============================
  final prestamistaId = docPrest.id;
  final summaryRef = FirebaseFirestore.instance
      .collection('prestamistas')
      .doc(prestamistaId)
      .collection('metrics')
      .doc('summary');

// 🔹 Asegura estructura base
  await EstadisticasTotalesService.ensureStructure(prestamistaId);

// 🔹 Actualiza totales globales sumando sin borrar datos previos
  await summaryRef.set({
    'totalCapitalRecuperado': FieldValue.increment(pagoCapital),
    'totalCapitalPendiente': FieldValue.increment(-pagoCapital),
    'totalGanancia': FieldValue.increment(deltaGanancia),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

// 🔹 Actualiza estadísticas por categoría (prestamo, producto o alquiler)
  await EstadisticasTotalesService.adjustCategoria(
    prestamistaId,
    categoria,
    capitalRecuperadoDelta: pagoCapital,
    capitalPendienteDelta: -pagoCapital,
    gananciaNetaDelta: deltaGanancia,
  );
}

