import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';     // 👈 UID del usuario
import 'clientes_screen.dart';

class PrestamistaRegistroScreen extends StatefulWidget {
  const PrestamistaRegistroScreen({super.key});

  @override
  State<PrestamistaRegistroScreen> createState() =>
      _PrestamistaRegistroScreenState();
}

class _PrestamistaRegistroScreenState extends State<PrestamistaRegistroScreen> {
  // Logo independiente (no empuja el contenido)
  static const double _logoTop = -20;
  static const double _logoHeight = 400;
  static const double _gapBelowLogo = -90; // ⬅️ marco un poco más abajo (no tapa)

  final _formKey = GlobalKey<FormState>();
  final _empresaCtrl = TextEditingController();
  final _servidorCtrl = TextEditingController(); // 👉 “Nombre y Apellido”
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  bool _guardando = false; // ⬅️ evita doble envío

  @override
  void initState() {
    super.initState();
    // 👇 Leemos los argumentos después del primer frame para tener ModalRoute disponible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

        if (prefill.isNotEmpty && _servidorCtrl.text.trim().isEmpty) {
          _servidorCtrl.text = prefill;
        }
      }
    });
  }

  @override
  void dispose() {
    _empresaCtrl.dispose();
    _servidorCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double contentTopPadding = _logoTop + _logoHeight + _gapBelowLogo;

    final kb = MediaQuery.of(context).viewInsets.bottom;
    final h = MediaQuery.of(context).size.height;

    // Cuando hay teclado, levanta un poco más (pero sin invadir el logo)
    const double extraLiftPx = 110; // ⬅️ leve empuje extra
    final double liftPx = kb > 0 ? (kb + extraLiftPx) : 0;
    final double liftFraction = (liftPx / h).clamp(0.0, 0.60); // ⬅️ CAP: 60%
    final double safeBottom = MediaQuery.of(context).padding.bottom; // ⬅️ padding seguro

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          child: Stack(
            children: [
              // Logo con fade cuando aparece el teclado (no lo tapamos)
              Positioned(
                top: _logoTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      opacity: kb > 0 ? 0.0 : 1.0, // ⬅️ ocultar logo con teclado
                      child: Image.asset(
                        'assets/images/logoB.png',
                        height: _logoHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // Marco translúcido
              Positioned(
                left: 16,
                right: 16,
                top: contentTopPadding,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  offset: Offset(0, kb > 0 ? -liftFraction : 0),
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
                        // padding inferior con teclado + safe area (no se tapa botón)
                        padding: EdgeInsets.fromLTRB(
                          16,
                          18,
                          16,
                          (kb > 0 ? 28 : 20) + safeBottom,
                        ),
                        child: SingleChildScrollView(
                          // No scroll si el teclado está abajo; scroll solo con teclado
                          physics: kb > 0
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Center(
                                  child: Text(
                                    'Registro Prestamista',
                                    style: GoogleFonts.playfair(
                                      textStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Tarjeta blanca con íconos y estética pro
                              Container(
                                width: double.infinity,
                                constraints: const BoxConstraints(maxWidth: 520),
                                padding: const EdgeInsets.all(22),
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
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _field(
                                        controller: _empresaCtrl,
                                        label: 'Nombre de la empresa (opcional)',
                                        icon: Icons.domain, // 🏢
                                      ),
                                      const SizedBox(height: 14),
                                      _field(
                                        controller: _servidorCtrl,
                                        label: 'Nombre y Apellido *',
                                        icon: Icons.badge, // 🪪
                                        validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Obligatorio'
                                            : null,
                                      ),
                                      const SizedBox(height: 14),
                                      _field(
                                        controller: _telefonoCtrl,
                                        label: 'Teléfono *',
                                        icon: Icons.call, // 📞
                                        keyboardType: TextInputType.phone,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Obligatorio';
                                          }
                                          final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                                          return digits.length < 8 ? 'Teléfono inválido' : null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _field(
                                        controller: _direccionCtrl,
                                        label: 'Dirección (opcional)',
                                        icon: Icons.home, // 🏠
                                      ),
                                      const SizedBox(height: 22),

                                      SizedBox(
                                        width: double.infinity,
                                        height: 58,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            textStyle: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            elevation: 6,
                                            shadowColor: Colors.black.withOpacity(0.25),
                                          ),
                                          onPressed: _guardando
                                              ? null
                                              : () async {
                                            if (_formKey.currentState!.validate()) {
                                              setState(() => _guardando = true);
                                              try {
                                                final args = (ModalRoute.of(context)?.settings.arguments as Map?) ?? {};
                                                final email = (args['email'] as String?)?.trim();

                                                final full = _servidorCtrl.text.trim();
                                                final parts = full.split(RegExp(r'\s+'));
                                                final nombre = parts.isNotEmpty ? parts.first : '';
                                                final apellido = parts.length > 1 ? parts.sublist(1).join(' ') : '';

                                                // 👉 UID único del prestamista
                                                final user = FirebaseAuth.instance.currentUser;
                                                if (user == null) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Sesión expirada. Vuelve a iniciar.')),
                                                  );
                                                  if (mounted) setState(() => _guardando = false);
                                                  return;
                                                }
                                                final uid = user.uid;

                                                // Guardar en Firestore con doc = UID
                                                await FirebaseFirestore.instance
                                                    .collection('prestamistas')
                                                    .doc(uid) // 👈 aquí va el UID único
                                                    .set({
                                                  'empresa'  : _empresaCtrl.text.trim(),
                                                  'nombre'   : nombre,
                                                  'apellido' : apellido,
                                                  'telefono' : _telefonoCtrl.text.trim(),
                                                  'direccion': _direccionCtrl.text.trim(),
                                                  'email'    : email,
                                                  'uid'      : uid, // 👈 lo guardamos también como campo
                                                  'updatedAt': FieldValue.serverTimestamp(),
                                                  'createdAt': FieldValue.serverTimestamp(),
                                                }, SetOptions(merge: true));

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Prestamista registrado ✅')),
                                                );

                                                if (!mounted) return;
                                                Navigator.pushAndRemoveUntil(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => const ClientesScreen(),
                                                    settings: RouteSettings(arguments: {
                                                      'bienvenidaNombre': _servidorCtrl.text.trim(),
                                                      'bienvenidaEmpresa': _empresaCtrl.text.trim(),
                                                    }),
                                                  ),
                                                      (route) => false,
                                                );
                                              } catch (e) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Error al guardar: $e')),
                                                );
                                              } finally {
                                                if (mounted) setState(() => _guardando = false);
                                              }
                                            }
                                          },
                                          child: Text(_guardando ? 'Guardando…' : 'Siguiente'),
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
            ],
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
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF94A3B8))
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF2563EB), // ✅ BorderSide correcto (no Color directo)
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
