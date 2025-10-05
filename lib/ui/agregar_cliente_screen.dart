import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';      // 👈 UID
import 'package:flutter/services.dart';                 // 👈 (inputFormatters)

class AgregarClienteScreen extends StatefulWidget {
  final String? id;
  final String? initNombre;
  final String? initApellido;
  final String? initTelefono;
  final String? initDireccion;
  final String? initNota;           // 👈 NUEVO
  final String? initProducto;
  final int? initCapital;
  final double? initTasa;
  final String? initPeriodo;        // 'Mensual' | 'Quincenal'
  final DateTime? initProximaFecha;

  const AgregarClienteScreen({
    super.key,
    this.id,
    this.initNombre,
    this.initApellido,
    this.initTelefono,
    this.initDireccion,
    this.initNota,                  // 👈 NUEVO (opcional)
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
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _notaCtrl;          // 👈 NUEVO
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
    _notaCtrl      = TextEditingController(text: widget.initNota ?? '');   // 👈 NUEVO
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
    _notaCtrl.dispose();                                          // 👈 NUEVO
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

  // 👇 Normaliza a 12:00 p. m. para evitar líos de zona horaria
  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

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

  // === helpers teléfono (igual que tenías) ===
  String _cleanDigits(String raw) {
    final t = raw.trim();
    final hasPlus = t.startsWith('+');
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    return hasPlus ? '+$digits' : digits;
  }

  bool _isValidPhone(String raw) {
    final t = raw.trim();
    final cleaned = _cleanDigits(t);
    if (cleaned.startsWith('+')) {
      final digits = cleaned.substring(1);
      return RegExp(r'^[0-9]{8,15}$').hasMatch(digits);
    }
    if (RegExp(r'^(809|829|849)[0-9]{7}$').hasMatch(cleaned)) return true;
    if (RegExp(r'^1(809|829|849)[0-9]{7}$').hasMatch(cleaned)) return true;
    return RegExp(r'^[0-9]{8,15}$').hasMatch(cleaned);
  }

  String _formatPhoneForStorage(String raw) {
    final t = raw.trim();
    final hasPlus = t.startsWith('+');
    final onlyDigits = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.length == 11 &&
        onlyDigits.startsWith('1') &&
        RegExp(r'^(809|829|849)$').hasMatch(onlyDigits.substring(1, 4))) {
      final area = onlyDigits.substring(1, 4);
      final pref = onlyDigits.substring(4, 7);
      final line = onlyDigits.substring(7, 11);
      return '$area-$pref-$line';
    }
    if (onlyDigits.length == 10 &&
        RegExp(r'^(809|829|849)$').hasMatch(onlyDigits.substring(0, 3))) {
      final area = onlyDigits.substring(0, 3);
      final pref = onlyDigits.substring(3, 6);
      final line = onlyDigits.substring(6, 10);
      return '$area-$pref-$line';
    }
    if (hasPlus) return '+$onlyDigits';
    if (onlyDigits.length == 10) {
      return '${onlyDigits.substring(0,3)}-'
          '${onlyDigits.substring(3,6)}-'
          '${onlyDigits.substring(6)}';
    }
    return onlyDigits;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool tecladoAbierto = bottomInset > 0;
    final double h = MediaQuery.of(context).size.height;

    // 👇 corrige posible padding negativo
    final safeBottomPadding = tecladoAbierto ? (bottomInset - 25).clamp(0.0, double.infinity) : 26.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              // (logo eliminado)

              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(
                    bottom: safeBottomPadding,
                    left: 16,
                    right: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: tecladoAbierto ? h * 0.75 : h * 0.96,
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
                          // ✅ un solo scroll (se quita el anidado)
                          child: SingleChildScrollView(
                            physics: tecladoAbierto
                                ? const AlwaysScrollableScrollPhysics()
                                : const NeverScrollableScrollPhysics(),
                            child: _formBody(),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            _isEdit ? 'Editar Cliente' : 'Agregar Cliente',
            style: GoogleFonts.playfairDisplay(
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: _deco('Nombre', icon: Icons.person),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: _deco('Apellido', icon: Icons.badge),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s\(\)]'))],
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
                  decoration: _deco('Dirección (opcional)', icon: Icons.home),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                // 👇 NUEVO CAMPO: NOTA (opcional, multilinea)
                TextFormField(
                  controller: _notaCtrl,
                  decoration: _deco('Nota (opcional)', icon: Icons.note_alt_outlined),
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _productoCtrl,
                  decoration: _deco('Producto (opcional)', icon: Icons.local_offer),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capitalCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _deco('Saldo inicial (RD\$)', icon: Icons.payments),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _tasaCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        decoration: _deco('% Interés', icon: Icons.percent),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obligatorio';
                          final x = double.tryParse(v.replaceAll(',', '.'));
                          if (x == null) return 'Número inválido';
                          if (x < 0 || x > 100) return 'Debe ser entre 0 y 100';
                          return null;
                        },
                        textInputAction: TextInputAction.done,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Text('Período:', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        color: _periodo == 'Mensual' ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
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
                        color: _periodo == 'Quincenal' ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 10),

                // Próxima fecha (obligatoria)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _proximaFecha == null ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
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
                                color: _proximaFecha == null ? const Color(0xFFEF4444) : const Color(0xFF374151),
                                fontWeight: _proximaFecha == null ? FontWeight.w700 : FontWeight.w400,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.date_range),
                            label: const Text('Elegir fecha'),
                            onPressed: () async {
                              final hoy = DateTime.now();
                              final hoy0 = DateTime(hoy.year, hoy.month, hoy.day);
                              final sel = await showDatePicker(
                                context: context,
                                initialDate: _proximaFecha ?? hoy0,
                                firstDate: hoy0,
                                lastDate: DateTime(hoy.year + 5),
                              );
                              if (sel != null) setState(() => _proximaFecha = sel);
                            },
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                      if (_proximaFecha == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            'Debes elegir una próxima fecha de pago',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      elevation: 4,
                      shadowColor: const Color(0xFF2563EB).withOpacity(0.35),
                    ),
                    onPressed: (_guardando || _proximaFecha == null) ? null : _guardar,
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

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_guardando) return;
    if (_proximaFecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la próxima fecha de pago.')),
      );
      setState(() => _guardando = false);
      return;
    }

    setState(() => _guardando = true);

    // ✅ Validación y normalización profesional del teléfono ANTES de guardar
    final rawTel = _telefonoCtrl.text.trim();
    if (!_isValidPhone(rawTel)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Número de teléfono inválido.')),
      );
      setState(() => _guardando = false);
      return;
    }
    final finalTel = _formatPhoneForStorage(rawTel);
    final initialTelFormatted = _formatPhoneForStorage(widget.initTelefono ?? '');

    final capital = int.tryParse(_capitalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final tasa = double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final nota = _notaCtrl.text.trim();                              // 👈 NUEVO

    // 👇 normaliza fechas al mediodía
    final DateTime venceElDate = _atNoon(_proximaFecha!);
    final DateTime proximaDate = _atNoon(_proximaFecha!);

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
        // 📞 Validar duplicado si el teléfono cambió
        if (finalTel != initialTelFormatted) {
          final dup = await col.where('telefono', isEqualTo: finalTel).limit(1).get();
          if (dup.docs.isNotEmpty && dup.docs.first.id != docId) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ese teléfono ya está asignado a otro cliente.')),
            );
            setState(() => _guardando = false);
            return;
          }
        }

        // ✂️ En edición: NO sobrescribir saldos/estado/venceEl
        final Map<String, dynamic> update = {
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          'nombreCompleto': '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}',
          'telefono': finalTel,
          'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          'nota'     : nota.isEmpty ? null : nota,
          'producto' : _productoCtrl.text.trim().isEmpty ? null : _productoCtrl.text.trim(),
          'capitalInicial': capital,
          'tasaInteres': tasa,
          'periodo': _periodo,
          'proximaFecha': Timestamp.fromDate(proximaDate),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        await col.doc(docId).set(update, SetOptions(merge: true));
      } else {
        // creación: validar duplicado
        final dup = await col.where('telefono', isEqualTo: finalTel).limit(1).get();
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
          'nombreCompleto': '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}',
          'telefono': finalTel,
          'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          'nota'     : nota.isEmpty ? null : nota,                   // 👈 NUEVO
          'producto' : _productoCtrl.text.trim().isEmpty ? null : _productoCtrl.text.trim(),
          'capitalInicial': capital,
          'saldoActual': capital,
          'saldoAnterior': capital,
          'saldado': capital == 0 ? true : false,
          'estado': capital == 0 ? 'saldado' : 'al_dia',
          'tasaInteres': tasa,
          'periodo': _periodo,
          'proximaFecha': Timestamp.fromDate(proximaDate),
          // 👇 agrega/borra venceEl automáticamente SOLO en creación
          'venceEl': capital == 0
              ? FieldValue.delete()
              : Timestamp.fromDate(venceElDate),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

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

      Navigator.pop(context, {
        if (_isEdit) 'id': docId,
        'nombre': _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
        'apellido': _apellidoCtrl.text.trim().isEmpty ? null : _apellidoCtrl.text.trim(),
        'telefono': finalTel.isEmpty ? null : finalTel,
        'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
        'nota': nota.isEmpty ? null : nota,                           // 👈 consistente con persistencia
        'producto': _productoCtrl.text.trim().isEmpty ? null : _productoCtrl.text.trim(),
        'capital': capital,
        'tasa': tasa,
        'periodo': _periodo,
        'proximaFecha': proximaDate,
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
