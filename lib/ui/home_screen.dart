import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/ui/sobre_mi_recibo_screen.dart';

import 'prestamista_registro_screen.dart';
import 'clientes/clientes_screen.dart';
import 'pin_screen.dart'; // Gate de PIN/huella

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ===== Layout consts =====
  static const double logoTop = -20;
  static const double logoSize = 400;
  static const double sloganTop = 270;
  static const double buttonsTop = 460;

  // ===== State =====
  bool _cargando = false;

  // ===== Utils =====
  void _showSnack(String msg) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            msg,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
  }

  Future<void> _googleSignOutSilently() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // No-op
    }
  }

  Future<UserCredential> _loginConGoogle() async {
    // Evita sesiones colgadas de intentos previos
    await _googleSignOutSilently();

    final google = GoogleSignIn();
    final googleUser = await google.signIn();
    if (googleUser == null) {
      throw const _UiFriendlyAuthError('Inicio cancelado por el usuario');
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  String _mapAuthError(Object e) {
    if (e is _UiFriendlyAuthError) return e.message;
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'network-request-failed':
          return 'Sin conexión. Intenta de nuevo.';
        case 'account-exists-with-different-credential':
          return 'Tu correo ya está vinculado con otro método.';
        case 'user-disabled':
          return 'Tu cuenta está deshabilitada.';
        case 'invalid-credential':
          return 'Credenciales inválidas. Intenta de nuevo.';
        case 'operation-not-allowed':
          return 'Método de acceso no habilitado.';
        default:
          return 'No se pudo iniciar sesión. (${e.code})';
      }
    }
    return 'Ocurrió un error. Intenta de nuevo.';
  }

  Future<void> _persistirMetadatos(User user) async {
    final ref = FirebaseFirestore.instance.collection('prestamistas').doc(user.uid);
    await ref.set({
      'email': user.email ?? '',
      'fotoUrl': user.photoURL ?? '',
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ✔ Regla de navegación:
  // - Si el doc NO existe -> Registro
  // - Si el doc existe PERO está incompleto (e.g. sin teléfono) -> Registro
  // - Si el doc existe y está completo -> Clientes (con gate PIN si aplica)
  Future<void> _manejarLoginPrestamista() async {
    if (_cargando) return;
    HapticFeedback.lightImpact();
    setState(() => _cargando = true);
    try {
      final cred = await _loginConGoogle();
      final user = cred.user;
      if (user == null) {
        throw const _UiFriendlyAuthError('No se pudo obtener el usuario.');
      }

      final docRef = FirebaseFirestore.instance.collection('prestamistas').doc(user.uid);
      // 🔒 Lee SIEMPRE del servidor para evitar cache después de borrar cuenta
      final snap = await docRef.get(const GetOptions(source: Source.server));

      if (!mounted) return;

      if (!snap.exists) {
        // 📝 No registrado (p.ej. la cuenta fue eliminada) → ir a REGISTRO
        final nombreCompleto = (user.displayName ?? '').trim();
        String? nombre;
        String? apellido;
        if (nombreCompleto.isNotEmpty) {
          final parts = nombreCompleto.split(RegExp(r'\s+'));
          nombre = parts.isNotEmpty ? parts.first : null;
          apellido = parts.length > 1 ? parts.sublist(1).join(' ') : null;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PrestamistaRegistroScreen(),
            settings: RouteSettings(arguments: {
              'nombreCompleto': nombreCompleto,
              'nombre': nombre,
              'apellido': apellido,
              'email': user.email,
              'fotoUrl': user.photoURL,
            }),
          ),
        );
        return;
      }

      // ✅ Doc existe. Chequeo de "perfil completo".
      final data = snap.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      final String telefono = (data['telefono'] ?? '').toString().trim();

      final bool perfilIncompleto = telefono.isEmpty; // puedes añadir más campos obligatorios si quieres

      if (perfilIncompleto) {
        // El doc existe pero falta info esencial -> Registro
        final nombreCompleto = (user.displayName ?? '').trim();
        String? nombre;
        String? apellido;
        if (nombreCompleto.isNotEmpty) {
          final parts = nombreCompleto.split(RegExp(r'\s+'));
          nombre = parts.isNotEmpty ? parts.first : null;
          apellido = parts.length > 1 ? parts.sublist(1).join(' ') : null;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PrestamistaRegistroScreen(),
            settings: RouteSettings(arguments: {
              'nombreCompleto': nombreCompleto,
              'nombre': nombre,
              'apellido': apellido,
              'email': user.email,
              'fotoUrl': user.photoURL,
            }),
          ),
        );
        return;
      }

      // ✔ Ya registrado y completo → persistimos metadatos útiles
      await _persistirMetadatos(user);

      // Seguridad: lockEnabled o pinEnabled + pinCode
      final bool lockEnabled = settings['lockEnabled'] == true;
      final bool pinEnabled = settings['pinEnabled'] == true;
      final String? pinCode = (settings['pinCode'] as String?)?.trim();

      final bool requiereGate = lockEnabled || (pinEnabled && (pinCode != null && pinCode.isNotEmpty));

      if (requiereGate) {
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const PinScreen()),
        );
        if (ok == true && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ClientesScreen()),
          );
        } else {
          _showSnack('Autenticación requerida para continuar.');
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClientesScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(_mapAuthError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _manejarLoginTrabajador() async {
    if (_cargando) return;
    HapticFeedback.lightImpact();
    setState(() => _cargando = true);
    try {
      final cred = await _loginConGoogle();
      final user = cred.user;

      if (!mounted) return;
      _showSnack('Bienvenido, ${user?.displayName ?? 'Usuario'}');

      // TODO: Implementar flujo de registro de trabajador similar al de prestamista.
    } catch (e) {
      if (!mounted) return;
      _showSnack(_mapAuthError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_cargando, // bloquea back mientras carga
      onPopInvoked: (_) {},
      child: Scaffold(
        body: Stack(
          children: [
            // Fondo
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Ajuste simple para pantallas pequeñas
                  final isSmall = constraints.maxHeight < 700;
                  final topLogo = isSmall ? -40.0 : logoTop;
                  final topSlogan = isSmall ? 220.0 : sloganTop;
                  final topButtons = isSmall ? 420.0 : buttonsTop;

                  return Stack(
                    children: [
                      // ==== LOGO ====
                      Positioned(
                        top: topLogo,
                        left: 0,
                        right: 0,
                        child: const IgnorePointer(
                          child: Center(
                            child: Image(
                              image: AssetImage('assets/images/logoB.png'),
                              height: logoSize,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // ==== ESLOGAN ====
                      Positioned(
                        top: topSlogan,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 340),
                            child: Text(
                              'Más que un recibo, la gestión que tu negocio merece',
                              style: GoogleFonts.playfairDisplay(
                                textStyle: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),

                      // ==== BOTONES ====
                      Positioned(
                        top: topButtons,
                        left: 24,
                        right: 24,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _googleButton(
                              labelIdle: 'Soy Negocio',
                              loading: _cargando,
                              onTap: _cargando ? null : _manejarLoginPrestamista,
                            ),
                            const SizedBox(height: 16),
                            _googleButton(
                              labelIdle: 'Soy Trabajador Independiente',
                              loading: _cargando,
                              onTap: _cargando ? null : _manejarLoginTrabajador,
                            ),

                            // 👇 BOTÓN PREMIUM
                            const SizedBox(height: 12),
                            _aboutButton(context),
                          ],
                        ),
                      ),

                      // Overlay de carga que bloquea interacción
                      if (_cargando)
                        Positioned.fill(
                          child: AbsorbPointer(
                            absorbing: true,
                            child: Container(
                              color: Colors.black.withOpacity(0.25),
                              child: const Center(
                                child: CircularProgressIndicator(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _googleButton({
    required String labelIdle,
    required bool loading,
    required VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFFFFF),
          foregroundColor: const Color(0xff4285F4),
          shape: const StadiumBorder(),
          elevation: 6,
          shadowColor: Colors.black.withOpacity(0.25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', height: 24, width: 24),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: Text(
                loading ? 'Entrando…' : labelIdle,
                key: ValueKey(loading ? 'loading' : 'idle-$labelIdle'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 👇 BOTÓN PREMIUM DEGRADADO + CONTRASTE OSCURO
  Widget _aboutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 110), // lo baja más
      child: Center(
        child: SizedBox(
          width: 260,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E3A8A), // azul más oscuro
                  Color(0xFF0F766E), // verde oscuro elegante
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SobreMiReciboScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent, // muestra el degradado
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 22, // más grande
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Sobre Mi Recibo Business',
                    style: TextStyle(
                      fontSize: 15, // más grande
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Error simple para UX (no expone códigos técnicos)
class _UiFriendlyAuthError implements Exception {
  final String message;
  const _UiFriendlyAuthError(this.message);
}