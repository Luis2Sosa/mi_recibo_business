import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'theme/app_theme.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _localAuth = LocalAuthentication();

  bool _loading = true;
  bool _deviceCanAuth = false;
  bool _authInProgress = false;
  bool _autoTried = false;

  // Doble-atrás para salir
  DateTime? _lastBack;

  // Estética
  static const double _logoTop = -70;
  static const double _logoHeight = 300;

  @override
  void initState() {
    super.initState();
    _initAndAutoPrompt();
  }

  Future<void> _initAndAutoPrompt() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      _deviceCanAuth = canCheck || supported;
    } catch (_) {
      _deviceCanAuth = false;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);

      // Prompt automático (1 sola vez) si el dispositivo soporta autenticación
      if (_deviceCanAuth && !_autoTried) {
        _autoTried = true;
        await Future.delayed(const Duration(milliseconds: 120));
        _triggerAuth();
      }
    }
  }

  Future<void> _triggerAuth() async {
    if (_authInProgress) return;
    if (!_deviceCanAuth) {
      _toast('Activa un método de bloqueo en tu dispositivo.', error: true);
      return;
    }

    // Cancelar cualquier prompt anterior por seguridad
    try { await _localAuth.stopAuthentication(); } catch (_) {}

    _authInProgress = true;
    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para continuar',
        options: const AuthenticationOptions(
          biometricOnly: false,   // huella/rostro o PIN/patrón del sistema / passcode (iOS)
          stickyAuth: false,      // evita prompts pegados al volver del background
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      _toast(_mapLocalAuthError(e.code), error: true);
    } catch (_) {
      _toast('No se pudo autenticar.', error: true);
    } finally {
      await Future.delayed(const Duration(milliseconds: 200));
      _authInProgress = false;
    }

    if (!mounted) return;
    if (ok) {
      // Éxito → cerramos esta pantalla con true (StartGate te manda a Clientes)
      Navigator.pop(context, true);
    } else {
      // No hacemos pop: el usuario puede reintentar con el botón
      _toast('Autenticación cancelada', error: true);
    }
  }

  String _mapLocalAuthError(String code) {
    switch (code) {
      case 'NotAvailable':
      case 'notAvailable':
        return 'Este dispositivo no tiene autenticación disponible.';
      case 'NotEnrolled':
      case 'notEnrolled':
        return 'No hay método de desbloqueo configurado. Actívalo en Ajustes.';
      case 'PasscodeNotSet':
      case 'passcodeNotSet':
        return 'Configura un bloqueo de pantalla para continuar.';
      case 'LockedOut':
      case 'lockedOut':
        return 'Temporalmente bloqueado. Intenta más tarde.';
      case 'PermanentlyLockedOut':
      case 'permanentlyLockedOut':
        return 'Bloqueo permanente. Desbloquea con el método del sistema.';
      default:
        return 'Error de autenticación: $code';
    }
  }

  void _toast(String msg, {bool error = false}) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFE11D48) : const Color(0xFF22C55E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(
        children: [
          Icon(error ? Icons.error_outline : Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 2),
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

  // ===== Banner premium "doble atrás para salir" =====
  void _showExitBanner() {
    final messenger = ScaffoldMessenger.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + 12),
        duration: const Duration(seconds: 2),
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 12)),
              BoxShadow(color: Color(0x26000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Atrás otra vez para salir de la app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      _showExitBanner();
      // Bloqueamos el pop: no devolvemos resultado a StartGate (así no te manda a Home)
      return false;
    }
    // Segunda vez dentro de la ventana → salir de la app de forma segura
    await SystemNavigator.pop();
    return false; // no pop de esta ruta (ya cerramos la app)
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool tecladoAbierto = bottomInset > 0;
    final double h = MediaQuery.of(context).size.height;

    final String title = _loading ? 'Cargando…' : 'Verifica tu identidad';

    // Posición del panel más arriba (y ajusta si aparece el teclado)
    final double panelAlignY = tecladoAbierto ? 0.80 : 0.20; // -1 top, 1 bottom

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.gradTop, AppTheme.gradBottom],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Logo
                Positioned(
                  top: _logoTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        opacity: 1.0,
                        child: Image.asset(
                          'assets/images/logoB.png',
                          height: _logoHeight,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // Watermark sutil en el centro
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 180,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                ),

                // Panel Glass (subido)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  alignment: Alignment(0, panelAlignY),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 560,
                      maxHeight: tecladoAbierto ? h * 0.70 : h * 0.58,
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
                        border: Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                            child: SingleChildScrollView(
                              physics: tecladoAbierto
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Título (usa tipografía del tema)
                                  Center(
                                    child: Text(
                                      title,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.black26,
                                            blurRadius: 6,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Tarjeta blanca
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
                                      border: Border.all(
                                        color: const Color(0xFFE9EEF5),
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.lock_outline_rounded,
                                          size: 36,
                                          color: Color(0xFF111827),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Usa el método de desbloqueo de tu dispositivo.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppTheme.gradTop,
                                              foregroundColor: Colors.white,
                                              shape: const StadiumBorder(),
                                              textStyle: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                              elevation: 2,
                                            ),
                                            onPressed: _authInProgress ? null : _triggerAuth,
                                            icon: const Icon(Icons.verified_user_rounded),
                                            label: Text(_authInProgress ? 'Verificando…' : 'Desbloquear'),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (!_deviceCanAuth && !_loading)
                                          const Text(
                                            'No hay un bloqueo configurado en este dispositivo.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Color(0xFFEF4444),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],
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

                // Botón back: usa el mismo flujo de doble-atrás
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => _onWillPop(),
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
