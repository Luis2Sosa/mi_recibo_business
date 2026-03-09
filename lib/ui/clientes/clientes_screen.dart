// lib/clientes/clientes_screen.dart

import '../../core/ads/ads_manager.dart';
import '../recibo_screen.dart';
import 'agregar_cliente_alquiler_screen.dart';
import 'agregar_cliente_prestamo.dart';
import 'agregar_cliente_producto_screen.dart';
import 'auto_filtro_service.dart';
import 'agregar_cliente_producto_screen.dart';
import '../adaptive_icons.dart';



import 'dart:async';
import 'package:flutter/material.dart';
import '../cliente_detalle_screen.dart';
import '../perfil_prestamista/perfil_prestamista_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../agregar_cliente_screen.dart';
import 'package:flutter/services.dart';
import 'dart:io' show exit, Platform;

// 🔥 Firestore + Auth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// 🔔 FCM
import 'package:firebase_messaging/firebase_messaging.dart';

// ==== módulos divididos / tipos compartidos ====
import 'clientes_shared.dart';
import 'prestamos_screen.dart';
import 'productos_screen.dart';
import 'alquiler_screen.dart';

// =====================
// 🔐 BLINDAJE FIRESTORE
// =====================

// Lee un int de forma segura
int fsInt(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) {
    final cleaned = v.replaceAll(RegExp(r'[^0-9\-]'), '');
    return int.tryParse(cleaned) ?? fallback;
  }
  return fallback;
}

// Lee un double de forma segura
double fsDouble(dynamic v, {double fallback = 0.0}) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) {
    final cleaned = v.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    return double.tryParse(cleaned) ?? fallback;
  }
  return fallback;
}

// Lee un String de forma segura
String fsString(dynamic v, {String fallback = ''}) {
  if (v is String) return v.trim();
  return fallback;
}

// Lee un Map de forma segura
Map<String, dynamic> fsMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return {};
}

// Lee fecha segura
DateTime fsDate(dynamic v, {required DateTime fallback}) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d;
  }
  return fallback;
}

// ===============================
// 🔐 BLINDAJE DE NAVEGACIÓN
// ===============================

// push seguro (evita pantallas rojas si la pantalla ya se cerró)
Future<T?> pushSafe<T>(BuildContext context, Widget page) async {
  if (!context.mounted) return null;
  try {
    return await Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  } catch (_) {
    return null;
  }
}

// pop seguro
void popSafe(BuildContext context, [dynamic result]) {
  if (!context.mounted) return;
  if (Navigator.canPop(context)) {
    try {
      Navigator.pop(context, result);
    } catch (_) {}
  }
}

// setState seguro
extension SafeState on State {
  void setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    try {
      setState(fn);
    } catch (_) {}
  }
}



class ClientesScreen extends StatefulWidget {
  final String? initFiltro; // 👈 nuevo parámetro opcional

  const ClientesScreen({super.key, this.initFiltro});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}


class _ClientesScreenState extends State<ClientesScreen> with WidgetsBindingObserver {
  // 👇 Bandera temporal para saber si venimos de enviar un recibo
  static bool _vieneDeRecibo = false;
  static bool _vieneDeRecordatorio = false; // 👈 FALTA ESTA



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
  FiltroClientes _filtro = FiltroClientes.prestamos; // por defecto: Préstamos
  bool _initFiltroAplicado = false; // 👈 NUEVO: para no re-aplicar

  // ===== Intent de notificación (si llega desde push) =====
  String? _intent; // 'vencidos' | 'hoy' | 'pronto'
  bool _intentBannerMostrado = false;

  // 🔒 Lee si debe mostrarse el aviso de PIN/huella/facial
  bool _lockEnabled = false;

  // 👇 detecta si venimos de un registro recién completado
  bool _esRecienRegistrado = false;

  @override
  void initState() {
    super.initState();

    // 👇 Observa el ciclo de vida (detecta cuando la app vuelve del fondo)
    WidgetsBinding.instance.addObserver(this);

    if (widget.initFiltro != null) {
      switch (widget.initFiltro) {
        case 'prestamos':
          _filtro = FiltroClientes.prestamos;
          break;
        case 'productos':
          _filtro = FiltroClientes.productos;
          break;
        case 'alquiler':
          _filtro = FiltroClientes.alquiler;
          break;
      }
    }


    _cargarPerfilPrestamista();
    _cargarSeguridad();              // carga inicial
    _escucharSeguridadTiempoReal();  // escucha en tiempo real
    // ⬇️ guardar token FCM y escuchar mensajes en foreground
    _guardarTokenFCM();
    _fcmSub = FirebaseMessaging.onMessage.listen((m) {
      // ignore: avoid_print
      print('📩 Push (foreground): ${m.notification?.title} - ${m.notification?.body}');
    });



    // ❌ (Quitado) NO forzamos cambio de pestaña aquí para evitar flicker
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   final nuevo = await AutoFiltroService.elegirFiltroPreferido(
    //     preferenciaActual: _filtro,
    //   );
    //   if (mounted && nuevo != _filtro) {
    //     setState(() => _filtro = nuevo);
    //   }
    // });
  }

  // 👇 NUEVO: Detectar cuando la app vuelve al primer plano
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Solo actuamos cuando vuelve al foreground
    if (state == AppLifecycleState.resumed) {
      // Si venimos de enviar recibo o recordatorio → mostrar anuncio especial
      if (_vieneDeRecibo) {
        _vieneDeRecibo = false; // reset para que no se dispare de nuevo
        AdsManager.showAfterWhatsApp(context, 'recibo');
        return;
      }

      if (_vieneDeRecordatorio) {
        _vieneDeRecordatorio = false;
        AdsManager.showAfterWhatsApp(context, 'recordatorio');
        return;
      }
    }
  }



  // 🕛 Normaliza al mediodía para evitar líos de zona horaria
  DateTime _atNoon(DateTime d) => DateTime(d.year, d.month, d.day, 12);

  // 👇 Lee prestamistas/<uid actual> (datos del prestamista para el recibo)
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

  // 🔔 guarda el token FCM en prestamistas/{uid}/meta.fcmToken
  Future<void> _guardarTokenFCM() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.trim().isEmpty) return;
      await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(user.uid)
          .set({'meta': {'fcmToken': token}}, SetOptions(merge: true));
      // ignore: avoid_print
      print('✅ FCM token guardado: $token');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error guardando FCM token: $e');
    }
  }

  void _showBanner(
      String texto, {
        Color? bg,         // si lo envías, se usa tal cual
        Color? color,      // compatibilidad
      }) {
    // ===== Paleta fija (mismos colores de vencimientos) =====
    const Color kVencido = Color(0xFFDC2626); // rojo
    const Color kHoy     = Color(0xFFF97316); // naranja
    const Color kPronto  = Color(0xFFF59E0B); // mostaza
    const Color kOK      = Color(0xFF16A34A); // verde éxito

    // --- 1) Separar título/detalle si viene con "·" y limpiar emojis ---
    String _clean(String s) =>
        s.replaceAll(RegExp(r'[\u{2190}-\u{2BFF}\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
            unicode: true), '').trim();

    String titulo = '';
    String detalle = _clean(texto);
    if (texto.contains('·')) {
      final p = texto.split('·');
      if (p.length >= 2) {
        titulo = _clean(p.first);
        detalle = _clean(p.sublist(1).join('·'));
      }
    }

    // --- 2) Elegir color base automáticamente si no lo pasan ---
    Color base = bg ?? color ?? (() {
      final t = (titulo + ' ' + detalle).toLowerCase();
      if (t.contains('error') || t.contains('vencid')) return kVencido;
      if (t.contains('vence hoy')) return kHoy;
      if (t.contains('mañana') || t.contains('2 días') || t.contains('pronto')) return kPronto;

// 🔵 Usa azul corporativo para todos los mensajes positivos
      if (t.contains('bienvenido') ||
          t.contains('agregado') ||
          t.contains('actualizado') ||
          t.contains('renovación') ||
          t.contains('al día') ||
          t.contains('no hay') ||
          t.contains('guardado') ||
          t.contains('pago')) return const Color(0xFF417CDE);

      return const Color(0xFF417CDE);
    })();

    // Gradiente suave desde la base
    Color _shade(Color c, double k) {
      final h = HSLColor.fromColor(c);
      return h.withLightness((h.lightness * k).clamp(0.0, 1.0)).toColor();
    }
    final c1 = _shade(base, 0.70), c2 = _shade(base, 0.52);

    final bottomSafe = MediaQuery.of(context).padding.bottom;

    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: EdgeInsets.fromLTRB(12, 6, 12, 6 + (bottomSafe * .4)),
      duration: const Duration(seconds: 3),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(.28), width: 1.3),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 20), // 👈 sube la campanita
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),

            // Centro perfecto
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (titulo.isNotEmpty)
                  Text(
                    titulo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: .2,
                      height: 1.1,
                    ),
                  ),
                if (titulo.isNotEmpty) const SizedBox(height: 4),
                Text(
                  detalle,
                  textAlign: TextAlign.center,
                  softWrap: true,
                  maxLines: 3,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

  // ===== Modal para confirmar salir =====
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
      if (Platform.isAndroid) {
        exit(0);
      } else {
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

  EstadoVenc _estadoDe(Cliente c) {
    // 🟢 PRIMERO: detectar saldados correctos
    if (c.saldoActual <= 0) {
      return EstadoVenc.alDia; // 👈 ESTE valor NO es el texto. El texto “SALDADO” sale en el Card.
    }

    final d = _diasHasta(c.proximaFecha);

    if (d < 0) return EstadoVenc.vencido;
    if (d == 0) return EstadoVenc.hoy;
    if (d <= 2) return EstadoVenc.pronto;
    return EstadoVenc.alDia;
  }

  bool _esSaldado(Cliente c) => c.saldoActual <= 0;

  bool _esArriendo(Cliente c) {
    final p = (c.producto ?? '').toLowerCase().trim();
    if (p.isEmpty) return false;
    return p.contains('arri')      // arriendo, arrendar
        || p.contains('alqui')     // alquiler, alquilar
        || p.contains('renta')     // renta
        || p.contains('rent')      // rent
        || p.contains('lease')     // lease
        || p.contains('casa')
        || p.contains('apart')
        || p.contains('estudio')
        || p.contains('apartaestudio')
        || p.contains('aparta estudio');
  }

  String _fmtFecha(DateTime d) {
    const meses = ['ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.', 'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.'];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  String _codigoDesdeId(String docId) {
    final base = docId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cut = base.length >= 6 ? base.substring(0, 6) : base.padRight(6, '0');
    return 'CL-${cut.toUpperCase()}';
  }

  void _abrirEditarCliente(Cliente c) async {
    Widget? destino;

    // 1. Determinamos a qué pantalla ir (Limpiando parámetros no definidos)
    switch (_filtro) {
      case FiltroClientes.prestamos:
        destino = AgregarClientePrestamoScreen(
          id: c.id,
          initNombre: c.nombre,
          initApellido: c.apellido,
          initTelefono: c.telefono,
          initDireccion: c.direccion,
          initNota: c.nota,
          initProducto: c.producto,
          initCapital: c.capitalInicial,
          initTasa: c.tasaInteres?.toDouble(),
          initPeriodo: c.periodo,
          initProximaFecha: c.proximaFecha,
        );
        break;

      case FiltroClientes.productos:
        destino = AgregarClienteProductoScreen(
          id: c.id,
          initNombre: c.nombre,
          initApellido: c.apellido,
          initTelefono: c.telefono,
          initDireccion: c.direccion,
          initNota: c.nota,
          initProducto: c.producto,
          initProximaFecha: c.proximaFecha,
          // ✅ Se eliminaron capital, tasa y periodo porque Productos no los usa
        );
        break;

      case FiltroClientes.alquiler:
        destino = AgregarClienteAlquilerScreen(
          id: c.id,
          initNombre: c.nombre,
          initApellido: c.apellido,
          initTelefono: c.telefono,
          initDireccion: c.direccion,
          initNota: c.nota,
          initProducto: c.producto,
          initProximaFecha: c.proximaFecha,
          // ✅ Se eliminaron capital, tasa y periodo para coincidir con el constructor
        );
        break;

      default:
        return;
    }

    if (destino == null) return;

    // 2. Navegamos
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destino!),
    );

    // 3. Procesamos el retorno (Opcional si la pantalla ya guarda por sí sola)
    if (result == null || result is! Map) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final String nombre = (result['nombre'] ?? c.nombre).toString().trim();
      final String apellido = (result['apellido'] ?? c.apellido).toString().trim();

      final Map<String, dynamic> update = {
        'nombre': nombre,
        'apellido': apellido,
        'nombreCompleto': '$nombre $apellido',
        'telefono': (result['telefono'] ?? c.telefono).toString().trim(),
        'direccion': result['direccion'],
        'producto': result['producto'],
        'nota': result['nota'],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Solo actualizamos estos campos si vienen en el resultado (útil para Préstamos)
      if (result.containsKey('capital')) update['capitalInicial'] = result['capital'];
      if (result.containsKey('tasa')) update['tasaInteres'] = (result['tasa'] as num).toDouble();
      if (result.containsKey('periodo')) update['periodo'] = result['periodo'];

      if (result['proximaFecha'] != null) {
        final DateTime prox = result['proximaFecha'] is DateTime
            ? result['proximaFecha']
            : DateTime.now();
        update['proximaFecha'] = Timestamp.fromDate(_atNoon(prox));
      }

      await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .doc(c.id)
          .set(update, SetOptions(merge: true));

      _showBanner('Cliente actualizado ✅', color: const Color(0xFF417CDE));

    } catch (e) {
      _showBanner('Error al actualizar: $e', color: Colors.red);
    }
  }


  void _confirmarEliminar(Cliente c) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2458D6), Color(0xFF0A9A76)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Eliminar cliente?',
                  style: GoogleFonts.playfairDisplay(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¿Seguro que deseas eliminar a "${c.nombreCompleto}"?\nEsta acción no se puede deshacer.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.9),
                          foregroundColor: const Color(0xFF2458D6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
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
                              _showBanner('Cliente eliminado correctamente',
                                  color: const Color(0xFFFFF1F2));
                            }
                          } catch (e) {
                            Navigator.pop(scaffoldCtx);
                            if (mounted) {
                              _showBanner('Error al eliminar: $e',
                                  color: const Color(0xFFFFF1F2));
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_forever_rounded,
                            color: Colors.white),
                        label: const Text('Eliminar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 6,
                          shadowColor: Colors.redAccent.withOpacity(0.4),
                        ),
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
  }


  void _mostrarOpcionesCliente(Cliente c) {
    bool _cerrado = false; // para no cerrar si ya se cerró manualmente
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      isScrollControlled: false,
      isDismissible: true,
      enableDrag: false,
      builder: (sheetCtx) {
        // ⏱️ Autocierre tras N segundos si no hay interacción
        const int autoCloseSeconds = 6;
        Future.delayed(const Duration(seconds: autoCloseSeconds), () {
          if (!_cerrado && Navigator.of(sheetCtx).canPop()) {
            Navigator.of(sheetCtx).pop();
          }
        });

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
          top: false, bottom: true,
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
      _cerrado = true;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 👇 NUEVO: aplicar initFiltro una sola vez (llega desde main.dart)
    if (!_initFiltroAplicado) {
      final args0 = ModalRoute.of(context)?.settings.arguments;
      if (args0 is Map && args0['initFiltro'] is String) {
        final s = (args0['initFiltro'] as String).trim().toLowerCase();
        FiltroClientes? f;
        if (s == 'prestamos') f = FiltroClientes.prestamos;
        else if (s == 'productos') f = FiltroClientes.productos;
        else if (s == 'alquiler') f = FiltroClientes.alquiler;
        if (f != null && f != _filtro) {
          _filtro = f; // sin setState para evitar parpadeo en primer build
        }
      }
      _initFiltroAplicado = true;
    }

    // Lee args para bienvenida existente
    if (!_bienvenidaMostrada) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final nombre = (args['bienvenidaNombre'] as String?)?.trim();
        final empresa = (args['bienvenidaEmpresa'] as String?)?.trim();
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
            _showBanner(texto, color: const Color(0xFFEFFBF3));
          });
        }
      }
    }
    // Intención de notificación (se guarda)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _intent == null) {
      final intent = (args['intent'] as String?)?.trim();
      if (intent == 'vencidos' || intent == 'hoy' || intent == 'pronto') {
        _intent = intent;
        _intentBannerMostrado = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 👈 importante
    _debounce?.cancel();
    _searchCtrl.dispose();
    _fcmSub?.cancel();
    _seguridadSub?.cancel();
    super.dispose();
  }

  // === Contenido según filtro seleccionado ===
  Widget _contenidoPorFiltro() {
    switch (_filtro) {
      case FiltroClientes.prestamos:
        return PrestamosScreen(
          search: _searchCtrl.text,
          resaltarVencimientos: _resaltarVencimientos,
          onTapCliente: _abrirDetalleYGuardar,
          onLongPressCliente: _mostrarOpcionesCliente,
        );
      case FiltroClientes.productos:
        return ProductosScreen(
          search: _searchCtrl.text,
          resaltarVencimientos: _resaltarVencimientos,
          onTapCliente: _abrirDetalleYGuardar,
          onLongPressCliente: _mostrarOpcionesCliente,
        );
      case FiltroClientes.alquiler:
        return AlquilerScreen(
          search: _searchCtrl.text,
          resaltarVencimientos: _resaltarVencimientos,
          onTapCliente: _abrirDetalleYGuardar,
          onLongPressCliente: _mostrarOpcionesCliente,
        );
    }
  }

  void _abrirDetalleYGuardar(Cliente c, String codigoCorto) async {
    // Siempre lee datos frescos antes de abrir detalles/pago
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .doc(c.id)
          .get();

      // Si por alguna razón no existe, uso lo que traía la tarjeta
      final data = (doc.data() ?? {}) as Map<String, dynamic>;

      // Campos “vivos” que pueden haber cambiado (renovación, etc.)
      final int saldoActual   = (data['saldoActual'] ?? c.saldoActual) as int;
      final String periodo    = (data['periodo'] ?? c.periodo) as String;
      final double tasa       = (data['tasaInteres'] ?? c.tasaInteres).toDouble();
      final String producto   = (data['producto'] ?? c.producto ?? '') as String;

      final DateTime proximaFecha = (() {
        final v = data['proximaFecha'];
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        return c.proximaFecha; // fallback
      })();

      final estadoAntes = _estadoDe(c);

      final result = await pushSafe(
        context,
        ClienteDetalleScreen(
            // -------- cliente ----------
            id: c.id,
            codigo: codigoCorto,
            nombreCompleto: c.nombreCompleto,
            telefono: c.telefono,
            direccion: c.direccion,
            saldoActual: saldoActual,        // ← ya viene fresco
            tasaInteres: tasa,               // ← ya viene fresco
            periodo: periodo,                // ← ya viene fresco
            proximaFecha: proximaFecha,      // ← ya viene fresca
            // -------- prestamista ------
            empresa: _empresa,
            servidor: _servidor,
            telefonoServidor: _telefonoServidor,
            // -------- producto ----------
            producto: producto,
            moraAcumulada: c.moraAcumulada, // 👈 NUEVO

          ),
    );

      // 🔥 Releer Firestore después de un pago para refrescar saldos/montos
      if (uid != null) {
        final snapCheck = await FirebaseFirestore.instance
            .collection('prestamistas')
            .doc(uid)
            .collection('clientes')
            .doc(c.id)
            .get();

        final fresh = snapCheck.data();
        if (fresh != null) {
          c = Cliente(
            id: c.id,
            codigo: c.codigo,
            nombre: c.nombre,
            apellido: c.apellido,
            telefono: c.telefono,
            direccion: c.direccion,
            nota: c.nota,
            producto: c.producto,
            capitalInicial: c.capitalInicial,
            saldoActual: fresh['saldoActual'] ?? c.saldoActual,
            tasaInteres: (fresh['tasaInteres'] ?? c.tasaInteres).toDouble(),
            periodo: fresh['periodo'] ?? c.periodo,
            proximaFecha: fresh['proximaFecha'] is Timestamp
                ? (fresh['proximaFecha'] as Timestamp).toDate()
                : c.proximaFecha,
            mora: fresh['mora'] is Map ? Map<String, dynamic>.from(fresh['mora']) : c.mora,
          );
        }
      }


      // Mensaje si volvemos desde un pago
      if (result != null && result is Map && result['accion'] == 'pago') {
        final DateTime proximaNueva = result['proximaFecha'] as DateTime? ?? proximaFecha;
        final int d = _diasHasta(proximaNueva);
        final EstadoVenc estadoDespues = (d < 0)
            ? EstadoVenc.vencido
            : (d == 0)
            ? EstadoVenc.hoy
            : (d <= 2)
            ? EstadoVenc.pronto
            : EstadoVenc.alDia;

        if (estadoDespues == EstadoVenc.alDia && estadoAntes != EstadoVenc.alDia) {
          _showBanner('Pago registrado ✅ · Ahora al día', color: const Color(0xFFEFFBF3));
        } else {
          _showBanner('Pago guardado correctamente ✅', color: const Color(0xFFEFFBF3));
        }
      }
    } catch (_) {
      // Fallback: si falla la lectura, abrimos con los datos que venían en la tarjeta
      final estadoAntes = _estadoDe(c);

      final docRef = FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .doc(c.id);


      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClienteDetalleScreen(
            id: c.id,
            codigo: codigoCorto,
            nombreCompleto: c.nombreCompleto,
            telefono: c.telefono,
            direccion: c.direccion,
            saldoActual: c.saldoActual,
            tasaInteres: c.tasaInteres,
            periodo: c.periodo,
            proximaFecha: c.proximaFecha,
            empresa: _empresa,
            servidor: _servidor,
            telefonoServidor: _telefonoServidor,
            producto: c.producto ?? '',
            moraAcumulada: c.moraAcumulada, // 👈 NUEVO

          ),
        ),
      );
      if (result != null && result is Map && result['accion'] == 'pago') {
        final DateTime proximaNueva = result['proximaFecha'] as DateTime? ?? c.proximaFecha;
        final int d = _diasHasta(proximaNueva);
        final EstadoVenc estadoDespues = (d < 0)
            ? EstadoVenc.vencido
            : (d == 0)
            ? EstadoVenc.hoy
            : (d <= 2)
            ? EstadoVenc.pronto
            : EstadoVenc.alDia;
        if (estadoDespues == EstadoVenc.alDia && estadoAntes != EstadoVenc.alDia) {
          _showBanner('Pago registrado ✅ · Ahora al día', color: const Color(0xFFEFFBF3));
        } else {
          _showBanner('Pago guardado correctamente ✅', color: const Color(0xFFEFFBF3));
        }
      }
    }
  }


  // ====== WATCHER de banners (cuenta vencidos/hoy/pronto en TODA la colección) ======
  Widget _bannerListener(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .orderBy('proximaFecha')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final docs = snap.data!.docs;

        // Mapear a Cliente para reutilizar _estadoDe
        final lista = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          final codigoGuardado = (data['codigo'] as String?)?.trim();
          final codigoVisible = (codigoGuardado != null && codigoGuardado.isNotEmpty)
              ? codigoGuardado
              : _codigoDesdeId(d.id);

          return Cliente(
            id: d.id,
            codigo: codigoVisible,
            nombre: fsString(data['nombre']),
            apellido: fsString(data['apellido']),
            telefono: fsString(data['telefono']),
            direccion: (data['direccion'] as String?)?.trim(),
            producto: (data['producto']  as String?)?.trim(),


            // 🔐 BLINDAJE NUMÉRICO
            capitalInicial: fsInt(data['capitalInicial']),
            saldoActual: fsInt(data['saldoActual']),


            tasaInteres: fsDouble(data['tasaInteres']),

            periodo: fsString(data['periodo'], fallback: 'Mensual'),

            // 🔐 BLINDAJE FECHA
            proximaFecha: fsDate(
              data['proximaFecha'],
              fallback: DateTime.now(),
            ),

            // 🔐 BLINDAJE MAPA
            mora: fsMap(data['mora']),
          );
        }).toList();


        int cVencidos = 0, cHoy = 0, cPronto = 0;
        for (final c in lista) {
          if (c.saldoActual <= 0) continue; // ignorar saldados
          final e = _estadoDe(c);
          if (e == EstadoVenc.vencido) cVencidos++;
          else if (e == EstadoVenc.hoy) cHoy++;
          else if (e == EstadoVenc.pronto) cPronto++;
        }

        final bool hayClientes = lista.isNotEmpty;
        final bool hayActivos = lista.any((c) => c.saldoActual > 0);

        // Autointent si no vino por args
        if (_intent == null) {
          if (cVencidos > 0) {
            _intent = 'vencidos';
          } else if (cHoy > 0) {
            _intent = 'hoy';
          } else if (cPronto > 0) {
            _intent = 'pronto';
          } else {
            _intent = 'hoy'; // para el OK cuando no hay nada
          }
          _intentBannerMostrado = false;
        }

        // Helper para tipo de cliente
        String tipoDe(Cliente c) {
          final p = (c.producto ?? '').toLowerCase();
          if (p.contains('alqui') || p.contains('arri') || p.contains('renta') ||
              p.contains('rent') || p.contains('lease') ||
              p.contains('casa') || p.contains('apart') ||
              p.contains('estudio') || p.contains('apartaestudio') || p.contains('aparta estudio')) {
            return 'Alquiler';
          }
          if (p.isNotEmpty) return 'Producto';
          return 'Préstamo';
        }

        if (_intent != null && !_intentBannerMostrado && mounted) {
          _intentBannerMostrado = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_intent == 'vencidos') {
              if (cVencidos == 1) {
                final c = lista.firstWhere(
                      (x) => _estadoDe(x) == EstadoVenc.vencido && x.saldoActual > 0,
                  orElse: () => lista.first,
                );
                _showBanner('⚠️ ${tipoDe(c)} · ${c.nombreCompleto} tiene un pago vencido.',
                    color: const Color(0xFFDC2626));
              } else if (cVencidos > 1) {
                _showBanner('⚠️ $cVencidos clientes tienen pagos vencidos.',
                    color: const Color(0xFFDC2626));
              } else {
                if (!hayClientes && !_esRecienRegistrado) {
                  _showBanner('Aún no has agregado clientes.', color: const Color(0xFFEFFBF3));
                } else if (hayClientes && !hayActivos) {
                  _showBanner('No tienes clientes activos.', color: const Color(0xFFEFFBF3));
                } else if (hayClientes && hayActivos) {
                  _showBanner('✅ No hay pagos vencidos ahora mismo.', color: const Color(0xFFEFFBF3));
                }
              }
            } else if (_intent == 'hoy') {
              if (cHoy == 1) {
                final c = lista.firstWhere(
                      (x) => _estadoDe(x) == EstadoVenc.hoy && x.saldoActual > 0,
                  orElse: () => lista.first,
                );
                _showBanner('📆 ${tipoDe(c)} · ${c.nombreCompleto} vence hoy. No olvides cobrar.',
                    color: const Color(0xFFFB923C));
              } else if (cHoy > 1) {
                _showBanner('📆 $cHoy clientes vencen hoy.', color: const Color(0xFFFB923C));
              } else {
                if (!hayClientes && !_esRecienRegistrado) {
                  _showBanner('Aún no has agregado clientes.', color: const Color(0xFF417CDE));
                } else if (hayClientes && !hayActivos) {
                  _showBanner('No tienes clientes activos.', color: const Color(0xFF417CDE));
                } else if (hayClientes && hayActivos) {
                  _showBanner('✅ Nadie vence hoy.', color: const Color(0xFF417CDE));
                }
              }
            } else if (_intent == 'pronto') {
              if (cPronto == 1) {
                final c = lista.firstWhere(
                      (x) => _estadoDe(x) == EstadoVenc.pronto && x.saldoActual > 0,
                  orElse: () => lista.first,
                );
                final d = _diasHasta(c.proximaFecha);
                final msg = d == 1
                    ? '⏳ ${tipoDe(c)} · ${c.nombreCompleto} vence mañana.'
                    : '⏳ ${tipoDe(c)} · ${c.nombreCompleto} vence en $d días.';
                _showBanner(msg, color: const Color(0xFFFACC15));
              } else if (cPronto > 1) {
                int d1 = 0, d2 = 0;
                for (final cli in lista) {
                  if (cli.saldoActual <= 0) continue;
                  final e = _estadoDe(cli);
                  if (e == EstadoVenc.pronto) {
                    final dd = _diasHasta(cli.proximaFecha);
                    if (dd == 1) d1++; else if (dd == 2) d2++;
                  }
                }
                if (d1 > 0 && d2 == 0) {
                  _showBanner('⏳ $cPronto clientes vencen mañana.', color: const Color(0xFFFACC15));
                } else if (d2 > 0 && d1 == 0) {
                  _showBanner('⏳ $cPronto clientes vencen en 2 días.', color: const Color(0xFFFACC15));
                } else {
                  _showBanner('⏳ $cPronto clientes vencen entre mañana y 2 días.',
                      color: const Color(0xFFFACC15));
                }
              } else {
                if (!hayClientes && !_esRecienRegistrado) {
                  _showBanner('Aún no has agregado clientes.', color: const Color(0xFFEFFBF3));
                } else if (hayClientes && !hayActivos) {
                  _showBanner('No tienes clientes activos.', color: const Color(0xFFEFFBF3));
                } else if (hayClientes && hayActivos) {
                  _showBanner('✅ No hay vencimientos en 1–2 días.', color: const Color(0xFFEFFBF3));
                }
              }
            }
          });
        }

        return const SizedBox.shrink(); // visualmente no muestra nada
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const double logoTop = -90;
    const double contentTop = 80; // ó 60 si quieres más espacio


    final uid = FirebaseAuth.instance.currentUser?.uid;

    return PopScope(
      canPop: false, // controlamos el back manualmente
      onPopInvoked: (didPop) {
        if (didPop) return;
        _confirmarSalirCliente(); // banner profesional bloqueante
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
                                    padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 4),
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
                                            height: 48,
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
                                                _debounce?.cancel();
                                                _debounce = Timer(const Duration(milliseconds: 250), () {
                                                  if (mounted) setState(() {});
                                                });
                                              },
                                              decoration: InputDecoration(
                                                hintText: 'Buscar',
                                                hintStyle: const TextStyle(color: Color(0xFF111827)),
                                                prefixIcon: Icon(Icons.search, color: Colors.black.withOpacity(0.7)),
                                                filled: true,
                                                fillColor: Colors.white.withOpacity(0.92),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                          width: 48,
                                          height: 48,
                                          child: Material(
                                            color: const Color(0xFF22C55E),
                                            borderRadius: BorderRadius.circular(14),
                                            elevation: 2,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(14),

                                              onTap: () async {
                                                final res = await Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => const AgregarClienteScreen(), // ✅ sin 'modulo'
                                                  ),
                                                );
                                                if (res is Map) {
                                                  _showBanner('Cliente agregado correctamente ✅');
                                                }
                                              },

                                              child: const Icon(Icons.add, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // === Chips de filtro ===
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: _filtroBoton(
                                            label: 'Préstamos',
                                            icon: Icons.request_quote_rounded,
                                            activo: _filtro == FiltroClientes.prestamos,
                                            onTap: () => setState(() => _filtro = FiltroClientes.prestamos),
                                            gradiente: const [Color(0xFF2563EB), Color(0xFF1E40AF)],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _filtroBoton(
                                            label: 'Productos',
                                            icon: Icons.shopping_bag_rounded,
                                            activo: _filtro == FiltroClientes.productos,
                                            onTap: () => setState(() => _filtro = FiltroClientes.productos),
                                            gradiente: const [Color(0xFF10B981), Color(0xFF047857)],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _filtroBoton(
                                            label: 'Alquiler',
                                            icon: Icons.house_rounded,
                                            activo: _filtro == FiltroClientes.alquiler,
                                            onTap: () => setState(() => _filtro = FiltroClientes.alquiler),
                                            gradiente: const [Color(0xFFF59E0B), Color(0xFFB45309)],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ===== Watcher de banners (no ocupa espacio visual) =====
                                  _bannerListener(uid),

                                  // ===== Contenido según filtro (listas divididas) =====
                                  Expanded(child: _contenidoPorFiltro()),
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
                            MaterialPageRoute(builder: (_) => const PerfilPrestamistaScreen()),
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
                  top: -100,
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
}

// === Widget reutilizable: botón de filtro premium (compacto) ===
Widget _filtroBoton({
  required String label,
  required IconData icon,
  required bool activo,
  required VoidCallback onTap,
  required List<Color> gradiente,
}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      height: 44,
      decoration: BoxDecoration(
        gradient: activo
            ? LinearGradient(colors: gradiente)
            : const LinearGradient(colors: [Colors.white, Color(0xFFF1F5F9)]),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          if (activo)
            BoxShadow(
              color: gradiente.last.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
        border: Border.all(
          color: activo ? Colors.transparent : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activo ? Colors.white : const Color(0xFF475569), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: activo ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}