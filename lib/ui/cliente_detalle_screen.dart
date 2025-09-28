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

  // --------- Datos del prestamista ---------
  final String empresa;
  final String servidor;
  final String telefonoServidor;

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

  static const double _logoHeight = 350;
  static const double _logoTop = -80;
  static const double _contentTop = 140;

  late int _saldoActual;
  late DateTime _proximaFecha;
  bool _tieneCambios = false;
  int _totalPrestado = 0;
  bool _btnPagoBusy = false;

  // ✅ Nota opcional (leída de Firestore SIN tocar el constructor)
  String? _nota;

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _proximaFecha = widget.proximaFecha;
    Future.microtask(_autoFixEstado);
    Future.microtask(_cargarTotalPrestado);
    Future.microtask(_cargarNota); // <-- lee 'nota' si existe
  }

  String _rd(int v) {
    final f = NumberFormat.currency(
      locale: 'es_DO',
      symbol: 'RD\$',
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
      final int capitalInicial = (data['capitalInicial'] ?? 0) is int
          ? (data['capitalInicial'] ?? 0)
          : 0;
      final int fallbackSaldoAnterior = (data['saldoAnterior'] ?? 0) is int
          ? (data['saldoAnterior'] ?? 0)
          : 0;
      int total = 0;

      if (data.containsKey('totalPrestado')) {
        final dynamic raw = data['totalPrestado'];
        if (raw is int) total = raw;
        if (raw is double) total = raw.round();
      } else {
        total = capitalInicial > 0 ? capitalInicial : fallbackSaldoAnterior;
        await ref.set(
            {'totalPrestado': total, 'updatedAt': FieldValue.serverTimestamp()},
            SetOptions(merge: true));
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
    if (uid == null)
      return {'empresa': empresa, 'servidor': servidor, 'telefono': telefono};

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
      servidor.isNotEmpty ? servidor : [nombre, apellido].where((s) =>
      s.isNotEmpty).join(' ');
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
        builder: (_) =>
            PagoFormScreen(
              saldoAnterior: _saldoActual,
              tasaInteres: widget.tasaInteres,
              periodo: widget.periodo,
              proximaFecha: _proximaFecha,
            ),
      ),
    );
    if (result == null) return;

    final int pagoInteres = result['pagoInteres'] as int? ?? 0;
    final int pagoCapital = result['pagoCapital'] as int? ?? 0;
    final int totalPagado = result['totalPagado'] as int? ??
        (pagoInteres + pagoCapital);
    final int saldoAnterior = result['saldoAnterior'] as int? ?? _saldoActual;
    final int saldoNuevo = result['saldoNuevo'] as int? ?? _saldoActual;
    final DateTime prox = result['proximaFecha'] as DateTime? ?? _proximaFecha;

    final DateTime proxAlDia = _siguienteFechaAlDia(prox, widget.periodo);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sesión expirada. Inicia sesión de nuevo.')),
      );
      return;
    }

    final clienteRef = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(widget.id);

    int nextReciboFinal = 1;
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(clienteRef);
        final current = (snap.data()?['nextReciboCliente'] ?? 0) as int;
        final next = current + 1;

        tx.set(clienteRef, {
          'saldoActual': saldoNuevo,
          'proximaFecha': Timestamp.fromDate(proxAlDia),
          'updatedAt': FieldValue.serverTimestamp(),
          'nextReciboCliente': next,
          'saldado': saldoNuevo <= 0,
          'estado': saldoNuevo <= 0 ? 'saldado' : 'al_dia',
        }, SetOptions(merge: true));

        nextReciboFinal = next;
      });

      await clienteRef.collection('pagos').add({
        'fecha': FieldValue.serverTimestamp(),
        'pagoInteres': pagoInteres,
        'pagoCapital': pagoCapital,
        'totalPagado': totalPagado,
        'saldoAnterior': saldoAnterior,
        'saldoNuevo': saldoNuevo,
        'periodo': widget.periodo,
        'tasaInteres': widget.tasaInteres,
        'producto': widget.producto,
      });

      final metricsRef = FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      await metricsRef.set({
        'lifetimeRecuperado': FieldValue.increment(pagoCapital),
        'lifetimeGanancia': FieldValue.increment(pagoInteres),
        'lifetimePagosSum': FieldValue.increment(totalPagado),
        'lifetimePagosCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el pago: $e')),
      );
      return;
    }

    // 🔔 Notificaciones Plus
    NotificationsPlus.trigger('pago_ok');
    if (saldoNuevo <= 0) {
      NotificationsPlus.trigger('deuda_finalizada');
    }

    final prest = await _prestamistaSeguro();
    final numeroRecibo = 'REC-${nextReciboFinal.toString().padLeft(4, '0')}';

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReciboScreen(
              empresa: prest['empresa'] ?? widget.empresa,
              servidor: prest['servidor'] ?? widget.servidor,
              telefonoServidor: prest['telefono'] ?? widget.telefonoServidor,
              cliente: widget.nombreCompleto,
              telefonoCliente: widget.telefono,
              numeroRecibo: numeroRecibo,
              producto: widget.producto,
              fecha: DateTime.now(),
              capitalInicial: saldoAnterior,
              pagoInteres: pagoInteres,
              pagoCapital: pagoCapital,
              totalPagado: totalPagado,
              saldoAnterior: saldoAnterior,
              saldoActual: saldoNuevo,
              proximaFecha: proxAlDia,
            ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _saldoActual = saldoNuevo;
      _proximaFecha = proxAlDia;
      _tieneCambios = true;
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
    // Quita todo lo que no sea dígito
    return t.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Normaliza el número para WhatsApp:
  /// - Acepta formatos con o sin +, guiones, espacios, paréntesis, etc.
  /// - Si tiene 10 dígitos: asume NANP (RD/US/CA) y antepone '1'
  /// - Si tiene 11 dígitos y empieza con '1': OK (NANP)
  /// - Si tiene >= 11 con otro código de país (ej. 52, 57, etc. sin el +): OK
  /// - Si tiene 7–9 dígitos: inválido (faltaría código de país)
  String? _normalizarParaWhatsapp(String telefono) {
    final digits = _limpiarTelefono(telefono);
    if (digits.isEmpty) return null;

    if (digits.length == 10) {
      // 10 dígitos (RD/US/CA) → anteponer 1
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
          'Número inválido. Agrega el código de país (ej. 1 para RD/EE.UU.).');
      return;
    }

    // App normal
    final uriApp = Uri.parse(
        'whatsapp://send?phone=$normalized&text=${Uri.encodeComponent(
            mensaje)}');
    // App Business (si la tienen instalada)
    final uriBiz = Uri.parse(
        'whatsapp-business://send?phone=$normalized&text=${Uri.encodeComponent(
            mensaje)}');
    // Fallback web
    final uriWeb = Uri.parse(
        'https://wa.me/$normalized?text=${Uri.encodeComponent(mensaje)}');

    try {
      if (await canLaunchUrl(uriApp)) {
        final ok = await launchUrl(
            uriApp, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (await canLaunchUrl(uriBiz)) {
        final ok = await launchUrl(
            uriBiz, mode: LaunchMode.externalApplication);
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

  // ✨ Mensajes “premium” cortos y claros para enviar por whatsapp
  String _mensajeRecordatorio(String tipo) {
    // tipo: 'vencido' | 'hoy' | 'manana' | 'dos_dias' | 'aldia'
    final nombre = widget.nombreCompleto;
    final fecha = _fmtFecha(_proximaFecha);
    final saldo = _rd(_saldoActual);

    switch (tipo) {
      case 'vencido':
        return 'Hola $nombre, tienes un pago vencido desde $fecha. Saldo: $saldo. ¿Coordinamos hoy?';
      case 'hoy':
        return 'Hola $nombre, tu pago vence HOY ($fecha). Saldo: $saldo. Avísame para pasar a cobrar.';
      case 'manana':
        return 'Hola $nombre, tu pago vence MAÑANA ($fecha). Saldo: $saldo. Quedo atento(a).';
      case 'dos_dias':
        return 'Hola $nombre, tu pago vence en 2 días ($fecha). Saldo: $saldo.';
      case 'aldia':
        return 'Hola $nombre, estás al día ✅. Próxima fecha: $fecha. ¡Gracias por tu puntualidad!';
      default:
        return 'Hola $nombre.';
    }
  }

  // ====== VALIDACIÓN DE ESTADO PARA HABILITAR / BLOQUEAR EL ENVÍO ======
  int _diasHasta(DateTime d) {
    final hoy = _soloFecha(DateTime.now());
    final dd = _soloFecha(d);
    return dd
        .difference(hoy)
        .inDays; // <0 vencido, 0 hoy, 1 mañana, 2 dos días, >2 al día
  }

  bool _permiteRecordatorio(String tipo) {
    final d = _diasHasta(_proximaFecha);
    final deuda = _saldoActual > 0;

    switch (tipo) {
      case 'vencido':
        return deuda && d < 0; // solo si ya está vencido
      case 'hoy':
        return deuda && d == 0; // solo si vence hoy
      case 'manana':
        return deuda && d == 1; // solo si vence mañana
      case 'dos_dias':
        return deuda && d == 2; // solo si vence en 2 días
      case 'aldia':
        return !deuda || d > 2; // al día: sin deuda o faltan >2 días
      default:
        return false;
    }
  }

  // 🔔 Banner “premium” cuando el recordatorio NO corresponde
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
            color: const Color(0xFFFEF3C7), // amarillo suave premium
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

  // Mini toast premium reutilizable
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

  // =====================================================

  void _abrirMenuRecordatorio() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF9FAFB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        Widget item(String title, String tipo,
            {IconData icon = Icons.schedule}) {
          return ListTile(
            leading: Icon(icon, color: Colors.black87, size: 26),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            trailing: _waIcon(size: 24),
            onTap: () async {
              Navigator.pop(context);

              // ✅ Bloqueo inteligente: solo permite si corresponde al estado real
              if (!_permiteRecordatorio(tipo)) {
                _avisoNoCorresponde();
                return;
              }

              final msg = _mensajeRecordatorio(tipo);
              await _enviarPorWhatsApp(widget.telefono, msg);
            },
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Enviar recordatorio',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Divider(),
                item('Pago vencido', 'vencido',
                    icon: Icons.warning_amber_rounded),
                const Divider(height: 0),
                item('Vence hoy', 'hoy', icon: Icons.event_available),
                const Divider(height: 0),
                item('Vence mañana', 'manana', icon: Icons.access_time),
                const Divider(height: 0),
                item('Vence en 2 días', 'dos_dias', icon: Icons.schedule),
                const Divider(height: 0),
                item('Al día', 'aldia', icon: Icons.check_circle),
              ],
            ),
          ),
        );
      },
    );
  }

  // =======================
  @override
  Widget build(BuildContext context) {
    final interesPeriodo = (_saldoActual * (widget.tasaInteres / 100)).round();

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

    // 🎯 Todos los textos de la izquierda en negro
    final labelInk = labelStyle.copyWith(color: const Color(0xFF0F172A));

    const azul = Color(0xFF2563EB);
    const verde = Color(0xFF22C55E);
    final saldoColor = _saldoActual > 0 ? Colors.red : verde;

    final valueBlue = valueStyle.copyWith(color: azul);
    final valueSaldo = valueStyle.copyWith(color: saldoColor);
    final valueGreen = valueStyle.copyWith(color: const Color(0xFF22C55E));
    final valueInk = valueStyle.copyWith(color: const Color(0xFF0F172A));

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
                    style: GoogleFonts.playfair(
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      // 👇 Ajuste para que el marco se adapte al contenido
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                // Estírate al alto disponible, pero permite crecer si hay más contenido
                                minHeight: constraints.maxHeight,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.nombreCompleto,
                                    style: GoogleFonts.inter(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),

                                  Text(
                                    'Tel: ${widget.telefono}',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF000000),
                                    ),
                                  ),
                                  if (widget.direccion != null &&
                                      widget.direccion!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Dirección: ${widget.direccion}',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF000000),
                                      ),
                                    ),
                                  ],

                                  // ✅ Nota opcional (si existe en Firestore)
                                  if ((_nota ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Nota: $_nota',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF000000),
                                      ),
                                    ),
                                  ],

                                  if (widget.producto
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Producto: ${widget.producto}',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF000000),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 16),
                                  Divider(height: 24,
                                      thickness: 1,
                                      color: const Color(0xFFE7E9EE)),

                                  Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF4FAF7),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: const Color(0xFFDDE7E1)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Column(
                                      children: [
                                        _rowStyled('Total histórico',
                                            _rd(_totalPrestado), labelInk,
                                            valueBlue),
                                        Divider(height: 14,
                                            thickness: 1,
                                            color: const Color(0xFFE7F0EA)),

                                        _rowStyled('Saldo actual pendiente',
                                            _rd(_saldoActual), labelInk,
                                            valueSaldo),
                                        Divider(height: 14,
                                            thickness: 1,
                                            color: const Color(0xFFE7F0EA)),

                                        _rowStyled(
                                          'Interés ${widget.periodo
                                              .toLowerCase()}',
                                          _rd((_saldoActual *
                                              (widget.tasaInteres / 100))
                                              .round()),
                                          labelInk,
                                          valueGreen,
                                        ),
                                        Divider(height: 14,
                                            thickness: 1,
                                            color: const Color(0xFFE7F0EA)),

                                        _rowStyled(
                                          'Próxima fecha',
                                          _fmtFecha(_proximaFecha),
                                          labelInk,
                                          valueInk,
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        elevation: 2,
                                        shadowColor: const Color(0xFF2563EB)
                                            .withOpacity(0.35),
                                        backgroundColor: const Color(
                                            0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                        textStyle: const TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      onPressed: _btnPagoBusy
                                          ? null
                                          : () async {
                                        HapticFeedback.lightImpact();
                                        setState(() => _btnPagoBusy = true);
                                        await _registrarPagoFlow(context);
                                        if (mounted) setState(() =>
                                        _btnPagoBusy = false);
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
                                        backgroundColor: const Color(
                                            0xFF22C55E),
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                        textStyle: const TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.w700),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                HistorialScreen(
                                                  idCliente: widget.id,
                                                  nombreCliente: widget
                                                      .nombreCompleto,
                                                  producto: widget.producto,
                                                ),
                                          ),
                                        );
                                      },
                                      child: const Text('Ver historial'),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // 🚀 Enviar recordatorio (WhatsApp only)
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: OutlinedButton.icon(
                                      icon: _waIcon(size: 22),
                                      label: const Text(
                                          'Enviar recordatorio por WhatsApp'),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                            color: Color(0xFF2563EB), width: 2),
                                        shape: const StadiumBorder(),
                                        foregroundColor: const Color(
                                            0xFF2563EB),
                                        textStyle: const TextStyle(fontSize: 16,
                                            fontWeight: FontWeight.w800),
                                      ),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        _abrirMenuRecordatorio();
                                      },
                                    ),
                                  ),
                                ],
                              ),
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
                    child: Icon(
                        Icons.arrow_back, color: Colors.white, size: 28),
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

