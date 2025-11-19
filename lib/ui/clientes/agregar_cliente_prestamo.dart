// lib/clientes/agregar_cliente_prestamo_screen.dart

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
    this.initCapital,
    this.initTasa,
    this.initPeriodo,
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
    _capitalCtrl =
        TextEditingController(text: widget.initCapital?.toString() ?? '');
    _tasaCtrl =
        TextEditingController(text: widget.initTasa?.toString() ?? '');
    _periodo = widget.initPeriodo ?? 'Mensual';
    _proximaFecha = widget.initProximaFecha;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _notaCtrl.dispose();
    _capitalCtrl.dispose();
    _tasaCtrl.dispose();
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

  bool _isValidPhone(String raw) {
    final t = raw.trim();
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (RegExp(r'^(809|829|849)[0-9]{7}$').hasMatch(digits)) return true;
    if (RegExp(r'^1(809|829|849)[0-9]{7}$').hasMatch(digits)) return true;
    return RegExp(r'^[0-9]{8,15}$').hasMatch(digits);
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                        child: SingleChildScrollView(
                          child: _formBody(),
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

  Widget _formBody() {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                            color: Colors.black26,
                            blurRadius: 6,
                            offset: Offset(0, 2))
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Préstamo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _formContainer(),
        ],
      ),
    );
  }

  Widget _formContainer() {
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
      child: _formFields(),
    );
  }

  Widget _formFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Nombre', icon: Icons.person),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _apellidoCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: _deco('Apellido', icon: Icons.badge),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
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
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Obligatorio';
            return _isValidPhone(v.trim()) ? null : 'Número inválido';
          },
        ),

        const SizedBox(height: 8),
        TextFormField(
          controller: _direccionCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: _deco('Dirección (opcional)', icon: Icons.home),
        ),

        const SizedBox(height: 8),
        TextFormField(
          controller: _notaCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          decoration: _deco('Nota (opcional)', icon: Icons.note_alt_outlined),
        ),

        const SizedBox(height: 12),
        TextFormField(
          controller: _capitalCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _deco('Monto del préstamo (\$)', icon: Icons.payments),
          validator: (v) =>
          (v == null || v.isEmpty) ? 'Obligatorio' : null,
        ),

        const SizedBox(height: 12),
        TextFormField(
          controller: _tasaCtrl,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          ],
          decoration: _deco('% Interés', icon: Icons.percent),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Obligatorio';
            final x = double.tryParse(v.replaceAll(',', '.'));
            if (x == null) return 'Número inválido';
            if (x < 0 || x > 100) return 'Debe ser entre 0 y 100';
            return null;
          },
        ),

        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Período:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Mensual'),
              selected: _periodo == 'Mensual',
              onSelected: (_) => setState(() => _periodo = 'Mensual'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Quincenal'),
              selected: _periodo == 'Quincenal',
              onSelected: (_) => setState(() => _periodo = 'Quincenal'),
            ),
          ],
        ),

        const SizedBox(height: 12),
        _fechaSelector(),

        const SizedBox(height: 20),
        _btnGuardar(),
      ],
    );
  }

  Widget _fechaSelector() {
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

  Widget _btnGuardar() {
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

  // ============================================================
  //                     MÉTODO _guardar BLINDADO
  // ============================================================

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
    final direccion = _direccionCtrl.text.trim();
    final nota = _notaCtrl.text.trim();

    // --- BLINDAJE: parse seguro ---
    int _safeParseInt(String v) {
      if (v.isEmpty) return 0;
      final cleaned = v.replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned) ?? 0;
    }

    double _safeParseDouble(String v) {
      if (v.isEmpty) return 0.0;
      final cleaned = v.replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }

    final capital = _safeParseInt(_capitalCtrl.text);
    final tasa = _safeParseDouble(_tasaCtrl.text);

    final fechaProxima = _proximaFecha ?? DateTime.now();

    final data = {
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'direccion': direccion.isEmpty ? null : direccion,
      'nota': nota.isEmpty ? null : nota,

      'capitalInicial': capital,
      'saldoActual': capital,
      'tasaInteres': tasa,

      'periodo': _periodo,

      'proximaFecha': Timestamp.fromDate(_atNoon(fechaProxima)),
      'venceEl':
      "${fechaProxima.year}-${fechaProxima.month.toString().padLeft(2, '0')}-${fechaProxima.day.toString().padLeft(2, '0')}",

      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'tipo': 'prestamo',
      'estado': 'al_dia',

    };

    try {
      final metricRef = FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('metrics')
          .doc('summary');

      // ============================================================
      //                     MODO EDITAR
      // ============================================================
      if (_isEdit && widget.id != null) {
        final docAnterior = await clientesRef.doc(widget.id).get();
        final old = docAnterior.data() ?? {};

        final double capitalAnterior = (() {
          final raw = old['capitalInicial'];
          if (raw == null) return 0.0;
          if (raw is int) return raw.toDouble();
          if (raw is double) return raw;
          if (raw is String) return double.tryParse(raw) ?? 0.0;
          return 0.0;
        })();

        final estadoAnterior =
        (old['estado'] ?? '').toString().toLowerCase();

        await clientesRef.doc(widget.id).set(data, SetOptions(merge: true));

        final double capitalNuevo = capital.toDouble();
        final double diferencia = capitalNuevo - capitalAnterior;

        if (diferencia != 0) {
          await metricRef.set({
            'totalCapitalPrestado': FieldValue.increment(diferencia),
            'ultimaActualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        if (estadoAnterior.contains('saldado') && capitalNuevo > 0) {
          await metricRef.set({
            'totalCapitalPrestado': FieldValue.increment(capitalNuevo),
            'ultimaActualizacion': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      // ============================================================
      //                    MODO NUEVO CLIENTE
      // ============================================================
      else {
        await clientesRef.add(data);

        await metricRef.set({
          'totalCapitalPrestado': FieldValue.increment(capital.toDouble()),
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }

    // ============================================================
    //           NAVEGACIÓN + FINALIZACIÓN BLINDADA
    // ============================================================

    if (!mounted) return;

    try {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const ClientesScreen(initFiltro: 'prestamos'),
        ),
            (r) => false,
      );
    } catch (e) {
      debugPrint("Navigator error: $e");
    }

    if (mounted) {
      setState(() => _guardando = false);
    }
  }
}
