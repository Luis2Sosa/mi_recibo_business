import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPlus {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static const _cooldowns = <String, Duration>{
    'pago_ok': Duration.zero,
    'deuda_finalizada': Duration.zero,
    'sync_ok': Duration(hours: 12),
    'backup_ok': Duration(hours: 12),
    'revision_semanal': Duration(days: 7),
    'inactividad_cobro': Duration(hours: 24),
    'resumen_mes': Duration(days: 30),
  };

  // =================== NUEVO: Colores por módulo y estado ===================
  static const _moduleTint = <String, Color>{
    'prestamos': Color(0xFF0EA5E9), // cielo
    'productos': Color(0xFF8B5CF6), // violeta
    'alquiler': Color(0xFF22C55E),  // verde
  };

  static const _dueTint = <String, Color>{
    'vencido': Color(0xFFDC2626),      // rojo
    'venceHoy': Color(0xFFFB923C),     // naranja
    'venceManana': Color(0xFFFACC15),  // amarillo
    'venceEn2Dias': Color(0xFF2563EB), // azul
  };

  static Future<void> trigger(String intent, {Map<String, dynamic>? payload}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'last_$intent';
    final lastIso = prefs.getString(key);
    final cd = _cooldowns[intent] ?? const Duration(hours: 12);

    if (cd > Duration.zero && lastIso != null) {
      final lastDt = DateTime.tryParse(lastIso);
      if (lastDt != null && now.difference(lastDt) < cd) return;
    }

    await prefs.setString(key, now.toIso8601String());
    _show(intent, payload ?? {});
  }

  static Future<void> onAppOpen(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final lastWeekIso = prefs.getString('last_revision_semanal');
    final lastWeek = DateTime.tryParse(lastWeekIso ?? '');
    if (lastWeek == null || now.difference(lastWeek).inDays >= 7) {
      await prefs.setString('last_revision_semanal', now.toIso8601String());
      trigger('revision_semanal');
    }

    final lastOpenIso = prefs.getString('last_app_open');
    final lastOpen = DateTime.tryParse(lastOpenIso ?? '');
    if (lastOpen != null && now.difference(lastOpen) >= const Duration(days: 3)) {
      trigger('inactividad_cobro');
    }
    await prefs.setString('last_app_open', now.toIso8601String());

    final lastMonthIso = prefs.getString('last_resumen_mes');
    final lastMonth = DateTime.tryParse(lastMonthIso ?? '');
    final monthChanged =
        lastMonth == null || lastMonth.month != now.month || lastMonth.year != now.year;
    if (monthChanged) {
      await prefs.setString('last_resumen_mes', now.toIso8601String());
      trigger('resumen_mes', payload: {
        'montoPrestado': 0,
        'montoCobrado': 0,
      });
    }
  }

  static void _show(String intent, Map payload) {
    switch (intent) {
      case 'pago_ok':
        _showBanner('📊 Pago confirmado', color: const Color(0xFF22C55E), intent: intent);
        break;
      case 'deuda_finalizada':
        _showBanner('📊 El cliente saldó su deuda',
            color: const Color(0xFF22C55E), intent: intent);
        break;
      case 'sync_ok':
        _showBanner('☁️ Datos sincronizados correctamente.',
            color: const Color(0xFF2563EB), intent: intent);
        break;
      case 'backup_ok':
        _showBanner('🔐 Copia de seguridad completada.',
            color: const Color(0xFF2563EB), intent: intent);
        break;
      case 'revision_semanal':
        _showBanner('📅 Revisa los pagos de esta semana.',
            color: const Color(0xFF2563EB), intent: intent);
        break;
      case 'inactividad_cobro':
        _showBanner('🔔 Han pasado varios días sin actividad. Revisa tus cobros pendientes.',
            color: const Color(0xFFFFB020), intent: intent);
        break;
      case 'resumen_mes':
        final prestado = payload['montoPrestado'] ?? 0;
        final cobrado = payload['montoCobrado'] ?? 0;
        _showBanner('📚 Resumen mensual: Prestaste RD\$$prestado y cobraste RD\$$cobrado.',
            color: const Color(0xFF2563EB), intent: intent);
        break;
      default:
        final msg = (payload['text'] as String?)?.trim();
        if (msg != null && msg.isNotEmpty) {
          _showBanner(msg, color: const Color(0xFF2563EB), intent: intent);
        }
    }
  }

  /// Muestra un banner modal “seguro” y lo cierra removiendo *esa* ruta,
  /// sin hacer `pop()` del stack general.
  static void _showBanner(String text, {required Color color, required String intent}) {
    void showNow() {
      final nav = navigatorKey.currentState;
      final ctx = nav?.overlay?.context ?? messengerKey.currentContext;
      if (nav == null || ctx == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showBanner(text, color: color, intent: intent);
        });
        return;
      }

      Widget _card() => Container(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: intent == 'deuda_finalizada'
            ? BoxDecoration(
          color: const Color(0xFF16A34A),
          borderRadius: BorderRadius.circular(26),
        )
            : BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 22,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: intent == 'deuda_finalizada'
                    ? Colors.white.withOpacity(0.18)
                    : color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 30,
                color: intent == 'deuda_finalizada' ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: intent == 'deuda_finalizada'
                    ? Colors.white
                    : const Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                height: 1.35,
                decoration: TextDecoration.none,
                decorationColor: Colors.transparent,
              ),
            ),
          ],
        ),
      );

      // 🚫 Nada de showGeneralDialog + nav.pop()
      // ✅ Empujamos una ruta propia y la removemos explícitamente.
      final route = PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.40),
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionsBuilder: (_, anim, __, ___) {
          final t = Curves.easeOutCubic.transform(anim.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: const SizedBox.shrink(),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: t,
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * t,
                    child: _card(),
                  ),
                ),
              ),
            ],
          );
        },
      );

      nav.push(route);

      // Cerrar SOLO esta ruta (no afecta otras pantallas)
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (route.isActive) {
          // removeRoute no toca las demás rutas del stack
          nav.removeRoute(route);
        }
      });
    }

    showNow();
  }

  static void showForeground(String text, {Color? color}) {
    final c = color ?? const Color(0xFF2563EB);
    _showBanner(text, color: c, intent: 'foreground');
  }


  // =================== FIRESTORE: LECTURA Y ROTACIÓN ===================

  static const _cfgCol = 'config';
  static const _cfgDoc = '(default)';
  static const _tplCol = 'push_templates';
  static const _dailyDoc = 'diarias';
  static const _dueCol = 'vencimiento';
  static const _dueDoc = 'mensajes';

  static Future<List<String>> _readDailyMessages() async {
    final snap = await FirebaseFirestore.instance
        .collection(_cfgCol)
        .doc(_cfgDoc)
        .collection(_tplCol)
        .doc(_dailyDoc)
        .get();

    final data = snap.data() ?? {};
    final List<dynamic> raw = (data['mensajes'] as List?) ?? const [];
    return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
  }

  static Future<Map<String, List<String>>> _readDueMessages() async {
    final snap = await FirebaseFirestore.instance
        .collection(_cfgCol)
        .doc(_cfgDoc)
        .collection(_dueCol)
        .doc(_dueDoc)
        .get();

    final data = snap.data() ?? {};
    final estados = (data['estados'] as Map?) ?? {};
    List<String> _arr(String k) {
      final v = estados[k];
      if (v is List) {
        return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
      }
      return const [];
    }

    return {
      'vencido': _arr('vencido'),
      'venceHoy': _arr('venceHoy'),
      'venceManana': _arr('venceManana'),
      'venceEn2Dias': _arr('venceEn2Dias'),
    };
  }

  static Future<String?> pickDailyMessage() async {
    final list = await _readDailyMessages();
    if (list.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final key = 'daily_index';
    final idx = (prefs.getInt(key) ?? -1) + 1;
    final next = idx % list.length;
    await prefs.setInt(key, next);
    return list[next];
  }

  static Future<String?> pickDueMessage(String estado) async {
    final map = await _readDueMessages();
    final list = map[estado] ?? const [];
    if (list.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    final key = 'due_index_$estado';
    final idx = (prefs.getInt(key) ?? -1) + 1;
    final next = idx % list.length;
    await prefs.setInt(key, next);
    return list[next];
  }

  static Future<void> showDailyForeground() async {
    final msg = await pickDailyMessage();
    if (msg == null) return;
    showForeground(msg);
  }

  static Future<void> showDueForeground(String estado) async {
    final msg = await pickDueMessage(estado);
    if (msg == null) return;
    final color = switch (estado) {
      'vencido' => const Color(0xFFDC2626),
      'venceHoy' => const Color(0xFFFB923C),
      'venceManana' => const Color(0xFFFACC15),
      'venceEn2Dias' => const Color(0xFF2563EB),
      _ => const Color(0xFF2563EB),
    };
    _showBanner(msg, color: color, intent: 'due_$estado');
  }

  // =================== NUEVO: Handler para datos de FCM ===================
  /// Llama esto desde tu listener de FCM en primer plano:
  /// FirebaseMessaging.onMessage.listen((msg) => NotificationsPlus.handleFcmData(msg.data));
  static void handleFcmData(Map<String, dynamic> data) {
    final type = (data['type'] ?? data['intent'] ?? '').toString(); // "vencimiento" | "daily" | ...
    final module = (data['module'] ?? '').toString();               // "prestamos" | "productos" | "alquiler"
    final kind = (data['kind'] ?? '').toString();                   // "vencido" | "venceHoy" | ...
    final body = (data['body'] ?? data['text'] ?? '').toString();   // opcional si incluyes body en data

    if (type == 'vencimiento') {
      final c = _dueTint[kind] ?? _moduleTint[module] ?? const Color(0xFF2563EB);
      final msg = body.isNotEmpty ? body : _labelForDue(module, kind);
      _showBanner(msg, color: c, intent: 'due_${module}_$kind');
      return;
    }

    if (type == 'daily') {
      final msg = body.isNotEmpty ? body : '📣 Revisa tu negocio hoy y cuida tu billetera.';
      _showBanner(msg, color: const Color(0xFF2563EB), intent: 'daily');
      return;
    }

    // Fallback genérico
    final msg = body.isNotEmpty ? body : '🔔 Tienes una notificación.';
    _showBanner(msg, color: const Color(0xFF2563EB), intent: type.isEmpty ? 'push' : type);
  }

  // =================== NUEVO: Etiquetas de respaldo ===================
  static String _labelForDue(String module, String kind) {
    final m = switch (module) {
      'prestamos' => 'préstamos',
      'productos' => 'productos',
      'alquiler' => 'alquileres',
      _ => 'tu cartera',
    };
    return switch (kind) {
      'vencido' => '⏰ Tienes $m vencidos. Revisa tus cobros.',
      'venceHoy' => '📅 Hoy vencen $m. No los dejes pasar.',
      'venceManana' => '🔔 Mañana vencen $m. Organiza tus cobros.',
      'venceEn2Dias' => '📆 En 2 días vencen $m. Prepárate.',
      _ => '🔔 Revisa $m en tu app.',
    };
  }
}