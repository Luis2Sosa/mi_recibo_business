import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io'; // ⬅️ para exit(0)

import 'theme/app_theme.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  // ====== Estado / Control ======
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _localAuth = LocalAuthentication();

  bool _loading = true;
  bool _creating = false;       // true = crear/confirmar PIN, false = validar
  String? _pinGuardado;         // si existe en Firestore
  String? _primerIntento;       // para confirmar
  bool _bioEnabled = false;     // flag guardado en Firestore (o switch unificado)
  bool _deviceCanBio = false;   // soporte en el dispositivo
  bool _authInProgress = false; // evita doble toques al prompt

  DateTime? _lastBack;          // doble “atrás” para salir

  // ====== Estética (alineado con AgregarClienteScreen) ======
  static const double _logoTop = -70;
  static const double _logoHeight = 300;

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pop(context, false);
      return;
    }
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      _deviceCanBio = canCheck || supported;

      final doc = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};

      // Un solo switch de seguridad o el legacy 'biometria'
      final bool securityEnabled = settings['securityEnabled'] == true;
      _bioEnabled = securityEnabled || (settings['biometria'] == true);

      _pinGuardado = (settings['pinCode'] as String?)?.trim();
      _creating = (_pinGuardado == null || _pinGuardado!.isEmpty);

      // Activa biometría si ya hay PIN guardado (para probar ya)
      if (!_creating && _bioEnabled == false) {
        _bioEnabled = true;
      }
    } catch (_) {
      _creating = true;
      _pinGuardado = null;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
      // Foco al campo en un pulso
      Future.delayed(const Duration(milliseconds: 180), () => _focus.requestFocus());
      // ❌ Nada de biometría automática. Solo al tocar el botón.
    }
  }

  Future<void> _guardarPinNuevo(String pin) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(user.uid)
        .set({
      'settings': {
        'pinCode': pin,
        'pinEnabled': true,
      }
    }, SetOptions(merge: true));
  }

  Future<void> _borrarPinEnFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(user.uid)
        .set({
      'settings': {
        'pinCode': null,
        'pinEnabled': false,
      }
    }, SetOptions(merge: true));
  }

  // Autenticación con fallback al PIN/patrón del sistema (una sola vez)
  Future<bool> _autenticarBiometria({String reason = 'Autentícate para continuar'}) async {
    try {
      if (!_deviceCanBio) return false;

      // 👇 Evita reintentos/sticky al volver de background
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // permite credencial del dispositivo si la biometría falla/cancela
          stickyAuth: false,      // <- importante para evitar prompt doble
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('LocalAuth error: ${e.code} - ${e.message}');
      String msg = 'No se pudo usar biometría.';
      switch (e.code) {
        case 'NotAvailable':
        case 'notAvailable':
          msg = 'Este dispositivo no tiene biometría disponible.';
          break;
        case 'NotEnrolled':
        case 'notEnrolled':
          msg = 'No hay huella/rostro configurado. Actívalo en Ajustes.';
          break;
        case 'PasscodeNotSet':
        case 'passcodeNotSet':
          msg = 'Configura un bloqueo de pantalla para activar biometría.';
          break;
        case 'LockedOut':
        case 'lockedOut':
          msg = 'Biometría temporalmente bloqueada. Intenta luego.';
          break;
        case 'PermanentlyLockedOut':
        case 'permanentlyLockedOut':
          msg = 'Biometría bloqueada. Desbloquea con el PIN del sistema.';
          break;
        default:
          msg = 'Error de biometría: ${e.code}';
      }
      _toast(msg, error: true);
      return false;
    } catch (_) {
      return false;
    }
  }

  // ====== UX Utils ======
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

  // ===== Banner doble atrás (premium) para salir de la app =====
  void _showExitBanner() {
    final messenger = ScaffoldMessenger.of(context);
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent, // no mezclar con el fondo
        elevation: 0,
        // más abajo para no chocar con botones
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomSafe + -20),
        duration: const Duration(seconds: 2),
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000), // sombra fuerte
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B), // navy sólido (alto contraste)
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white, width: 2), // borde blanco premium
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // pastilla/icón teal
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: const Color(0xFF14B8A6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'Presiona atrás otra vez para salir de la app',
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

  // Evita dobles toques, cancela sesiones previas y abre prompt 1 sola vez
  Future<void> _onUsarHuella() async {
    if (_authInProgress) return;
    if (!_bioEnabled || !_deviceCanBio) {
      _toast('Biometría no disponible', error: true);
      return;
    }

    // cancela cualquier prompt activo antes de abrir uno nuevo
    try { await _localAuth.stopAuthentication(); } catch (_) {}

    _authInProgress = true;
    final ok = await _autenticarBiometria(reason: 'Accede con tu rostro o huella');

    // pequeño delay para evitar redisparos por rebuild inmediatos
    await Future.delayed(const Duration(milliseconds: 300));
    _authInProgress = false;

    if (!mounted) return;
    if (ok) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } else {
      _toast('Autenticación cancelada', error: true);
    }
  }

  Future<void> _onOlvidePin() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('¿Olvidaste tu PIN?',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 6),
                const Text(
                  'Puedes confirmar tu identidad con rostro/huella para borrar el PIN o cerrar sesión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (_bioEnabled && _deviceCanBio)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.gradTop,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 2,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final ok = await _autenticarBiometria(
                          reason: 'Confirma tu identidad para borrar el PIN',
                        );
                        if (!mounted) return;
                        if (ok) {
                          await _borrarPinEnFirestore();
                          _toast('PIN borrado. Entra y configura otro cuando quieras.');
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context, true);
                          }
                        } else {
                          _toast('No se pudo confirmar tu identidad', error: true);
                        }
                      },
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Borrar PIN con rostro/huella'),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE11D48),
                      side: const BorderSide(color: Color(0xFFE11D48)),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      _toast('Sesión cerrada. Inicia nuevamente.');
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context, false);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _onBackPressed() async {
    final now = DateTime.now();
    if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
      _lastBack = now;
      _showExitBanner();   // 👈 muestra el banner premium
      return false;        // no salir todavía
    }
    exit(0);               // 👈 segunda vez: salir COMPLETO
    // ignore: dead_code
    return false;
  }

  void _onSubmit(String value) async {
    final pin = value.trim();
    if (pin.length != 4) return;

    if (_creating) {
      if (_primerIntento == null) {
        setState(() => _primerIntento = pin);
        _ctrl.clear();
        _toast('Repite el PIN para confirmar');
        return;
      } else {
        if (_primerIntento == pin) {
          setState(() => _loading = true);
          await _guardarPinNuevo(pin);
          if (!mounted) return;
          _toast('PIN configurado ✅');
          if (Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        } else {
          _primerIntento = null;
          _ctrl.clear();
          _toast('Los PIN no coinciden', error: true);
        }
      }
      return;
    }

    if (_pinGuardado != null && pin == _pinGuardado) {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } else {
      _ctrl.clear();
      _toast('PIN incorrecto', error: true);
    }
  }

  // ====== UI ======
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bool tecladoAbierto = bottomInset > 0;
    final double h = MediaQuery.of(context).size.height;

    final String title = _loading
        ? 'Cargando…'
        : _creating
        ? (_primerIntento == null ? 'Crea tu PIN' : 'Confirma tu PIN')
        : 'Ingresa tu PIN';

    return WillPopScope(
      onWillPop: _onBackPressed,
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
                // ===== Logo =====
                Positioned(
                  top: _logoTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        opacity: tecladoAbierto ? 1 : 1.0,
                        child: Image.asset(
                          'assets/images/logoB.png',
                          height: _logoHeight,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),

                // ===== Panel Glass =====
                Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      bottom: tecladoAbierto ? bottomInset + 12 : 10,
                      left: 16,
                      right: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: tecladoAbierto ? h * 0.75 : h * 0.90,
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
                                    // ===== Título =====
                                    Center(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          shadows: [
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

                                    // ===== Tarjeta blanca =====
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
                                          // Campo PIN
                                          SizedBox(
                                            width: 240,
                                            child: TextField(
                                              controller: _ctrl,
                                              focusNode: _focus,
                                              onChanged: (v) {
                                                if (v.length == 4) _onSubmit(v);
                                              },
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                                LengthLimitingTextInputFormatter(4),
                                              ],
                                              textAlign: TextAlign.center,
                                              obscureText: true,
                                              decoration: InputDecoration(
                                                counterText: '',
                                                filled: true,
                                                fillColor: const Color(0xFFF7FAFF),
                                                hintText: '••••',
                                                hintStyle: const TextStyle(
                                                  letterSpacing: 8,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderSide: BorderSide.none,
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                letterSpacing: 8,
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _creating
                                                ? 'PIN de 4 dígitos'
                                                : 'Introduce tu PIN de 4 dígitos',
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF64748B),
                                                fontWeight: FontWeight.w700),
                                          ),
                                          const SizedBox(height: 16),

                                          // Botón biometría (con fallback y bloqueo mientras autentica)
                                          if (!_creating && _bioEnabled && _deviceCanBio)
                                            SizedBox(
                                              width: double.infinity,
                                              height: 50,
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.gradTop,
                                                  foregroundColor: Colors.white,
                                                  shape: const StadiumBorder(),
                                                  textStyle: const TextStyle(
                                                      fontWeight: FontWeight.w900),
                                                  elevation: 2,
                                                ),
                                                onPressed: _authInProgress ? null : _onUsarHuella,
                                                icon: const Icon(Icons.fingerprint),
                                                label: const Text('Acceder con rostro o huella'),
                                              ),
                                            ),

                                          if (!_creating && _bioEnabled && _deviceCanBio)
                                            const SizedBox(height: 12),

                                          // Acciones
                                          if (!_creating) ...[
                                            TextButton(
                                              onPressed: _onOlvidePin,
                                              child: const Text(
                                                'Olvidé mi PIN',
                                                style: TextStyle(fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ] else ...[
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
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
                        ),
                      ),
                    ),
                  ),
                ),

                // Botón back
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
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
