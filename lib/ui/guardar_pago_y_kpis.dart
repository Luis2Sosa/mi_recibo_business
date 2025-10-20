// lib/ui/widgets/guardar_pago_y_kpis.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Guarda el pago, actualiza el cliente y los KPIs (globales y por categoría).
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

  // Leemos el cliente para detectar categoría (prestamo / producto / alquiler)
  final cliSnap = await clienteRef.get();
  final m = cliSnap.data() ?? {};
  final tipoRaw = (m['tipo'] ?? '').toString().toLowerCase().trim();
  final prodTxt  = (m['producto'] ?? '').toString().toLowerCase().trim();

  final bool esAlquiler = tipoRaw == 'alquiler' || prodTxt.contains('alquiler') || prodTxt.contains('renta');
  final bool esProducto = !esAlquiler && (tipoRaw == 'producto' || tipoRaw == 'fiado' || prodTxt.isNotEmpty);
  final bool esPrestamo = !esAlquiler && !esProducto; // por descarte
  final String cat = esAlquiler ? 'alquiler' : (esProducto ? 'producto' : 'prestamo');

  // Ganancia incremental: intereses; si no hubo, usa fallback aprox (no negativo)
  int deltaGanancia = pagoInteres > 0 ? pagoInteres : (totalPagado - pagoCapital);
  if (deltaGanancia < 0) deltaGanancia = 0;

  final now = DateTime.now();
  final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final batch = FirebaseFirestore.instance.batch();

  // 1) Registrar el pago en subcolección del cliente
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

  // 2) Actualizar campos del cliente
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

  // 3) KPIs globales (resumen)
  final metricsRef = docPrest.collection('metrics').doc('summary');
  batch.set(
    metricsRef,
    {
      'lifetimeRecuperado': FieldValue.increment(pagoCapital),
      'lifetimeGanancia': FieldValue.increment(deltaGanancia), // usamos deltaGanancia para ser consistente
      'lifetimePagosSum': FieldValue.increment(totalPagado),
      'lifetimePagosCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  // 3.1) Contadores permanentes
  final evergreenRef = docPrest.collection('metrics').doc('evergreen');
  batch.set(
    evergreenRef,
    {
      'everRecuperado': FieldValue.increment(pagoCapital),
      'everGananciaInteres': FieldValue.increment(pagoInteres),
      'everPagosSum': FieldValue.increment(totalPagado),
      'everPagosCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  // 4) KPIs POR CATEGORÍA (alquiler / prestamo / producto)
  final catRef = docPrest.collection('stats').doc(cat);
  batch.set(
    catRef,
    {
      // pendienteCobro baja con el capital cobrado de ese cliente
      'pendienteCobro': FieldValue.increment(-pagoCapital),
      // gananciaNeta suma intereses o fallback si no hubo
      'gananciaNeta': FieldValue.increment(deltaGanancia),
      // acumulados
      'lifetimePagosSum': FieldValue.increment(totalPagado),
      'lifetimePagosCount': FieldValue.increment(1),
      // cambios de estado
      if (saldoAnterior > 0 && saldoNuevo <= 0) 'activos': FieldValue.increment(-1),
      if (saldoAnterior > 0 && saldoNuevo <= 0) 'finalizados': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  // 4.1) Bucket mensual para gráficas: stats/{cat}/mensual/YYYY-MM
  final monthRef = catRef.collection('mensual').doc(monthKey);
  batch.set(
    monthRef,
    {
      'sum': FieldValue.increment(totalPagado),
      'updatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );

  await batch.commit();
}