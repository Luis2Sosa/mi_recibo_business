// lib/clientes/agregar_cliente_alquiler_screen.dart

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
      if (i == 2 || i == 5) newText += '-'; // agrega guiones automáticamente
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}


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

  bool _moraEnabled = false;
  String _moraTipo = 'porcentaje';
  double _moraValor = 10;
  bool _mora15 = true, _mora30 = false;

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
    _inmuebleCtrl = TextEditingController(text: widget.initProducto ?? '');
    _montoCtrl =
        TextEditingController(text: widget.initCapital?.toString() ?? '');
    _proximaFecha = widget.initProximaFecha;
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
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
    ),
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
                const Text('Alquiler de inmuebles',
                    style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
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
                  inputFormatters: [
                    TelefonoInputFormatter(), // 👈 agrega los guiones automáticos
                  ],
                  decoration: _deco('Teléfono', icon: Icons.call),
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _direccionCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                  _deco('Dirección (opcional)', icon: Icons.home_rounded),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notaCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Nota (opcional)',
                      icon: Icons.note_alt_outlined),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _inmuebleCtrl,
                  decoration: _deco('Inmueble / Propiedad',
                      icon: Icons.house_rounded),
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _montoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _deco('Monto mensual (\$)',
                      icon: Icons.payments_rounded),
                  validator: (v) =>
                  (v == null || v.isEmpty) ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 14),
                _moraSection(),
                const SizedBox(height: 16),
                _fechaSection(),
                const SizedBox(height: 20),
                SizedBox(
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moraSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mora por atraso',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Switch.adaptive(
                value: _moraEnabled,
                activeColor: const Color(0xFF2563EB), // Azul cuando está encendido
                inactiveTrackColor: Colors.grey.shade400, // Fondo gris visible cuando está apagado
                inactiveThumbColor: Colors.grey.shade200, // Botón gris claro
                onChanged: (v) => setState(() => _moraEnabled = v),
              ),
            ],
          ),
          if (_moraEnabled) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Porcentaje'),
                  selected: _moraTipo == 'porcentaje',
                  onSelected: (_) => setState(() => _moraTipo = 'porcentaje'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Monto fijo'),
                  selected: _moraTipo == 'fijo',
                  onSelected: (_) => setState(() => _moraTipo = 'fijo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _moraValor.toString(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
              ],
              decoration: _deco(_moraTipo == 'porcentaje'
                  ? 'Valor de mora (%)'
                  : 'Valor de mora (monto)'),
              onChanged: (v) =>
              _moraValor = double.tryParse(v.replaceAll(',', '.')) ?? 0,
            ),
            const SizedBox(height: 8),
            const Text('Aplicar si pasan:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: const Text('15 días'),
                  selected: _mora15,
                  onSelected: (s) => setState(() => _mora15 = s),
                ),
                FilterChip(
                  label: const Text('30 días'),
                  selected: _mora30,
                  onSelected: (s) => setState(() => _mora30 = s),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fechaSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _proximaFecha == null
                      ? 'Próxima fecha: (selecciona)'
                      : 'Próxima fecha: ${_fmtFecha(_proximaFecha!)}',
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
          if (_proximaFecha == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Debes elegir una fecha de pago',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
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

    final clientesRef = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes');

    final nombre = _nombreCtrl.text.trim();
    final apellido = _apellidoCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();
    final inmueble = _inmuebleCtrl.text.trim();
    final direccion = _direccionCtrl.text.trim();
    final nota = _notaCtrl.text.trim();
    final monto =
        int.tryParse(_montoCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    final data = {
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'direccion': direccion.isEmpty ? null : direccion,
      'nota': nota.isEmpty ? null : nota,
      'producto': inmueble,
      'capitalInicial': monto,
      'saldoActual': monto,
      'esArriendo': true,
      'periodo': 'Mensual',
      'proximaFecha': Timestamp.fromDate(_proximaFecha!),
      'mora': _moraEnabled
          ? {
        'tipo': _moraTipo,
        'valor': _moraValor,
        'umbralesDias': [
          if (_mora15) 15,
          if (_mora30) 30,
        ],
      }
          : null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'estado': 'al_dia',
    };

    try {
      if (_isEdit && widget.id != null) {
        // 🔹 Actualiza si ya existe el cliente
        await clientesRef.doc(widget.id).update(data);
      } else {
        // 🔹 Crea uno nuevo si no existe
        await clientesRef.add(data);
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ClientesScreen(initFiltro: 'alquiler'),
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
