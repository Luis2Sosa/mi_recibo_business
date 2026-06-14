import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/ui/sobre_mi_recibo_screen.dart';

import '../core/ads/ads_manager.dart';
import 'prestamista_registro_screen.dart';
import 'clientes/clientes_screen.dart';
import 'pin_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _cargando = false;

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      ));
  }

  Future<void> _googleSignOutSilently() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
  }

  Future<UserCredential> _loginConGoogle() async {
    await _googleSignOutSilently();
    final google = GoogleSignIn();
    final googleUser = await google.signIn();
    if (googleUser == null) throw const _UiFriendlyAuthError('Inicio cancelado por el usuario');
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
        case 'network-request-failed': return 'Sin conexión. Intenta de nuevo.';
        case 'account-exists-with-different-credential': return 'Tu correo ya está vinculado con otro método.';
        case 'user-disabled': return 'Tu cuenta está deshabilitada.';
        case 'invalid-credential': return 'Credenciales inválidas. Intenta de nuevo.';
        case 'operation-not-allowed': return 'Método de acceso no habilitado.';
        default: return 'No se pudo iniciar sesión. (${e.code})';
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

  Future<void> _manejarLoginPrestamista() async {
    if (_cargando) return;
    HapticFeedback.lightImpact();
    setState(() => _cargando = true);

    try {
      final cred = await _loginConGoogle();
      final user = cred.user;
      if (user == null) throw const _UiFriendlyAuthError('No se pudo obtener el usuario.');

      final docRef = FirebaseFirestore.instance.collection('prestamistas').doc(user.uid);
      final snap = await docRef.get(const GetOptions(source: Source.server));

      if (!mounted) return;

      final nombreCompleto = (user.displayName ?? '').trim();
      String? nombre;
      String? apellido;
      if (nombreCompleto.isNotEmpty) {
        final p = nombreCompleto.split(RegExp(r'\s+'));
        nombre = p.isNotEmpty ? p.first : null;
        apellido = p.length > 1 ? p.sublist(1).join(' ') : null;
      }

      if (!snap.exists) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PrestamistaRegistroScreen(),
          settings: RouteSettings(arguments: {
            'nombreCompleto': nombreCompleto, 'nombre': nombre,
            'apellido': apellido, 'email': user.email, 'fotoUrl': user.photoURL,
          }),
        ));
        return;
      }

      final data = snap.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      final String telefono = (data['telefono'] ?? '').toString().trim();

      if (telefono.isEmpty) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const PrestamistaRegistroScreen(),
          settings: RouteSettings(arguments: {
            'nombreCompleto': nombreCompleto, 'nombre': nombre,
            'apellido': apellido, 'email': user.email, 'fotoUrl': user.photoURL,
          }),
        ));
        return;
      }

      await _persistirMetadatos(user);

      final bool lockEnabled = settings['lockEnabled'] == true;
      final bool pinEnabled = settings['pinEnabled'] == true;
      final String? pinCode = (settings['pinCode'] as String?)?.trim();
      final bool requiereGate = lockEnabled || (pinEnabled && pinCode != null && pinCode.isNotEmpty);

      if (requiereGate) {
        final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const PinScreen()));
        if (ok == true && mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClientesScreen()));
        } else {
          _showSnack('Autenticación requerida.');
        }
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClientesScreen()));
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack(_mapAuthError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await AdsManager.handleDailyAd(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: !_cargando,
      onPopInvoked: (_) {},
      child: Scaffold(
        body: Stack(
          children: [
            // ── Fondo degradado ──────────────────────────────────────────
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A3FAA), Color(0xFF0E8A6A)],
                ),
              ),
            ),

            // ── Círculo decorativo superior izquierdo ────────────────────
            Positioned(
              top: -80, left: -80,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),

            // ── Círculo decorativo inferior derecho ──────────────────────
            Positioned(
              bottom: -60, right: -60,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),

            // ── Contenido principal ──────────────────────────────────────
            SafeArea(
              child: Column(
                children: [
                  // Parte superior: logo + eslogan
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Image(
                            image: const AssetImage('assets/images/logoB.png'),
                            height: size.height * 0.40,
                            fit: BoxFit.contain,
                          ),

                          const SizedBox(height: 24),

                          Transform.translate(
                            offset: const Offset(0, -50),
                            child: Column(
                              children: [
                                // Línea divisora sutil
                                Row(
                                  children: [
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withOpacity(0.25),
                                        thickness: 1,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.50),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Divider(
                                        color: Colors.white.withOpacity(0.25),
                                        thickness: 1,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 20),

                                Text(
                                  'Más que un recibo,\nla gestión que tu negocio merece',
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: size.width * 0.055,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontStyle: FontStyle.italic,
                                    height: 1.45,
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                const SizedBox(height: 14),

                                Text(
                                  'Gestión inteligente para tu negocio',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.white.withOpacity(0.70),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Parte inferior: botones
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Botón Google
                          _googleButton(
                            labelIdle: 'Continuar con Google',
                            loading: _cargando,
                            onTap: _cargando ? null : _manejarLoginPrestamista,
                          ),

                          const SizedBox(height: 16),

                          // Botón Sobre Mi Recibo
                          _aboutButton(context),

                          const SizedBox(height: 28),

                          // Pie legal
                          Text(
                            'Al continuar aceptas nuestros Términos y Política de Privacidad',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.45),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Overlay de carga ─────────────────────────────────────────
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
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1A3FAA),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/google_logo.png', height: 22, width: 22),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                loading ? 'Entrando…' : labelIdle,
                key: ValueKey(loading ? 'loading' : 'idle'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A3FAA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SobreMiReciboScreen()));
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withOpacity(0.35), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: Colors.white,
          backgroundColor: Colors.white.withOpacity(0.08),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              'Sobre Mi Recibo Business',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UiFriendlyAuthError implements Exception {
  final String message;
  const _UiFriendlyAuthError(this.message);
}