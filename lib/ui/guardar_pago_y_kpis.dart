import 'package:cloud_firestore/cloud_firestore.dart';

/// Guarda el pago, actualiza el cliente y los KPIs de resumen.
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

  final batch = FirebaseFirestore.instance.batch();

  // 1️⃣ Registrar el pago
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
  final venceTs = saldoNuevo <= 0 ? null : Timestamp.fromDate(proximaFecha);

  batch.set(
    clienteRef,
    {
      'saldoActual': saldoNuevo,
      'proximaFecha': Timestamp.fromDate(proximaFecha),
      'updatedAt': FieldValue.serverTimestamp(),
      'saldado': saldoNuevo <= 0,
      'estado': saldoNuevo <= 0 ? 'saldado' : 'al_dia',
      if (venceTs == null) 'venceEl': FieldValue.delete() else 'venceEl': venceTs,
    },
    SetOptions(merge: true),
  );

  // 3️⃣ Actualizar KPIs globales
  final metricsRef = docPrest.collection('metrics').doc('summary');
  batch.set(
    metricsRef,
    {
      'lifetimeRecuperado': FieldValue.increment(pagoCapital),
      'lifetimeGanancia': FieldValue.increment(pagoInteres),
      'lifetimePagosSum': FieldValue.increment(totalPagado),
      'lifetimePagosCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  await batch.commit();
}
