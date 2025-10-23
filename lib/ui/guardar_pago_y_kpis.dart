import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mi_recibo/core/estadisticas_totales_service.dart';

/// Guarda el pago y actualiza los KPIs globales sin sobrescribir totales.
/// Versión corregida y universal (suma préstamo, producto y alquiler correctamente).
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
  // LEER CLIENTE Y DETERMINAR CATEGORÍA ROBUSTAMENTE
  // ==============================
  final cliSnap = await clienteRef.get();
  final m = cliSnap.data() ?? {};

  final texto = '${m['tipo'] ?? ''} ${m['producto'] ?? ''}'.toLowerCase();

  String categoria = 'prestamo';
  if (texto.contains('alquiler') ||
      texto.contains('renta') ||
      texto.contains('arriendo') ||
      texto.contains('casa') ||
      texto.contains('apartamento')) {
    categoria = 'alquiler';
  } else if (texto.contains('producto') ||
      texto.contains('mercancia') ||
      texto.contains('mercancía') ||
      texto.contains('articulo') ||
      texto.contains('artículo') ||
      texto.contains('venta')) {
    categoria = 'producto';
  } else if (texto.contains('prestamo') ||
      texto.contains('crédito') ||
      texto.contains('loan')) {
    categoria = 'prestamo';
  }

  // ==============================
  // GANANCIA REAL DEL PAGO
  // ==============================
  int deltaGanancia = 0;
  switch (categoria) {
    case 'prestamo':
    // Ganancia = Interés + Mora (si existe)
      deltaGanancia = pagoInteres + moraCobrada;
      break;

    case 'producto':
    // Ganancia = Mora si existe, o el interés si se aplica
      deltaGanancia = moraCobrada > 0 ? moraCobrada : pagoInteres;
      break;

    case 'alquiler':
    // Ganancia = Todo el monto pagado (ingreso total)
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
    'categoria': categoria, // 🔹 Se guarda para referencia
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
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final prestamistaId = user.uid;

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

  // 🔹 Actualiza estadísticas por categoría
  await EstadisticasTotalesService.adjustCategoria(
    prestamistaId,
    categoria,
    capitalRecuperadoDelta: pagoCapital,
    capitalPendienteDelta: -pagoCapital,
    gananciaNetaDelta: deltaGanancia,
  );

  // 🔹 (Opcional) Registrar log global del pago
  await FirebaseFirestore.instance
      .collection('prestamistas')
      .doc(prestamistaId)
      .collection('historial_pagos')
      .add({
    'categoria': categoria,
    'clienteId': clienteRef.id,
    'pagoCapital': pagoCapital,
    'pagoInteres': pagoInteres,
    'moraCobrada': moraCobrada,
    'totalPagado': totalPagado,
    'fecha': FieldValue.serverTimestamp(),
    'ganancia': deltaGanancia,
  });
}
