import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'clientes/clientes_screen.dart';

// =====================
// FORMATTER: Teléfono con guiones
// =====================
class TelefonoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = '';
    for (int i = 0; i < numbers.length; i++) {
      formatted += numbers[i];
      if (i == 2 || i == 5) {
        if (i != numbers.length - 1) formatted += '-';
      }
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PrestamistaRegistroScreen extends StatefulWidget {
  const PrestamistaRegistroScreen({super.key});

  @override
  State<PrestamistaRegistroScreen> createState() => _PrestamistaRegistroScreenState();
}

class _PrestamistaRegistroScreenState extends State<PrestamistaRegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _empresaCtrl = TextEditingController();
  final _servidorCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  bool _guardando = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servidorCtrl.text.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final nombreCompleto = (args['nombreCompleto'] as String?)?.trim();
        final nombre = (args['nombre'] as String?)?.trim();
        final apellido = (args['apellido'] as String?)?.trim();

        final prefill = (nombreCompleto?.isNotEmpty ?? false)
            ? nombreCompleto!
            : [
          if (nombre?.isNotEmpty ?? false) nombre!,
          if (apellido?.isNotEmpty ?? false) apellido!,
        ].join(' ').trim();

        _servidorCtrl.text = _colapsarEspacios(prefill);
      }
    }
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _servidorCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  String _colapsarEspacios(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
  String _soloDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
  String? _toNullIfEmpty(String s) => s.trim().isEmpty ? null : s.trim();

  (String nombre, String apellido) _splitNombreApellido(String full) {
    final t = _colapsarEspacios(full);
    if (t.isEmpty) return ('', '');
    final parts = t.split(' ');
    if (parts.length == 1) return (parts.first, '');
    final apellido = parts.removeLast();
    final nombre = parts.join(' ');
    return (nombre, apellido);
  }

  // Lógica de guardado separada para limpiar el build
  Future<void> _handleRegistro() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    try {
      final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
      final email = (args['email'] as String?)?.trim();
      final fullName = _servidorCtrl.text;
      final (nombre, apellido) = _splitNombreApellido(fullName);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión expirada.')));
        return;
      }

      final uid = user.uid;
      final docRef = FirebaseFirestore.instance.collection('prestamistas').doc(uid);

      final telRaw = _telefonoCtrl.text;
      final telDigits = _soloDigitos(telRaw);

      final data = {
        'empresa': _toNullIfEmpty(_empresaCtrl.text),
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telRaw.trim(),
        'telefonoE164': _toNullIfEmpty(telDigits),
        'direccion': _toNullIfEmpty(_direccionCtrl.text),
        'email': _toNullIfEmpty(email ?? ''),
        'uid': uid,
        'settings': {
          'lockEnabled': false,
          'pinEnabled': false,
          'biometria': false,
          'backupHabilitado': false,
          'notifVenc': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const ClientesScreen(),
          settings: RouteSettings(arguments: {
            'bienvenidaNombre': _colapsarEspacios(fullName),
            'bienvenidaEmpresa': _empresaCtrl.text.trim(),
          }),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isSmall = size.height < 700;
    final double kb = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      // Importante: Dejamos que el Scaffold maneje el espacio del teclado
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // 1. LOGO: Se oculta automáticamente cuando sale el teclado
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: kb > 0 ? 0 : (isSmall ? 180 : 250),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: kb > 0 ? 0 : 1,
                      child: Center(
                        child: Image.asset(
                          'assets/images/logoB.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // 2. TÍTULO
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      'Registro',
                      style: GoogleFonts.playfairDisplay(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                  // 3. TARJETA DE FORMULARIO
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 500),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        children: [
                          _field(
                            controller: _empresaCtrl,
                            label: 'Nombre de la empresa (opcional)',
                            icon: Icons.domain,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _servidorCtrl,
                            label: 'Nombre y Apellido *',
                            icon: Icons.badge,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _telefonoCtrl,
                            label: 'Teléfono *',
                            icon: Icons.call,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [TelefonoFormatter()],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Obligatorio';
                              return _soloDigitos(v).length < 8 ? 'Teléfono inválido' : null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _field(
                            controller: _direccionCtrl,
                            label: 'Dirección (opcional)',
                            icon: Icons.home,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: 26),

                          // BOTÓN SIGUIENTE
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                elevation: 4,
                              ),
                              onPressed: _guardando ? null : _handleRegistro,
                              child: Text(
                                _guardando ? 'Guardando...' : 'Siguiente',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // Espacio para que el scroll respire al final
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF94A3B8)) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
    );
  }
}