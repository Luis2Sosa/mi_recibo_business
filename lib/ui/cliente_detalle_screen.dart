import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../core/ads/ads_manager.dart';
import 'pago_form_screen.dart';
import 'recibo_screen.dart';
import 'historial_screen.dart';
import 'widgets/app_frame.dart';
import '../core/notifications_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'guardar_pago_y_kpis.dart';

class ClienteDetalleScreen extends StatefulWidget {
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
  final String? tipoProducto;
  final String? vehiculoTipo;
  final String empresa;
  final String servidor;
  final String telefonoServidor;
  final int moraAcumulada;

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
    required this.moraAcumulada,
  });

  @override
  State<ClienteDetalleScreen> createState() => _ClienteDetalleScreenState();
}

class _ClienteDetalleScreenState extends State<ClienteDetalleScreen> {
  // ─── Getters de tipo ─────────────────────────────────────────────────────
  bool get _esPrestamo {
    final p = widget.producto.trim().toLowerCase();
    if (p.isEmpty) return true;
    return p.contains('prest') ||
        p.contains('crédito') ||
        p.contains('credito') ||
        p.contains('loan');
  }

  bool get _esAlquiler {
    final p = widget.producto.toLowerCase();
    return p.contains('alquiler') ||
        p.contains('arriendo') ||
        p.contains('renta') ||
        p.contains('casa') ||
        p.contains('apart') ||
        p.contains('estudio');
  }

  bool get _esProducto => !_esPrestamo && !_esAlquiler;
  bool get _esProdOAlq => _esAlquiler || _esProducto;
  bool get _estaSaldado => _saldoActual <= 0;

  // ─── Estado ──────────────────────────────────────────────────────────────
  late int _saldoActual;
  late DateTime _proximaFecha;
  bool _tieneCambios = false;

  String? _fechaPrimerPago;
  bool _esPremium = false;
  int _totalPrestado = 0;
  bool _btnPagoBusy = false;
  bool _autoFecha = true;
  late int _moraAcumulada;
  int _pagoInicial = 0;
  String? _nota;

  Widget _waIcon({double size = 24}) => Image.asset(
    'assets/images/logo_whatsapp.png',
    width: size, height: size, fit: BoxFit.contain,
  );

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _proximaFecha = widget.proximaFecha;
    _moraAcumulada = widget.moraAcumulada > 0
        ? widget.moraAcumulada
        : _calcMoraAcumulada();

    Future.microtask(_autoFixEstado);
    Future.microtask(_cargarTotalPrestado);
    Future.microtask(_cargarNota);
    Future.microtask(_cargarFlags);
    Future.microtask(_cargarPagoInicial);
    Future.microtask(() async {
      _fechaPrimerPago = await _obtenerFechaPrimerPago();
      if (mounted) setState(() {});
    });
    Future.microtask(() async {
      _esPremium = await _cargarPremium();
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant ClienteDetalleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proximaFecha != widget.proximaFecha ||
        oldWidget.saldoActual != widget.saldoActual) {
      _proximaFecha = widget.proximaFecha;
      _saldoActual = widget.saldoActual;
      _moraAcumulada = widget.moraAcumulada > 0
          ? widget.moraAcumulada
          : _calcMoraAcumulada();
      setState(() {});
    }
  }

  // ─── Mora offline ────────────────────────────────────────────────────────
  int _calcMoraAcumulada() {
    if (_saldoActual <= 0) return 0;
    if (!_esProdOAlq) return 0;
    final hoy = _soloFecha(DateTime.now());
    final vence = _soloFecha(_proximaFecha);
    final diasAtraso = hoy.difference(vence).inDays;
    if (diasAtraso < 15) return 0;
    const double valorPct = 10;
    double monto = _saldoActual * (valorPct / 100.0);
    if (diasAtraso >= 30) monto *= 2;
    return monto.round();
  }

  // ─── Formato ─────────────────────────────────────────────────────────────
  String _rd(int v) => NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0).format(v);

  String _fmtFecha(DateTime d) {
    const meses = ['ene.','feb.','mar.','abr.','may.','jun.','jul.','ago.','sept.','oct.','nov.','dic.'];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  bool _esHoyOAnterior(DateTime d) {
    final hoy = _soloFecha(DateTime.now());
    final dd = _soloFecha(d);
    return dd.isBefore(hoy) || dd.isAtSameMomentAs(hoy);
  }

  DateTime _sumarPeriodo(DateTime base, String periodo) {
    final p = periodo.toLowerCase().trim();
    if (p.startsWith('mens')) return DateTime(base.year, base.month + 1, base.day);
    if (p.startsWith('quin')) return base.add(const Duration(days: 15));
    if (p.startsWith('seman')) return base.add(const Duration(days: 7));
    if (p.startsWith('diar')) return base.add(const Duration(days: 1));
    return DateTime(base.year, base.month + 1, base.day);
  }

  DateTime _siguienteFechaAlDia(DateTime propuesta, String periodo) {
    var f = propuesta;
    while (_esHoyOAnterior(f)) f = _sumarPeriodo(f, periodo);
    return f;
  }

  // ─── Icono producto ──────────────────────────────────────────────────────
  IconData _iconoProducto() {
    final p = widget.producto.toLowerCase().trim();
    final tipo = (widget.tipoProducto ?? '').toLowerCase();
    final veh = (widget.vehiculoTipo ?? '').toLowerCase();
    if (p.contains('alquiler') || p.contains('arriendo') ||
        p.contains('renta') || p.contains('casa') || p.contains('apart')) return Icons.house_rounded;
    if (tipo == 'vehiculo') {
      if (veh == 'carro' || veh == 'auto') return Icons.directions_car_filled_rounded;
      if (veh == 'guagua' || veh == 'bus') return Icons.directions_bus_filled_rounded;
      if (veh == 'moto' || veh == 'motor') return Icons.two_wheeler_rounded;
    }
    if (p.contains('carro') || p.contains('auto')) return Icons.directions_car_filled_rounded;
    if (p.contains('guagua') || p.contains('bus')) return Icons.directions_bus_filled_rounded;
    if (p.contains('moto') || p.contains('motor')) return Icons.two_wheeler_rounded;
    return Icons.shopping_bag_rounded;
  }

  // ─── Firestore helpers ───────────────────────────────────────────────────
  DocumentReference<Map<String, dynamic>> get _clienteRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Usuario no autenticado');
    return FirebaseFirestore.instance
        .collection('prestamistas').doc(uid).collection('clientes').doc(widget.id);
  }

  Future<void> _autoFixEstado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await _clienteRef.get();
    final data = snap.data() ?? {};
    final bool saldado = data['saldado'] == true;
    final Map<String, dynamic> updates = {};
    bool needsUpdate = false;
    if (_esAlquiler) {
      if ((data['estado'] ?? '') != 'al_dia' || saldado) {
        updates['saldado'] = false; updates['estado'] = 'al_dia'; needsUpdate = true;
      }
    } else if (_saldoActual > 0 && (saldado || data['estado'] == 'saldado')) {
      updates['saldado'] = false; updates['estado'] = 'al_dia'; needsUpdate = true;
    } else if (_saldoActual <= 0 && !saldado) {
      updates['saldado'] = true; updates['estado'] = 'saldado';
      updates['venceEl'] = FieldValue.delete(); needsUpdate = true;
    }
    if (needsUpdate) {
      await _clienteRef.set(updates, SetOptions(merge: true));
      if (mounted) setState(() {});
    }
  }

  Future<void> _cargarTotalPrestado() async {
    try {
      final snap = await _clienteRef.get();
      final data = snap.data() ?? {};
      int total = 0;
      if (_esProducto) {
        final rawTotal = data['productoMontoTotal'];
        if (rawTotal is num) total = rawTotal.round();
        if (total <= 0) { final rawMonto = data['montoProducto']; if (rawMonto is num) total = rawMonto.round(); }
        if (total <= 0) {
          final cap = (data['capitalInicial'] as num?)?.round() ?? 0;
          final iniRaw = data['productoPagoInicial'] ?? data['pagoInicial'];
          final ini = (iniRaw as num?)?.round() ?? 0;
          total = cap + ini;
        }
      } else if (_esAlquiler) {
        final raw = data['totalCobrado']; if (raw is num) total = raw.round();
      } else {
        if (data.containsKey('totalPrestado')) {
          final raw = data['totalPrestado']; if (raw is num) total = raw.round();
        } else {
          final cap = (data['capitalInicial'] as num?)?.round() ?? 0;
          final prev = (data['saldoAnterior'] as num?)?.round() ?? 0;
          total = cap > 0 ? cap : prev;
          await _clienteRef.set({'totalPrestado': total, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        }
      }
      if (mounted) setState(() => _totalPrestado = total);
    } catch (_) {}
  }

  Future<void> _cargarNota() async {
    try {
      final snap = await _clienteRef.get();
      final nota = ((snap.data() ?? {})['nota'] ?? '').toString().trim();
      if (mounted) setState(() => _nota = nota.isEmpty ? null : nota);
    } catch (_) {}
  }

  Future<void> _cargarFlags() async {
    try {
      final snap = await _clienteRef.get();
      final auto = (snap.data() ?? {})['autoFecha'] as bool? ?? true;
      if (mounted) setState(() => _autoFecha = auto);
    } catch (_) {}
  }

  Future<bool> _cargarPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await FirebaseFirestore.instance.collection('prestamistas').doc(uid).get();
      return (snap.data() ?? {})['isPremium'] == true;
    } catch (_) { return false; }
  }

  Future<void> _cargarPagoInicial() async {
    try {
      final snap = await _clienteRef.get();
      final data = snap.data() ?? {};
      final raw = data.containsKey('productoPagoInicial') ? data['productoPagoInicial'] : data['pagoInicial'];
      final val = (raw as num?)?.round() ?? 0;
      if (mounted) setState(() => _pagoInicial = val);
    } catch (_) {}
  }

  Future<String?> _obtenerFechaPrimerPago() async {
    try {
      final snap = await _clienteRef.get();
      final fechaRaw = (snap.data() ?? {})['primerPago'];
      if (fechaRaw is Timestamp) return DateFormat('dd/MM/yyyy').format(fechaRaw.toDate());
    } catch (_) {}
    return null;
  }

  Future<Map<String, String>> _prestamistaSeguro() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'empresa': widget.empresa, 'servidor': widget.servidor, 'telefono': widget.telefonoServidor};
    try {
      final snap = await FirebaseFirestore.instance.collection('prestamistas').doc(uid).get();
      final data = snap.data() ?? {};
      final empresa = (data['empresa'] ?? widget.empresa).toString().trim();
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();
      final servidor = [nombre, apellido].where((e) => e.isNotEmpty).join(' ').trim();
      final telefono = (data['telefono'] ?? widget.telefonoServidor).toString().trim();
      return {
        'empresa': empresa.isEmpty ? widget.empresa : empresa,
        'servidor': servidor.isEmpty ? widget.servidor : servidor,
        'telefono': telefono.isEmpty ? widget.telefonoServidor : telefono,
      };
    } catch (_) {
      return {'empresa': widget.empresa, 'servidor': widget.servidor, 'telefono': widget.telefonoServidor};
    }
  }

  // ─── Flujo de pago ───────────────────────────────────────────────────────
  Future<void> _registrarPagoFlow(BuildContext context) async {
    final snap = await _clienteRef.get();
    final data = snap.data() ?? {};
    final productosLista = data['productos'] ?? [];

    final result = await Navigator.push<Map?>(
      context,
      MaterialPageRoute(
        builder: (_) => PagoFormScreen(
          saldoAnterior: _saldoActual,
          tasaInteres: widget.tasaInteres,
          periodo: widget.periodo,
          proximaFecha: _proximaFecha,
          esPrestamo: _esPrestamo,
          nombreCliente: widget.nombreCompleto,
          producto: widget.producto,
          moraActual: _moraAcumulada,
          autoFecha: _autoFecha,
          productosLista: productosLista,
        ),
      ),
    );
    if (result == null) return;

    final int pagoInteres = result['pagoInteres'] as int? ?? 0;
    final int pagoCapital = result['pagoCapital'] as int? ?? 0;
    final int totalPagado = result['totalPagado'] as int? ?? (pagoInteres + pagoCapital);
    final int saldoAnterior = result['saldoAnterior'] as int? ?? _saldoActual;
    final int saldoNuevo = result['saldoNuevo'] as int? ?? _saldoActual;
    final DateTime prox = result['proximaFecha'] as DateTime? ?? _proximaFecha;
    final DateTime proxLocalBase = _atNoon(prox.toLocal());
    final DateTime proxAlDia = _siguienteFechaAlDia(proxLocalBase, widget.periodo);
    final DateTime proxNoon = _atNoon(proxAlDia);
    final int moraCobrada = (result['moraCobrada'] as int?) ?? (_esProdOAlq ? _moraAcumulada : 0);
    final int totalConMora = totalPagado + moraCobrada;

    String numeroRecibo = 'REC-0001';
    try {
      final snap = await _clienteRef.get();
      final current = (snap.data()?['nextReciboCliente'] ?? 0) as int;
      final next = (current + 1).clamp(1, 999999);
      numeroRecibo = 'REC-${next.toString().padLeft(4, '0')}';
    } catch (_) {}

    if (!mounted) return;
    final prest = await _prestamistaSeguro();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReciboScreen(
          empresa: prest['empresa'] ?? widget.empresa,
          servidor: prest['servidor'] ?? widget.servidor,
          telefonoServidor: prest['telefono'] ?? widget.telefonoServidor,
          cliente: widget.nombreCompleto,
          telefonoCliente: widget.telefono,
          numeroRecibo: numeroRecibo,
          producto: (productosLista is List && productosLista.isNotEmpty)
              ? productosLista.map((p) => p is Map<String, dynamic> ? (p['nombre'] ?? p.toString()) : p.toString()).join(' / ')
              : widget.producto,
          tipoProducto: widget.tipoProducto,
          vehiculoTipo: widget.vehiculoTipo,
          fecha: DateTime.now(),
          capitalInicial: saldoAnterior,
          pagoInteres: pagoInteres,
          pagoCapital: pagoCapital,
          totalPagado: totalConMora,
          saldoAnterior: saldoAnterior,
          saldoRestante: saldoNuevo,
          saldoActual: saldoNuevo,
          proximaFecha: proxNoon,
          tasaInteres: widget.tasaInteres,
          moraCobrada: moraCobrada,
          isPremium: _esPremium,
        ),
      ),
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final docPrest = FirebaseFirestore.instance.collection('prestamistas').doc(uid);
      try {
        await guardarPagoYActualizarKPIs(
          docPrest: docPrest, clienteRef: _clienteRef,
          pagoCapital: pagoCapital, pagoInteres: pagoInteres,
          totalPagado: totalConMora, moraCobrada: moraCobrada,
          saldoAnterior: saldoAnterior, proximaFecha: proxNoon,
        );
        if (_esAlquiler) {
          await _clienteRef.set({
            'saldado': false, 'estado': 'al_dia',
            'saldoActual': saldoAnterior, 'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final s = await tx.get(_clienteRef);
          final current = (s.data()?['nextReciboCliente'] ?? 0) as int;
          tx.set(_clienteRef, {'nextReciboCliente': current + 1, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        });
        if (_esAlquiler) {
          await _clienteRef.set({'totalCobrado': FieldValue.increment(totalConMora)}, SetOptions(merge: true));
        }
        await FirebaseFirestore.instance.collection('prestamistas').doc(uid)
            .collection('metrics').doc('totales').set({
          'lifetimeRecuperado': FieldValue.increment(totalConMora),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _saldoActual = saldoNuevo;
      _proximaFecha = proxNoon;
      _moraAcumulada = 0;
      _tieneCambios = true;
    });
  }

  void _onBack() {
    if (_tieneCambios) {
      Navigator.pop(context, {'accion': 'pago', 'saldoNuevo': _saldoActual, 'proximaFecha': _proximaFecha});
    } else {
      Navigator.pop(context);
    }
  }

  // ─── WhatsApp ────────────────────────────────────────────────────────────
  String? _normalizarParaWhatsapp(String telefono) {
    final digits = telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty || digits.length > 15) return null;
    if (digits.length == 10) return '1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return digits;
    if (digits.length >= 11) return digits;
    return null;
  }

  Future<void> _enviarPorWhatsApp(String telefono, String mensaje) async {
    final normalized = _normalizarParaWhatsapp(telefono);
    if (normalized == null) { _showToast('Número inválido. Agrega el código de país.'); return; }
    final uriApp = Uri.parse('whatsapp://send?phone=$normalized&text=${Uri.encodeComponent(mensaje)}');
    final uriBiz = Uri.parse('whatsapp-business://send?phone=$normalized&text=${Uri.encodeComponent(mensaje)}');
    final uriWeb = Uri.parse('https://wa.me/$normalized?text=${Uri.encodeComponent(mensaje)}');
    try {
      for (final uri in [uriApp, uriBiz]) {
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) { await AdsManager.showAfterWhatsApp(context, 'recordatorio'); return; }
        }
      }
      if (await canLaunchUrl(uriWeb)) {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      } else { _showToast('No se pudo abrir WhatsApp en este dispositivo.'); }
    } catch (_) { _showToast('Error al intentar abrir WhatsApp.'); }
  }

  String _mensajeRecordatorio(String tipo) {
    final nombre = widget.nombreCompleto;
    final fecha = _fmtFecha(_proximaFecha);
    final saldo = _rd(_saldoActual);
    final base = _esPrestamo ? 'tu pago vence' : _esAlquiler ? 'tu alquiler vence' : 'tu producto vence';
    switch (tipo) {
      case 'vencido': return 'Hola $nombre, $base desde $fecha. Saldo: $saldo. ¿Coordinamos hoy?';
      case 'hoy': return 'Hola $nombre, $base HOY ($fecha). Saldo: $saldo.';
      case 'manana': return 'Hola $nombre, $base MAÑANA ($fecha). Saldo: $saldo.';
      case 'dos_dias': return 'Hola $nombre, $base en 2 días ($fecha). Saldo: $saldo.';
      case 'aldia': return 'Hola $nombre, estás al día ✅. Próxima fecha: $fecha. ¡Gracias por tu puntualidad!';
      default: return 'Hola $nombre.';
    }
  }

  int _diasHasta(DateTime d) => _soloFecha(d).difference(_soloFecha(DateTime.now())).inDays;

  bool _permiteRecordatorio(String tipo) {
    final d = _diasHasta(_proximaFecha);
    final deuda = _saldoActual > 0;
    switch (tipo) {
      case 'vencido': return deuda && d < 0;
      case 'hoy': return deuda && d == 0;
      case 'manana': return deuda && d == 1;
      case 'dos_dias': return deuda && d == 2;
      case 'aldia': return !deuda || d > 2;
      default: return false;
    }
  }

  // ─── Snackbars ───────────────────────────────────────────────────────────
  void _showToast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, backgroundColor: Colors.transparent, elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18), duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFF1F2937), borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 14, offset: const Offset(0, 8))]),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ));
  }

  void _showSaldadoBanner() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, backgroundColor: Colors.transparent, elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18), duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDBEAFE)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 8))]),
          child: Row(children: const [
            Icon(Icons.verified_rounded, color: Color(0xFF2563EB)), SizedBox(width: 10),
            Expanded(child: Text('Este cliente está saldado. No se pueden registrar pagos ni enviar recordatorios.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w800))),
          ]),
        ),
      ));
  }

  void _avisoNoCorresponde() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, backgroundColor: Colors.transparent, elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18), duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFDE68A)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 14, offset: const Offset(0, 8))]),
          child: Row(children: const [
            Icon(Icons.lock_clock_rounded, color: Color(0xFF92400E)), SizedBox(width: 10),
            Expanded(child: Text('⏳ Aún no es momento para este recordatorio.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF78350F), fontWeight: FontWeight.w800))),
          ]),
        ),
      ));
  }

  // ─── Menú recordatorio ───────────────────────────────────────────────────
  void _abrirMenuRecordatorio() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FB)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: const Color(0xFFE9EEF5)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 22, offset: const Offset(0, -6))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(width: 44, height: 5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(999))),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Row(children: [
                    Icon(Icons.sms_rounded, color: Color(0xFF0F172A)), SizedBox(width: 8),
                    Expanded(child: Text('Enviar recordatorio', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)))),
                  ]),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFFE9EEF5)),
                _itemRecordatorio('Pago vencido', 'vencido', Icons.warning_amber_rounded),
                const Divider(height: 1, color: Color(0xFFE9EEF5)),
                _itemRecordatorio('Vence hoy', 'hoy', Icons.event_available),
                const Divider(height: 1, color: Color(0xFFE9EEF5)),
                _itemRecordatorio('Vence mañana', 'manana', Icons.access_time),
                const Divider(height: 1, color: Color(0xFFE9EEF5)),
                _itemRecordatorio('Vence en 2 días', 'dos_dias', Icons.schedule),
                const Divider(height: 1, color: Color(0xFFE9EEF5)),
                _itemRecordatorio('Al día', 'aldia', Icons.check_circle),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemRecordatorio(String title, String tipo, IconData icon) {
    final enabled = _permiteRecordatorio(tipo);
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        if (!enabled) { _avisoNoCorresponde(); return; }
        await _enviarPorWhatsApp(widget.telefono, _mensajeRecordatorio(tipo));
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(color: const Color(0xFFEFF4FF), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDCE7FF))),
                child: Icon(icon, size: 22, color: const Color(0xFF2563EB))),
            const SizedBox(width: 12),
            Expanded(child: Opacity(opacity: enabled ? 1 : .48,
                child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: enabled ? const Color(0xFF22C55E) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(999),
                boxShadow: enabled ? [BoxShadow(color: const Color(0xFF22C55E).withOpacity(.28), blurRadius: 10, offset: const Offset(0, 4))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: enabled ? 1 : .55, child: _waIcon(size: 14)),
                const SizedBox(width: 6),
                Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                    color: enabled ? Colors.white : const Color(0xFF334155))),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  UI HELPERS NUEVOS
  // ═══════════════════════════════════════════════════════════════

  /// Avatar con iniciales del cliente
  Widget _avatar(double radius) {
    final initials = widget.nombreCompleto.trim().split(' ')
        .where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
    final List<Color> avatarColors = _esPrestamo
        ? [const Color(0xFF60A5FA), const Color(0xFF2563EB)]
        : _esAlquiler
        ? [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]
        : [const Color(0xFF4ADE80), const Color(0xFF22C55E)];
    final Color avatarShadow = _esPrestamo
        ? const Color(0xFF2563EB)
        : _esAlquiler
        ? const Color(0xFFF59E0B)
        : const Color(0xFF22C55E);

    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: avatarColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: avatarShadow.withOpacity(0.40), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Center(
        child: Text(initials, style: GoogleFonts.inter(fontSize: radius * 0.70, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
      ),
    );
  }

  /// Badge tipo de cliente — fondo blanco sólido para contrastar con cabecera
  Widget _tipoBadge() {
    late String label; late Color color; late IconData icon;
    if (_esPrestamo) { label = 'Préstamo'; color = const Color(0xFF2563EB); icon = Icons.request_quote_rounded; }
    else if (_esAlquiler) { label = 'Alquiler'; color = const Color(0xFFD97706); icon = Icons.house_rounded; }
    else { label = 'Producto'; color = const Color(0xFF16A34A); icon = _iconoProducto(); }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color), const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.2)),
      ]),
    );
  }

  /// Badge de estado — fondo blanco sólido para contrastar con cabecera
  Widget _statusBadge() {
    final dias = _diasHasta(_proximaFecha);
    late String label; late Color fg; late IconData icon;
    if (_estaSaldado) { label = 'Saldado'; fg = const Color(0xFF2563EB); icon = Icons.verified_rounded; }
    else if (_moraAcumulada > 0) { label = 'En mora'; fg = const Color(0xFFDC2626); icon = Icons.warning_amber_rounded; }
    else if (dias < 0) { label = 'Vencido'; fg = const Color(0xFFDC2626); icon = Icons.error_outline_rounded; }
    else if (dias <= 2) { label = 'Vence pronto'; fg = const Color(0xFFD97706); icon = Icons.schedule_rounded; }
    else { label = 'Al día'; fg = const Color(0xFF16A34A); icon = Icons.check_circle_rounded; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: fg), const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.2)),
      ]),
    );
  }

  /// Fila de tabla financiera con ícono de color
  Widget _filaTabla({
    required IconData icon, required Color iconColor,
    required String label, required String value, required Color valueColor,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 17, color: iconColor)),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), fontWeight: FontWeight.w600))),
              Text(value, style: GoogleFonts.inter(fontSize: 14, color: valueColor, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9), indent: 56, endIndent: 14),
      ],
    );
  }

  /// Botón de acción principal con ícono
  Widget _actionButton({
    required String label, required IconData icon,
    required Color bgColor, required Color fgColor,
    required VoidCallback onPressed, bool isBusy = false,
  }) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    return SizedBox(
      width: double.infinity,
      height: (screenH * 0.068).clamp(48.0, 58.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0, backgroundColor: bgColor, foregroundColor: fgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: TextStyle(fontSize: (screenW * 0.04).clamp(14.0, 16.0), fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: isBusy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18), const SizedBox(width: 8), Text(label),
        ]),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    final botPad = MediaQuery.of(context).padding.bottom;

    final double logoH = (screenH * 0.38).clamp(200.0, 320.0);
    final double logoTop = -(logoH * 0.32);
    final double contentTop = (screenH * 0.12).clamp(90.0, 130.0);
    final double hPad = (screenW * 0.04).clamp(12.0, 24.0);

    const azul = Color(0xFF2563EB);
    const verde = Color(0xFF22C55E);
    final saldoColor = _saldoActual > 0 ? const Color(0xFFDC2626) : verde;
    final bool saldado = _estaSaldado;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) { if (didPop) return; _onBack(); },
      child: Scaffold(
        body: AppGradientBackground(
          child: Stack(
            children: [
              // Logo de fondo
              Positioned(
                top: logoTop, left: 0, right: 0,
                child: IgnorePointer(
                  child: Center(child: Image.asset('assets/images/logoB.png', height: logoH, fit: BoxFit.contain)),
                ),
              ),

              // Contenido principal
              Positioned(
                top: contentTop, left: 0, right: 0, bottom: 0,
                child: AppFrame(
                  header: Center(
                    child: Text('Detalle del Cliente',
                      style: GoogleFonts.playfairDisplay(textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: (screenW * 0.058).clamp(18.0, 26.0),
                        fontWeight: FontWeight.w600, fontStyle: FontStyle.italic,
                      )),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 6))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // ════════════════════════════════════════════
                            // CABECERA PREMIUM — gradiente azul profundo
                            // ════════════════════════════════════════════
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(hPad, 22, hPad, 22),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                                  colors: _esPrestamo
                                      ? [const Color(0xFF1E3A8A), const Color(0xFF2563EB)]
                                      : _esAlquiler
                                      ? [const Color(0xFF92400E), const Color(0xFFF59E0B)]
                                      : [const Color(0xFF065F46), const Color(0xFF22C55E)],
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _avatar(30),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.nombreCompleto,
                                          maxLines: 2, overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: (screenW * 0.052).clamp(17.0, 22.0),
                                            fontWeight: FontWeight.w900, color: Colors.white, height: 1.2, letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Teléfono bajo el nombre
                                        Row(children: [
                                          const Icon(Icons.phone_rounded, size: 13, color: Colors.white54),
                                          const SizedBox(width: 4),
                                          Text(widget.telefono,
                                              style: const TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w600)),
                                        ]),
                                        const SizedBox(height: 8),
                                        Wrap(spacing: 6, runSpacing: 4, children: [_tipoBadge(), _statusBadge()]),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // ── Contacto / info adicional ────────────
                                  if ((widget.direccion ?? '').trim().isNotEmpty ||
                                      (_nota ?? '').isNotEmpty ||
                                      !_esPrestamo)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                                      ),
                                      child: Column(
                                        children: [
                                          if ((widget.direccion ?? '').trim().isNotEmpty) ...[
                                            _filaInfo(Icons.location_on_rounded, widget.direccion!, const Color(0xFFDC2626), maxLines: 2),
                                          ],
                                          if ((widget.direccion ?? '').trim().isNotEmpty && (_nota ?? '').isNotEmpty)
                                            const Divider(height: 14, thickness: 0.8, color: Color(0xFFE2E8F0)),
                                          if ((_nota ?? '').isNotEmpty) ...[
                                            _filaInfo(Icons.sticky_note_2_rounded, _nota!, const Color(0xFFF59E0B), maxLines: 3),
                                          ],
                                          if (!_esPrestamo) ...[
                                            if ((widget.direccion ?? '').trim().isNotEmpty || (_nota ?? '').isNotEmpty)
                                              const Divider(height: 14, thickness: 0.8, color: Color(0xFFE2E8F0)),
                                            FutureBuilder<DocumentSnapshot>(
                                              key: ValueKey(widget.id),
                                              future: _clienteRef.get(),
                                              builder: (context, snapshot) {
                                                String productosTexto = widget.producto;
                                                if (snapshot.hasData) {
                                                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                                                  final prods = data?['productos'];
                                                  if (prods is List && prods.isNotEmpty) {
                                                    productosTexto = prods
                                                        .map((p) => p is Map && p.containsKey('nombre') ? p['nombre'].toString() : p.toString())
                                                        .take(4).join(' / ');
                                                  }
                                                }
                                                return _filaInfo(_iconoProducto(), productosTexto, const Color(0xFF7C3AED), maxLines: 2);
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                  if ((widget.direccion ?? '').trim().isNotEmpty ||
                                      (_nota ?? '').isNotEmpty ||
                                      !_esPrestamo)
                                    const SizedBox(height: 14),

                                  // ════════════════════════════════════════
                                  // SALDO DESTACADO — tarjeta prominente
                                  // ════════════════════════════════════════
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: saldado
                                            ? [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)]
                                            : _saldoActual > 0
                                            ? [const Color(0xFFFFF1F2), const Color(0xFFFFE4E6)]
                                            : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: saldado ? const Color(0xFFBFDBFE) : _saldoActual > 0 ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0)),
                                      boxShadow: [BoxShadow(color: saldoColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48, height: 48,
                                          decoration: BoxDecoration(shape: BoxShape.circle, color: saldoColor.withOpacity(0.12)),
                                          child: Icon(saldado ? Icons.verified_rounded : Icons.account_balance_wallet_rounded, color: saldoColor, size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Saldo pendiente',
                                                  style: GoogleFonts.inter(fontSize: 12, color: saldoColor.withOpacity(0.70), fontWeight: FontWeight.w600)),
                                              const SizedBox(height: 3),
                                              Text(saldado ? 'Saldado ✓' : _rd(_saldoActual),
                                                  style: GoogleFonts.inter(
                                                    fontSize: 26, fontWeight: FontWeight.w900, color: saldoColor,
                                                    fontFeatures: const [FontFeature.tabularFigures()], height: 1.1,
                                                  )),
                                            ],
                                          ),
                                        ),
                                        // Mini chip de mora si aplica
                                        if (_moraAcumulada > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE11D48).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.25)),
                                            ),
                                            child: Column(children: [
                                              const Text('Mora', style: TextStyle(fontSize: 10, color: Color(0xFFE11D48), fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 2),
                                              Text(_rd(_moraAcumulada),
                                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFFE11D48))),
                                            ]),
                                          ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // ── Tabla financiera ─────────────────────
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFE5E7EB)),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
                                    ),
                                    child: Column(children: [
                                      _filaTabla(
                                        icon: Icons.calendar_month_rounded, iconColor: const Color(0xFF6366F1),
                                        label: 'Primer pago', value: _fechaPrimerPago ?? 'Sin registro', valueColor: const Color(0xFF0F172A),
                                      ),
                                      if (_esProducto && _pagoInicial > 0)
                                        _filaTabla(
                                          icon: Icons.payments_rounded, iconColor: const Color(0xFF059669),
                                          label: 'Pago inicial', value: _rd(_pagoInicial), valueColor: const Color(0xFF059669),
                                        ),
                                      if (_saldoActual > 0 && _esPrestamo)
                                        _filaTabla(
                                          icon: Icons.percent_rounded, iconColor: const Color(0xFF22C55E),
                                          label: 'Interés ${widget.periodo.toLowerCase()}',
                                          value: _rd((_saldoActual * (widget.tasaInteres / 100)).round()),
                                          valueColor: const Color(0xFF16A34A),
                                        ),
                                      if (_saldoActual > 0)
                                        _filaTabla(
                                          icon: Icons.event_rounded, iconColor: const Color(0xFF2563EB),
                                          label: 'Próxima fecha', value: _fmtFecha(_proximaFecha),
                                          valueColor: const Color(0xFF1D4ED8), isLast: true,
                                        ),
                                      if (_saldoActual <= 0)
                                        _filaTabla(
                                          icon: Icons.event_rounded, iconColor: const Color(0xFF2563EB),
                                          label: 'Primer pago', value: _fechaPrimerPago ?? '—',
                                          valueColor: const Color(0xFF1D4ED8), isLast: true,
                                        ),
                                    ]),
                                  ),

                                  SizedBox(height: (screenH * 0.022).clamp(14.0, 22.0)),

                                  // ── Botón Registrar pago ─────────────────
                                  _actionButton(
                                    label: 'Registrar pago', icon: Icons.add_card_rounded,
                                    bgColor: saldado ? azul.withOpacity(0.42) : azul,
                                    fgColor: Colors.white, isBusy: _btnPagoBusy,
                                    onPressed: () async {
                                      if (saldado) { HapticFeedback.selectionClick(); _showSaldadoBanner(); return; }
                                      if (_btnPagoBusy) return;
                                      HapticFeedback.lightImpact();
                                      setState(() => _btnPagoBusy = true);
                                      await _registrarPagoFlow(context);
                                      if (mounted) setState(() => _btnPagoBusy = false);
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  // ── Botón Ver historial ──────────────────
                                  _actionButton(
                                    label: 'Ver historial', icon: Icons.history_rounded,
                                    bgColor: verde, fgColor: Colors.white,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => HistorialScreen(
                                          idCliente: widget.id,
                                          nombreCliente: widget.nombreCompleto,
                                          producto: widget.producto,
                                        ),
                                      ));
                                    },
                                  ),

                                  const SizedBox(height: 10),

                                  // ── Botón WhatsApp ───────────────────────
                                  SizedBox(
                                    width: double.infinity,
                                    height: (screenH * 0.068).clamp(48.0, 58.0),
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: saldado ? const Color(0xFF94A3B8) : azul, width: 1.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        foregroundColor: saldado ? const Color(0xFF64748B) : azul,
                                        backgroundColor: Colors.white,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        if (saldado) { _showSaldadoBanner(); return; }
                                        _abrirMenuRecordatorio();
                                      },
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Opacity(opacity: saldado ? 0.5 : 1, child: _waIcon(size: 18)),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text('Recordatorio por WhatsApp',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: (screenW * 0.036).clamp(12.0, 15.0),
                                                  color: saldado ? const Color(0xFF64748B) : azul,
                                                )),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: botPad > 0 ? botPad : 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets auxiliares originales ──────────────────────────────────────
  Widget _rowStyled(String l, String v, TextStyle ls, TextStyle vs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: Text(l, style: ls)),
        const SizedBox(width: 8),
        Flexible(flex: 5, child: Text(v, style: vs, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _filaInfo(IconData icon, String texto, Color color, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 28, child: Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: color, size: 20))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto, maxLines: maxLines, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A), height: 1.3)),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SCROLL TUBE INDICATOR
// Barra vertical pegada al borde derecho de la tarjeta.
// Mitad de la altura de la pantalla, centrada, degradado arriba→abajo.
// Parpadea suavemente hasta que el usuario llega al final del scroll.
// ═══════════════════════════════════════════════════════════════════════════
class _ScrollTubeIndicator extends StatefulWidget {
  final double height;
  final Color colorTop;
  final Color colorBottom;

  const _ScrollTubeIndicator({
    required this.height,
    required this.colorTop,
    required this.colorBottom,
  });

  @override
  State<_ScrollTubeIndicator> createState() => _ScrollTubeIndicatorState();
}

class _ScrollTubeIndicatorState extends State<_ScrollTubeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.20, end: 0.90).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          width: 5,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.colorTop, widget.colorBottom],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colorBottom.withOpacity(0.35),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(-1, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}