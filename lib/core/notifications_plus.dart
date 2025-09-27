import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationsPlus {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
  GlobalKey<ScaffoldMessengerState>();

  // 👇 NUEVO: clave para abrir el diálogo en cualquier pantalla
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  // Cooldown por intención (0 = sin cooldown)
  static const _cooldowns = <String, Duration>{
    'pago_ok': Duration.zero,
    'deuda_finalizada': Duration.zero,
    'sync_ok': Duration(hours: 12),
    'backup_ok': Duration(hours: 12),
    'revision_semanal': Duration(days: 7),
    'inactividad_cobro': Duration(hours: 24),
    'resumen_mes': Duration(days: 30),
  };

  static Future<void> trigger(String intent,
      {Map<String, dynamic>? payload}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = 'last_$intent';
    final lastIso = prefs.getString(key);
    final cd = _cooldowns[intent] ?? const Duration(hours: 12);

    // Respeta cooldown solo si es > 0
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

    // Semanal (1 vez/semana)
    final lastWeekIso = prefs.getString('last_revision_semanal');
    final lastWeek = DateTime.tryParse(lastWeekIso ?? '');
    if (lastWeek == null || now
        .difference(lastWeek)
        .inDays >= 7) {
      await prefs.setString('last_revision_semanal', now.toIso8601String());
      trigger('revision_semanal');
    }

    // Inactividad (3+ días sin abrir)
    final lastOpenIso = prefs.getString('last_app_open');
    final lastOpen = DateTime.tryParse(lastOpenIso ?? '');
    if (lastOpen != null &&
        now.difference(lastOpen) >= const Duration(days: 3)) {
      trigger('inactividad_cobro');
    }
    await prefs.setString('last_app_open', now.toIso8601String());

    // Resumen mensual (una vez al entrar a un mes nuevo)
    final lastMonthIso = prefs.getString('last_resumen_mes');
    final lastMonth = DateTime.tryParse(lastMonthIso ?? '');
    final monthChanged =
        lastMonth == null || lastMonth.month != now.month ||
            lastMonth.year != now.year;
    if (monthChanged) {
      await prefs.setString('last_resumen_mes', now.toIso8601String());
      trigger('resumen_mes', payload: {
        'montoPrestado': 0,
        'montoCobrado': 0,
      });
    }
  }

  // ---- Interno: decide texto/tono del banner ----
  static void _show(String intent, Map payload) {
    switch (intent) {
      case 'pago_ok':
        _showBanner('📊 Pago confirmado',
            color: const Color(0xFF22C55E), intent: intent);
        break;
      case 'deuda_finalizada':
        _showBanner('📊 El cliente saldó su deuda',
            color: const Color(0xFF22C55E), intent: intent); // 👈 verde
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
        _showBanner(
            '🔔 Han pasado varios días sin actividad. Revisa tus cobros pendientes.',
            color: const Color(0xFFFFB020), intent: intent);
        break;
      case 'resumen_mes':
        final prestado = payload['montoPrestado'] ?? 0;
        final cobrado = payload['montoCobrado'] ?? 0;
        _showBanner(
            '📚 Resumen mensual: Prestaste RD\$${prestado} y cobraste RD\$${cobrado}.',
            color: const Color(0xFF2563EB), intent: intent);
        break;
    }
  }

  // ===================== BANNER PREMIUM CENTRADO ======================
  static void _showBanner(String text,
      {required Color color, required String intent}) {
    void showNow() {
      final ctx = navigatorKey.currentState?.overlay?.context ??
          messengerKey.currentContext;
      if (ctx == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) =>
            _showBanner(text, color: color, intent: intent));
        return;
      }

      // Tarjeta premium (sin borde blanco en deuda_finalizada)
      Widget _card() => Container(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 340), // 📏 más compacto
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // 🪶 menos aire
        decoration: intent == 'deuda_finalizada'
            ? BoxDecoration(
          color: const Color(0xFF16A34A), // 🟢 verde plano limpio
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
            // 🌟 Ícono más pequeño y elegante
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

            // ✨ Texto más pequeño pero aún profesional
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




      showGeneralDialog(
        context: ctx,
        barrierLabel: 'notifications_plus_banner',
        barrierDismissible: false,
        // 🔦 Fondo más oscuro
        barrierColor: Colors.black.withOpacity(0.40),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
        transitionBuilder: (_, anim, __, ___) {
          final t = Curves.easeOutCubic.transform(anim.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              // 💎 Blur suave del fondo para que resalte
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

      // Cierre automático
      Future.delayed(const Duration(milliseconds: 1500), () {
        final nav = navigatorKey.currentState;
        if (nav != null && nav.canPop()) nav.pop();
      });
    }

    showNow();
  }
}