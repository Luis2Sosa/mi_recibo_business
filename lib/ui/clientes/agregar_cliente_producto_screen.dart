// lib/ui/clientes/agregar_cliente_producto_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../core/estadisticas_totales_service.dart';
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
    prefixIcon:
    icon != null ? Icon(icon, color: const Color(0xFF94A3B8)) : null,
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
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
                  padding: const EdgeInsets.symmetric(horizontal: 5),
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
                        padding: const EdgeInsets.all(16),
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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                      fontSize: 26,
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
          const SizedBox(height: 16),
          _formPrincipal(),
          const SizedBox(height: 16),
          _listaProductos(),
          const SizedBox(height: 16),
          _resumenTotales(),
          const SizedBox(height: 20),
          _fechaSection(),
          const SizedBox(height: 20),
          _botonGuardar(),
        ],
      ),
    );
  }

  Widget _formPrincipal() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Productos o Servicios',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.white, size: 28),
              onPressed: _agregarProducto,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (int i = 0; i < _productos.length; i++) _productoCard(i),
      ],
    );
  }

  Widget _productoCard(int index) {
    final prod = _productos[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
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
                icon: Icons.inventory_2_rounded),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ganancia estimada: \$${_gananciaTotal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Monto total: \$${_montoTotal.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pagoInicialCtrl,
            keyboardType: TextInputType.number,
            decoration:
            _deco('Pago inicial (opcional)', icon: Icons.price_check),
          ),
        ],
      ),
    );
  }

  Widget _fechaSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _proximaFecha == null
              ? const Color(0xFFEF4444)
              : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
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
                    : const Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            icon: const Icon(Icons.date_range),
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

  Widget _botonGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2458D6),
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.3),
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
          'precioBase': (double.tryParse(p['precioBase']!.text) ?? 0).toInt(),
          'precioCliente':
          (double.tryParse(p['precioCliente']!.text) ?? 0).toInt(),
        };
      }).toList(),
      'gananciaTotal': _gananciaTotal.toInt(),
      'montoTotal': _montoTotal.toInt(),
      'pagoInicial': pagoInicial.toInt(),
      'saldoActual': saldoActual.toInt(),
      'capitalInicial': _montoTotal.toInt(),
      'periodo': widget.initPeriodo ?? 'Mensual',
      'proximaFecha': Timestamp.fromDate(_proximaFecha!),
      'estado': saldoActual <= 0 ? 'saldado' : 'al_dia',
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
      }


      // 🔹 Calcula los valores para las estadísticas
      final ganancia = _gananciaTotal.toInt();

// 🔹 Calcular capital invertido real (solo el precio base de cada producto)
      double capitalInvertido = 0;
      for (final p in _productos) {
        final base = double.tryParse(p['precioBase']!.text) ?? 0;
        capitalInvertido += base;
      }
      final capital = capitalInvertido.toInt();

// ✅ Asegurar estructura base
      await EstadisticasTotalesService.ensureStructure(uid);

// ✅ Actualizar métricas globales (solo inversión)
      final summaryRef = db
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      await summaryRef.set({
        'totalCapitalInvertido': FieldValue.increment(capital),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

// ✅ Registrar solo una vez la ganancia neta del producto
      await EstadisticasTotalesService.adjustCategoria(
        uid,
        'producto',
        gananciaNetaDelta: ganancia,
      );


      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ClientesScreen(initFiltro: 'productos'),
        ),
            (r) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    if (mounted) setState(() => _guardando = false);
  }

}
