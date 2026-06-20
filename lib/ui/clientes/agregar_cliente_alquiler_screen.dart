// 📂 lib/ui/clientes/agregar_cliente_alquiler_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'clientes_screen.dart';
import 'widgets/phone_country_field.dart';

class AgregarClienteAlquilerScreen extends StatefulWidget {
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

  const AgregarClienteAlquilerScreen({
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
  State<AgregarClienteAlquilerScreen> createState() =>
      _AgregarClienteAlquilerScreenState();
}

class _AgregarClienteAlquilerScreenState
    extends State<AgregarClienteAlquilerScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _notaCtrl;
  late final TextEditingController _inmuebleCtrl;
  late final TextEditingController _montoCtrl;

  bool _moraEnabled  = false;
  String _moraTipo   = 'porcentaje';
  double _moraValor  = 10;

  DateTime? _proximaFecha;
  bool _guardando = false;
  CountryCode _selectedCountry = kCountryCodes.first; // 🇩🇴 por defecto

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl    = TextEditingController(text: widget.initNombre ?? '');
    _apellidoCtrl  = TextEditingController(text: widget.initApellido ?? '');
    _telefonoCtrl  = TextEditingController(text: widget.initTelefono ?? '');
    _direccionCtrl = TextEditingController(text: widget.initDireccion ?? '');
    _notaCtrl      = TextEditingController(text: widget.initNota ?? '');
    _inmuebleCtrl  = TextEditingController(text: widget.initProducto ?? '');
    _montoCtrl     = TextEditingController(
        text: widget.initCapital?.toString() ?? '');
    _proximaFecha  = widget.initProximaFecha;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _notaCtrl.dispose();
    _inmuebleCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF64748B)),
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

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.all(16),
                child:
                SingleChildScrollView(child: _formBody()),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formBody() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Text(
            _isEdit ? 'Editar Cliente' : 'Agregar Cliente',
            style: GoogleFonts.playfairDisplay(
              textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const Text('ALQUILER',
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22)),
            padding: const EdgeInsets.all(16),
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
                        v!.isEmpty ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _deco('Apellido', icon: Icons.badge),
                        validator: (v) =>
                        v!.isEmpty ? 'Obligatorio' : null,
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
                  decoration:
                  _deco('Dirección', icon: Icons.home_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inmuebleCtrl,
                  decoration: _deco('Inmueble / Propiedad',
                      icon: Icons.house_rounded),
                  validator: (v) =>
                  v!.isEmpty ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _deco('Monto mensual (\$)',
                      icon: Icons.payments_rounded),
                  validator: (v) =>
                  v!.isEmpty ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notaCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration:
                  _deco('Nota o detalles', icon: Icons.edit_note),
                ),
                const SizedBox(height: 14),
                _moraSection(),
                const SizedBox(height: 16),
                _fechaSection(),
                const SizedBox(height: 20),
                _btnGuardar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moraSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Mora por atraso',
                      style: TextStyle(fontWeight: FontWeight.w700))),
              Switch.adaptive(
                  value: _moraEnabled,
                  activeColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _moraEnabled = v)),
            ],
          ),
          if (_moraEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                    label: const Text('Porcentaje'),
                    selected: _moraTipo == 'porcentaje',
                    onSelected: (_) =>
                        setState(() => _moraTipo = 'porcentaje')),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('Monto fijo'),
                    selected: _moraTipo == 'fijo',
                    onSelected: (_) =>
                        setState(() => _moraTipo = 'fijo')),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _moraValor.toString(),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: _deco(
                  _moraTipo == 'porcentaje' ? 'Mora (%)' : 'Mora (\$)'),
              onChanged: (v) =>
              _moraValor =
                  double.tryParse(v.replaceAll(',', '.')) ?? 0,
            ),
          ],
        ],
      ),
    );
  }

  Widget _fechaSection() {
    return InkWell(
      onTap: () async {
        final sel = await showDatePicker(
            context: context,
            initialDate: _proximaFecha ?? DateTime.now(),
            firstDate: DateTime.now(),
            lastDate: DateTime(2100));
        if (sel != null) setState(() => _proximaFecha = sel);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _proximaFecha == null
                  ? Colors.red
                  : const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Icon(Icons.date_range,
                color:
                _proximaFecha == null ? Colors.red : Colors.blue),
            const SizedBox(width: 10),
            Text(
              _proximaFecha == null
                  ? 'Elegir Próxima Fecha'
                  : 'Pago: ${_fmtFecha(_proximaFecha!)}',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _proximaFecha == null
                      ? Colors.red
                      : Colors.black87),
            ),
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
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2458D6),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15))),
        onPressed: _guardando ? null : _guardar,
        child: _guardando
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('GUARDAR ALQUILER',
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

    final clientesRef = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes');

    final monto = int.tryParse(
        _montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;

    final data = {
      'nombre':    _nombreCtrl.text.trim(),
      'apellido':  _apellidoCtrl.text.trim(),
      'telefono':  _telefonoCtrl.text.trim(),
      'telefonoE164':
      buildE164(_selectedCountry.dialCode, _telefonoCtrl.text),
      'direccion': _direccionCtrl.text.trim(),
      'nota':      _notaCtrl.text.trim(),
      'producto':  _inmuebleCtrl.text.trim(),
      'capitalInicial': monto,
      'saldoActual':    monto,
      'tipo':    'alquiler',
      'periodo': 'Mensual',
      'proximaFecha': Timestamp.fromDate(DateTime(
          _proximaFecha!.year,
          _proximaFecha!.month,
          _proximaFecha!.day,
          12)),
      'updatedAt': FieldValue.serverTimestamp(),
      'mora': _moraEnabled
          ? {'tipo': _moraTipo, 'valor': _moraValor}
          : null,
    };

    try {
      if (_isEdit) {
        await clientesRef.doc(widget.id).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await clientesRef.add(data);
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) =>
              const ClientesScreen(initFiltro: 'alquiler')),
              (r) => false,
        );
      }
    } catch (e) {
      setState(() => _guardando = false);
    }
  }
}