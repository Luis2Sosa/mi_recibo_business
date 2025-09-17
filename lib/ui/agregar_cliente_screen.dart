import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';   // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';      // 👈 UID

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
  static const double _logoTop = -40;
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

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF2563EB)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

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
              // Logo
              Positioned(
                top: _logoTop, left: 0, right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: Image.asset(
                      'assets/images/logoB.png',
                      height: _logoHeight,
                      fit: BoxFit.contain,
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
                    bottom: bottomInset > 0 ? bottomInset + 12 : 50,
                    left: 16,
                    right: 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            child: Column(
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
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: _nombreCtrl,
                                                autofocus: true,
                                                decoration: _deco('Nombre'),
                                                textInputAction: TextInputAction.next,
                                                validator: (v) => (v == null || v.trim().isEmpty)
                                                    ? 'Obligatorio' : null,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller: _apellidoCtrl,
                                                decoration: _deco('Apellido'),
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
                                          decoration: _deco('Teléfono'),
                                          textInputAction: TextInputAction.next,
                                          validator: (v) => (v == null || v.trim().isEmpty)
                                              ? 'Obligatorio' : null,
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _direccionCtrl,
                                          decoration: _deco('Dirección (opcional)'),
                                          textInputAction: TextInputAction.next,
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _productoCtrl,
                                          decoration: _deco('Producto (opcional)'),
                                          textInputAction: TextInputAction.next,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: _capitalCtrl,
                                                keyboardType: TextInputType.number,
                                                decoration: _deco('Saldo inicial (RD\$)'),
                                                textInputAction: TextInputAction.next,
                                                validator: (v) => (v == null || v.isEmpty)
                                                    ? 'Obligatorio' : null,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: TextFormField(
                                                controller: _tasaCtrl,
                                                keyboardType: TextInputType.number,
                                                decoration: _deco('% Interés'),
                                                validator: (v) => (v == null || v.isEmpty)
                                                    ? 'Obligatorio' : null,
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

                                        // Fecha
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _proximaFecha == null
                                                    ? 'Próxima fecha: (automática)'
                                                    : 'Próxima fecha: ${_fmtFecha(_proximaFecha!)}',
                                                style: const TextStyle(color: Colors.black87),
                                              ),
                                            ),
                                            TextButton.icon(
                                              icon: const Icon(Icons.date_range),
                                              label: const Text('Elegir fecha'),
                                              onPressed: () async {
                                                final hoy = DateTime.now();
                                                final sel = await showDatePicker(
                                                  context: context,
                                                  initialDate: _proximaFecha ?? hoy,
                                                  firstDate: DateTime(hoy.year - 1),
                                                  lastDate: DateTime(hoy.year + 5),
                                                );
                                                if (sel != null) {
                                                  setState(() => _proximaFecha = sel);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Guardar
                                        SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2563EB),
                                              foregroundColor: Colors.white,
                                              shape: const StadiumBorder(),
                                              textStyle: const TextStyle(
                                                  fontSize: 16, fontWeight: FontWeight.w700),
                                              elevation: 0,
                                              shadowColor: Colors.transparent,
                                            ),
                                            onPressed: _guardando ? null : _guardar,
                                            child: Text(_guardando ? 'Guardando…' : 'Guardar'),
                                          ),
                                        ),
                                      ],
                                    ),
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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_guardando) return;
    setState(() => _guardando = true);

    final capital = int.tryParse(
      _capitalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    ) ?? 0;

    final tasa = double.tryParse(
      _tasaCtrl.text.replaceAll(',', '.'),
    ) ?? 0.0;

    _proximaFecha ??= DateTime.now().add(
      Duration(days: _periodo == 'Quincenal' ? 15 : 30),
    );

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
        // 🔧 EDITAR: si se pone un nuevo capital, el cliente vuelve a estar “al día”
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

        // 👇 Reseteo de estado/valores si el capital es > 0 (nuevo préstamo)
        update.addAll({
          'saldoAnterior': capital,
          'saldoActual'  : capital,
          'saldado'      : capital == 0,               // si pones 0 queda saldado
          'estado'       : capital == 0 ? 'saldado' : 'al_dia',
        });

        await col.doc(docId).set(update, SetOptions(merge: true));
      } else {
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