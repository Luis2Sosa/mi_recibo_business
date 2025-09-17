import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'prestamista_registro_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const double logoTop = -20;
  static const double logoSize = 400;
  static const double sloganTop = 270;
  static const double buttonsTop = 500;

  bool cargando = false;

  Future<UserCredential> _loginConGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception('Login cancelado por el usuario');
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> _manejarLoginPrestamista() async {
    if (cargando) return;
    setState(() => cargando = true);
    try {
      final cred = await _loginConGoogle();

      final user = cred.user;
      final nombreCompleto = (user?.displayName ?? '').trim();
      String? nombre;
      String? apellido;
      if (nombreCompleto.isNotEmpty) {
        final parts = nombreCompleto.split(RegExp(r'\s+'));
        if (parts.length == 1) {
          nombre = parts.first;
        } else {
          nombre = parts.first;
          apellido = parts.sublist(1).join(' ');
        }
      }
      final email = user?.email;
      final fotoUrl = user?.photoURL;

      if (!mounted) return;

      // 👉 Navegamos pasando los datos por RouteSettings.arguments (sin tocar el constructor)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PrestamistaRegistroScreen(),
          settings: RouteSettings(arguments: {
            'nombreCompleto': nombreCompleto,
            'nombre': nombre,
            'apellido': apellido,
            'email': email,
            'fotoUrl': fotoUrl,
          }),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  Future<void> _manejarLoginTrabajador() async {
    if (cargando) return;
    setState(() => cargando = true);
    try {
      final cred = await _loginConGoogle();

      final user = cred.user;
      final nombreCompleto = (user?.displayName ?? '').trim();
      String? nombre;
      String? apellido;
      if (nombreCompleto.isNotEmpty) {
        final parts = nombreCompleto.split(RegExp(r'\s+'));
        if (parts.length == 1) {
          nombre = parts.first;
        } else {
          nombre = parts.first;
          apellido = parts.sublist(1).join(' ');
        }
      }
      final email = user?.email;
      final fotoUrl = user?.photoURL;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bienvenido, ${nombreCompleto.isEmpty ? 'Usuario' : nombreCompleto}')),
      );

      // TODO: cuando tengas la pantalla de registro de Trabajador,
      // haz lo mismo: navega y pasa los argumentos con RouteSettings.
      // Ejemplo (cuando exista):
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (_) => const TrabajadorRegistroScreen(),
      //   settings: RouteSettings(arguments: {
      //     'nombreCompleto': nombreCompleto,
      //     'nombre': nombre,
      //     'apellido': apellido,
      //     'email': email,
      //     'fotoUrl': fotoUrl,
      //   }),
      // ));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF2458D6),
              Color(0xFF0A9A76),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ==== LOGO ====
              const Positioned(
                top: logoTop,
                left: 0,
                right: 0,
                child: IgnorePointer(
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
                top: sloganTop,
                left: 0,
                right: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      'Más que un recibo, la gestión que tu negocio merece',
                      style: GoogleFonts.playfair(
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
                top: buttonsTop,
                left: 32,
                right: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _googleButton(
                      label:
                      cargando ? 'Entrando...' : 'Soy Prestamista',
                      onTap: cargando ? null : _manejarLoginPrestamista,
                    ),
                    const SizedBox(height: 18),
                    _googleButton(
                      label:
                      cargando ? 'Entrando...' : 'Soy Trabajador',
                      onTap: cargando ? null : _manejarLoginTrabajador,
                    ),
                  ],
                ),
              ),

              if (cargando)
                Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _googleButton({
    required String label,
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
            Image.asset(
              'assets/images/google_logo.png',
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}