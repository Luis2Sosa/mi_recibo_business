// 📂 lib/core/ads/ads_manager.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../premium_service.dart';

class AdsManager {
  static DateTime? _lastAdTime;
  static Map<String, DateTime> _shownAds = {};

  /// 🔢 Contador de entradas por pantalla
  static Map<String, int> _entradas = {};

  /// 👉 Reiniciar contador de una pantalla específica
  static void resetCounter(String screenName) {
    _entradas[screenName] = 0;
  }

  static Future<bool> _esPremium() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final snap = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(user.uid)
          .get();

      if (!snap.exists) {
        debugPrint("⛔ Usuario sin registro — No mostrar anuncios");
        return true;
      }

      final premiumService = PremiumService();
      final activo = await premiumService.esPremiumActivo(user.uid);

      debugPrint("💎 Premium activo?: $activo");

      return activo;
    } catch (e) {
      debugPrint("❌ Error Premium/Registro: $e");
      return false;
    }
  }

  /// 👉 Función MAESTRA
  /// Regla: 1 anuncio → 3 entradas libres → anuncio → repetir
  static Future<void> showEveryFiveEntries(
      BuildContext context, String screenName) async {
    final esPro = await _esPremium();
    if (esPro) return;

    _entradas.putIfAbsent(screenName, () => 0);
    _entradas[screenName] = _entradas[screenName]! + 1;
    final int count = _entradas[screenName]!;
    debugPrint("📌 Entradas en $screenName: $count");

    if (count == 1) {
      Future.delayed(const Duration(seconds: 3), () {
        // FIX: guard mounted antes de usar context en callbacks asíncronos.
        // Sin esto, si el usuario navega fuera durante el delay, el context
        // ya no existe y ScaffoldMessenger lanza una excepción.
        if (!context.mounted) return;
        showAd(context, 'Primer acceso: $screenName');
      });
      return;
    }

    if (count >= 2 && count <= 4) return;

    if (count == 5) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!context.mounted) return; // FIX: mismo guard
        showAd(context, 'Reingreso #5: $screenName');
      });
      _entradas[screenName] = 0;
    }
  }

  /// 👉 Mostrar anuncio (simulado)
  static Future<void> showAd(BuildContext context, String adName) async {
    final esPro = await _esPremium();
    if (esPro) return;

    // FIX: verificar mounted después del await — el context pudo haberse
    // desmontado mientras esperaba _esPremium()
    if (!context.mounted) return;

    debugPrint('🔸 Mostrar anuncio: $adName');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 2),
        content: Text(
          'Anuncio simulado: $adName',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );

    _lastAdTime = DateTime.now();
  }

  /// 👉 Anuncios diarios (mañana/tarde/noche)
  static Future<void> handleDailyAd(BuildContext context) async {
    final esPro = await _esPremium();
    if (esPro) return;

    final now = DateTime.now();
    final hour = now.hour;
    String block = '';

    if (hour >= 8 && hour < 12) block = 'morning';
    else if (hour >= 13 && hour < 17) block = 'afternoon';
    else if (hour >= 19 && hour < 22) block = 'night';
    else return;

    final lastShown = _shownAds[block];
    if (lastShown == null || now.difference(lastShown).inHours >= 4) {
      Future.delayed(const Duration(minutes: 3), () {
        if (!context.mounted) return; // FIX: guard mounted
        showAd(context, 'Bloque diario: $block');
        _shownAds[block] = DateTime.now();
      });
    }
  }

  /// 👉 Anuncio después de WhatsApp
  static Future<void> showAfterWhatsApp(
      BuildContext context, String action) async {
    final esPro = await _esPremium();
    if (esPro) return;

    await Future.delayed(const Duration(seconds: 2));

    if (!context.mounted) return; // FIX: guard mounted tras el delay
    showAd(context, 'Anuncio después de $action');
  }

  /// 👉 Anuncio en pantallas valiosas
  static Future<void> showOnValuableScreen(
      BuildContext context, String screenName) async {
    final esPro = await _esPremium();
    if (esPro) return;

    if (!context.mounted) return; // FIX: guard mounted tras el await
    showAd(context, 'Pantalla: $screenName');
  }
}