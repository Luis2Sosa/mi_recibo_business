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
  static const double _contentTop = 230;

  late int _saldoActual;
  late DateTime _proximaFecha;
  bool _tieneCambios = false;

  int _totalPrestado = 0; // 👈 NUEVO acumulado

  // 👇 NUEVO: evita doble toque en “Registrar pago”
  bool _btnPagoBusy = false;

  @override
  void initState() {
    super.initState();
    _saldoActual = widget.saldoActual;
    _proximaFecha = widget.proximaFecha;
    Future.microtask(_autoFixEstado);
    Future.microtask(_cargarTotalPrestado); // 👈 lee/initializa totalPrestado
  }

  // ===== Formateo robusto de moneda (RD$) =====
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

  /// 🔧 **Autofix** mínimo: solo corrige flags "saldado" si hay saldo > 0.
  /// ❌ No mueve proximaFecha aquí (la fecha solo cambia al registrar un pago).
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

    if (_saldoActual > 0 && (saldado == true || (data['estado'] ?? '') == 'saldado')) {
      updates['saldado'] = false;
      updates['estado'] = 'al_dia';
      needsUpdate = true;
    }

    if (needsUpdate) {
      await ref.set(updates, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        // No tocamos _proximaFecha aquí.
      });
    }
  }
  // ====== /Autofix ======

  /// 👇 NUEVO: leer/inicializar el total prestado acumulado
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

      // Si existe totalPrestado se usa; si no, inicializamos con capitalInicial o saldoAnterior
      final int capitalInicial = (data['capitalInicial'] ?? 0) is int ? (data['capitalInicial'] ?? 0) : 0;
      final int fallbackSaldoAnterior = (data['saldoAnterior'] ?? 0) is int ? (data['saldoAnterior'] ?? 0) : 0;
      int total = 0;

      if (data.containsKey('totalPrestado')) {
        final dynamic raw = data['totalPrestado'];
        if (raw is int) total = raw;
        if (raw is double) total = raw.round();
      } else {
        total = capitalInicial > 0 ? capitalInicial : fallbackSaldoAnterior;
        // Inicializamos el campo en Firestore para futuras acumulaciones
        await ref.set({'totalPrestado': total, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _totalPrestado = total);
    } catch (_) {
      // Silencioso: si falla, dejamos 0 y la UI sigue
    }
  }

  /// 👇 NUEVO: usa esto cuando hagas una renovación/nuevo préstamo al cliente.
  /// Ejemplo de uso (en la pantalla donde otorgas el nuevo capital):
  /// await incrementarTotalPrestado(montoNuevo);
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

      // Refrescamos el valor local
      if (!mounted) return;
      setState(() => _totalPrestado += monto);
    } catch (_) {
      // Silencioso
    }
  }

  Future<Map<String, String>> _prestamistaSeguro() async {
    String empresa = widget.empresa.trim();
    String servidor = widget.servidor.trim();
    String telefono = widget.telefonoServidor.trim();

    if (empresa.isNotEmpty && servidor.isNotEmpty && telefono.isNotEmpty) {
      return {'empresa': empresa, 'servidor': servidor, 'telefono': telefono};
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'empresa': empresa, 'servidor': servidor, 'telefono': telefono};

    try {
      final snap = await FirebaseFirestore.instance.collection('prestamistas').doc(uid).get();
      final data = snap.data() ?? {};
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();

      empresa = empresa.isNotEmpty ? empresa : (data['empresa'] ?? '').toString().trim();
      servidor = servidor.isNotEmpty ? servidor : [nombre, apellido].where((s) => s.isNotEmpty).join(' ');
      telefono = telefono.isNotEmpty ? telefono : (data['telefono'] ?? '').toString().trim();
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
      // === TRANSACCIÓN: actualiza saldo, fecha y obtiene consecutivo atómico ===
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
          'estado' : saldoNuevo <= 0 ? 'saldado' : 'al_dia',
        }, SetOptions(merge: true));

        nextReciboFinal = next;
      });

      // === Registro de pago (fuera de la transacción) ===
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

      // === ACUMULAR HISTÓRICO: pagos/ganancias que NO se borran al eliminar clientes ===
      final metricsRef = FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      await metricsRef.set({
        'lifetimeRecuperado': FieldValue.increment(pagoCapital),   // capital devuelto
        'lifetimeGanancia'  : FieldValue.increment(pagoInteres),   // intereses cobrados
        'lifetimePagosSum'  : FieldValue.increment(totalPagado),   // suma de pagos
        'lifetimePagosCount': FieldValue.increment(1),             // cantidad de pagos
        'updatedAt'         : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));


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

    // ===== Tipos premium (solo UI) =====
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

    return Scaffold(
      body: AppGradientBackground(
        child: Stack(
          children: [
            // Logo al fondo
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

            // Contenido
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
                // 👇 QUITAMOS Expanded y envolvemos el contenido con Scroll
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
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre
                            Text(
                              widget.nombreCompleto,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Tel / Dirección / Producto
                            Text('Tel: ${widget.telefono}',
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827))),
                            if (widget.direccion != null && widget.direccion!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Dirección: ${widget.direccion}',
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827))),
                            ],
                            if (widget.producto.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Producto: ${widget.producto}',
                                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827))),
                            ],

                            const SizedBox(height: 16),
                            Divider(height: 24, thickness: 1, color: const Color(0xFFE7E9EE)),

                            // ==== Banda mint (incluye Total prestado) ====
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4FAF7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFDDE7E1)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Column(
                                children: [
                                  _rowStyled('Total prestado', _rd(_totalPrestado), labelStyle, valueStyle),
                                  Divider(height: 14, thickness: 1, color: const Color(0xFFE7F0EA)),

                                  _rowStyled('Saldo actual', _rd(_saldoActual), labelStyle, valueStyle),
                                  Divider(height: 14, thickness: 1, color: const Color(0xFFE7F0EA)),

                                  _rowStyled('Interés ${widget.periodo.toLowerCase()}', _rd(interesPeriodo), labelStyle, valueStyle),
                                  Divider(height: 14, thickness: 1, color: const Color(0xFFE7F0EA)),

                                  _rowStyled('Próxima fecha', _fmtFecha(_proximaFecha), labelStyle, valueStyle),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Botón principal
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  elevation: 2,
                                  shadowColor: const Color(0xFF2563EB).withOpacity(0.35),
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                                onPressed: _btnPagoBusy ? null : () async {
                                  HapticFeedback.lightImpact();
                                  setState(() => _btnPagoBusy = true);
                                  await _registrarPagoFlow(context);
                                  if (mounted) setState(() => _btnPagoBusy = false);
                                },
                                child: const Text('Registrar pago'),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Botón secundario
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
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Atrás (área táctil amplia)
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

  // ===== Helpers UI (no cambian lógica) =====
  Widget _rowStyled(String l, String v, TextStyle ls, TextStyle vs) {
    return Row(
      children: [
        Expanded(child: Text(l, style: ls)),
        Text(v, style: vs),
      ],
    );
  }

  // Mantengo tu helper original (por compatibilidad con otros usos)
  Widget _row(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
