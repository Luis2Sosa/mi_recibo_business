import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 Firestore
import 'package:firebase_auth/firebase_auth.dart';     // 👈 UID del usuario
import 'package:flutter/services.dart';                // 👈 input formatters
import 'clientes/clientes_screen.dart';
import 'package:mi_recibo/ui/theme/currency_utils.dart'; // 🌍 util de moneda automática

// =====================
// FORMATTER: Teléfono con guiones
// =====================
class TelefonoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    String numbers = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Formato: 000-000-0000
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
  State<PrestamistaRegistroScreen> createState() =>
      _PrestamistaRegistroScreenState();
}

class _PrestamistaRegistroScreenState extends State<PrestamistaRegistroScreen> {
  // Logo independiente (no empuja el contenido)
  static const double _logoTop = -80;
  static const double _logoHeight = 400;
  static const double _gapBelowLogo = -70; // ⬅️ marco un poco más abajo (no tapa)

  final _formKey = GlobalKey<FormState>();

  final _empresaCtrl = TextEditingController();
  final _servidorCtrl = TextEditingController(); // 👉 “Nombre y Apellido”
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  bool _guardando = false; // ⬅️ evita doble envío

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

  // ========= Helpers =========

  String _colapsarEspacios(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _soloDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Convierte vacío a null (para guardar limpio en Firestore)
  String? _toNullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  /// Separa un "Nombre y Apellido" robustamente (maneja 1 palabra, múltiples espacios)
  (String nombre, String apellido) _splitNombreApellido(String full) {
    final t = _colapsarEspacios(full);
    if (t.isEmpty) return ('', '');
    final parts = t.split(' ');
    if (parts.length == 1) return (parts.first, '');
    final apellido = parts.removeLast();
    final nombre = parts.join(' ');
    return (nombre, apellido);
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
                                    'Registro',
                                    style: GoogleFonts.playfairDisplay(
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
                                  autovalidateMode:
                                  AutovalidateMode.onUserInteraction, // ✅
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _field(
                                        controller: _empresaCtrl,
                                        label: 'Nombre de la empresa (opcional)',
                                        icon: Icons.domain, // 🏢
                                        textInputAction: TextInputAction.next,
                                      ),
                                      const SizedBox(height: 14),
                                      _field(
                                        controller: _servidorCtrl,
                                        label: 'Nombre y Apellido *',
                                        icon: Icons.badge, // 🪪
                                        textInputAction: TextInputAction.next,
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
                                        textInputAction: TextInputAction.next,
                                        // 👇 Permitir números y guion (antes bloqueaba el guion)
                                        inputFormatters: [
                                          TelefonoFormatter(), // ← aquí
                                        ],

                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Obligatorio';
                                          }
                                          final digits = _soloDigitos(v);
                                          return digits.length < 8
                                              ? 'Teléfono inválido'
                                              : null;
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _field(
                                        controller: _direccionCtrl,
                                        label: 'Dirección (opcional)',
                                        icon: Icons.home, // 🏠
                                        textInputAction: TextInputAction.done,
                                      ),
                                      const SizedBox(height: 22),

                                      SizedBox(
                                        width: double.infinity,
                                        height: 58,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                            const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            shape: const StadiumBorder(),
                                            textStyle: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            elevation: 6,
                                            shadowColor:
                                            Colors.black.withOpacity(0.25),
                                          ),
                                          onPressed: _guardando
                                              ? null
                                              : () async {
                                            if (!(_formKey.currentState
                                                ?.validate() ??
                                                false)) {
                                              return;
                                            }
                                            setState(() =>
                                            _guardando = true);
                                            try {
                                              final args = (ModalRoute.of(
                                                  context)
                                                  ?.settings
                                                  .arguments
                                              as Map?) ??
                                                  {};
                                              final email =
                                              (args['email']
                                              as String?)
                                                  ?.trim();

                                              final fullName =
                                                  _servidorCtrl.text;
                                              final (nombre, apellido) =
                                              _splitNombreApellido(
                                                  fullName);

                                              // 👉 UID único del prestamista
                                              final user = FirebaseAuth
                                                  .instance.currentUser;
                                              if (user == null) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(
                                                    context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          'Sesión expirada. Vuelve a iniciar.')),
                                                );
                                                return;
                                              }
                                              final uid = user.uid;
                                              final docRef =
                                              FirebaseFirestore
                                                  .instance
                                                  .collection(
                                                  'prestamistas')
                                                  .doc(uid);

                                              // Preservar createdAt si ya existe
                                              Timestamp? createdAt;
                                              try {
                                                final snap =
                                                await docRef.get();
                                                if (snap.exists) {
                                                  final d =
                                                      snap.data() ?? {};
                                                  final ca =
                                                  d['createdAt'];
                                                  if (ca is Timestamp) {
                                                    createdAt = ca;
                                                  }
                                                }
                                              } catch (_) {}

                                              // Normalización de teléfono
                                              final telRaw =
                                                  _telefonoCtrl.text;
                                              final telDigits =
                                              _soloDigitos(telRaw);

                                              final data = {
                                                'empresa': _toNullIfEmpty(
                                                    _empresaCtrl.text),
                                                'nombre': nombre,
                                                'apellido': apellido,
                                                'telefono': telRaw.trim(),
                                                'telefonoE164':
                                                _toNullIfEmpty(
                                                    telDigits),
                                                'direccion':
                                                _toNullIfEmpty(
                                                    _direccionCtrl
                                                        .text),
                                                'email':
                                                _toNullIfEmpty(email ?? ''),
                                                'uid': uid,
                                                'settings': {
                                                  // defaults razonables
                                                  'lockEnabled': false,
                                                  'pinEnabled': false,
                                                  'biometria': false,
                                                  'backupHabilitado':
                                                  false,
                                                  'notifVenc': true,
                                                },
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                                'createdAt': createdAt ??
                                                    FieldValue
                                                        .serverTimestamp(),
                                              };

                                              await docRef.set(
                                                data,
                                                SetOptions(merge: true),
                                              );

                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                  context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        'Prestamista registrado ✅')),
                                              );

                                              Navigator
                                                  .pushAndRemoveUntil(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                  const ClientesScreen(),
                                                  settings:
                                                  RouteSettings(
                                                    arguments: {
                                                      'bienvenidaNombre':
                                                      _colapsarEspacios(
                                                          fullName),
                                                      'bienvenidaEmpresa':
                                                      _empresaCtrl.text
                                                          .trim(),
                                                    },
                                                  ),
                                                ),
                                                    (route) => false,
                                              );
                                            } catch (e) {
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                  context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Error al guardar: $e'),
                                                ),
                                              );
                                            } finally {
                                              if (mounted) {
                                                setState(() =>
                                                _guardando = false);
                                              }
                                            }
                                          },
                                          child: Text(_guardando
                                              ? 'Guardando…'
                                              : 'Siguiente'),
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
    List<TextInputFormatter>? inputFormatters,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        prefixIcon:
        icon != null ? Icon(icon, color: const Color(0xFF94A3B8)) : null,
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
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
