import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _localAuth = LocalAuthentication();

  bool _loading = true;
  bool _creating = false;       // true = crear/confirmar PIN, false = validar
  String? _pinGuardado;         // si existe en Firestore
  String? _primerIntento;       // para confirmar
  bool _bioEnabled = false;     // flag guardado en Firestore
  bool _deviceCanBio = false;   // soporte en el dispositivo

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
      // soporte biométrico del dispositivo
      final canCheck = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      _deviceCanBio = canCheck || supported;

      final doc = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      _pinGuardado = (settings['pinCode'] as String?)?.trim();
      _bioEnabled = settings['biometria'] == true;

      // si no hay PIN guardado, iniciamos flujo de creación
      _creating = (_pinGuardado == null || _pinGuardado!.isEmpty);
    } catch (_) {
      _creating = true;
      _pinGuardado = null;
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
      Future.delayed(const Duration(milliseconds: 180), () => _focus.requestFocus());
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
        'pinEnabled': true, // asegurar activo
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

  Future<bool> _autenticarBiometria({String reason = 'Autentícate para continuar'}) async {
    try {
      if (!_deviceCanBio) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  void _onSubmit(String value) async {
    final pin = value.trim();
    if (pin.length != 4) return;

    if (_creating) {
      // Crear/confirmar flujo
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
          Navigator.pop(context, true); // éxito → caller decide navegación
        } else {
          _primerIntento = null;
          _ctrl.clear();
          _toast('Los PIN no coinciden', error: true);
        }
      }
      return;
    }

    // Validación
    if (_pinGuardado != null && pin == _pinGuardado) {
      Navigator.pop(context, true); // éxito
    } else {
      _ctrl.clear();
      _toast('PIN incorrecto', error: true);
    }
  }

  void _toast(String msg, {bool error = false}) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFE11D48) : const Color(0xFF22C55E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Text(
        msg,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

  Future<void> _onUsarHuella() async {
    if (!_bioEnabled || !_deviceCanBio) {
      _toast('Biometría no disponible', error: true);
      return;
    }
    final ok = await _autenticarBiometria(reason: 'Usa tu huella/FaceID para ingresar');
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _toast('Autenticación fallida', error: true);
    }
  }

  Future<void> _onOlvidePin() async {
    // Hoja con opciones
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  'Elige una opción para recuperar el acceso.',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (_bioEnabled && _deviceCanBio)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 2,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        final ok = await _autenticarBiometria(
                            reason: 'Confirma con tu huella/FaceID para borrar el PIN');
                        if (!mounted) return;
                        if (ok) {
                          await _borrarPinEnFirestore();
                          _toast('PIN borrado. Puedes entrar y configurar otro cuando quieras.');
                          Navigator.pop(context, true); // acceso concedido
                        } else {
                          _toast('No se pudo confirmar tu identidad', error: true);
                        }
                      },
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Usar huella/FaceID para BORRAR PIN'),
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
                      // Salida segura: cerrar sesión → StartGate te lleva a Home y podrás iniciar nuevamente.
                      Navigator.pop(context);
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      _toast('Sesión cerrada. Inicia nuevamente para recuperar acceso.');
                      Navigator.pop(context, false); // caller decide navegar a Home
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

  @override
  Widget build(BuildContext context) {
    final title = _loading
        ? 'Cargando…'
        : _creating
        ? (_primerIntento == null ? 'Crea tu PIN' : 'Confirma tu PIN')
        : 'Ingresa tu PIN';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.96),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE8EEF8)),
              ),
              child: _loading
                  ? Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                  SizedBox(width: 10),
                  Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
                ],
              )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onChanged: (v) {
                        if (v.length == 4) {
                          // dispara al llegar a 4
                          _onSubmit(v);
                        }
                      },
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      textAlign: TextAlign.center,
                      obscureText: true,
                      decoration: const InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Color(0xFFF7FAFF),
                        hintText: '••••',
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ),
                      style: const TextStyle(
                        letterSpacing: 8,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _creating ? 'PIN de 4 dígitos' : 'Introduce tu PIN de 4 dígitos',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Acciones contextuales
                  if (!_creating) ...[
                    if (_bioEnabled && _deviceCanBio)
                      SizedBox(
                        width: 220,
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            textStyle: const TextStyle(fontWeight: FontWeight.w900),
                            elevation: 2,
                          ),
                          onPressed: _onUsarHuella,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Usar huella / FaceID'),
                        ),
                      ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _onOlvidePin,
                      child: const Text(
                        'Olvidé mi PIN',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () {
                        // Cambiar PIN → pasa a modo crear
                        setState(() {
                          _creating = true;
                          _primerIntento = null;
                          _ctrl.clear();
                        });
                      },
                      child: const Text('Cambiar PIN'),
                    ),
                  ] else ...[
                    // En modo creación: botón cancelar creación
                    TextButton(
                      onPressed: () {
                        // Si estaba creando porque no existía, cancelar vuelve al caller sin desbloquear
                        Navigator.pop(context, false);
                      },
                      child: const Text('Cancelar'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
