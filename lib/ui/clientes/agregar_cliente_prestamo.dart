// 📂 lib/clientes/agregar_cliente_prestamo_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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

class AgregarClientePrestamoScreen extends StatefulWidget {
  final String? id;
  final String? initNombre;
  final String? initApellido;
  final String? initTelefono;
  final String? initDireccion;
  final String? initNota;
  final String? initProducto;
  // --- Nombres corregidos para eliminar el error en clientes_screen ---
  final int? initCapital;
  final double? initTasa;
  final String? initPeriodo;
  final DateTime? initProximaFecha;

  const AgregarClientePrestamoScreen({
    super.key,
    this.id,
    this.initNombre,
    this.initApellido,
    this.initTelefono,
    this.initDireccion,
    this.initNota,
    this.initProducto,
    this.initCapital, // <--- Ahora sí coincide con tu otro archivo
    this.initTasa,    // <--- Ahora sí coincide con tu otro archivo
    this.initPeriodo, // <--- Ahora sí coincide con tu otro archivo
    this.initProximaFecha,
  });

  @override
  State<AgregarClientePrestamoScreen> createState() =>
      _AgregarClientePrestamoScreenState();
}

class _AgregarClientePrestamoScreenState
    extends State<AgregarClientePrestamoScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _notaCtrl;
  late final TextEditingController _capitalCtrl;
  late final TextEditingController _tasaCtrl;

  String _periodo = 'Mensual';
  DateTime? _proximaFecha;
  bool _guardando = false;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.initNombre ?? '');
    _apellidoCtrl = TextEditingController(text: widget.initApellido ?? '');
    _telefonoCtrl = TextEditingController(text: widget.initTelefono ?? '');
    _direccionCtrl = TextEditingController(text: widget.initDireccion ?? '');
    _notaCtrl = TextEditingController(text: widget.initNota ?? '');

    // Inicialización usando los nombres correctos del widget
    _capitalCtrl = TextEditingController(text: widget.initCapital?.toString() ?? '');
    _tasaCtrl = TextEditingController(text: widget.initTasa?.toString() ?? '');
    _periodo = widget.initPeriodo ?? 'Mensual';
    _proximaFecha = widget.initProximaFecha;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _apellidoCtrl.dispose(); _telefonoCtrl.dispose();
    _direccionCtrl.dispose(); _notaCtrl.dispose(); _capitalCtrl.dispose(); _tasaCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8), size: 20) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5)),
  );

  bool _isValidPhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length >= 10;
  }

  String _fmtFecha(DateTime d) {
    const meses = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2458D6),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 20),
                _formCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            ),
            const Spacer(),
          ],
        ),
        Text(
          _isEdit ? 'Editar Cliente' : 'Agregar Cliente',
          style: GoogleFonts.playfairDisplay(
            textStyle: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
          ),
        ),
        const Text('PRÉSTAMO', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12)),
      ],
    );
  }

  Widget _formCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: TextFormField(controller: _nombreCtrl, textCapitalization: TextCapitalization.sentences, decoration: _deco('Nombre', icon: Icons.person), validator: (v) => v!.isEmpty ? 'Obligatorio' : null)),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _apellidoCtrl, textCapitalization: TextCapitalization.sentences, decoration: _deco('Apellido', icon: Icons.badge), validator: (v) => v!.isEmpty ? 'Obligatorio' : null)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _telefonoCtrl, keyboardType: TextInputType.phone, inputFormatters: [TelefonoInputFormatter()], decoration: _deco('Teléfono', icon: Icons.call), validator: (v) => _isValidPhone(v!) ? null : 'Revisa el número'),
            const SizedBox(height: 12),
            TextFormField(controller: _direccionCtrl, decoration: _deco('Dirección (opcional)', icon: Icons.home)),
            const SizedBox(height: 12),
            TextFormField(controller: _notaCtrl, maxLines: 2, decoration: _deco('Nota adicional', icon: Icons.edit_note)),
            const Divider(height: 30),
            TextFormField(controller: _capitalCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _deco('Monto Prestado (\$)', icon: Icons.monetization_on), validator: (v) => v!.isEmpty ? 'Escribe el monto' : null),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tasaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: _deco('% Interés', icon: Icons.percent),
              validator: (v) {
                if (v!.isEmpty) return 'Obligatorio';
                final n = double.tryParse(v.replaceAll(',', '.'));
                if (n == null || n < 0) return 'Inválido';
                return null;
              },
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cobro:', style: TextStyle(fontWeight: FontWeight.bold)),
                ChoiceChip(label: const Text('Mensual'), selected: _periodo == 'Mensual', onSelected: (_) => setState(() => _periodo = 'Mensual')),
                ChoiceChip(label: const Text('Quincenal'), selected: _periodo == 'Quincenal', onSelected: (_) => setState(() => _periodo = 'Quincenal')),
              ],
            ),
            const SizedBox(height: 15),
            _fechaSelector(),
            const SizedBox(height: 25),
            _btnGuardar(),
          ],
        ),
      ),
    );
  }

  Widget _fechaSelector() {
    return InkWell(
      onTap: () async {
        final sel = await showDatePicker(context: context, initialDate: _proximaFecha ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
        if (sel != null) setState(() => _proximaFecha = sel);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14), border: Border.all(color: _proximaFecha == null ? Colors.red : Colors.transparent)),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 18, color: _proximaFecha == null ? Colors.red : Colors.blue),
            const SizedBox(width: 10),
            Text(_proximaFecha == null ? 'Elegir Próximo Pago' : 'Pago: ${_fmtFecha(_proximaFecha!)}', style: TextStyle(fontWeight: FontWeight.bold, color: _proximaFecha == null ? Colors.red : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _btnGuardar() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2458D6), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        onPressed: _guardando ? null : _guardar,
        child: _guardando ? const CircularProgressIndicator(color: Colors.white) : const Text('GUARDAR CLIENTE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate() || _proximaFecha == null) return;
    setState(() => _guardando = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final clientesRef = FirebaseFirestore.instance.collection('prestamistas').doc(uid).collection('clientes');
    final metricRef = FirebaseFirestore.instance.collection('prestamistas').doc(uid).collection('metrics').doc('summary');

    final int capital = int.tryParse(_capitalCtrl.text) ?? 0;
    final double tasa = double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0.0;

    final data = {
      'nombre': _nombreCtrl.text.trim(),
      'apellido': _apellidoCtrl.text.trim(),
      'telefono': _telefonoCtrl.text.trim(),
      'direccion': _direccionCtrl.text.trim(),
      'nota': _notaCtrl.text.trim(),
      'capitalInicial': capital,
      'saldoActual': capital,
      'tasaInteres': tasa,
      'periodo': _periodo,
      'proximaFecha': Timestamp.fromDate(_atNoon(_proximaFecha!)),
      'updatedAt': FieldValue.serverTimestamp(),
      'tipo': 'prestamo',
      'estado': 'al_dia',
    };

    try {
      if (_isEdit) {
        final doc = await clientesRef.doc(widget.id).get();
        final int capAnterior = doc.data()?['capitalInicial'] ?? 0;
        await clientesRef.doc(widget.id).update(data);
        await metricRef.set({'totalCapitalPrestado': FieldValue.increment((capital - capAnterior).toDouble())}, SetOptions(merge: true));
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await clientesRef.add(data);
        await metricRef.set({'totalCapitalPrestado': FieldValue.increment(capital.toDouble())}, SetOptions(merge: true));
      }
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const ClientesScreen(initFiltro: 'prestamos')), (r) => false);
    } catch (e) {
      setState(() => _guardando = false);
    }
  }
}