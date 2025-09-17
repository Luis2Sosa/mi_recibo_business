import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';      // 👈 UID
import 'pago_form_screen.dart';
import 'recibo_screen.dart';
import 'historial_screen.dart';
import 'widgets/app_frame.dart'; // <-- ruta desde lib/ui/

class ClienteDetalleScreen extends StatefulWidget {
  // --------- Datos del cliente ---------
  final String id;              // docId interno (para Firestore)
  final String codigo;          // 👈 código corto visible (ID-1, ID-2…)
  final String nombreCompleto;
  final String telefono;
  final String? direccion;

  final int saldoActual;
  final double tasaInteres;
  final String periodo;
  final DateTime proximaFecha;

  // 👉 producto del préstamo/venta
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
  static const double _logoHeight = 350;
  static const double _logoTop = -20;
  static const double _contentTop = 310;

  late int _saldoActual;
  late DateTime _proximaFecha;
  bool _tieneCambios = false;

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _proximaFecha = widget.proximaFecha;

    // 👇 Autofix: si quedó "saldado" pero ya tiene nuevo capital, lo ponemos al día.
    // (Se hace en segundo plano y sin tocar el diseño)
    Future.microtask(_autoFixEstado);
  }

  String _rd(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return 'RD\$${buf.toString().split('').reversed.join()}';
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  // ====== Fechas y período ======
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

  /// 🔧 **Autofix** de estado:
  /// - Si tiene saldoActual > 0, nos aseguramos de que NO esté marcado como saldado.
  /// - Si la próxima fecha está vencida o es hoy, la movemos al siguiente ciclo.
  Future<void> _autoFixEstado() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(widget.id);

    // Leemos lo mínimo para decidir
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final bool saldado = (data['saldado'] == true);
    DateTime prox = _proximaFecha;

    bool needsUpdate = false;
    final Map<String, dynamic> updates = {};

    // Si tiene saldo > 0, debe estar "al_dia"
    if (_saldoActual > 0 && (saldado == true || (data['estado'] ?? '') == 'saldado')) {
      updates['saldado'] = false;
      updates['estado'] = 'al_dia';
      needsUpdate = true;
    }

    // Si la próxima fecha está vencida o es hoy, la adelantamos
    final DateTime proxAlDia = _siguienteFechaAlDia(prox, widget.periodo);
    if (proxAlDia != prox) {
      updates['proximaFecha'] = Timestamp.fromDate(proxAlDia);
      prox = proxAlDia;
      needsUpdate = true;
    }

    if (needsUpdate) {
      await ref.set(updates, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _proximaFecha = prox;
      });
    }
  }
  // ====== /Autofix ======

  /// ✅ Forzar datos del prestamista si vienen vacíos
  Future<Map<String, String>> _prestamistaSeguro() async {
    String empresa = widget.empresa.trim();
    String servidor = widget.servidor.trim();
    String telefono = widget.telefonoServidor.trim();

    if (empresa.isNotEmpty && servidor.isNotEmpty && telefono.isNotEmpty) {
      return {
        'empresa': empresa,
        'servidor': servidor,
        'telefono': telefono,
      };
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {
        'empresa': empresa,
        'servidor': servidor,
        'telefono': telefono,
      };
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .get();

      final data = snap.data() ?? {};
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();

      empresa = empresa.isNotEmpty ? empresa : (data['empresa'] ?? '').toString().trim();
      servidor = servidor.isNotEmpty ? servidor : [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
      telefono = telefono.isNotEmpty ? telefono : (data['telefono'] ?? '').toString().trim();
    } catch (_) {
      // si falla la lectura, devolvemos lo que tengamos
    }

    return {
      'empresa': empresa,
      'servidor': servidor,
      'telefono': telefono,
    };
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

    final DateTime proxAlDia = _siguienteFechaAlDia(prox, widget.periodo);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión expirada. Inicia sesión de nuevo.')),
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
      await clienteRef.set({
        'saldoActual': saldoNuevo,
        'proximaFecha': Timestamp.fromDate(proxAlDia),
        'updatedAt': FieldValue.serverTimestamp(),
        'nextReciboCliente': FieldValue.increment(1),
        // 👇 Si quedó en 0, marcamos saldado; si no, al día
        'saldado': saldoNuevo <= 0,
        'estado' : saldoNuevo <= 0 ? 'saldado' : 'al_dia',
      }, SetOptions(merge: true));

      final snapFinal = await clienteRef.get();
      nextReciboFinal = (snapFinal.data()?['nextReciboCliente'] ?? 1) as int;

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar el pago: $e')),
      );
      return;
    }

    final prest = await _prestamistaSeguro();
    final numeroRecibo = 'REC-${nextReciboFinal.toString().padLeft(4, '0')}';

    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final interesPeriodo = (_saldoActual * (widget.tasaInteres / 100)).round();

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
                child: Expanded(
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.nombreCompleto,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Tel: ${widget.telefono}',
                                style: const TextStyle(fontSize: 14)),
                            if (widget.direccion != null &&
                                widget.direccion!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Dirección: ${widget.direccion}',
                                  style: const TextStyle(fontSize: 14)),
                            ],
                            if (widget.producto.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Producto: ${widget.producto}',
                                  style: const TextStyle(fontSize: 14)),
                            ],
                            const Divider(height: 28),
                            _row('Saldo actual', _rd(_saldoActual)),
                            const SizedBox(height: 8),
                            _row('Interés ${widget.periodo.toLowerCase()}',
                                _rd(interesPeriodo)),
                            const SizedBox(height: 8),
                            _row('Próxima fecha', _fmtFecha(_proximaFecha)),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => _registrarPagoFlow(context),
                                child: const Text('Registrar pago'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF22C55E),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HistorialScreen(
                                        idCliente: widget.id,
                                        nombreCliente: widget.nombreCompleto,
                                        producto: widget.producto, // ✅ agregado aquí
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Ver historial'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _onBack,
              ),
            ),
          ],
        ),
      ),
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