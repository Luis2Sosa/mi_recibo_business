// 📂 lib/ui/clientes/agregar_cliente_producto_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../core/estadisticas_totales_service.dart';
import '../recibo_screen.dart';
import 'clientes_screen.dart';
import 'widgets/phone_country_field.dart';

class AgregarClienteProductoScreen extends StatefulWidget {
  final String? id;
  final String? initNombre;
  final String? initApellido;
  final String? initTelefono;
  final String? initDireccion;
  final String? initNota;
  final String? initProducto;
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
    this.initProximaFecha,
  });

  @override
  State<AgregarClienteProductoScreen> createState() =>
      _AgregarClienteProductoScreenState();
}

class _AgregarClienteProductoScreenState
    extends State<AgregarClienteProductoScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl    = TextEditingController();
  final _apellidoCtrl  = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _notaCtrl      = TextEditingController();
  final _pagoInicialCtrl = TextEditingController(text: '0');

  List<Map<String, TextEditingController>> _productos = [];

  double _gananciaTotal = 0;
  double _montoTotal    = 0;
  DateTime? _proximaFecha;
  bool _guardando = false;
  CountryCode _selectedCountry = kCountryCodes.first; // 🇩🇴 por defecto

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl.text    = widget.initNombre ?? '';
    _apellidoCtrl.text  = widget.initApellido ?? '';
    _telefonoCtrl.text  = widget.initTelefono ?? '';
    _direccionCtrl.text = widget.initDireccion ?? '';
    _notaCtrl.text      = widget.initNota ?? '';
    _proximaFecha       = widget.initProximaFecha;
    _agregarProducto();
  }

  void _agregarProducto() {
    setState(() {
      _productos.add({
        'nombre': TextEditingController(
            text: _productos.isEmpty ? (widget.initProducto ?? '') : ''),
        'precioBase':    TextEditingController(),
        'precioCliente': TextEditingController(),
      });
    });
  }

  void _calcularTotales() {
    double ganancia = 0;
    double total    = 0;
    for (final prod in _productos) {
      final base    = double.tryParse(prod['precioBase']!.text)    ?? 0;
      final cliente = double.tryParse(prod['precioCliente']!.text) ?? 0;
      ganancia += (cliente - base);
      total    += cliente;
    }
    setState(() {
      _gananciaTotal = ganancia;
      _montoTotal    = total;
    });
  }

  InputDecoration _deco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF64748B)),
    floatingLabelStyle: const TextStyle(
        color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon != null
        ? Icon(icon, color: const Color(0xFF94A3B8))
        : null,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
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
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child:
                        SingleChildScrollView(child: _formBody()),
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
                        fontWeight: FontWeight.w600),
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
          // Nombre + Apellido
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

          // Teléfono con selector de país
          PhoneWithCountryField(
            controller: _telefonoCtrl,
            initialCountry: _selectedCountry,
            decoBuilder: _deco,
            onCountryChanged: (c) =>
                setState(() => _selectedCountry = c),
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _direccionCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration:
            _deco('Dirección (opcional)', icon: Icons.home),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notaCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration:
            _deco('Nota (opcional)', icon: Icons.note_alt_outlined),
            maxLines: 2,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_productos.length >= 3)
                      ? null
                      : _agregarProducto,
                  icon: const Icon(Icons.add_rounded,
                      color: Colors.white),
                  label: const Text('Agregar',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25))),
                ),
              ),
              if (_productos.length > 1) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() {
                      _productos.removeLast();
                      _calcularTotales();
                    }),
                    icon: const Icon(Icons.remove_rounded,
                        color: Colors.white),
                    label: const Text('Quitar',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25))),
                  ),
                ),
              ]
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
          border: Border.all(color: const Color(0xFFE2E8F0))),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          TextFormField(
            controller: prod['nombre'],
            decoration: _deco('Producto', icon: Icons.local_offer),
            validator: (v) =>
            (v == null || v.isEmpty) ? 'Obligatorio' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: prod['precioBase'],
                  keyboardType: TextInputType.number,
                  decoration: _deco('Costo'),
                  onChanged: (_) => _calcularTotales(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: prod['precioCliente'],
                  keyboardType: TextInputType.number,
                  decoration: _deco('Venta'),
                  onChanged: (_) => _calcularTotales(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resumenTotales() {
    final pagoInicial  = double.tryParse(_pagoInicialCtrl.text) ?? 0;
    final montoRestante =
    (_montoTotal - pagoInicial).clamp(0, 999999999);
    return _tarjeta(
      child: Column(
        children: [
          _iconLabel(Icons.trending_up_rounded, 'Ganancia estimada',
              'RD\$${_gananciaTotal.toStringAsFixed(0)}',
              color: Colors.blue),
          const SizedBox(height: 10),
          _iconLabel(Icons.account_balance_wallet_rounded, 'Monto total',
              'RD\$${_montoTotal.toStringAsFixed(0)}',
              color: Colors.cyan),
          const SizedBox(height: 10),
          TextFormField(
            controller: _pagoInicialCtrl,
            keyboardType: TextInputType.number,
            decoration:
            _deco('Pago inicial', icon: Icons.payments_outlined),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: const Color(0xFFBAE6FD))),
            child: Text(
              'Monto restante: RD\$${montoRestante.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Color(0xFF0369A1),
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconLabel(IconData icon, String label, String value,
      {Color color = Colors.black}) {
    return Row(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _fechaSection() {
    return _tarjeta(
      colorFondo: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _proximaFecha == null
                  ? 'Selecciona fecha de pago'
                  : 'Fecha: ${_proximaFecha!.day}/${_proximaFecha!.month}/${_proximaFecha!.year}',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _proximaFecha == null
                      ? Colors.red
                      : Colors.black87),
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
                  lastDate: DateTime(2100));
              if (sel != null) setState(() => _proximaFecha = sel);
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
          borderRadius: BorderRadius.circular(24)),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30))),
        onPressed: _guardando ? null : _guardar,
        child: _guardando
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('GUARDAR',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _proximaFecha == null)
      return;
    setState(() => _guardando = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final db = FirebaseFirestore.instance;
    final clientesRef = db
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes');

    final pagoInicial = double.tryParse(_pagoInicialCtrl.text) ?? 0;
    final saldoActual =
    (_montoTotal - pagoInicial).clamp(0, 999999999);

    double costoTotal = 0;
    for (final p in _productos) {
      costoTotal +=
      (double.tryParse(p['precioBase']!.text) ?? 0);
    }

    final data = {
      'tipo': 'producto',
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'telefonoE164':
      buildE164(_selectedCountry.dialCode, _telefonoCtrl.text),
      'producto': _productos.isNotEmpty
          ? _productos.first['nombre']!.text.trim()
          : 'Producto',
      'direccion': _direccionCtrl.text.trim(),
      'nota': _notaCtrl.text.trim(),
      'productos': _productos
          .map((p) => {
        'nombre': p['nombre']!.text.trim(),
        'precioBase':
        (double.tryParse(p['precioBase']!.text) ?? 0).toInt(),
        'precioCliente':
        (double.tryParse(p['precioCliente']!.text) ?? 0)
            .toInt(),
      })
          .toList(),
      'ganancia':     _gananciaTotal.toInt(),
      'montoTotal':   _montoTotal.toInt(),
      'saldoActual':  saldoActual.toInt(),
      'pagoInicial':  pagoInicial.toInt(),
      'capitalInicial': costoTotal.toInt(),
      'proximaFecha': Timestamp.fromDate(DateTime(
          _proximaFecha!.year,
          _proximaFecha!.month,
          _proximaFecha!.day,
          12)),
      'updatedAt': FieldValue.serverTimestamp(),
      'tasa':    null,
      'cuota':   null,
      'periodo': 'Venta Directa',
    };

    try {
      DocumentReference docRef;
      if (_isEdit) {
        docRef = clientesRef.doc(widget.id);
        await docRef.set(data, SetOptions(merge: false));
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        docRef = await clientesRef.add(data);
      }

      if (pagoInicial > 0) {
        await docRef.collection('pagos').add({
          'fecha':           FieldValue.serverTimestamp(),
          'pagoCapital':     pagoInicial.toInt(),
          'pagoInteres':     0,
          'totalPagado':     pagoInicial.toInt(),
          'saldoAnterior':   _montoTotal.toInt(),
          'saldoNuevo':      saldoActual.toInt(),
          'metodo':          'pago_inicial',
          'registradoAutomatico': true,
          'createdAt':       FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ReciboScreen(
              empresa:         "Mi Recibo Business",
              servidor:        FirebaseAuth.instance.currentUser
                  ?.displayName ??
                  "Usuario",
              telefonoServidor: "809-000-0000",
              cliente:         "${_nombreCtrl.text} ${_apellidoCtrl.text}",
              telefonoCliente: _telefonoCtrl.text,
              producto:        _productos.isNotEmpty
                  ? _productos.first['nombre']!.text
                  : "Producto",
              numeroRecibo:
              "INI-${DateTime.now().millisecondsSinceEpoch % 10000}",
              fecha:           DateTime.now(),
              capitalInicial:  costoTotal.toInt(),
              pagoInteres:     0,
              pagoCapital:     pagoInicial.toInt(),
              totalPagado:     pagoInicial.toInt(),
              saldoAnterior:   _montoTotal.toInt(),
              saldoRestante:   saldoActual.toInt(),
              saldoActual:     saldoActual.toInt(),
              proximaFecha:    _proximaFecha!,
              tasaInteres:     0.0,
              esPrimerPago:    true,
            ),
          ),
        );
      } else {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) =>
                const ClientesScreen(initFiltro: 'productos')),
                (r) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}