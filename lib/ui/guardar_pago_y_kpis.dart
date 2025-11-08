// lib/core/guardar_pago_y_actualizar_kpis.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mi_recibo/core/estadisticas_totales_service.dart';
import 'package:intl/intl.dart';


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
  try {
    int saldoNuevo = saldoAnterior - pagoCapital;
    if (saldoNuevo < 0) saldoNuevo = 0;

    // ==============================
    // 🔹 LEER CLIENTE Y DETERMINAR CATEGORÍA
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
    }

    // ==============================
    // 🔹 CALCULAR GANANCIA DEL PAGO
    // ==============================
    int deltaGanancia = 0;

    if (categoria == 'prestamo') {
      deltaGanancia = pagoInteres + moraCobrada;
    } else if (categoria == 'alquiler') {
      deltaGanancia = totalPagado;
    } else if (categoria == 'producto') {
      final gananciaTotal = (m['gananciaTotal'] ?? 0) as int;
      final capitalInicial = (m['capitalInicial'] ?? 1) as int;

      if (gananciaTotal > 0 && capitalInicial > 0) {
        if (saldoNuevo <= 0) {
          // ✅ Producto completamente pagado → registrar ganancia total
          deltaGanancia = gananciaTotal;
        } else {
          // 📉 Pago parcial → registrar ganancia proporcional
          final pagado = saldoAnterior - saldoNuevo;
          deltaGanancia = ((gananciaTotal * pagado) / capitalInicial).round();
        }
      }
    }

    if (deltaGanancia < 0) deltaGanancia = 0;

    // ==============================
    // 🔹 GUARDAR EL PAGO Y ACTUALIZAR CLIENTE
    // ==============================
    final batch = FirebaseFirestore.instance.batch();

    final pagosRef = clienteRef.collection('pagos').doc();
    batch.set(pagosRef, {
      'fecha': Timestamp.fromDate(DateTime.now()), // ✅ fecha real
      'fechaTexto': DateFormat("dd/MM/yyyy").format(DateTime.now()), // legible
      'pagoInteres': pagoInteres,
      'pagoCapital': pagoCapital,
      'moraCobrada': moraCobrada,
      'totalPagado': totalPagado,
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': saldoNuevo,
      'categoria': categoria,
      'gananciaPago': deltaGanancia,
    });


    batch.set(clienteRef, {
      'saldoActual': saldoNuevo,
      'proximaFecha': Timestamp.fromDate(proximaFecha),
      'updatedAt': FieldValue.serverTimestamp(),
      'estado': saldoNuevo <= 0 ? 'saldado' : 'al_dia',
    }, SetOptions(merge: true));

    await batch.commit();

    // ✅ Guardar fecha del primer pago solo si el cliente aún no la tiene
    final clienteSnapshot = await clienteRef.get();
    final clienteData = clienteSnapshot.data() ?? {};
    if (clienteData['primerPago'] == null) {
      await clienteRef.set({
        'primerPago': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    }


    // ==============================
    // 🔹 REFERENCIAS GENERALES
    // ==============================
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prestamistaId = user.uid;
    final db = FirebaseFirestore.instance;

    final summaryRef = db
        .collection('prestamistas')
        .doc(prestamistaId)
        .collection('metrics')
        .doc('summary');

    // ==============================
    // 🔹 ACTUALIZAR ESTADÍSTICAS NORMALES
    // ==============================
    await EstadisticasTotalesService.ensureStructure(prestamistaId);

    await summaryRef.set({
      'totalCapitalRecuperado': FieldValue.increment(pagoCapital),
      'totalCapitalPendiente': FieldValue.increment(-pagoCapital),
      'totalGanancia': FieldValue.increment(deltaGanancia),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await EstadisticasTotalesService.adjustCategoria(
      prestamistaId,
      categoria,
      capitalRecuperadoDelta: pagoCapital,
      capitalPendienteDelta: -pagoCapital,
      gananciaNetaDelta: deltaGanancia,
    );

    // ==============================
// 🔹 SUMAR AUTOMÁTICAMENTE TOTAL ALQUILADO (cada pago cuenta)
// ==============================
    if (categoria == 'alquiler') {
      try {
        await summaryRef.set({
          'totalCapitalAlquilado': FieldValue.increment(totalPagado * 1.0),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('💰 Total alquilado incrementado +$totalPagado correctamente');
      } catch (e) {
        print('⚠️ Error al actualizar totalCapitalAlquilado: $e');
      }
    }


    // ==============================
    // 🔹 SI EL PRODUCTO SE SALDÓ → REGISTRAR GANANCIA TOTAL HISTÓRICA
    // ==============================
    if (categoria == 'producto' && saldoNuevo <= 0) {
      final gananciaTotal = (m['gananciaTotal'] ?? 0) as int;
      final capitalTotal = (m['capitalInicial'] ?? 0) as int;

      if (gananciaTotal > 0) {
        // 📈 Actualiza métricas globales
        await summaryRef.set({
          'totalGanancia': FieldValue.increment(gananciaTotal),
          'totalCapitalRecuperado': FieldValue.increment(capitalTotal),
          'totalCapitalPendiente': FieldValue.increment(-capitalTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 📊 Actualiza categoría "producto"
        final estadisticaProducto = db
            .collection('prestamistas')
            .doc(prestamistaId)
            .collection('estadisticas')
            .doc('producto');

        await estadisticaProducto.set({
          'gananciaNeta': FieldValue.increment(gananciaTotal),
          'capitalRecuperado': FieldValue.increment(capitalTotal),
          'capitalPendiente': FieldValue.increment(-capitalTotal),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // 🧾 Registrar evento en historial
        await db
            .collection('prestamistas')
            .doc(prestamistaId)
            .collection('historial_pagos')
            .add({
          'categoria': 'producto',
          'clienteId': clienteRef.id,
          'pagoCapital': capitalTotal,
          'pagoInteres': pagoInteres,
          'moraCobrada': moraCobrada,
          'totalPagado': totalPagado,
          'fecha': Timestamp.fromDate(DateTime.now()), // ✅ guarda la fecha real del pago
          'fechaTexto': DateFormat("dd/MM/yyyy 'a las' hh:mm a").format(DateTime.now()), // 🧠 texto legible para mostrar

          'ganancia': gananciaTotal,
          'nota': 'Producto saldado — ganancia total registrada',
        });

        print('✅ Ganancia total registrada correctamente en "producto".');
      }
    }

    print('✅ KPI actualizado: $categoria (+$deltaGanancia ganancia)');
  } catch (e) {
    print('⚠️ Error en guardarPagoYActualizarKPIs: $e');
  }
}
