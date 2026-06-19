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

  @override
  void initState() {
    super.initState();
    _initAndAutoPrompt();
  }

  Future<void> _initAndAutoPrompt() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      // isDeviceSupported() en Android devuelve KeyguardManager.isDeviceSecure():
      // true SOLO si el dispositivo tiene PIN, patrón, contraseña o biometría
      // configurados. Si el celular solo se desliza (sin bloqueo real), da false.
      final supported = await _localAuth.isDeviceSupported();
      _deviceCanAuth = canCheck || supported;
    } catch (_) {
      _deviceCanAuth = false;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);

      // FIX: solo se intenta el auto-prompt si el dispositivo SÍ tiene
      // algún método de bloqueo configurado. Si no tiene, no se dispara
      // ningún intento de autenticación automático.
      if (_deviceCanAuth && !_autoTried) {
        _autoTried = true;
        await Future.delayed(const Duration(milliseconds: 120));
        _triggerAuth();
      }
    }
  }

  Future<void> _triggerAuth() async {
    if (_authInProgress) return;

    // FIX: si el dispositivo no tiene ningún bloqueo configurado, no se
    // permite continuar bajo ninguna circunstancia. Esta función ya no
    // se puede ni siquiera invocar desde la UI (el botón queda
    // deshabilitado), pero se deja esta verificación como segunda barrera.
    if (!_deviceCanAuth) {
      _toast(
        'Tu dispositivo no tiene un método de bloqueo configurado (PIN, patrón, huella o rostro). Actívalo en Ajustes para poder continuar.',
        error: true,
      );
      return;
    }

    try {
      await _localAuth.stopAuthentication();
    } catch (_) {}

    _authInProgress = true;
    if (mounted) setState(() {});

    bool ok = false;
    try {
      ok = await _localAuth.authenticate(
        localizedReason: 'Verifica tu identidad para continuar',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: false,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      // FIX: mounted check antes de usar context en el catch
      if (!mounted) return;
      _toast(_mapLocalAuthError(e.code), error: true);
    } catch (_) {
      if (!mounted) return;
      _toast('No se pudo autenticar.', error: true);
    } finally {
      await Future.delayed(const Duration(milliseconds: 200));
      // FIX: mounted check en finally antes de modificar estado
      if (!mounted) return;
      _authInProgress = false;
      setState(() {});
    }

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
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
      backgroundColor:
      error ? const Color(0xFFE11D48) : const Color(0xFF22C55E),
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(
        children: [
          Icon(
              error ? Icons.error_outline : Icons.check_circle,
              color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 3),
    );
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

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
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 24,
                  offset: Offset(0, 12)),
              BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 8,
                  offset: Offset(0, 2)),
            ],
          ),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
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

  // WillPopScope → PopScope (WillPopScope deprecado en Flutter 3.12+)
  // onPopInvoked recibe didPop=true si el pop ya ocurrió, false si fue bloqueado
  void _onPopInvoked(bool didPop) async {
    if (didPop) return; // el pop ya se procesó, nada que hacer

    final now = DateTime.now();
    if (_lastBack == null ||
        now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      _showExitBanner();
      // No hacemos pop: bloqueamos la salida la primera vez
      return;
    }
    // Segunda pulsación dentro de la ventana → cerrar la app
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final String title = _loading ? 'Cargando…' : 'Verifica tu identidad';

    return PopScope(
      // canPop: false bloquea el pop por defecto; onPopInvoked maneja la lógica
      canPop: false,
      onPopInvoked: _onPopInvoked,
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
                // Watermark sutil (de fondo, no interfiere con el layout)
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

                // FIX PRINCIPAL: en vez de un Stack con AnimatedAlign al
                // centro (que hacía que el panel quedara EXACTAMENTE sobre
                // el logo y lo tapara), ahora el logo y el panel viven en
                // dos zonas separadas de un Column. El logo ocupa la parte
                // de arriba y el panel queda anclado abajo, dentro de su
                // propia zona, sin poder pisar al logo nunca.
                Column(
                  children: [
                    // Zona del logo (arriba)
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          opacity: 1.0,
                          child: Image.asset(
                            'assets/images/logoB.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    // Zona del panel (mucho más abajo, nunca se solapa)
                    Expanded(
                      flex: 6,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: 28, left: 16, right: 16),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: _buildPanel(context, title),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Botón back: usa el mismo flujo de doble-atrás
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: Colors.white),
                    onPressed: () => _onPopInvoked(false),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, String title) {
    // FIX: el botón ahora se deshabilita por completo y cambia de texto
    // cuando el dispositivo NO tiene ningún bloqueo configurado. Así no
    // solo se evita el acceso, sino que es visualmente obvio que no hay
    // nada que se pueda activar.
    final bool puedeDesbloquear = _deviceCanAuth && !_loading;

    String labelBoton;
    if (_authInProgress) {
      labelBoton = 'Verificando…';
    } else if (_loading) {
      labelBoton = 'Cargando…';
    } else if (!_deviceCanAuth) {
      labelBoton = 'Sin bloqueo configurado';
    } else {
      labelBoton = 'Desbloquear';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
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
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    border: Border.all(color: const Color(0xFFE9EEF5)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 36,
                        color: puedeDesbloquear
                            ? const Color(0xFF111827)
                            : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        puedeDesbloquear
                            ? 'Usa el método de desbloqueo de tu dispositivo.'
                            : 'No hay un método de bloqueo configurado en este dispositivo.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
                            backgroundColor: puedeDesbloquear
                                ? AppTheme.gradTop
                                : const Color(0xFFCBD5E1),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFFCBD5E1),
                            disabledForegroundColor: Colors.white70,
                            shape: const StadiumBorder(),
                            textStyle:
                            const TextStyle(fontWeight: FontWeight.w900),
                            elevation: puedeDesbloquear ? 2 : 0,
                          ),
                          // FIX: si el dispositivo no tiene bloqueo, o ya
                          // está autenticando, o todavía está cargando,
                          // el botón queda deshabilitado (onPressed: null).
                          // Esto impide físicamente "activar bloqueo" en un
                          // celular sin ningún método de seguridad.
                          onPressed: (_authInProgress || !puedeDesbloquear)
                              ? null
                              : _triggerAuth,
                          icon: Icon(_authInProgress
                              ? Icons.hourglass_top_rounded
                              : Icons.verified_user_rounded),
                          label: Text(labelBoton),
                        ),
                      ),
                      if (!_deviceCanAuth && !_loading) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Ve a Ajustes de tu teléfono y configura un PIN, patrón, huella o reconocimiento facial para poder usar esta app.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
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