// 📘 Archivo: lib/core/guardar_pago_y_actualizar_kpis.dart
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

    // ✅ Calcular abono real al capital (resta interés y mora si corresponde)
    int abonoReal = totalPagado - pagoInteres - moraCobrada;
    if (abonoReal < 0) abonoReal = 0;

// ✅ Nuevo saldo basado solo en el abono real
    int saldoNuevo = saldoAnterior - abonoReal;
    if (saldoNuevo < 0) saldoNuevo = 0;

    // .,



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
      // ⚠️ No sumar ganancia durante los pagos
      // porque ya fue registrada al crear el cliente.
      deltaGanancia = 0;
    }


    if (deltaGanancia < 0) deltaGanancia = 0;

    // ==============================
    // 🔹 GUARDAR EL PAGO Y ACTUALIZAR CLIENTE
    // ==============================
    final batch = FirebaseFirestore.instance.batch();

    final pagosRef = clienteRef.collection('pagos').doc();
    batch.set(pagosRef, {
      'fecha': Timestamp.fromDate(DateTime.now()),
      'fechaTexto': DateFormat("dd/MM/yyyy").format(DateTime.now()),
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

    // ==============================
    // 🔹 REGISTRAR FECHA DEL PRIMER PAGO
    // ==============================
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

    // ✅ Actualizar estadísticas NORMALES (ajustadas según categoría)
    if (categoria == 'producto') {
      // Solo sumar la parte real del capital recuperado (no ganancia)
      final capitalInicial = (m['capitalInicial'] ?? 0) as int;
      final montoTotal = (m['montoTotal'] ?? 0) as int;

      // Calcular proporción del capital que se está recuperando en este pago
      final pagado = saldoAnterior - saldoNuevo;
      final capitalPagado = ((pagado * capitalInicial) / montoTotal).round();

      await summaryRef.set({
        'totalCapitalRecuperado': FieldValue.increment(capitalPagado),
        'totalCapitalPendiente': FieldValue.increment(-capitalPagado),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await EstadisticasTotalesService.adjustCategoria(
        prestamistaId,
        categoria,
        capitalRecuperadoDelta: capitalPagado,
        capitalPendienteDelta: -capitalPagado,
        gananciaNetaDelta: 0, // no se suma ganancia todavía
      );
    } else {
      // Resto de categorías normales (préstamos, alquileres)
      await summaryRef.set({
        'totalCapitalRecuperado': FieldValue.increment(abonoReal),
        'totalCapitalPendiente': FieldValue.increment(-abonoReal),
        'totalGanancia': FieldValue.increment(deltaGanancia),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await EstadisticasTotalesService.adjustCategoria(
        prestamistaId,
        categoria,
        capitalRecuperadoDelta: abonoReal,
        capitalPendienteDelta: -abonoReal,
        gananciaNetaDelta: deltaGanancia,
      );
    }



    // ==============================
    // 🔹 SUMAR AUTOMÁTICAMENTE TOTAL ALQUILADO
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
    // 🔹 REGISTRAR HISTORIAL GLOBAL (para TODAS las categorías)
    // ==============================
    await db
        .collection('prestamistas')
        .doc(prestamistaId)
        .collection('historial_pagos')
        .add({
      'saldoAnterior': saldoAnterior,
      'saldoNuevo': saldoNuevo,
      'categoria': categoria,
      'clienteId': clienteRef.id,
      'pagoCapital': pagoCapital,
      'pagoInteres': pagoInteres,
      'moraCobrada': moraCobrada,
      'totalPagado': totalPagado,
      'ganancia': deltaGanancia,
      'fecha': Timestamp.fromDate(DateTime.now()),
      'fechaTexto': DateFormat("dd/MM/yyyy 'a las' hh:mm a").format(DateTime.now()),
      'nota': categoria == 'producto' && saldoNuevo <= 0
          ? 'Producto saldado — ganancia total registrada'
          : 'Pago registrado correctamente',
    });

    print('✅ Historial global actualizado correctamente');

    // ==============================
    // 🔹 PRODUCTO SALDADO → GANANCIA TOTAL FINAL
    // ==============================
    if (categoria == 'producto' && saldoNuevo <= 0) {
      final gananciaTotal = (m['gananciaTotal'] ?? 0) as int;

      // ✅ Solo sumar la ganancia final del producto
      await summaryRef.set({
        'totalGanancia': FieldValue.increment(gananciaTotal),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await db
          .collection('prestamistas')
          .doc(prestamistaId)
          .collection('estadisticas')
          .doc('producto')
          .set({
        'gananciaNeta': FieldValue.increment(gananciaTotal),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Producto saldado — ganancia total registrada ($gananciaTotal).');
    }



    print('✅ KPI actualizado: $categoria (+$deltaGanancia ganancia)');
  } catch (e) {
    print('⚠️ Error en guardarPagoYActualizarKPIs: $e');
  }
}
