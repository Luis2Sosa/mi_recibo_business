import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';      // 👈 UID
import 'package:intl/intl.dart';                        // 👈 Formato moneda pro
import 'pago_form_screen.dart';
import 'recibo_screen.dart';
import 'historial_screen.dart';
import 'widgets/app_frame.dart'; // <-- ruta desde lib/ui/

// 🚀 Notificaciones Plus
import '../core/notifications_plus.dart';
// 📲 Envíos por WhatsApp (Bloque 3)
import 'package:url_launcher/url_launcher.dart';
import 'guardar_pago_y_kpis.dart';



class ClienteDetalleScreen extends StatefulWidget {
  // --------- Datos del cliente ---------
  final String id;
  final String codigo;
  final String nombreCompleto;
  final String telefono;
  final String? direccion;
  final int saldoActual;
  final double tasaInteres;
  final String periodo;
  final DateTime proximaFecha;
  final String producto;
  final String? tipoProducto;   // 'vehiculo' | 'otro'
  final String? vehiculoTipo;   // 'carro' | 'guagua' | 'moto'


  // --------- Datos del prestamista ---------
  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final int moraAcumulada; // 👈 mora unificada desde Cliente


  const ClienteDetalleScreen({
    super.key,
    required this.id,
    required this.codigo,
    required this.nombreCompleto,
    required this.telefono,
    this.direccion,
    required this.saldoActual,
    required this.tasaInteres,
    required this.periodo,
    required this.proximaFecha,
    required this.empresa,
    required this.servidor,
    required this.telefonoServidor,
    required this.producto,
    this.tipoProducto,
    this.vehiculoTipo,

    required this.moraAcumulada, // 👈 NUEVO

  });

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  // ✅ Icono de WhatsApp reutilizable (usa el PNG de assets)
  Widget _waIcon({double size = 24}) {
    return Image.asset(
      'assets/images/logo_whatsapp.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  static const double _logoHeight = 310;
  static const double _logoTop = -80;
  static const double _contentTop = 110;

  late int _saldoActual;
  late DateTime _proximaFecha;
  bool _tieneCambios = false;
  int _totalPrestado = 0;
  bool _btnPagoBusy = false;
  bool _autoFecha = true; // 👈 NUEVO: por defecto automático
  // ✅ Mora acumulada offline (calculada aquí)
  late int _moraAcumulada; // 👈 NUEVO
  // 👇 Pago inicial (solo para productos)
  int _pagoInicial = 0;


  // Es PRÉSTAMO solo si el campo producto está vacío
  // o si explícitamente contiene palabras de préstamo.
  bool get _esPrestamo {
    final p = widget.producto.trim().toLowerCase();
    if (p.isEmpty) return true; // vacío = préstamo normal
    return p.contains('prest') || p.contains('crédito') || p.contains('credito') || p.contains('loan');
  }

  // ✅ Nota opcional (leída de Firestore SIN tocar el constructor)
  String? _nota;

  bool get _estaSaldado => _saldoActual <= 0;

  IconData _iconoProducto() {
    final p    = (widget.producto).toLowerCase().trim();
    final tipo = (widget.tipoProducto ?? '').toLowerCase();
    final veh  = (widget.vehiculoTipo ?? '').toLowerCase();

    // 1) Si es alquiler de inmueble → casa
    final esInmueble = p.contains('alquiler') ||
        p.contains('arriendo') ||
        p.contains('renta') ||
        p.contains('casa') ||
        p.contains('apart');
    if (esInmueble) return Icons.house_rounded;

    // 2) Si marcaste que es vehículo, respeta el tipo
    if (tipo == 'vehiculo') {
      if (veh == 'carro' || veh == 'auto' || veh == 'vehiculo') {
        return Icons.directions_car_filled_rounded;
      }
      if (veh == 'guagua' || veh == 'bus' || veh == 'minibus') {
        return Icons.directions_bus_filled_rounded;
      }
      if (veh == 'moto' || veh == 'motor') {
        return Icons.two_wheeler_rounded;
      }
    }

    // 3) Fallback por texto (por si no llegaron los campos)
    if (p.contains('carro') || p.contains('auto') || p.contains('vehí')) {
      return Icons.directions_car_filled_rounded;
    }
    if (p.contains('guagua') || p.contains('bus') || p.contains('mini')) {
      return Icons.directions_bus_filled_rounded;
    }
    if (p.contains('moto') || p.contains('motor')) {
      return Icons.two_wheeler_rounded;
    }

    // 4) Otro producto → bolsita
    return Icons.shopping_bag_rounded;
  }


  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _proximaFecha = widget.proximaFecha;
    _moraAcumulada = (widget.moraAcumulada > 0) ? widget.moraAcumulada : _calcMoraAcumulada();
    Future.microtask(_autoFixEstado);
    Future.microtask(_cargarTotalPrestado);
    Future.microtask(_cargarNota); // <-- lee 'nota' si existe
    Future.microtask(_cargarFlags); // 👈 NUEVO: lee autoFecha del cliente
    Future.microtask(_cargarPagoInicial);


  }

  @override
  void didUpdateWidget(covariant ClienteDetalleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambian fecha o saldo provenientes del widget, sincroniza y recalcula mora
    if (oldWidget.proximaFecha != widget.proximaFecha ||
        oldWidget.saldoActual != widget.saldoActual) {
      _proximaFecha = widget.proximaFecha;
      _saldoActual = widget.saldoActual;
      _moraAcumulada = (widget.moraAcumulada > 0) ? widget.moraAcumulada : _calcMoraAcumulada();
      setState(() {});
    }
  }


  // =======================
  // 👇 NUEVO: cálculo de mora offline (defaults del modelo)
  // umbrales: [15,30], tipo: porcentaje, valor: 10, dobleEn30: true
  int _calcMoraAcumulada() {
    if (_saldoActual <= 0) return 0;

    final hoy = _soloFecha(DateTime.now());
    final vence = _soloFecha(_proximaFecha);
    final diasAtraso = hoy.difference(vence).inDays;
    if (diasAtraso <= 0) return 0;

    // Solo aplica a Producto / Alquiler
    final productoTxt = widget.producto.toLowerCase();
    final esAlquiler = productoTxt.contains('alquiler') ||
        productoTxt.contains('arriendo') ||
        productoTxt.contains('renta') ||
        productoTxt.contains('casa') ||
        productoTxt.contains('apartamento');
    final esProducto = !_esPrestamo && !esAlquiler;
    final esProdOAlq = esAlquiler || esProducto;
    if (!esProdOAlq) return 0;

    const List<int> umbrales = [15, 30];
    if (diasAtraso < umbrales.first) return 0;

    const String tipo = 'porcentaje';
    const double valor = 10; // 10%
    const bool dobleEn30 = true;

    final int base = _saldoActual;
    double monto = (tipo == 'fijo') ? valor : (base * (valor / 100.0));
    if (dobleEn30 && diasAtraso >= 30) monto *= 2;

    return monto.round();
  }
  // =======================

  String _rd(int v) {
    final f = NumberFormat.currency(
      locale: 'en_US',
      symbol: '\$',
      decimalDigits: 0,
    );
    return f.format(v);
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  // 🕛 Normaliza al mediodía para evitar problemas de zona horaria
  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  bool _esHoyOAnterior(DateTime d) {
    final hoy = _soloFecha(DateTime.now());
    final dd = _soloFecha(d);
    return dd.isBefore(hoy) || dd.isAtSameMomentAs(hoy);
  }

  DateTime _sumarPeriodo(DateTime base, String periodo) {
    final p = periodo.toLowerCase().trim();
    if (p.startsWith('mens')) {
      return DateTime(base.year, base.month + 1, base.day);
    } else if (p.startsWith('quin')) {
      return base.add(const Duration(days: 15));
    } else if (p.startsWith('seman')) {
      return base.add(const Duration(days: 7));
    } else if (p.startsWith('diar')) {
      return base.add(const Duration(days: 1));
    }
    return DateTime(base.year, base.month + 1, base.day);
  }

  DateTime _siguienteFechaAlDia(DateTime propuesta, String periodo) {
    var f = propuesta;
    while (_esHoyOAnterior(f)) {
      f = _sumarPeriodo(f, periodo);
    }
    return f;
  }

  Future<void> _autoFixEstado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(widget.id);

    final snap = await ref.get();
    final data = snap.data() ?? {};
    final bool saldado = (data['saldado'] == true);

    bool needsUpdate = false;
    final Map<String, dynamic> updates = {};

    if (_saldoActual > 0 &&
        (saldado == true || (data['estado'] ?? '') == 'saldado')) {
      updates['saldado'] = false;
      updates['estado'] = 'al_dia';
      needsUpdate = true;
    }

    // 🔒 Detectar si es cliente de alquiler
    final productoTxt = (widget.producto).toLowerCase();
    final esAlquiler = productoTxt.contains('alquiler') ||
        productoTxt.contains('arriendo') ||
        productoTxt.contains('renta') ||
        productoTxt.contains('casa') ||
        productoTxt.contains('apart') ||
        productoTxt.contains('estudio');

// ⚙️ Evitar que los alquileres se marquen saldados
    if (esAlquiler) {
      if ((data['estado'] ?? '') != 'al_dia' || saldado == true) {
        updates['saldado'] = false;
        updates['estado'] = 'al_dia';
        needsUpdate = true;
      }
    } else if (_saldoActual <= 0 && !(saldado == true)) {
      updates['saldado'] = true;
      updates['estado'] = 'saldado';
      updates['venceEl'] = FieldValue.delete();
      needsUpdate = true;
    }


    if (needsUpdate) {
      await ref.set(updates, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _cargarTotalPrestado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(widget.id);

    try {
      final snap = await ref.get();
      final data = snap.data() ?? {};

      // ¿Este cliente es "Producto" o "Alquiler"?
      final pTxt = (widget.producto).toLowerCase();
      final esInmueble = pTxt.contains('alquiler') ||
          pTxt.contains('arriendo') ||
          pTxt.contains('renta') ||
          pTxt.contains('casa') ||
          pTxt.contains('apart');
      final esProducto = !_esPrestamo && !esInmueble;

      int total = 0;

      if (esProducto) {
        // 1) Prioriza el total explícito del flujo de productos
        final rawTotal = data['productoMontoTotal'];
        if (rawTotal is int) total = rawTotal;
        if (rawTotal is double) total = rawTotal.round();

        // 2) Intentar clave antigua/migraciones
        if (total <= 0) {
          final rawMonto = data['montoProducto'];
          if (rawMonto is int) total = rawMonto;
          if (rawMonto is double) total = rawMonto.round();
        }

        // 3) Fallback: capitalInicial (saldo restante) + pago inicial
        if (total <= 0) {
          final cap = (data['capitalInicial'] is num) ? (data['capitalInicial'] as num).round() : 0;
          final iniRaw = data.containsKey('productoPagoInicial')
              ? data['productoPagoInicial']
              : data['pagoInicial'];
          final ini = (iniRaw is num) ? iniRaw.round() : 0;
          total = cap + ini;
        }
      } else if (esInmueble) {
        // 👈 ALQUILER: leer el histórico cobrado (lo incrementas en renovaciones/pagos)
        final rawCobrado = data['totalCobrado'];
        if (rawCobrado is int) total = rawCobrado;
        if (rawCobrado is double) total = rawCobrado.round();

        // Fallback si aún no existe el campo
        if (total <= 0) total = 0;
      } else {
        // Préstamo → como lo tenías (totalPrestado / fallback)
        if (data.containsKey('totalPrestado')) {
          final raw = data['totalPrestado'];
          if (raw is int) total = raw;
          if (raw is double) total = raw.round();
        } else {
          final capitalInicial = (data['capitalInicial'] is num) ? (data['capitalInicial'] as num).round() : 0;
          final fallbackSaldoAnterior = (data['saldoAnterior'] is num) ? (data['saldoAnterior'] as num).round() : 0;
          total = capitalInicial > 0 ? capitalInicial : fallbackSaldoAnterior;
          await ref.set({'totalPrestado': total, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }

      if (!mounted) return;
      setState(() => _totalPrestado = total);
    } catch (_) {}
  }


  Future<void> _cargarNota() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('prestamistas').doc(uid)
          .collection('clientes').doc(widget.id)
          .get();
      final data = snap.data() ?? {};
      final nota = (data['nota'] ?? '').toString().trim();
      if (!mounted) return;
      setState(() {
        _nota = nota.isEmpty ? null : nota;
      });
    } catch (_) {}
  }

  Future<void> _cargarFlags() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('prestamistas').doc(uid)
          .collection('clientes').doc(widget.id)
          .get();
      final data = snap.data() ?? {};
      final bool auto = (data['autoFecha'] as bool?) ?? true;

      if (!mounted) return;
      setState(() {
        _autoFecha = auto;
      });
    } catch (_) {
      // si falla, dejamos _autoFecha=true por defecto
    }
  }

  // 👇 Cargar el pago inicial solo para productos (prioriza productoPagoInicial)
  Future<void> _cargarPagoInicial() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('prestamistas').doc(uid)
          .collection('clientes').doc(widget.id)
          .get();
      final data = snap.data() ?? {};

      final raw = data.containsKey('productoPagoInicial')
          ? data['productoPagoInicial']
          : data['pagoInicial'];
      final val = (raw is int) ? raw : (raw is double ? raw.round() : 0);

      if (!mounted) return;
      setState(() => _pagoInicial = val);
    } catch (_) {/* ignore */}
  }



  Future<void> incrementarTotalPrestado(int monto) async {
    if (monto <= 0) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(widget.id);

    try {
      await ref.set({
        'totalPrestado': FieldValue.increment(monto),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _totalPrestado += monto);
    } catch (_) {}
  }

  Future<Map<String, String>> _prestamistaSeguro() async {
    String empresa = widget.empresa.trim();
    String servidor = widget.servidor.trim();
    String telefono = widget.telefonoServidor.trim();

    if (empresa.isNotEmpty && servidor.isNotEmpty && telefono.isNotEmpty) {
      return {'empresa': empresa, 'servidor': servidor, 'telefono': telefono};
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'empresa': empresa, 'servidor': servidor, 'telefono': telefono};
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .get();
      final data = snap.data() ?? {};
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();

      empresa =
      empresa.isNotEmpty ? empresa : (data['empresa'] ?? '').toString().trim();
      servidor =
      servidor.isNotEmpty ? servidor : [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
      telefono = telefono.isNotEmpty ? telefono : (data['telefono'] ?? '')
          .toString()
          .trim();
    } catch (_) {}
    return {'empresa': empresa, 'servidor': servidor, 'telefono': telefono};
  }

  Future<void> _registrarPagoFlow(BuildContext context) async {
    final result = await Navigator.push<Map?>(
      context,
      MaterialPageRoute(
        builder: (_) => PagoFormScreen(
          saldoAnterior: _saldoActual,
          tasaInteres: widget.tasaInteres,
          periodo: widget.periodo,
          proximaFecha: _proximaFecha,
          esPrestamo: _esPrestamo,
          nombreCliente: widget.nombreCompleto, // ← izquierda
          producto: widget.producto,           // ← para decidir Producto/Arriendo
          moraActual: _moraAcumulada,          // 👈 pasa la mora al formulario
          autoFecha: _autoFecha, // 👈 NUEVO: respeta el flag del cliente

        ),
      ),
    );
    if (result == null) return;

    final int pagoInteres   = result['pagoInteres']   as int? ?? 0;
    final int pagoCapital   = result['pagoCapital']   as int? ?? 0;
    final int totalPagado   = result['totalPagado']   as int? ?? (pagoInteres + pagoCapital);
    final int saldoAnterior = result['saldoAnterior'] as int? ?? _saldoActual;
    final int saldoNuevo    = result['saldoNuevo']    as int? ?? _saldoActual;
    final DateTime prox     = result['proximaFecha']  as DateTime? ?? _proximaFecha;
    // 🔒 Asegura local + 12:00 antes de avanzar períodos/guardar
    final DateTime proxLocalBase = _atNoon(prox.toLocal());


    // 🕛 Normaliza antes de usar/guardar
    final DateTime proxAlDia = _siguienteFechaAlDia(proxLocalBase, widget.periodo);
    final DateTime proxNoon  = _atNoon(proxAlDia);

    // 👇 Sumar mora SOLO en producto/alquiler (si hay)
    final txt = widget.producto.toLowerCase();
    final esAlquiler = txt.contains('alquiler') || txt.contains('arriendo') || txt.contains('renta') || txt.contains('casa') || txt.contains('apartamento');
    final esProducto = !_esPrestamo && !esAlquiler;
    final bool esProdOAlq = esAlquiler || esProducto;

    // 1) Usar el valor que vino del form si lo hay; si no, usa la mora local
    final int moraCobrada = (result['moraCobrada'] as int?) ?? (esProdOAlq ? _moraAcumulada : 0);
    final int totalConMora = totalPagado + moraCobrada;

    // === Obtener correlativo visible del recibo (optimista) ===
    String numeroRecibo = 'REC-0001';
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final clienteRef = FirebaseFirestore.instance
            .collection('prestamistas').doc(uid)
            .collection('clientes').doc(widget.id);

        final snap = await clienteRef.get();
        final current = (snap.data()?['nextReciboCliente'] ?? 0) as int;
        final next = (current + 1).clamp(1, 999999); // evita 0 o negativos
        numeroRecibo = 'REC-${next.toString().padLeft(4, '0')}';
      }
    } catch (_) {
      // si falla, seguimos con 'REC-0001'
    }


    // 👉 Mostrar Recibo ya mismo
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboScreen(
          empresa: widget.empresa,
          servidor: widget.servidor,
          telefonoServidor: widget.telefonoServidor,
          cliente: widget.nombreCompleto,
          telefonoCliente: widget.telefono,
          numeroRecibo: numeroRecibo,
          producto: widget.producto,
          tipoProducto: widget.tipoProducto,
          vehiculoTipo: widget.vehiculoTipo,
          fecha: DateTime.now(),
          capitalInicial: saldoAnterior,
          pagoInteres: pagoInteres,
          pagoCapital: pagoCapital,
          totalPagado: totalConMora,  // incluye mora
          saldoAnterior: saldoAnterior,
          saldoRestante: saldoNuevo, // 👈 NUEVO
          saldoActual: saldoNuevo,
          proximaFecha: proxNoon,
          tasaInteres: widget.tasaInteres,
          moraCobrada: moraCobrada,   // para mostrar línea "Mora cobrada"
        ),
      ),
    );

    // ✅ 3) GUARDAR DESPUÉS (si hay internet). Sin duplicar nada.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final docPrest = FirebaseFirestore.instance
          .collection('prestamistas').doc(uid);
      final clienteRef = docPrest
          .collection('clientes').doc(widget.id);

      try {
        // 3.a) Guardar pago + actualizar cliente + KPIs de summary (todo dentro del helper)
        await guardarPagoYActualizarKPIs(
          docPrest: docPrest,
          clienteRef: clienteRef,
          pagoCapital:  pagoCapital,
          pagoInteres:  pagoInteres,      // 0 si no es préstamo
          totalPagado:  totalConMora,     // incluye mora
          moraCobrada:  moraCobrada,      // 0 si no aplica
          saldoAnterior: saldoAnterior,
          proximaFecha: proxNoon,
        );

        // 🔧 Bloque especial: evitar que los alquileres se marquen saldados o bajen a 0
        final textoProducto = widget.producto.toLowerCase();
        final esAlquiler = textoProducto.contains('alquiler') ||
            textoProducto.contains('renta') ||
            textoProducto.contains('arriendo') ||
            textoProducto.contains('apart') ||
            textoProducto.contains('casa') ||
            textoProducto.contains('estudio');

        if (esAlquiler) {
          await clienteRef.set({
            'saldado': false,
            'estado': 'al_dia',
            'saldoActual': saldoAnterior, // 🔒 mantiene su monto original
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print('✅ Alquiler actualizado: al día, saldo conservado ($saldoAnterior)');
        }


        // 3.b) Incrementar correlativo del cliente (NO tocamos saldos aquí)
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snap = await tx.get(clienteRef);
          final current = (snap.data()?['nextReciboCliente'] ?? 0) as int;
          final next = current + 1;
          tx.set(clienteRef, {
            'nextReciboCliente': next,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });

        // 3.c) Si es ALQUILER, acumula histórico cobrado (no afecta KPIs)
        if (esAlquiler) {
          await clienteRef.set({
            'totalCobrado': FieldValue.increment(totalConMora),
          }, SetOptions(merge: true));
        }

        // ✅ NUEVO BLOQUE: mantener total recuperado permanente
        try {
          final metricsRef = FirebaseFirestore.instance
              .collection('prestamistas')
              .doc(uid)
              .collection('metrics')
              .doc('totales');

          // 👇 Incrementa siempre, sin importar si el cliente se borra o se salda
          await metricsRef.set({
            'lifetimeRecuperado': FieldValue.increment(totalConMora),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          print('[OK] Total recuperado actualizado: +$totalConMora');
        } catch (e) {
          print('⚠️ Error al actualizar lifetimeRecuperado: $e');
        }

        // ⛔️ Eliminado: NO escribimos metricsRef.lifetime* para evitar doble conteo.
        // ⛔️ Eliminado: NO volvemos a agregar el pago ni a tocar saldo/proximaFecha aquí (ya lo hizo el helper).
      } catch (_) {
        // sin internet o error: no bloquea nada
      }
    }

    if (!mounted) return;
    setState(() {
      _saldoActual   = saldoNuevo;
      _proximaFecha  = proxNoon;
      _moraAcumulada = 0; // recalcular con la nueva fecha/saldo
      _tieneCambios  = true;
    });
  }

  void _onBack() {
    if (_tieneCambios) {
      Navigator.pop(context, {
        'accion': 'pago',
        'saldoNuevo': _saldoActual,
        'proximaFecha': _proximaFecha,
      });
    } else {
      Navigator.pop(context);
    }
  }

  // =======================
  // 🚀 BLOQUE 3 - Recordatorios SOLO WhatsApp (premium)
  // =======================

  String _limpiarTelefono(String t) {
    return t.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _normalizarParaWhatsapp(String telefono) {
    final digits = _limpiarTelefono(telefono);
    if (digits.isEmpty) return null;

    if (digits.length > 15) return null;

    if (digits.length == 10) {
      return '1$digits';
    }
    if (digits.length == 11 && digits.startsWith('1')) {
      return digits;
    }
    if (digits.length >= 11) {
      return digits;
    }
    return null;
  }

  Future<void> _enviarPorWhatsApp(String telefono, String mensaje) async {
    final normalized = _normalizarParaWhatsapp(telefono);
    if (normalized == null) {
      if (!mounted) return;
      _showToastPremium(
          'Número inválido. Agrega el código de país (ej. 1 para RD/EE.UU.) y máximo 15 dígitos.');
      return;
    }

    final uriApp = Uri.parse(
        'whatsapp://send?phone=$normalized&text=${Uri.encodeComponent(mensaje)}');
    final uriBiz = Uri.parse(
        'whatsapp-business://send?phone=$normalized&text=${Uri.encodeComponent(mensaje)}');
    final uriWeb = Uri.parse(
        'https://wa.me/$normalized?text=${Uri.encodeComponent(mensaje)}');

    try {
      if (await canLaunchUrl(uriApp)) {
        final ok = await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (await canLaunchUrl(uriBiz)) {
        final ok = await launchUrl(uriBiz, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (await canLaunchUrl(uriWeb)) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        return;
      }
      if (!mounted) return;
      _showToastPremium('No se pudo abrir WhatsApp en este dispositivo.');
    } catch (_) {
      if (!mounted) return;
      _showToastPremium('Error al intentar abrir WhatsApp.');
    }
  }

  String _mensajeRecordatorio(String tipo) {
    final nombre = widget.nombreCompleto;
    final fecha = _fmtFecha(_proximaFecha);
    final saldo = _rd(_saldoActual);

    final producto = widget.producto.toLowerCase();
    final esAlquiler = producto.contains('alquiler') ||
        producto.contains('arriendo') ||
        producto.contains('renta') ||
        producto.contains('casa') ||
        producto.contains('apartamento');
    final esPrestamo = _esPrestamo;
    final esProducto = !esPrestamo && !esAlquiler;

    String base;
    if (esPrestamo) {
      base = 'tu pago vence';
    } else if (esAlquiler) {
      base = 'tu alquiler vence';
    } else if (esProducto) {
      base = 'tu producto vence';
    } else {
      base = 'tu pago vence';
    }

    switch (tipo) {
      case 'vencido':
        return 'Hola $nombre, $base desde $fecha. Saldo: $saldo. ¿Coordinamos hoy?';
      case 'hoy':
        return 'Hola $nombre, $base HOY ($fecha). Saldo: $saldo.';
      case 'manana':
        return 'Hola $nombre, $base MAÑANA ($fecha). Saldo: $saldo.';
      case 'dos_dias':
        return 'Hola $nombre, $base en 2 días ($fecha). Saldo: $saldo.';
      case 'aldia':
        return 'Hola $nombre, estás al día ✅. Próxima fecha: $fecha. ¡Gracias por tu puntualidad!';
      default:
        return 'Hola $nombre.';
    }
  }

  int _diasHasta(DateTime d) {
    final hoy = _soloFecha(DateTime.now());
    final dd = _soloFecha(d);
    return dd.difference(hoy).inDays;
  }

  bool _permiteRecordatorio(String tipo) {
    final d = _diasHasta(_proximaFecha);
    final deuda = _saldoActual > 0;

    switch (tipo) {
      case 'vencido':
        return deuda && d < 0;
      case 'hoy':
        return deuda && d == 0;
      case 'manana':
        return deuda && d == 1;
      case 'dos_dias':
        return deuda && d == 2;
      case 'aldia':
        return !deuda || d > 2;
      default:
        return false;
    }
  }

  void _avisoNoCorresponde() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFDE68A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.lock_clock_rounded, color: Color(0xFF92400E)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⏳ Aún no es momento para este recordatorio de este cliente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF78350F),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaldadoBanner() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDBEAFE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: const [
              Icon(Icons.verified_rounded, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Este cliente está saldado. No se pueden registrar pagos ni enviar recordatorios.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showToastPremium(String text) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2937),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirMenuRecordatorio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        Widget _waChip(bool enabled) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(999),
              boxShadow: enabled
                  ? [BoxShadow(color: const Color(0xFF22C55E).withOpacity(.28), blurRadius: 10, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: enabled ? 1 : .55, child: _waIcon(size: 14)),
                const SizedBox(width: 6),
                Text(
                  'WhatsApp',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: enabled ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ],
            ),
          );
        }


        Widget _premiumItem(String title, String tipo, IconData icon) {
          final enabled = _permiteRecordatorio(tipo);

          return InkWell(
            onTap: () async {
              Navigator.pop(context);
              if (!enabled) {
                _avisoNoCorresponde();
                return;
              }
              final msg = _mensajeRecordatorio(tipo);
              await _enviarPorWhatsApp(widget.telefono, msg);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF4FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFDCE7FF)),
                    ),
                    child: Icon(icon, size: 22, color: const Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Opacity(
                      opacity: enabled ? 1 : .48,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                  _waChip(enabled),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FB)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: const Color(0xFFE9EEF5)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 22, offset: const Offset(0, -6)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Icon(Icons.sms_rounded, color: Color(0xFF0F172A)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Enviar recordatorio',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFE9EEF5)),

                  _premiumItem('Pago vencido', 'vencido', Icons.warning_amber_rounded),
                  const Divider(height: 1, color: Color(0xFFE9EEF5)),
                  _premiumItem('Vence hoy', 'hoy', Icons.event_available),
                  const Divider(height: 1, color: Color(0xFFE9EEF5)),
                  _premiumItem('Vence mañana', 'manana', Icons.access_time),
                  const Divider(height: 1, color: Color(0xFFE9EEF5)),
                  _premiumItem('Vence en 2 días', 'dos_dias', Icons.schedule),
                  const Divider(height: 1, color: Color(0xFFE9EEF5)),
                  _premiumItem('Al día', 'aldia', Icons.check_circle),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.inter(
      fontSize: 15,
      color: const Color(0xFF667084),
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
    final valueStyle = GoogleFonts.inter(
      fontSize: 16,
      color: const Color(0xFF0F172A),
      fontWeight: FontWeight.w800,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final labelInk = labelStyle.copyWith(color: const Color(0xFF0F172A));

    const azul = Color(0xFF2563EB);
    const verde = Color(0xFF22C55E);
    final saldoColor = _saldoActual > 0 ? Colors.red : verde;

    final valueBlue = valueStyle.copyWith(color: azul);
    final valueSaldo = valueStyle.copyWith(color: saldoColor);
    final valueGreen = valueStyle.copyWith(color: const Color(0xFF22C55E));
    final valueInk = valueStyle.copyWith(color: const Color(0xFF0F172A));

    final bool saldado = _estaSaldado;

    final registrarPagoStyle = ElevatedButton.styleFrom(
      elevation: saldado ? 0 : 2,
      shadowColor: const Color(0xFF2563EB).withOpacity(saldado ? 0.0 : 0.35),
      backgroundColor: saldado ? const Color(0xFF2563EB).withOpacity(0.55) : const Color(0xFF2563EB),
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );

    final waButtonStyle = OutlinedButton.styleFrom(
      side: BorderSide(
        color: saldado ? const Color(0xFF94A3B8) : const Color(0xFF2563EB),
        width: 2,
      ),
      shape: const StadiumBorder(),
      foregroundColor: saldado ? const Color(0xFF64748B) : const Color(0xFF2563EB),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      backgroundColor: saldado ? Colors.white.withOpacity(0.92) : Colors.white,
    );

    final productoTxt = widget.producto.toLowerCase();
    final esAlquiler = productoTxt.contains('alquiler') ||
        productoTxt.contains('arriendo') ||
        productoTxt.contains('renta') ||
        productoTxt.contains('casa') ||
        productoTxt.contains('apartamento');
    final esProducto = !_esPrestamo && !esAlquiler;
    final esProdOAlq = esAlquiler || esProducto;

    return Scaffold(
      body: AppGradientBackground(
        child: Stack(
          children: [
            Positioned(
              top: _logoTop,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  'assets/images/logoB.png',
                  height: _logoHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Positioned(
              top: _contentTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: AppFrame(
                header: Center(
                  child: Text(
                    'Detalle del Cliente',
                    style: GoogleFonts.playfairDisplay(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // 👈 clave: se adapta al contenido
                              children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 38,
                                            child: Container(
                                              width: 38,
                                              height: 38,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFFEFF6FF),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.person, color: Color(0xFF2563EB)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              widget.nombreCompleto,
                                              style: GoogleFonts.inter(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // 🌟 BLOQUE PREMIUM DE DATOS DEL CLIENTE
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            _filaInfo(Icons.phone_rounded, widget.telefono, const Color(0xFF16A34A)),
                                            const Divider(height: 16, thickness: 0.8, color: Color(0xFFE2E8F0)),

                                            if (widget.direccion != null && widget.direccion!.trim().isNotEmpty) ...[
                                              _filaInfo(Icons.location_on_rounded, widget.direccion!, const Color(0xFFDC2626), maxLines: 2),
                                              const Divider(height: 16, thickness: 0.8, color: Color(0xFFE2E8F0)),
                                            ],

                                            if ((_nota ?? '').isNotEmpty) ...[
                                              _filaInfo(Icons.sticky_note_2_rounded, _nota!, const Color(0xFFF59E0B)),
                                              const Divider(height: 16, thickness: 0.8, color: Color(0xFFE2E8F0)),
                                            ],

                                            if (widget.producto.trim().isNotEmpty)
                                              _filaInfo(_iconoProducto(), widget.producto, const Color(0xFF7C3AED)),
                                          ],
                                        ),
                                      ),


                                      const SizedBox(height: 4),
                                    ],
                                  ),

                                  const Divider(height: 24, thickness: 1, color: Color(0xFFE7E9EE)),

                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4FAF7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFDDE7E1)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    child: Column(
                                      children: [
                                        _rowStyled(
                                          esProducto
                                              ? 'Monto total'
                                              : (esAlquiler ? 'Total cobrado' : 'Total histórico'),
                                          _rd(_totalPrestado),
                                          labelInk,
                                          valueBlue,
                                        ),

                                        const Divider(
                                          height: 14,
                                          thickness: 1,
                                          color: Color(0xFFE7F0EA),
                                        ),

                                        // 🟢 Mostrar “Pago inicial” solo en Productos y si existe
                                        if (esProducto && _pagoInicial > 0) ...[
                                          _rowStyled(
                                            'Pago inicial',
                                            _rd(_pagoInicial),
                                            labelInk,
                                            valueStyle.copyWith(
                                              color: const Color(0xFF059669), // verde
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const Divider(height: 14, thickness: 1, color: Color(0xFFE7F0EA)),
                                        ],


                                        _rowStyled(
                                          'Saldo actual pendiente',
                                          _rd(_saldoActual),
                                          labelInk,
                                          valueSaldo,
                                        ),

                                        // 👇 NUEVO: Línea Mora (solo producto/alquiler y si hay mora)
                                        if (esProdOAlq && _moraAcumulada > 0) ...[
                                          const Divider(height: 14, thickness: 1, color: Color(0xFFE7F0EA)),
                                          _rowStyled(
                                            'Mora',
                                            _rd(_moraAcumulada),
                                            labelInk,
                                            valueStyle.copyWith(
                                              color: const Color(0xFFDC2626),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],

                                        if (_saldoActual > 0 && _esPrestamo) ...[
                                          const Divider(height: 14, thickness: 1, color: Color(0xFFE7F0EA)),
                                          _rowStyled(
                                            'Interés ${widget.periodo.toLowerCase()}',
                                            _rd((_saldoActual * (widget.tasaInteres / 100)).round()),
                                            labelInk,
                                            valueGreen,
                                          ),
                                        ],

                                        if (_saldoActual > 0) ...[
                                          const Divider(
                                            height: 14,
                                            thickness: 1,
                                            color: Color(0xFFE7F0EA),
                                          ),
                                          _rowStyled(
                                            'Próxima fecha',
                                            _fmtFecha(_proximaFecha),
                                            labelInk,
                                            valueInk,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: registrarPagoStyle,
                                      onPressed: () async {
                                        if (saldado) {
                                          HapticFeedback.selectionClick();
                                          _showSaldadoBanner();
                                          return;
                                        }
                                        if (_btnPagoBusy) return;
                                        HapticFeedback.lightImpact();
                                        setState(() => _btnPagoBusy = true);
                                        await _registrarPagoFlow(context);
                                        if (mounted) setState(() => _btnPagoBusy = false);
                                      },
                                      child: const Text('Registrar pago'),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        elevation: 0,
                                        backgroundColor: const Color(0xFF22C55E),
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => HistorialScreen(
                                              idCliente: widget.id,
                                              nombreCliente: widget.nombreCompleto,
                                              producto: widget.producto,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text('Ver historial'),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton.icon(
                                      icon: Opacity(
                                        opacity: saldado ? 0.55 : 1,
                                        child: _waIcon(size: 22),
                                      ),
                                      label: Text(
                                        'Enviar recordatorio por WhatsApp',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: saldado ? const Color(0xFF64748B) : const Color(0xFF2563EB),
                                        ),
                                      ),
                                      style: waButtonStyle,
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        if (saldado) {
                                          _showSaldadoBanner();
                                          return;
                                        }
                                        _abrirMenuRecordatorio();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 8,
              left: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _onBack,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowStyled(String l, String v, TextStyle ls, TextStyle vs) {
    return Row(
      children: [
        Expanded(child: Text(l, style: ls)),
        Text(v, style: vs),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
Widget _filaInfo(IconData icon, String texto, Color color, {int maxLines = 1}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 28,
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          texto,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14.2,
            color: Color(0xFF0F172A),
            height: 1.2,
          ),
        ),
      ),
    ],
  );
}


