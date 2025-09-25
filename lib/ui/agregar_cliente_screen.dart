import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';      // 👈 UID
import 'package:flutter/services.dart';                // 👈 (para inputFormatters)

class AgregarClienteScreen extends StatefulWidget {
  final String? id;
  final String? initNombre;
  final String? initApellido;
  final String? initTelefono;
  final String? initDireccion;
  final String? initProducto;
  final int? initCapital;
  final double? initTasa;
  final String? initPeriodo; // 'Mensual' | 'Quincenal'
  final DateTime? initProximaFecha;

  const AgregarClienteScreen({
    super.key,
    this.id,
    this.initNombre,
    this.initApellido,
    this.initTelefono,
    this.initDireccion,
    this.initProducto,
    this.initCapital,
    this.initTasa,
    this.initPeriodo,
    this.initProximaFecha,
  });

  @override
  State<AgregarClienteScreen> createState() => _AgregarClienteScreenState();
}

class _AgregarClienteScreenState extends State<AgregarClienteScreen> {
  static const double _logoTop = -70;
  static const double _logoHeight = 300;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _productoCtrl;
  late final TextEditingController _capitalCtrl;
  late final TextEditingController _tasaCtrl;

  late String _periodo;
  DateTime? _proximaFecha;

  bool get _isEdit => widget.id != null;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl    = TextEditingController(text: widget.initNombre ?? '');
    _apellidoCtrl  = TextEditingController(text: widget.initApellido ?? '');
    _telefonoCtrl  = TextEditingController(text: widget.initTelefono ?? '');
    _direccionCtrl = TextEditingController(text: widget.initDireccion ?? '');
    _productoCtrl  = TextEditingController(text: widget.initProducto ?? '');
    _capitalCtrl   = TextEditingController(
      text: widget.initCapital != null ? widget.initCapital.toString() : '',
    );
    _tasaCtrl      = TextEditingController(
      text: widget.initTasa != null ? widget.initTasa.toString() : '',
    );
    _periodo       = widget.initPeriodo ?? 'Mensual';
    _proximaFecha  = widget.initProximaFecha;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _productoCtrl.dispose();
    _capitalCtrl.dispose();
    _tasaCtrl.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime d) {
    const meses = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  // 🔧 Solo estética: soporte opcional para ícono
  InputDecoration _deco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF64748B)),
    floatingLabelStyle: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8)) : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool tecladoAbierto = bottomInset > 0;
    final double h = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: false, // 👈 No empujar todo el Scaffold
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Logo (ahora con desvanecido cuando el teclado está abierto)
              Positioned(
                top: _logoTop, left: 0, right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: tecladoAbierto ? 0.15 : 1.0,
                      child: Image.asset(
                        'assets/images/logoB.png',
                        height: _logoHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // ======= MARCO PEGADO ABAJO =======
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: tecladoAbierto ? bottomInset + 12 : 10,
                    left: 16,
                    right: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // 👇 Más alto cuando NO hay teclado; 75% cuando hay teclado
                      maxHeight: tecladoAbierto ? h * 0.75 : h * 0.90,
                    ),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          // 👇 SOLO hay scroll cuando el teclado está abierto
                          // ✅ siempre hay scroll; cuando no hay teclado, no permite arrastrar
                          child: SingleChildScrollView(
                            physics: tecladoAbierto
                                ? const ClampingScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: _formBody(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Botón back
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

  /// ======= Contenido del formulario (sin cambios de lógica) =======
  Widget _formBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            _isEdit ? 'Editar Cliente' : 'Agregar Cliente',
            style: GoogleFonts.playfair(
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
                    offset: Offset(0, 2),
                  )
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Formulario
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction, // 👈 (5)
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words, // 👈 (3)
                        decoration: _deco('Nombre', icon: Icons.person),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoCtrl,
                        textCapitalization: TextCapitalization.words, // 👈 (3)
                        decoration: _deco('Apellido', icon: Icons.badge),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 👈 (2)
                  decoration: _deco('Teléfono', icon: Icons.call),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Obligatorio' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _direccionCtrl,
                  decoration: _deco('Dirección (opcional)', icon: Icons.home),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productoCtrl,
                  decoration: _deco('Producto (opcional)', icon: Icons.local_offer),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capitalCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 👈 (2)
                        decoration: _deco('Saldo inicial (RD\$)', icon: Icons.payments),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tasaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true), // 👈 (1)
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), // 👈 (1)
                        ],
                        decoration: _deco('% Interés', icon: Icons.percent),
                        validator: (v) { // 👈 (1)
                          if (v == null || v.isEmpty) return 'Obligatorio';
                          final x = double.tryParse(v.replaceAll(',', '.'));
                          if (x == null) return 'Número inválido';
                          if (x < 0 || x > 100) return 'Debe ser entre 0 y 100';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Período
                Row(
                  children: [
                    const Text('Período:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Mensual'),
                      selected: _periodo == 'Mensual',
                      onSelected: (_) => setState(() => _periodo = 'Mensual'),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: _periodo == 'Mensual' ? Colors.white : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: _periodo == 'Mensual'
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Quincenal'),
                      selected: _periodo == 'Quincenal',
                      onSelected: (_) => setState(() => _periodo = 'Quincenal'),
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: _periodo == 'Quincenal' ? Colors.white : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: _periodo == 'Quincenal'
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 10),

                // ===== Próxima fecha (OBLIGATORIA) =====
                Container(
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
                                fontWeight: _proximaFecha == null
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: const Text('Elegir fecha'),
                            onPressed: () async {
                              final hoy = DateTime.now();
                              final hoy0 = DateTime(hoy.year, hoy.month, hoy.day); // 👈 (4)
                              final sel = await showDatePicker(
                                context: context,
                                initialDate: _proximaFecha ?? hoy0,            // 👈 (4)
                                firstDate: hoy0,                                // 👈 (4) no fechas pasadas
                                lastDate: DateTime(hoy.year + 5),
                              );
                              if (sel != null) {
                                setState(() => _proximaFecha = sel);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                      if (_proximaFecha == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Debes elegir una próxima fecha de pago',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Guardar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                      elevation: 4,
                      shadowColor: const Color(0xFF2563EB).withOpacity(0.35),
                    ),
                    onPressed: (_guardando || _proximaFecha == null)
                        ? null
                        : _guardar,
                    child: Text(_guardando ? 'Guardando…' : 'Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== LÓGICA ORIGINAL – con validación de fecha obligatoria =====
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus(); // 👈 (6) ocultar teclado
    if (!_formKey.currentState!.validate()) return;
    if (_guardando) return;
    if (_proximaFecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la próxima fecha de pago.')),
      );
      return;
    }

    setState(() => _guardando = true);

    final capital = int.tryParse(
      _capitalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    ) ?? 0;

    final tasa = double.tryParse(
      _tasaCtrl.text.replaceAll(',', '.'),
    ) ?? 0.0;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesión expirada. Inicia sesión nuevamente.')),
      );
      setState(() => _guardando = false);
      return;
    }

    final col = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes');

    try {
      String? docId = widget.id;

      if (_isEdit && docId != null) {
        // 🔧 EDITAR (no cambia históricos)
        final Map<String, dynamic> update = {
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          'producto': _productoCtrl.text.trim().isEmpty ? null : _productoCtrl.text.trim(),
          'capitalInicial': capital,
          'tasaInteres': tasa,
          'periodo': _periodo,
          'proximaFecha': Timestamp.fromDate(_proximaFecha!),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        update.addAll({
          'saldoAnterior': capital,
          'saldoActual'  : capital,
          'saldado'      : capital == 0,
          'estado'       : capital == 0 ? 'saldado' : 'al_dia',
        });

        await col.doc(docId).set(update, SetOptions(merge: true));
      } else {
        // 👇 NUEVO: alta de cliente incrementa el histórico lifetimePrestado
        final tel = _telefonoCtrl.text.trim();
        final dup = await col.where('telefono', isEqualTo: tel).limit(1).get();
        if (dup.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ese cliente ya existe (teléfono duplicado).')),
          );
          setState(() => _guardando = false);
          return;
        }

        final newDoc = col.doc();
        docId = newDoc.id;
        await newDoc.set({
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          'telefono': tel,
          'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          'producto': _productoCtrl.text.trim().isEmpty ? null : _productoCtrl.text.trim(),
          'capitalInicial': capital,
          'saldoActual': capital,
          'saldoAnterior': capital,
          'saldado': capital == 0 ? true : false,
          'estado': capital == 0 ? 'saldado' : 'al_dia',
          'tasaInteres': tasa,
          'periodo': _periodo,
          'proximaFecha': Timestamp.fromDate(_proximaFecha!),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // === ACUMULAR HISTÓRICO: total prestado ===
        final metricsRef = FirebaseFirestore.instance
            .collection('prestamistas')
            .doc(uid)
            .collection('metrics')
            .doc('summary');

        await metricsRef.set({
          'lifetimePrestado': FieldValue.increment(capital),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Cliente actualizado ✅' : 'Cliente agregado ✅')),
      );

      Navigator.pop(context, {
        if (_isEdit) 'id': docId,
        'nombre': _nombreCtrl.text,
        'apellido': _apellidoCtrl.text,
        'telefono': _telefonoCtrl.text,
        'direccion': _direccionCtrl.text,
        'producto': _productoCtrl.text,
        'capital': capital,
        'tasa': tasa,
        'periodo': _periodo,
        'proximaFecha': _proximaFecha,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
      setState(() => _guardando = false);
      return;
    }

    if (mounted) setState(() => _guardando = false);
  }
}
