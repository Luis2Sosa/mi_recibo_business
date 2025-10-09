import 'dart:async';
import 'package:flutter/material.dart';
import 'cliente_detalle_screen.dart';
import 'perfil_prestamista/perfil_prestamista_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'agregar_cliente_screen.dart';
import 'package:flutter/services.dart';
import 'dart:io' show exit, Platform;
import 'dart:ui' show FontFeature;



// 🔥 Firestore + Auth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔔 FCM (añadido)
import 'package:firebase_messaging/firebase_messaging.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce; // para debounce del buscador

  // Suscripciones
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _seguridadSub;

  // Vencimientos
  bool _resaltarVencimientos = true;

  // Bienvenida
  bool _bienvenidaMostrada = false;

  // ===== Datos del prestamista para el recibo =====
  String _empresa = '';
  String _servidor = '';
  String _telefonoServidor = '';

  // ===== Filtro por chips =====
  FiltroClientes _filtro = FiltroClientes.todos;

  // ===== Intent de notificación: 'vencidos' | 'hoy' | 'pronto' =====
  String? _intent;
  bool _intentBannerMostrado = false;

  // 🔒 Lee si debe mostrarse el aviso de PIN/huella/facial
  bool _lockEnabled = false;

  // 👇 NUEVO: detecta si venimos de un registro recién completado
  bool _esRecienRegistrado = false;

  @override
  void initState() {
    super.initState();
    _cargarPerfilPrestamista();
    _cargarSeguridad();              // 👈 carga inicial
    _escucharSeguridadTiempoReal();  // 👈 escucha en tiempo real

    // ⬇️ NUEVO: guardar token FCM y escuchar mensajes en foreground
    _guardarTokenFCM();
    _fcmSub = FirebaseMessaging.onMessage.listen((m) {
      // ignore: avoid_print
      print('📩 Push (foreground): ${m.notification?.title} - ${m.notification?.body}');
    });
  }

  // 🕛 Normaliza al mediodía para evitar líos de zona horaria
  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  // 👇 Lee prestamistas/<uid actual> (datos básicos del prestamista para el recibo)
  Future<void> _cargarPerfilPrestamista() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .get();

      final data = doc.data() ?? {};
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();

      setState(() {
        _empresa = (data['empresa'] ?? '').toString().trim();
        _servidor = [nombre, apellido].where((s) => s.isNotEmpty).join(' ').trim();
        _telefonoServidor = (data['telefono'] ?? '').toString().trim();
      });
    } catch (_) {
      // si falla, simplemente quedan strings vacíos
    }
  }

  // 🔒 Lee settings.lockEnabled (true = mostrar línea de PIN/huella)
  Future<void> _cargarSeguridad() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .get();
      final data = snap.data() ?? {};
      final settings = (data['settings'] as Map?) ?? {};
      final val = settings['lockEnabled'];
      if (!mounted) return;
      setState(() {
        _lockEnabled = (val is bool) ? val : false;
      });
    } catch (_) {
      // si falla, dejamos _lockEnabled en false
    }
  }

  // 👂 Escucha en tiempo real los cambios del campo settings.lockEnabled
  void _escucharSeguridadTiempoReal() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _seguridadSub = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;

      final data = doc.data();
      final settings = (data?['settings'] as Map?) ?? {};
      final val = settings['lockEnabled'];

      if (mounted) {
        setState(() {
          _lockEnabled = (val is bool) ? val : false;
        });
      }
    });
  }

  // 🔔 NUEVO: guarda el token FCM en prestamistas/{uid}/meta.fcmToken
  Future<void> _guardarTokenFCM() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // En Android 13+/iOS hay que pedir permiso
      await FirebaseMessaging.instance.requestPermission();

      // Obtener token del dispositivo
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;

      await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(user.uid)
          .set({'meta': {'fcmToken': token}}, SetOptions(merge: true));

      // ignore: avoid_print
      print('✅ FCM token guardado: $token');

      // (Opcional) Suscribirse a un tema común
      // await FirebaseMessaging.instance.subscribeToTopic('diarias');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error guardando FCM token: $e');
    }
  }

  // ---- Banner estilo Badoo (2s) ----
  void _showBanner(
      String texto, {
        Color? bg,            // nombre nuevo
        Color? color,         // alias para compatibilidad con tus llamadas actuales
        IconData icon = Icons.info_outline, // ya no se usa, pero lo dejo para compatibilidad
      }) {
    final background = bg ?? color ?? const Color(0xffe9ce53); // amarillo RD

    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      duration: const Duration(seconds: 3), // tu duración preferida
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // 👇 Solo texto centrado (sin icono lateral)
        child: Center(
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

  // ===== Banner profesional para salir (modal bloqueante) =====
  Future<void> _confirmarSalirCliente() async {
    final bool? salir = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline, size: 26, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(height: 14),
                const Text(
                  '¿Seguro que quieres salir?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),

                // 👇 Solo mostramos la línea de PIN/huella si settings.lockEnabled == true
                if (_lockEnabled)
                  const Text(
                    'Al reabrir, validaremos tu identidad con el desbloqueo de tu dispositivo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                  ),

                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F4F6),
                          foregroundColor: const Color(0xFF111827),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        child: const Text('Volver'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        child: const Text('Sí, salir'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (salir == true) {
      // 🔥 Mata el proceso para que Android arranque la app desde 0 (mostrará PinScreen)
      if (Platform.isAndroid) {
        exit(0);
      } else {
        // fallback para otras plataformas
        SystemNavigator.pop();
      }
    }
  }

  int _diasHasta(DateTime d) {
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  _EstadoVenc _estadoDe(_Cliente c) {
    final d = _diasHasta(c.proximaFecha);
    if (d < 0) return _EstadoVenc.vencido; // vencido
    if (d == 0) return _EstadoVenc.hoy; // hoy
    if (d <= 2) return _EstadoVenc.pronto; // faltan 1–2 días
    return _EstadoVenc.alDia; // más de 2 días
  }

  bool _esSaldado(_Cliente c) => c.saldoActual <= 0;

  // Orden: primero NO saldados; luego saldados. Dentro: por proximaFecha; si empatan, por nombre.
  int _compareClientes(_Cliente a, _Cliente b) {
    final sa = _esSaldado(a);
    final sb = _esSaldado(b);
    if (sa != sb) return sa ? 1 : -1; // saldados al final
    final fa = a.proximaFecha;
    final fb = b.proximaFecha;
    if (fa != fb) return fa.compareTo(fb);
    return a.nombreCompleto.compareTo(b.nombreCompleto);
  }

  // ---------- Acciones ----------
  void _abrirEditarCliente(_Cliente c) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarClienteScreen(
          id: c.id,
          initNombre: c.nombre,
          initApellido: c.apellido,
          initTelefono: c.telefono,
          initDireccion: c.direccion,
          initProducto: c.producto,
          initCapital: c.capitalInicial,
          initTasa: c.tasaInteres,
          initPeriodo: c.periodo,
          initProximaFecha: c.proximaFecha,
        ),
      ),
    );

    if (result == null || result is! Map) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Datos del form
    final String nombre = (result['nombre'] as String).trim();
    final String apellido = (result['apellido'] as String).trim();
    final String nombreCompleto = '$nombre $apellido';
    final String telefono = (result['telefono'] as String).trim();
    final String? direccion = ((result['direccion'] as String?)?.trim().isEmpty ?? true)
        ? null
        : (result['direccion'] as String).trim();
    final String? producto = ((result['producto'] as String?)?.trim().isEmpty ?? true)
        ? null
        : (result['producto'] as String).trim();
    final String? nota = ((result['nota'] as String?)?.trim().isEmpty ?? true)
        ? null
        : (result['nota'] as String).trim();

    final int nuevoCapital = result['capital'] as int? ?? c.capitalInicial;
    final double tasa = result['tasa'] as double? ?? c.tasaInteres;
    final String periodo = result['periodo'] as String? ?? c.periodo;
    final DateTime nuevaProxRaw = result['proximaFecha'] as DateTime? ?? c.proximaFecha;
    final DateTime nuevaProx = _atNoon(nuevaProxRaw); // 🕛 normaliza

    final docId = result['id'] ?? c.id;
    final docRef = FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .collection('clientes')
        .doc(docId);

    try {
      // 1) Actualiza datos generales (sin tocar saldos/estado todavía)
      final Map<String, dynamic> update = {
        'nombre': nombre,
        'apellido': apellido,
        'nombreCompleto': nombreCompleto,
        'telefono': telefono,
        'direccion': direccion,
        'producto': producto,
        'nota': nota,
        'capitalInicial': nuevoCapital,
        'tasaInteres': tasa,
        'periodo': periodo,
        'proximaFecha': Timestamp.fromDate(nuevaProx),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await docRef.set(update, SetOptions(merge: true));

      // 2) LÓGICA DE RENOVACIÓN AUTOMÁTICA CUANDO APLICA
      final bool estabaSaldado = c.saldoActual <= 0;
      final bool capitalCambiado = nuevoCapital != c.saldoActual;
      final bool renovarFlag = (result['renovar'] as bool?) ?? false;

      // Renovar si: flag explícito, o si estaba saldado y ahora hay capital,
      // o si el capital cambió (intención evidente de reestructurar).
      final bool renovar = renovarFlag || (estabaSaldado && nuevoCapital > 0) || capitalCambiado;

      if (renovar) {
        final Map<String, dynamic> ren = {
          'saldoActual': nuevoCapital,
          'saldado': nuevoCapital <= 0,
          'estado': nuevoCapital <= 0 ? 'saldado' : 'al_dia',
          'proximaFecha': Timestamp.fromDate(nuevaProx),
          'updatedAt': FieldValue.serverTimestamp(),
          'venceEl': nuevoCapital <= 0
              ? FieldValue.delete()
              : Timestamp.fromDate(nuevaProx),
        };
        await docRef.set(ren, SetOptions(merge: true));

        // Sumar SOLO el extra prestado (si hay)
        final int extra = nuevoCapital - c.saldoActual;
        if (extra > 0) {
          await docRef.set({
            'totalPrestado': FieldValue.increment(extra),
          }, SetOptions(merge: true));
        }

        _showBanner('Renovación aplicada ✅', color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
      } else {
        _showBanner('Cliente actualizado ✅', color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
      }
    } catch (e) {
      _showBanner('Error al actualizar: $e', color: const Color(0xFFFFF1F2), icon: Icons.error_outline);
    }
  }



  Future<void> _abrirAgregarCliente() async {
    final res = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AgregarClienteScreen()));
    if (res is Map) {
      _showBanner('Cliente agregado correctamente ✅',
          color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
    }
  }

  void _confirmarEliminar(_Cliente c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Seguro que deseas eliminar a ${c.nombreCompleto}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final scaffoldCtx = context;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              try {
                await FirebaseFirestore.instance
                    .collection('prestamistas')
                    .doc(uid)
                    .collection('clientes')
                    .doc(c.id)
                    .delete();
                Navigator.pop(scaffoldCtx);
                if (mounted) {
                  _showBanner('Cliente eliminado',
                      color: const Color(0xFFFFF1F2), icon: Icons.delete_outline);
                }
              } catch (e) {
                Navigator.pop(scaffoldCtx);
                if (mounted) {
                  _showBanner('Error al eliminar: $e',
                      color: const Color(0xFFFFF1F2), icon: Icons.error_outline);
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesCliente(_Cliente c) {
    bool _cerrado = false; // para no cerrar si ya se cerró manualmente

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55), // 🔆 un poco más oscuro
      isScrollControlled: false,  // no altura full-screen
      isDismissible: true,        // tocar fuera lo cierra
      enableDrag: false,          // sin drag/scroll del sheet
      builder: (sheetCtx) {
        // ⏱️ Autocierre tras N segundos si no hay interacción
        const int autoCloseSeconds = 6; // cambia a 5 o 7 si prefieres
        Future.delayed(const Duration(seconds: autoCloseSeconds), () {
          if (!_cerrado && Navigator.of(sheetCtx).canPop()) {
            Navigator.of(sheetCtx).pop(); // cierra solo el sheet
          }
        });

        // Ítem premium (mismo helper tuyo)
        Widget _actionItem({
          required String title,
          required IconData icon,
          required Color color,
          required VoidCallback onTap,
          bool destructive = false,
        }) {
          final Color capsuleBg = color.withOpacity(0.12);
          return InkWell(
            onTap: () { HapticFeedback.selectionClick(); onTap(); },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: capsuleBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withOpacity(0.18)),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: destructive ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false, bottom: true, // respeta el home indicator
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.20),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 44, height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'Acciones',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),

                    _actionItem(
                      title: 'Editar',
                      icon: Icons.edit_rounded,
                      color: const Color(0xFF2563EB),
                      onTap: () {
                        _cerrado = true;
                        Navigator.pop(sheetCtx);
                        _abrirEditarCliente(c);
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFEFF1F5)),

                    _actionItem(
                      title: 'Eliminar',
                      icon: Icons.delete_rounded,
                      color: const Color(0xFFDC2626),
                      destructive: true,
                      onTap: () {
                        _cerrado = true;
                        Navigator.pop(sheetCtx);
                        _confirmarEliminar(c);
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFEFF1F5)),

                    _actionItem(
                      title: 'Cancelar',
                      icon: Icons.close_rounded,
                      color: const Color(0xFF64748B),
                      onTap: () {
                        _cerrado = true;
                        Navigator.pop(sheetCtx);
                      },
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      // si el usuario lo cerró manualmente, marcamos como cerrado para que el timer no actúe
      _cerrado = true;
    });
  }



  String _fmtFecha(DateTime d) {
    const meses = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Lee args para bienvenida existente
    if (!_bienvenidaMostrada) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final nombre = (args['bienvenidaNombre'] as String?)?.trim();
        final empresa = (args['bienvenidaEmpresa'] as String?)?.trim();

        // 👇 Marca que venimos de un registro recién completado (usa tus mismos argumentos)
        final recien = (args['recienRegistrado'] == true) ||
            ((nombre != null && nombre.isNotEmpty));

        if (recien) {
          _esRecienRegistrado = true;
        }

        if (nombre != null && nombre.isNotEmpty) {
          _bienvenidaMostrada = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final texto = (empresa != null && empresa.isNotEmpty)
                ? '¡Bienvenido, $nombre! ($empresa)'
                : '¡Bienvenido, $nombre!';
            _showBanner(texto, color: const Color(0xFFEFFBF3), icon: Icons.verified);
          });
        }
      }
    }

    // Lee args de intención de notificación
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _intent == null) {
      final intent = (args['intent'] as String?)?.trim();
      if (intent == 'vencidos' || intent == 'hoy' || intent == 'pronto') {
        _intent = intent;
        // No mostramos banner aquí; esperamos a tener datos del Stream para contar.
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _fcmSub?.cancel();
    _seguridadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double logoTop = -90;
    const double logoHeight = 300;
    const double contentTop = 95;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false, // controlamos el back manualmente
      onPopInvoked: (didPop) {
        if (didPop) return; // si otra capa ya hizo pop, no hacemos nada
        _confirmarSalirCliente(); // 👈 banner profesional bloqueante
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // ===== Columna principal =====
                Padding(
                  padding: const EdgeInsets.only(top: contentTop),
                  child: Column(
                    children: [
                      // ===== Tarjeta principal (título + buscador + lista) =====
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 14, left: 16, right: 16, bottom: 4),
                                    child: Text(
                                      'CLIENTES',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfairDisplay(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  // Buscador + botón agregar
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 48, // ⬆️
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: TextField(
                                              controller: _searchCtrl,
                                              onChanged: (txt) {
                                                // Debounce de 250ms para no recalcular en cada tecla
                                                _debounce?.cancel();
                                                _debounce = Timer(const Duration(milliseconds: 250), () {
                                                  if (mounted) setState(() {});
                                                });
                                              },
                                              decoration: InputDecoration(
                                                hintText: 'Buscar',
                                                hintStyle: const TextStyle(color: Color(0xFF111827)),
                                                prefixIcon:
                                                Icon(Icons.search, color: Colors.black.withOpacity(0.7)),
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.92),
                                                contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 14, vertical: 12),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 48, // ⬆️
                                          height: 48, // ⬆️
                                          child: Material(
                                            color: const Color(0xFF22C55E),
                                            borderRadius: BorderRadius.circular(14),
                                            elevation: 2,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(14),
                                              onTap: _abrirAgregarCliente,
                                              child: const Icon(Icons.add, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // === Chips de filtro (tus chips se mantienen igual) ===
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Todos'),
                                          selected: _filtro == FiltroClientes.todos,
                                          onSelected: (_) => setState(() => _filtro = FiltroClientes.todos),
                                          backgroundColor: Colors.white.withOpacity(0.85),
                                          selectedColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                                          labelStyle: TextStyle(
                                            color: _filtro == FiltroClientes.todos
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Text('Pendientes'),
                                          selected: _filtro == FiltroClientes.pendientes,
                                          onSelected: (_) =>
                                              setState(() => _filtro = FiltroClientes.pendientes),
                                          backgroundColor: Colors.white.withOpacity(0.85),
                                          selectedColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                                          labelStyle: TextStyle(
                                            color: _filtro == FiltroClientes.pendientes
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Text('Saldados'),
                                          selected: _filtro == FiltroClientes.saldados,
                                          onSelected: (_) =>
                                              setState(() => _filtro = FiltroClientes.saldados),
                                          backgroundColor: Colors.white.withOpacity(0.85),
                                          selectedColor: Colors.white,
                                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                                          labelStyle: TextStyle(
                                              color: _filtro == FiltroClientes.saldados
                                                  ? const Color(0xFF2563EB)
                                                  : const Color(0xFF0F172A),
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ===== Lista desde Firestore (tiempo real) =====
                                  Expanded(
                                    child: _buildClientesStream(uid),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== Barra mínima (perfil) =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PerfilPrestamistaScreen(),
                            ),
                          );
                        },
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, color: Color(0xFF2458D6)),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // ===== Logo (independiente) =====
                const Positioned(
                  top: -90,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Image(
                        image: AssetImage('assets/images/logoB.png'),
                        height: 300,
                        fit: BoxFit.contain,
                      ),
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

  Widget _buildClientesStream(String? uid) {
    if (uid == null) {
      return const Center(
        child: Text('No hay sesión. Inicia sesión.', style: TextStyle(color: Colors.white)),
      );
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .orderBy('proximaFecha', descending: false)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.white)),
          );
        }
        final docs = snap.data?.docs ?? [];

        // Mapear a modelo _Cliente
        final lista = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final codigoGuardado = (data['codigo'] as String?)?.trim();
          final codigoVisible = (codigoGuardado != null && codigoGuardado.isNotEmpty)
              ? codigoGuardado
              : _codigoDesdeId(d.id);
          return _Cliente(
            id: d.id,
            codigo: codigoVisible,
            nombre: (data['nombre'] ?? '') as String,
            apellido: (data['apellido'] ?? '') as String,
            telefono: (data['telefono'] ?? '') as String,
            direccion: data['direccion'] as String?,
            producto: (data['producto'] as String?)?.trim(),
            capitalInicial: (data['capitalInicial'] ?? 0) as int,
            saldoActual: (data['saldoActual'] ?? 0) as int,
            tasaInteres: (data['tasaInteres'] ?? 0.0).toDouble(),
            periodo: (data['periodo'] ?? 'Mensual') as String,
            proximaFecha: (data['proximaFecha'] is Timestamp)
                ? (data['proximaFecha'] as Timestamp).toDate()
                : DateTime.now(),
          );
        }).toList();

        // Filtro búsqueda
        final q = _searchCtrl.text.toLowerCase();
        var filtered = lista.where((c) {
          return c.codigo.toLowerCase().contains(q) ||
              c.nombreCompleto.toLowerCase().contains(q) ||
              c.telefono.contains(q);
        }).toList();

        // Filtro por chips
        filtered = filtered.where((c) {
          switch (_filtro) {
            case FiltroClientes.todos:
              return true;
            case FiltroClientes.pendientes:
              return c.saldoActual > 0;
            case FiltroClientes.saldados:
              return c.saldoActual <= 0;
          }
        }).toList()
          ..sort(_compareClientes);

        // === Cálculo de conteos para banner/intención ===
        int cVencidos = 0, cHoy = 0, cPronto = 0;
        for (final c in lista) {
          if (c.saldoActual <= 0) continue; // ignorar saldados
          final e = _estadoDe(c);
          if (e == _EstadoVenc.vencido) cVencidos++;
          else if (e == _EstadoVenc.hoy) cHoy++;
          else if (e == _EstadoVenc.pronto) cPronto++;
        }

        final bool hayClientes = lista.isNotEmpty;
        final bool hayActivos  = lista.any((c) => c.saldoActual > 0);

        // 👇 Auto-intent si no viene ninguno: prioridad VENCIDOS > HOY > PRONTO
        if (_intent == null) {
          if (cVencidos > 0) {
            _intent = 'vencidos';
          } else if (cHoy > 0) {
            _intent = 'hoy';
          } else if (cPronto > 0) {
            _intent = 'pronto';
          } else {
            _intent = 'hoy'; // para mostrar el "OK" si no hay nada
          }
          _intentBannerMostrado = false; // permitir que el banner se dispare
        }

        // Muestra banner SOLO una vez por intención, cuando ya tenemos datos
        if (_intent != null && !_intentBannerMostrado && mounted) {
          _intentBannerMostrado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_intent == 'vencidos') {
              if (cVencidos == 1) {
                // Buscar el cliente para singular
                final c = lista.firstWhere(
                      (x) => _estadoDe(x) == _EstadoVenc.vencido && x.saldoActual > 0,
                  orElse: () => lista.first,
                );
                _showBanner(
                  '⚠️ ${c.nombreCompleto} tiene un pago vencido.',
                  color: const Color(0xFFDC2626), // 🔴 rojo
                  icon: Icons.warning_amber_rounded,
                );
              } else if (cVencidos > 1) {
                _showBanner(
                  '⚠️ $cVencidos clientes tienen pagos vencidos.',
                  color: const Color(0xFFDC2626), // 🔴 rojo
                  icon: Icons.warning_amber_rounded,
                );
              } else {
                // ✅ Ajuste: NO mostrar "Aún no has agregado clientes" si viene de registro nuevo
                if (!hayClientes && !_esRecienRegistrado) {
                  _showBanner('Aún no has agregado clientes.',
                      color: const Color(0xFFEFFBF3), icon: Icons.info_outline);
                } else if (hayClientes && !hayActivos) {
                  _showBanner('No tienes clientes activos.',
                      color: const Color(0xFFEFFBF3), icon: Icons.info_outline);
                } else if (hayClientes && hayActivos) {
                  _showBanner('✅ No hay pagos vencidos ahora mismo.',
                      color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
                }
              }
            } else if (_intent == 'hoy') {
              if (cHoy == 1) {
                final c = lista.firstWhere(
                      (x) => _estadoDe(x) == _EstadoVenc.hoy && x.saldoActual > 0,
                  orElse: () => lista.first,
                );
                _showBanner(
                  '📆 ${c.nombreCompleto} vence hoy. No olvides cobrar.',
                  color: const Color(0xFFFB923C), // 🟠 naranja
                  //icon: Icons.event_available,
                );
              } else if (cHoy > 1) {
                _showBanner(
                  '📆 $cHoy clientes vencen hoy.',
                  color: const Color(0xFFFB923C), // 🟠 naranja
                  //icon: Icons.event_available,
                );
              } else {
                // ✅ Ajuste: NO mostrar "Aún no has agregado clientes" si viene de registro nuevo
                if (!hayClientes && !_esRecienRegistrado) {
                  _showBanner('Aún no has agregado clientes.',
                      color: const Color(0xFFEFFBF3), icon: Icons.info_outline);
                } else if (hayClientes && !hayActivos) {
                  _showBanner('No tienes clientes activos.',
                      color: const Color(0xFFEFFBF3), icon: Icons.info_outline);
                } else if (hayClientes && hayActivos) {
                  _showBanner('✅ Nadie vence hoy.',
                      color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
                }
              }
            } else if (_intent == 'pronto') {
              if (cPronto == 1) {
                final c = lista.firstWhere(
                      (x) => _estadoDe(x) == _EstadoVenc.pronto && x.saldoActual > 0,
                  orElse: () => lista.first,
                );
                final d = _diasHasta(c.proximaFecha);
                final msg = d == 1
                    ? '⏳ ${c.nombreCompleto} vence mañana.'
                    : '⏳ ${c.nombreCompleto} vence en $d días.';
                _showBanner(
                  msg,
                  color: const Color(0xFFFACC15), // 🟡 amarillo
                  icon: Icons.access_time,
                );
              } else if (cPronto > 1) {
                // ✅ Distinguir "mañana" vs "2 días" cuando hay varios
                int d1 = 0, d2 = 0;
                for (final cli in lista) {
                  if (cli.saldoActual <= 0) continue;
                  if (_estadoDe(cli) == _EstadoVenc.pronto) {
                    final dd = _diasHasta(cli.proximaFecha);
                    if (dd == 1) d1++;
                    else if (dd == 2) d2++;
                  }
                }

                if (d1 > 0 && d2 == 0) {
                  _showBanner(
                    '⏳ $cPronto clientes vencen mañana.',
                    color: const Color(0xFFFACC15),
                    icon: Icons.access_time,
                  );
                } else if (d2 > 0 && d1 == 0) {
                  _showBanner(
                    '⏳ $cPronto clientes vencen en 2 días.',
                    color: const Color(0xFFFACC15),
                    icon: Icons.access_time,
                  );
                } else {
                  _showBanner(
                    '⏳ $cPronto clientes vencen entre mañana y 2 días.',
                    color: const Color(0xFFFACC15),
                    icon: Icons.access_time,
                  );
                }
              } else {
                // ✅ Ajuste: NO mostrar "Aún no has agregado clientes" si viene de registro nuevo
                if (!hayClientes && !_esRecienRegistrado) {
                  _showBanner('Aún no has agregado clientes.',
                      color: const Color(0xFFEFFBF3), icon: Icons.info_outline);
                } else if (hayClientes && !hayActivos) {
                  _showBanner('No tienes clientes activos.',
                      color: const Color(0xFFEFFBF3), icon: Icons.info_outline);
                } else if (hayClientes && hayActivos) {
                  _showBanner('✅ No hay vencimientos en 1–2 días.',
                      color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
                }
              }
            }
          });
        }

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No hay clientes',
                style: TextStyle(fontSize: 16, color: Colors.white)),
          );
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(), // ⬅️ feel premium
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final c = filtered[i];
            final estado = _estadoDe(c);
            final codigoCorto = 'CL-${(i + 1).toString().padLeft(4, '0')}'; // CL-0001, CL-0002...

            return GestureDetector(
              onTap: () => _abrirDetalleYGuardar(c, codigoCorto),
              onLongPress: () => _mostrarOpcionesCliente(c),
              child: _ClienteCard(
                cliente: c,
                resaltar: _resaltarVencimientos,
                estado: estado,
                diasHasta: _diasHasta(c.proximaFecha),
                codigoCorto: codigoCorto,
              ),
            );
          },
        );
      },
    );
  }

  // Abrir detalle y pasar datos del prestamista al recibo
  void _abrirDetalleYGuardar(_Cliente c, String codigoCorto) async {
    final estadoAntes = _estadoDe(c);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClienteDetalleScreen(
          // -------- cliente ----------
          id: c.id,
          codigo: codigoCorto,
          nombreCompleto: c.nombreCompleto,
          telefono: c.telefono,
          direccion: c.direccion,
          saldoActual: c.saldoActual,
          tasaInteres: c.tasaInteres,
          periodo: c.periodo,
          proximaFecha: c.proximaFecha,

          // -------- prestamista ------
          empresa: _empresa,
          servidor: _servidor,
          telefonoServidor: _telefonoServidor,

          // -------- producto ----------
          producto: c.producto ?? '',
        ),
      ),
    );

    if (result != null && result is Map && result['accion'] == 'pago') {
      // Usa los datos devueltos para evaluar el estado después
      final int saldoNuevo = result['saldoNuevo'] as int? ?? c.saldoActual;
      final DateTime proximaNueva = result['proximaFecha'] as DateTime? ?? c.proximaFecha;
      final int d = _diasHasta(proximaNueva);
      final _EstadoVenc estadoDespues = (d < 0)
          ? _EstadoVenc.vencido
          : (d == 0)
          ? _EstadoVenc.hoy
          : (d <= 2)
          ? _EstadoVenc.pronto
          : _EstadoVenc.alDia;

      if (estadoDespues == _EstadoVenc.alDia && estadoAntes != _EstadoVenc.alDia) {
        _showBanner('Pago registrado ✅ · Ahora al día', color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
      } else {
        _showBanner('Pago guardado correctamente ✅', color: const Color(0xFFEFFBF3), icon: Icons.check_circle);
      }
    }
  }

  String _codigoDesdeId(String docId) {
    final base = docId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cut = base.length >= 6 ? base.substring(0, 6) : base.padRight(6, '0');
    return 'CL-${cut.toUpperCase()}';
  }
}

enum FiltroClientes { todos, pendientes, saldados }
enum _EstadoVenc { vencido, hoy, pronto, alDia }

// ================= Tarjeta de cliente =================

class _ClienteCard extends StatelessWidget {
  final _Cliente cliente;
  final bool resaltar;
  final _EstadoVenc estado;
  final int diasHasta;
  final String? codigoCorto;

  const _ClienteCard({
    required this.cliente,
    this.resaltar = false,
    this.estado = _EstadoVenc.alDia,
    this.diasHasta = 0,
    this.codigoCorto,
    super.key,
  });

  String _moneda(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.'); // ← usa punto para miles, como en RD
        count = 0;
      }
    }
    // Reemplaza el punto decimal por coma solo si hubiera alguno
    final texto = buf.toString().split('').reversed.join().replaceAll('.', ',');
    return '\$$texto';
  }

  // 👇 NUEVO: helper de cápsulas premium
  Widget _chip(
      String text, {
        EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        Color bg = const Color(0xFFF4F6FA),
        Color border = const Color(0xFFE5E7EB),
        Color fg = const Color(0xFF0F172A),
        double fs = 13,
        FontWeight fw = FontWeight.w800,
        IconData? icon,
        Color? iconColor,
      }) {
    return Container(
      padding: pad,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? fg),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: fs,
              fontWeight: fw,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }



// 👇 NUEVO: cápsula para el CÓDIGO (CL-0001, etc.)
  Widget _codePill(String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Color(0xFF334155),
          letterSpacing: .6,
        ),
      ),
    );
  }

// 👇 NUEVO: cápsula para el ESTADO (AL DÍA / VENCIDO / HOY / PRONTO / SALDADO)
  Widget _statusPill(String estado) {
    // Colores por estado (coinciden con tu lógica visual)
    Color bg, fg, border;
    switch (estado) {
      case 'Vencido':
        bg = const Color(0xFFFFE6E6);
        fg = const Color(0xFFB91C1C);
        border = const Color(0xFFFFC9C9);
        break;
      case 'Vence hoy':
        bg = const Color(0xFFFFF1E6);
        fg = const Color(0xFFB45309);
        border = const Color(0xFFFBD2A8);
        break;
      case 'Vence mañana':
      default:
        if (estado.startsWith('Vence en')) {
          bg = const Color(0xFFFEF9C3);
          fg = const Color(0xFF92400E);
          border = const Color(0xFFFDE68A);
        } else if (estado == 'Saldado') {
          bg = const Color(0xFFE2E8F0);
          fg = const Color(0xFF475569);
          border = const Color(0xFFCBD5E1);
        } else { // Al día
          bg = const Color(0xFFE6FFF4);
          fg = const Color(0xFF047857);
          border = const Color(0xFFC6F6D5);
        }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: .3,
        ),
      ),
    );
  }


  // Colores según pedido (saldado: banda GRIS)
  Color _headerColor() {
    if (cliente.saldoActual <= 0) return const Color(0xFFCBD5E1); // gris
    if (!resaltar) return Colors.transparent;
    switch (estado) {
      case _EstadoVenc.vencido:
        return const Color(0xFFDC2626); // rojo más elegante
      case _EstadoVenc.hoy:
        return const Color(0xFFFB923C); // naranja cálido
      case _EstadoVenc.pronto:
        return const Color(0xFFFACC15); // amarillo
      case _EstadoVenc.alDia:
        return const Color(0xFF22C55E); // verde
    }
  }

  String _estadoTexto() {
    if (cliente.saldoActual <= 0) return 'Saldado';
    switch (estado) {
      case _EstadoVenc.vencido:
        return 'Vencido';
      case _EstadoVenc.hoy:
        return 'Vence hoy';
      case _EstadoVenc.pronto:
        return diasHasta == 1 ? 'Vence mañana' : 'Vence en $diasHasta días';
      case _EstadoVenc.alDia:
        return 'Al día';
    }
  }

  @override
  Widget build(BuildContext context) {
    final interesPeriodo = (cliente.saldoActual * (cliente.tasaInteres / 100)).round();
    final saldoConInteres = cliente.saldoActual + interesPeriodo;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Banda superior con código visible y estado (mejor jerarquía)
            Container(
              height: 36,
              color: _headerColor(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    codigoCorto ?? cliente.codigo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                      letterSpacing: .3,
                    ),
                  ),
                  const Spacer(),
                  if (resaltar || cliente.saldoActual <= 0)
                    Text(
                      _estadoTexto(),
                      style: const TextStyle(
                        fontSize: 16,                  // ⬆️ un poco más grande
                        fontWeight: FontWeight.w900,   // ⬆️ más fuerte
                        color: Colors.black87,
                        letterSpacing: .3,
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Fila 1: Nombre + Saldo (cápsula a la derecha)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          cliente.nombreCompleto,
                          style: const TextStyle(
                            fontSize: 20,                // ⬆️ +1pt más grande
                            fontWeight: FontWeight.w900, // más sólida
                            color: Color(0xFF0F172A),    // tono premium azul-gris oscuro
                            letterSpacing: 0.2,          // ligera separación elegante
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _chip(
                        _moneda(saldoConInteres),           // ← saldo + interés
                        pad: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        bg: const Color(0xFFF4FAF7),
                        border: const Color(0xFFDDE7E1),
                        fg: const Color(0xFF065F46),
                        fs: 16,
                        fw: FontWeight.w900,
                        icon: Icons.request_quote_rounded,
                        iconColor: const Color(0xFF065F46),
                      ),
                    ],
                  ),



                  const SizedBox(height: 10),

                  // ── Fila 2: Teléfono (izq) + Interés quincenal (der)
                  Row(
                    children: [
                      _chip(
                        cliente.telefono,
                        bg: Colors.white,
                        border: const Color(0xFFE5E7EB),
                        fg: const Color(0xFF334155),
                        fs: 13,
                        fw: FontWeight.w700,
                        icon: Icons.phone_rounded,
                        iconColor: const Color(0xFF334155),
                      ),
                      const Spacer(),
                      _chip(
                        _moneda(interesPeriodo),            // ← sólo interés del periodo
                        bg: const Color(0xFFF1F5FF),
                        border: const Color(0xFFDCE7FF),
                        fg: const Color(0xFF1D4ED8),
                        fs: 13,
                        fw: FontWeight.w800,
                        icon: Icons.trending_up_rounded,
                        iconColor: const Color(0xFF1D4ED8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cliente {
  final String id; // docId (interno)
  final String codigo; // código visible (CL-XXXXXX)
  final String nombre;
  final String apellido;
  final String telefono;
  final String? direccion;
  final String? producto;

  final int capitalInicial;
  final int saldoActual;
  final double tasaInteres;
  final String periodo;
  final DateTime proximaFecha;

  _Cliente({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    this.direccion,
    this.producto,
    required this.capitalInicial,
    required this.saldoActual,
    required this.tasaInteres,
    required this.periodo,
    required this.proximaFecha,
  });

  String get nombreCompleto => '$nombre $apellido';
}
