// 📂 lib/ui/clientes/agregar_cliente_producto_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../core/estadisticas_totales_service.dart';
import '../recibo_screen.dart';
import 'clientes_screen.dart';


// --- Formateador automático de teléfono ---
class TelefonoInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    var newText = '';
    for (int i = 0; i < text.length; i++) {
      newText += text[i];
      if (i == 2 || i == 5) newText += '-';
    }
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class AgregarClienteProductoScreen extends StatefulWidget {
  final String? id;
  final String? initNombre;
  final String? initApellido;
  final String? initTelefono;
  final String? initDireccion;
  final String? initNota;
  final String? initProducto;
  final int? initCapital;
  final double? initTasa;
  final String? initPeriodo;
  final DateTime? initProximaFecha;

  const AgregarClienteProductoScreen({
    super.key,
    this.id,
    this.initNombre,
    this.initApellido,
    this.initTelefono,
    this.initDireccion,
    this.initNota,
    this.initProducto,
    this.initCapital,
    this.initTasa,
    this.initPeriodo,
    this.initProximaFecha,
  });

  @override
  State<AgregarClienteProductoScreen> createState() =>
      _AgregarClienteProductoScreenState();
}

class _AgregarClienteProductoScreenState
    extends State<AgregarClienteProductoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notaCtrl = TextEditingController();
  final _pagoInicialCtrl = TextEditingController(text: '0');

  List<Map<String, TextEditingController>> _productos = [];

  double _gananciaTotal = 0;
  double _montoTotal = 0;
  DateTime? _proximaFecha;
  bool _guardando = false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text = widget.initNombre ?? '';
    _apellidoCtrl.text = widget.initApellido ?? '';
    _telefonoCtrl.text = widget.initTelefono ?? '';
    _direccionCtrl.text = widget.initDireccion ?? '';
    _notaCtrl.text = widget.initNota ?? '';
    _proximaFecha = widget.initProximaFecha;
    _agregarProducto();
  }

  void _agregarProducto() {
    setState(() {
      _productos.add({
        'nombre': TextEditingController(text: widget.initProducto ?? ''),
        'precioBase': TextEditingController(),
        'precioCliente': TextEditingController(),
      });
    });
  }

  void _calcularTotales() {
    double ganancia = 0;
    double total = 0;
    for (final prod in _productos) {
      final base = double.tryParse(prod['precioBase']!.text) ?? 0;
      final cliente = double.tryParse(prod['precioCliente']!.text) ?? 0;
      ganancia += (cliente - base);
      total += cliente;
    }
    setState(() {
      _gananciaTotal = ganancia;
      _montoTotal = total;
    });
  }

  InputDecoration _deco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF64748B)),
    floatingLabelStyle: const TextStyle(
      color: Color(0xFF2563EB),
      fontWeight: FontWeight.w600,
    ),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon != null ? Icon(icon, color: Color(0xFF94A3B8)) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

    // 🔹 Bordes finos y más transparentes (como en Préstamos)
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
  );


  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: h * 0.95),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: SingleChildScrollView(child: _formBody()),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formBody() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  _isEdit ? 'Editar Cliente' : 'Agregar Cliente',
                  style: GoogleFonts.playfairDisplay(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Productos / Fiados',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _formPrincipal(),
          const SizedBox(height: 18),
          _listaProductos(),
          const SizedBox(height: 22),
          _resumenTotales(),
          const SizedBox(height: 25),
          _fechaSection(),
          const SizedBox(height: 25),
          _botonGuardar(),
        ],
      ),
    );
  }

  Widget _formPrincipal() {
    return _tarjeta(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nombreCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Nombre', icon: Icons.person),
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Obligatorio' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _apellidoCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Apellido', icon: Icons.badge),
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Obligatorio' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefonoCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [TelefonoInputFormatter()],
            decoration: _deco('Teléfono', icon: Icons.call),
            validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _direccionCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: _deco('Dirección (opcional)', icon: Icons.home),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notaCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: _deco('Nota (opcional)', icon: Icons.note_alt_outlined),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _listaProductos() {
    return _tarjeta(
      colorFondo: Colors.white.withOpacity(0.95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Productos o Servicios',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontSize: 16)),
          const SizedBox(height: 12),
          for (int i = 0; i < _productos.length; i++) _productoCard(i),
          const SizedBox(height: 8),
          // 🟦 Botones de acción (Agregar / Quitar producto)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ➕ Agregar producto
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_productos.length >= 3) ? null : _agregarProducto,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                  label: const Text(
                    'Agregar producto',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 🔴 Quitar último producto (solo si hay más de uno)
              if (_productos.length > 1)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _productos.removeLast();
                        _calcularTotales();
                      });
                    },
                    icon: const Icon(Icons.remove_rounded, color: Colors.white),
                    label: const Text(
                      'Quitar último',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 6,
                    ),
                  ),
                ),
            ],
          ),


        ],
      ),
    );
  }

  Widget _productoCard(int index) {
    final prod = _productos[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextFormField(
            controller: prod['nombre'],
            decoration: _deco('Producto o Servicio', icon: Icons.local_offer),
            validator: (v) =>
            (v == null || v.isEmpty) ? 'Obligatorio' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: prod['precioBase'],
            keyboardType: TextInputType.number,
            decoration: _deco('Precio base (costo real)',
                icon: Icons.inventory_2_outlined),
            onChanged: (_) => _calcularTotales(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: prod['precioCliente'],
            keyboardType: TextInputType.number,
            decoration: _deco('Precio al cliente (venta total)',
                icon: Icons.attach_money_rounded),
            onChanged: (_) => _calcularTotales(),
          ),
        ],
      ),
    );
  }

  Widget _resumenTotales() {
    final pagoInicial = double.tryParse(_pagoInicialCtrl.text) ?? 0;
    final montoRestante = (_montoTotal - pagoInicial).clamp(0, 999999999);

    return _tarjeta(
      colorFondo: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Encabezado
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Color(0xFF2458D6)),
              const SizedBox(width: 8),
              Text(
                'Resumen del producto',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 💰 Ganancia estimada
          Row(
            children: [
              _iconLabel(Icons.trending_up_rounded, 'Ganancia estimada',
                  'RD\$${_gananciaTotal.toStringAsFixed(0)}',
                  color: const Color(0xFF2563EB)),
            ],
          ),
          const SizedBox(height: 10),

          // 💵 Monto total
          Row(
            children: [
              _iconLabel(Icons.account_balance_wallet_rounded, 'Monto total',
                  'RD\$${_montoTotal.toStringAsFixed(0)}',
                  color: const Color(0xFF0EA5E9)),
            ],
          ),
          const SizedBox(height: 10),

          // 💳 Pago inicial
          TextFormField(
            controller: _pagoInicialCtrl,
            keyboardType: TextInputType.number,
            decoration: _deco('Pago inicial (opcional)',
                icon: Icons.payments_outlined),
            onChanged: (_) => setState(() {}), // 👈 recalcula en vivo
          ),
          const SizedBox(height: 12),

          // 🧾 Monto restante
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF0284C7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Monto restante: RD\$${montoRestante.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0369A1),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// 🔹 Pequeño helper visual para no repetir estilo
  Widget _iconLabel(IconData icon, String label, String value,
      {Color color = Colors.black}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w500)),
                Text(value,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B))),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _fechaSection() {
    return _tarjeta(
      colorFondo: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _proximaFecha == null
                  ? 'Próxima fecha: (selecciona)'
                  : 'Próxima fecha: ${_proximaFecha!.day}/${_proximaFecha!.month}/${_proximaFecha!.year}',
              style: TextStyle(
                color: _proximaFecha == null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: const Text('Elegir'),
            onPressed: () async {
              final sel = await showDatePicker(
                context: context,
                initialDate: _proximaFecha ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (sel != null) {
                setState(() => _proximaFecha = sel);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required Widget child, Color? colorFondo}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorFondo ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: child,
    );
  }

  Widget _botonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2458D6),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        onPressed: _guardando ? null : _guardar,
        child: _guardando
            ? const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                )),
            SizedBox(width: 10),
            Text('Guardando...'),
          ],
        )
            : const Text('Guardar'),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proximaFecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la próxima fecha.')),
      );
      return;
    }

    setState(() => _guardando = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión expirada.')),
      );
      setState(() => _guardando = false);
      return;
    }

    final db = FirebaseFirestore.instance;
    final clientesRef =
    db.collection('prestamistas').doc(uid).collection('clientes');

    final pagoInicial = double.tryParse(_pagoInicialCtrl.text) ?? 0;
    final saldoActual = (_montoTotal - pagoInicial).clamp(0, 999999999);

    // 🔹 Calcular capital invertido real (solo el costo de los productos)
    double capitalInvertido = 0;
    for (final p in _productos) {
      final base = double.tryParse(p['precioBase']!.text) ?? 0;
      capitalInvertido += base;
    }
    final capital = capitalInvertido.toInt();

    // ========================================
// 🔹 Datos principales del cliente
// ========================================
    final data = {
      'tipo': 'producto',
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'producto': _productos.isNotEmpty
          ? _productos.first['nombre']!.text.trim()
          : '',
      'direccion': _direccionCtrl.text.trim().isEmpty
          ? null
          : _direccionCtrl.text.trim(),
      'nota': _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
      'productos': _productos.map((p) {
        return {
          'nombre': p['nombre']!.text.trim(),
          'precioBase':
          (double.tryParse(p['precioBase']!.text) ?? 0).toInt(),
          'precioCliente':
          (double.tryParse(p['precioCliente']!.text) ?? 0).toInt(),
        };
      }).toList(),

      // 🔹 Campos financieros
      'gananciaTotal': _gananciaTotal.toInt(),
      'ganancia': _gananciaTotal.toInt(),
      'montoTotal': _montoTotal.toInt(),
      'pagoInicial': pagoInicial.toInt(),
      'saldoActual': saldoActual.toInt(),
      'capitalInicial': capital,



      // 🔹 Fechas
      // 🔹 Fechas (MEDIODÍA PARA NOTIFICACIONES CORRECTAS)
      'proximaFecha': Timestamp.fromDate(
        DateTime(
          _proximaFecha!.year,
          _proximaFecha!.month,
          _proximaFecha!.day,
          12, // 🔥 Siempre mediodía
        ),
      ),
      'venceEl': _proximaFecha != null
          ? "${_proximaFecha!.year}-${_proximaFecha!.month.toString().padLeft(2, '0')}-${_proximaFecha!.day.toString().padLeft(2, '0')}"
          : null,


      // 🔹 Estado y timestamps
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };



    try {
      if (_isEdit && widget.id != null) {
        // ✅ Si estás editando, actualiza el cliente existente
        await clientesRef.doc(widget.id).update(data);
      } else {
        // ✅ Si es nuevo, crea un registro nuevo
        await clientesRef.add(data);

        // ✅ Registrar ganancia individual en “Ganancia por producto”
        final estadisticasProductoRef = db
            .collection('prestamistas')
            .doc(uid)
            .collection('estadisticas')
            .doc('producto')
            .collection('clientes_producto')
            .doc();

        await estadisticasProductoRef.set({
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          'ganancia': _gananciaTotal.toInt(),
          'montoTotal': _montoTotal.toInt(),
          'fechaRegistro': FieldValue.serverTimestamp(),
        });
      }

      // ========================================
      // 🔹 Actualizar métricas globales
      // ========================================
      await EstadisticasTotalesService.ensureStructure(uid);

      final summaryRef = db
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      await summaryRef.set({
        'totalCapitalInvertido': FieldValue.increment(capital),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

// 🔹 Si el cliente hizo un pago inicial, ir directo al recibo
      if (pagoInicial > 0) {
        final nuevoClienteRef = await clientesRef
            .where('telefono', isEqualTo: _telefonoCtrl.text.trim())
            .get();

        if (nuevoClienteRef.docs.isNotEmpty) {
          final clienteDoc = nuevoClienteRef.docs.last; // 👈 toma el último registro
          final clienteData = clienteDoc.data();
          final clienteId = clienteDoc.id;


// 🔹 Crear registro de pago inicial en el historial
          final pagoRef = clientesRef.doc(clienteId).collection('pagos').doc();

          await pagoRef.set({
            'fecha': FieldValue.serverTimestamp(),
            'pagoCapital': pagoInicial.toInt(),
            'pagoInteres': 0,
            'totalPagado': pagoInicial.toInt(),
            'saldoAnterior': clienteData['montoTotal'] ?? 0,
            'saldoNuevo': clienteData['saldoActual'] ?? 0,
            'moraCobrada': 0,
            'metodo': 'pago_inicial',
            'registradoAutomatico': true,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // 🔹 Registrar la fecha del primer pago (si aún no existe)
          await clientesRef.doc(clienteId).set({
            'primerPago': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));




          // === Ir al Recibo automáticamente ===
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ReciboScreen(
                empresa: "Mi Recibo Business",
                servidor:
                FirebaseAuth.instance.currentUser?.displayName ?? "Usuario",
                telefonoServidor: clienteData['telefono'] ?? '',
                cliente: "${clienteData['nombre']} ${clienteData['apellido']}",
                telefonoCliente: clienteData['telefono'] ?? '',
                producto: clienteData['producto'] ?? 'Producto',
                numeroRecibo:
                "AUTO-${DateTime.now().millisecondsSinceEpoch % 10000}",
                fecha: DateTime.now(),
                capitalInicial: clienteData['capitalInicial'] ?? 0,
                pagoInteres: 0,
                pagoCapital: pagoInicial.toInt(),
                totalPagado: pagoInicial.toInt(),
                saldoAnterior: clienteData['montoTotal'] ?? 0,
                saldoRestante: clienteData['saldoActual'] ?? 0,
                saldoActual: clienteData['saldoActual'] ?? 0,
                proximaFecha:
                (clienteData['proximaFecha'] as Timestamp).toDate(),
                tasaInteres: 0.0,
                esPrimerPago: true,

              ),
            ),
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const ClientesScreen(initFiltro: 'productos'),
            ),
                (r) => false,
          );
        }
      } else {
        // 🔹 Si no hay pago inicial, guardar y volver como siempre
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ClientesScreen(initFiltro: 'productos'),
          ),
              (r) => false,
        );
      }



    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (mounted) setState(() => _guardando = false);
  }


}
