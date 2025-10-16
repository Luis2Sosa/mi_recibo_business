// lib/agregar_cliente_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// 👇 Para saber en qué módulo estamos (Préstamos / Productos / Alquiler)
import 'clientes/clientes_shared.dart';

class AgregarClienteScreen extends StatefulWidget {
  // Módulo actual: controla la UI y las reglas del guardado
  final FiltroClientes modulo;

  // --- Parámetros opcionales para editar ---
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

  const AgregarClienteScreen({
    super.key,
    required this.modulo,
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
  State<AgregarClienteScreen> createState() => _AgregarClienteScreenState();
}

class _AgregarClienteScreenState extends State<AgregarClienteScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _notaCtrl;
  late final TextEditingController _productoCtrl;
  late final TextEditingController _capitalCtrl;
  late final TextEditingController _tasaCtrl;

  late String _periodo;
  DateTime? _proximaFecha;

  bool get _isEdit => widget.id != null;
  bool _guardando = false;

  // ===== Helpers de módulo =====
  bool get _esPrestamo => widget.modulo == FiltroClientes.prestamos;
  bool get _esProducto => widget.modulo == FiltroClientes.productos;
  bool get _esAlquiler => widget.modulo == FiltroClientes.alquiler;

  String get _moduloLabel {
    switch (widget.modulo) {
      case FiltroClientes.prestamos:
        return 'Préstamo';
      case FiltroClientes.productos:
        return 'Productos';
      case FiltroClientes.alquiler:
        return 'Alquiler';
    }
  }

  // === Mora (solo para Alquiler) ===
  bool _moraEnabled = false;             // visible; apagado por defecto
  String _moraTipo = 'porcentaje';       // 'porcentaje' | 'fijo'
  double _moraValor = 10;                // 10% o monto fijo
  bool _mora15 = true, _mora30 = false;  // solo 15 y 30; 15 activo por defecto

  // === Hint flotante (consejo) ===
  final LayerLink _hintLink = LayerLink();
  OverlayEntry? _hintEntry;
  bool _hintMostrado = false;

  void _showProductoHint([double keyboardInset = 0]) {
    if (_hintMostrado || _esPrestamo) return; // solo tiene sentido si hay Producto/Alquiler
    _hintMostrado = true;

    _hintEntry = OverlayEntry(
      builder: (context) {
        double opacity = 0.5;
        Offset offset = const Offset(0, .04);
        return StatefulBuilder(
          builder: (context, setLocal) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setLocal(() {
                opacity = 1.0;
                offset = Offset.zero;
              });
            });

            return IgnorePointer(
              ignoring: true,
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: (keyboardInset > 0 ? keyboardInset : MediaQuery.of(context).viewInsets.bottom) + 24,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      offset: offset,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        opacity: opacity,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 360),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF1B3CA9), Color(0xFF0A5F4F)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Colors.white70),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _esProducto
                                        ? 'Aquí van fiados y alquileres cortos (vehículos/equipos por días o semanas). '
                                        'Para alquiler mensual de inmueble usa la pestaña Alquiler.'
                                        : 'Completa los datos del alquiler mensual de inmueble. '
                                        'El interés no aplica; puedes activar la mora.',

                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    final overlay = Overlay.of(context);
    if (_hintEntry != null && overlay != null) {
      overlay.insert(_hintEntry!);
      Future.delayed(const Duration(milliseconds: 2500), () {
        _hintEntry?.remove();
        _hintEntry = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.initNombre ?? '');
    _apellidoCtrl = TextEditingController(text: widget.initApellido ?? '');
    _telefonoCtrl = TextEditingController(text: widget.initTelefono ?? '');
    _direccionCtrl = TextEditingController(text: widget.initDireccion ?? '');
    _notaCtrl = TextEditingController(text: widget.initNota ?? '');
    _productoCtrl = TextEditingController(text: widget.initProducto ?? '');
    _capitalCtrl = TextEditingController(
      text: widget.initCapital != null ? widget.initCapital.toString() : '',
    );
    _tasaCtrl = TextEditingController(
      text: widget.initTasa != null ? widget.initTasa.toString() : (_esPrestamo ? '' : '0'),
    );

    // Periodo inicial
    _periodo = widget.initPeriodo ?? 'Mensual';
    if (_esAlquiler) _periodo = 'Mensual'; // Alquiler es siempre mensual

    _proximaFecha = widget.initProximaFecha;

    // Si no es préstamo, fuerza tasa 0 para la UI
    if (!_esPrestamo) {
      _tasaCtrl.text = '0';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _notaCtrl.dispose();
    _productoCtrl.dispose();
    _capitalCtrl.dispose();
    _tasaCtrl.dispose();
    super.dispose();
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
      'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  InputDecoration _deco(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFF64748B)),
    floatingLabelStyle:
    const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
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
      return '${onlyDigits.substring(0, 3)}-'
          '${onlyDigits.substring(3, 6)}-'
          '${onlyDigits.substring(6)}';
    }
    return onlyDigits;
  }

  @override
  Widget build(BuildContext context) {
    final double h = MediaQuery.of(context).size.height;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0 && !_hintMostrado) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showProductoHint(bottomInset));
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                          child: SingleChildScrollView(
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
    final String montoLabel =
    _esAlquiler ? 'Monto mensual (\$)' : 'Saldo inicial (\$)';

    return Column(
      mainAxisSize: MainAxisSize.min,
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
                    shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _moduloLabel, // 👈 subtítulo con el nombre del módulo
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 10))],
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
                TextFormField(
                  controller: _notaCtrl,
                  decoration: _deco('Nota (opcional)', icon: Icons.note_alt_outlined),
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                ),
                const SizedBox(height: 8),

                // === Producto/Alquiler (solo cuando NO es Préstamo) ===
                if (!_esPrestamo) ...[
                  CompositedTransformTarget(
                    link: _hintLink,
                    child: TextFormField(
                      controller: _productoCtrl,
                      decoration: InputDecoration(
                        label: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            const Icon(Icons.local_offer_rounded, color: Color(0xFF94A3B8), size: 18),
                            const SizedBox(width: 6),
                            const Flexible(
                              child: Text(
                                'Producto / Alquiler (corto–mediano–largo)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
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
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio en este módulo' : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Text('Para alquiler de inmuebles, usa la pestaña Alquiler. ' 'Fiados de productos y alquileres de vehículos o equipos van aquí en Productos.',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],


                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _capitalCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: _deco(montoLabel, icon: Icons.payments),
                        textInputAction: _esPrestamo ? TextInputAction.next : TextInputAction.done,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // % Interés solo en Préstamo
                    if (_esPrestamo)
                      Expanded(
                        child: TextFormField(
                          controller: _tasaCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                          decoration: _deco('% Interés', icon: Icons.percent),
                          validator: (v) {
                            if (!_esPrestamo) return null;
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

                // === Mora (solo en Alquiler) — colapsable ===
                if (_esAlquiler || _esProducto) ...[
                  const SizedBox(height: 14),
                  Container(
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
                              activeColor: const Color(0xFF2563EB),        // 🔵 Azul brillante cuando está activado
                              inactiveTrackColor: const Color(0xFFCBD5E1), // ⚪ Gris notable cuando está apagado
                              inactiveThumbColor: const Color(0xFF94A3B8), // 🔘 Gris más oscuro para contraste
                              onChanged: (v) => setState(() => _moraEnabled = v),
                            ),
                          ],
                        ),

                        // 👇 Aviso visible cuando la mora está desactivada
                        if (!_moraEnabled)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Mora desactivada (toca el botón para activar)',
                                style: TextStyle(
                                  color: Color(0xFF0369A1),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
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
                            decoration: _deco(
                              _moraTipo == 'porcentaje'
                                  ? 'Valor de mora (%)'
                                  : 'Valor de mora (monto)',
                            ),
                            onChanged: (v) =>
                            _moraValor = double.tryParse(v.replaceAll(',', '.')) ?? _moraValor,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Aplicar si pasan:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
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
                  ),
                ],

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
                    if (!_esAlquiler) // En alquiler, siempre mensual
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

  Map<String, String?> _detectarProductoTipo(String nombre) {
    final s = nombre.toLowerCase();

    // Palabras clave
    final esGuagua = s.contains('guagua') || s.contains('bus') || s.contains('autobus') || s.contains('autobús');
    final esMoto   = s.contains('moto') || s.contains('motor');
    final esCarro  = s.contains('carro') || s.contains('auto') || s.contains('coche') ||
        s.contains('vehiculo') || s.contains('vehículo') ||
        s.contains('camioneta') || s.contains('jeepeta') ||
        s.contains('pickup') || s.contains('camion') || s.contains('camión') || s.contains('taxi');

    if (esGuagua) return {'tipoProducto': 'vehiculo', 'vehiculoTipo': 'guagua'};
    if (esMoto)   return {'tipoProducto': 'vehiculo', 'vehiculoTipo': 'moto'};
    if (esCarro)  return {'tipoProducto': 'vehiculo', 'vehiculoTipo': 'carro'};

    // Genérico (no vehículo)
    return {'tipoProducto': 'generico', 'vehiculoTipo': null};
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

    // Teléfono
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

    // Datos numéricos
    final capital =
        int.tryParse(_capitalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final double tasa = _esPrestamo
        ? (double.tryParse(_tasaCtrl.text.replaceAll(',', '.')) ?? 0.0)
        : 0.0;

    final String productoTexto =
    _esPrestamo ? '' : _productoCtrl.text.trim(); // requerido por validador arriba
    // Solo para módulo Productos, calculamos tipo para íconos adaptativos
    final Map<String, String?> _tipoProd =
    _esProducto ? _detectarProductoTipo(productoTexto) : {'tipoProducto': null, 'vehiculoTipo': null};

    final String nota = _notaCtrl.text.trim();

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

    // Config mora (Alquiler o Productos) si está activada
    Map<String, dynamic>? moraCfg;
    if ((_esAlquiler || _esProducto) && _moraEnabled) {
      final umbrales = <int>[
        if (_mora15) 15,
        if (_mora30) 30,
      ];
      moraCfg = {
        'tipo': _moraTipo,            // 'porcentaje' | 'fijo'
        'valor': _moraValor,          // double
        'umbralesDias': umbrales,     // p.ej. [15,30]
        'dobleEn30': true,            // a los 30 días se cobra doble
      };
    }

    try {
      String? docId = widget.id;

      if (_isEdit && docId != null) {
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

        final Map<String, dynamic> update = {
          'nombre': _nombreCtrl.text.trim(),
          'apellido': _apellidoCtrl.text.trim(),
          'nombreCompleto': '${_nombreCtrl.text.trim()} ${_apellidoCtrl.text.trim()}',
          'telefono': finalTel,
          'direccion': _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          'nota': nota.isEmpty ? null : nota,
          'producto': _esPrestamo ? null : (productoTexto.isEmpty ? null : productoTexto),
          'esArriendo': _esAlquiler,
          'capitalInicial': capital,
          'tasaInteres': tasa,
          'periodo': _esAlquiler ? 'Mensual' : _periodo,
          'proximaFecha': Timestamp.fromDate(proximaDate),
          'autoFecha': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'mora': moraCfg, // null para otros módulos o si está desactivada
          'esFiado': _esProducto && _moraEnabled,
          // 👇 Ícono adaptativo (solo Productos)
          'tipoProducto': _tipoProd['tipoProducto'],
          'vehiculoTipo': _tipoProd['vehiculoTipo'],


        };

        await col.doc(docId).set(update, SetOptions(merge: true));
      } else {
        // Crear
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
          'nota': nota.isEmpty ? null : nota,
          'producto': _esPrestamo ? null : (productoTexto.isEmpty ? null : productoTexto),
          'esArriendo': _esAlquiler,
          'capitalInicial': capital,
          'saldoActual': capital,
          'saldoAnterior': capital,
          'saldado': capital == 0 ? true : false,
          'estado': capital == 0 ? 'saldado' : 'al_dia',
          'tasaInteres': tasa,
          'periodo': _esAlquiler ? 'Mensual' : _periodo,
          'proximaFecha': Timestamp.fromDate(proximaDate),   // fecha ancla inicial
          'autoFecha': true,
          'venceEl': capital == 0 ? FieldValue.delete() : Timestamp.fromDate(venceElDate),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'mora': moraCfg,
          'moraAplicadaEnDias': <int>[], // para evitar aplicar dos veces el mismo umbral
          'esFiado': _esProducto && _moraEnabled,
          // 👇 Ícono adaptativo (solo Productos)
          'tipoProducto': _tipoProd['tipoProducto'],
          'vehiculoTipo': _tipoProd['vehiculoTipo'],

        });


        // Métricas
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
        'nota': nota.isEmpty ? null : nota,
        'producto': _esPrestamo ? null : (productoTexto.isEmpty ? null : productoTexto),
        'capital': capital,
        'tasa': tasa,
        'periodo': _esAlquiler ? 'Mensual' : _periodo,
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

// === Pill compacto (no cubre pantalla) ===
class _HintPill extends StatelessWidget {
  final String text;
  const _HintPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}