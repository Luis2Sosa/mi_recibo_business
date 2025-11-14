
import 'package:flutter/foundation.dart';
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
  static const double logoTop = -50;
  static const double logoSize = 400;
  static const double sloganTop = 230;
  static const double buttonsTop = 420;

  bool _cargando = false;

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
    } catch (_) {}
  }

  // ============================================================
  // 🔥 LOGIN GOOGLE UNIFICADO (WEB + ANDROID + iOS)
  // ============================================================
  Future<UserCredential> _loginConGoogleUnificado() async {
    // 🌐 WEB
    if (kIsWeb) {
      try {
        print("🔥 Iniciando Google Sign-In en Web…");

        // Método oficial para Flutter Web
        final provider = GoogleAuthProvider();

        // Forzar siempre elegir la cuenta
        provider.setCustomParameters({
          'prompt': 'select_account',
        });

        final cred = await FirebaseAuth.instance.signInWithPopup(provider);

        print("🔥 Usuario Web: ${cred.user?.email}");
        return cred;

      } catch (e) {
        print("❌ Error Web Google Sign-In: $e");
        throw const _UiFriendlyAuthError("Error iniciando sesión en la Web.");
      }
    }

    // 📱 ANDROID / iOS
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
          return 'Credenciales inválidas.';
        default:
          return 'No se pudo iniciar sesión. (${e.code})';
      }
    }
    return 'Ocurrió un error.';
  }

  Future<void> _persistirMetadatos(User user) async {
    final ref = FirebaseFirestore.instance.collection('prestamistas').doc(user.uid);
    await ref.set({
      'email': user.email ?? '',
      'fotoUrl': user.photoURL ?? '',
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ============================================================
  // 🔥 MANEJAR LOGIN PRESTAMISTA (UNIFICADO)
  // ============================================================
  Future<void> _manejarLoginPrestamista() async {
    if (_cargando) return;
    HapticFeedback.lightImpact();
    setState(() => _cargando = true);

    try {
      final cred = await _loginConGoogleUnificado();
      final user = cred.user ?? FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw const _UiFriendlyAuthError('No se pudo obtener el usuario.');
      }

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

      final data = snap.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      final String telefono = (data['telefono'] ?? '').toString().trim();

      if (telefono.isEmpty) {
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

      await _persistirMetadatos(user);

      final bool lockEnabled = settings['lockEnabled'] == true;
      final bool pinEnabled = settings['pinEnabled'] == true;
      final String? pinCode = (settings['pinCode'] as String?)?.trim();
      final bool requiereGate = lockEnabled || (pinEnabled && pinCode != null && pinCode.isNotEmpty);

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
          _showSnack('Autenticación requerida.');
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdsManager.handleDailyAd(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_cargando,
      onPopInvoked: (_) {},
      child: Scaffold(
        body: Stack(
          children: [
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

            // 🧱 TODO EL RESTO SIN CAMBIAR (IGUALITO COMO LO TENÍAS)
            // ⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐
            // — solo se cambió login — nada visual —
            // ⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐⭐

            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmall = constraints.maxHeight < 700;
                  final topLogo = isSmall ? -40.0 : logoTop;
                  final topSlogan = isSmall ? 220.0 : sloganTop;
                  final topButtons = isSmall ? 420.0 : buttonsTop;

                  return Stack(children: [
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
                    Positioned(
                      top: topButtons,
                      left: 24,
                      right: 24,
                      child: Column(
                        children: [
                          _googleButton(
                            labelIdle: 'Soy Negocio',
                            loading: _cargando,
                            onTap: _cargando ? null : _manejarLoginPrestamista,
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'Gestión inteligente para tu negocio',
                            style: GoogleFonts.playfairDisplay(
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.width > 600 ? 320 : 200,
                          ),
                          _aboutButton(context),
                        ],
                      ),
                    ),

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
                  ]);
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
    final isWeb = MediaQuery.of(context).size.width > 600;

    return Center(
      child: SizedBox(
        width: isWeb ? 420 : double.infinity,
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
                child: Text(
                  loading ? 'Entrando…' : labelIdle,
                  key: ValueKey(loading ? 'loading' : 'idle-$labelIdle'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutButton(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 48,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF0F2A45),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F2A45).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
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
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'Sobre Mi Recibo Business',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UiFriendlyAuthError implements Exception {
  final String message;
  const _UiFriendlyAuthError(this.message);
}


