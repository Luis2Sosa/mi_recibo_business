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
    // Calcular abono real al capital (resta interés y mora si corresponde)
    int abonoReal = totalPagado - pagoInteres - moraCobrada;
    if (abonoReal < 0) abonoReal = 0;

    // Nuevo saldo basado solo en el abono real
    int saldoNuevo = saldoAnterior - abonoReal;
    if (saldoNuevo < 0) saldoNuevo = 0;

    // ==============================
    // LEER CLIENTE Y DETERMINAR CATEGORÍA
    // ==============================
    final cliSnap = await clienteRef.get();
    final m = cliSnap.data() ?? {};

    // FIX Bug 1: detectar categoría por campo 'tipo' primero (fuente de verdad),
    // luego por el texto del producto como fallback.
    // Antes solo se usaba texto libre y nombres como "bolso", "ropa", "telefono"
    // nunca hacían match → todo caía en 'prestamo' → ganancias de producto = $0.
    String categoria = 'prestamo'; // default

    final tipoDirecto = (m['tipo'] ?? '').toString().toLowerCase().trim();

    if (tipoDirecto == 'producto' ||
        tipoDirecto == 'fiado' ||
        tipoDirecto == 'mercancia' ||
        tipoDirecto == 'venta') {
      categoria = 'producto';
    } else if (tipoDirecto == 'alquiler' ||
        tipoDirecto == 'arriendo' ||
        tipoDirecto == 'renta') {
      categoria = 'alquiler';
    } else {
      // Fallback: buscar en texto combinado
      final texto =
      '${m['tipo'] ?? ''} ${m['producto'] ?? ''}'.toLowerCase();

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
          texto.contains('venta') ||
          texto.contains('fiado')) {
        categoria = 'producto';
      }
      // si no hace match → queda 'prestamo'
    }

    // ==============================
    // CALCULAR GANANCIA DEL PAGO
    // ==============================
    int deltaGanancia = 0;

    if (categoria == 'prestamo') {
      deltaGanancia = pagoInteres + moraCobrada;
    } else if (categoria == 'alquiler') {
      deltaGanancia = totalPagado;
    } else if (categoria == 'producto') {
      // Ganancia de producto se consolida al saldar (ver bloque final).
      deltaGanancia = 0;
    }

    if (deltaGanancia < 0) deltaGanancia = 0;

    // ==============================
    // FIX Bug 2: acumular gananciaTotal en el cliente pago a pago
    // Antes 'gananciaTotal' nunca se escribía durante pagos intermedios,
    // entonces al saldar siempre encontraba 0 → ganancia registrada = $0.
    // Ahora calculamos el excedente de cada pago y lo acumulamos.
    // ==============================
    if (categoria == 'producto') {
      final capitalInicial =
      ((m['capitalInicial'] ?? 0) as num).toInt();
      final montoTotal =
      ((m['productoMontoTotal'] ?? m['montoTotal'] ?? 0) as num).toInt();

      int gananciaEstePago = 0;

      if (montoTotal > 0 && capitalInicial > 0 && montoTotal > capitalInicial) {
        // Ganancia proporcional: del total pagado, qué porcentaje es excedente
        final excedente = montoTotal - capitalInicial;
        gananciaEstePago =
            ((totalPagado * excedente) / montoTotal).round();
      } else {
        // Fallback: solo mora cobrada cuenta como ganancia
        gananciaEstePago = moraCobrada;
      }

      if (gananciaEstePago > 0) {
        await clienteRef.set({
          'gananciaTotal': FieldValue.increment(gananciaEstePago),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    // ==============================
    // GUARDAR EL PAGO Y ACTUALIZAR CLIENTE
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
    // REGISTRAR FECHA DEL PRIMER PAGO
    // ==============================
    final clienteSnapshot = await clienteRef.get();
    final clienteData = clienteSnapshot.data() ?? {};
    if (clienteData['primerPago'] == null) {
      await clienteRef.set({
        'primerPago': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
    }

    // ==============================
    // REFERENCIAS GENERALES
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
    // ACTUALIZAR ESTADÍSTICAS NORMALES
    // ==============================
    await EstadisticasTotalesService.ensureStructure(prestamistaId);

    if (categoria == 'producto') {
      final capitalInicial =
      ((m['capitalInicial'] ?? 0) as num).toInt();
      final montoTotal =
      ((m['productoMontoTotal'] ?? m['montoTotal'] ?? 0) as num).toInt();

      final pagado = saldoAnterior - saldoNuevo;
      final capitalPagado = montoTotal > 0
          ? ((pagado * capitalInicial) / montoTotal).round()
          : pagado;

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
        gananciaNetaDelta: 0,
      );
    } else {
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
    // SUMAR AUTOMÁTICAMENTE TOTAL ALQUILADO
    // ==============================
    if (categoria == 'alquiler') {
      try {
        await summaryRef.set({
          'totalCapitalAlquilado': FieldValue.increment(totalPagado * 1.0),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        print('⚠️ Error al actualizar totalCapitalAlquilado: $e');
      }
    }

    // ==============================
    // REGISTRAR HISTORIAL GLOBAL
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
      'fechaTexto':
      DateFormat("dd/MM/yyyy 'a las' hh:mm a").format(DateTime.now()),
      'nota': categoria == 'producto' && saldoNuevo <= 0
          ? 'Producto saldado — ganancia total registrada'
          : 'Pago registrado correctamente',
    });

    // ==============================
    // PRODUCTO SALDADO → GANANCIA TOTAL FINAL
    // Guard contra doble escritura via flag 'gananciaRegistrada'
    // ==============================
    if (categoria == 'producto' && saldoNuevo <= 0) {
      final clienteFinal = await clienteRef.get();
      final dataFinal = clienteFinal.data() ?? {};

      final gananciaYaRegistrada = dataFinal['gananciaRegistrada'] == true;

      if (!gananciaYaRegistrada) {
        // FIX Bug 2: ahora tiene valor real acumulado pago a pago
        final gananciaTotal =
        ((dataFinal['gananciaTotal'] ?? 0) as num).toInt();

        // Marcar primero para evitar duplicados en retry de red
        await clienteRef.set({
          'gananciaRegistrada': true,
        }, SetOptions(merge: true));

        if (gananciaTotal > 0) {
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

          print(
              '✅ Producto saldado — ganancia total registrada (\$$gananciaTotal).');
        } else {
          print(
              'ℹ️ Producto saldado — gananciaTotal era 0, nada que registrar.');
        }
      } else {
        print(
            'ℹ️ Producto saldado — ganancia ya registrada, se omite duplicado.');
      }
    }

    print('✅ KPI actualizado: $categoria (+$deltaGanancia ganancia)');
  } catch (e) {
    print('⚠️ Error en guardarPagoYActualizarKPIs: $e');
  }
}