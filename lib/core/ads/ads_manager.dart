// 📂 lib/core/ads/ads_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../premium_service.dart'; // 👈 importante este import

class AdsManager {
  static DateTime? _lastAdTime;
  static Map<String, DateTime> _shownAds = {};

  /// ✅ Comprueba si el usuario tiene Premium
  static Future<bool> _esPremium() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final premiumService = PremiumService();
      return await premiumService.esPremiumActivo(user.uid);
    } catch (_) {
      return false;
    }
  }

  /// ✅ Muestra un anuncio (solo si NO es premium)
  static Future<void> showAd(BuildContext context, String adName) async {
    final esPro = await _esPremium();
    if (esPro) return; // 🚫 Premium → no mostrar

    debugPrint('🔸 Mostrar anuncio: $adName');

    // Placeholder temporal mientras se integran los anuncios reales de Google
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

  /// ✅ Lógica para los anuncios diarios inteligentes
  static Future<void> handleDailyAd(BuildContext context) async {
    final esPro = await _esPremium();
    if (esPro) return; // 🚫 Premium → no mostrar

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
        showAd(context, 'Bloque diario: $block');
        _shownAds[block] = DateTime.now();
      });
    }
  }

  /// ✅ Anuncio al volver de WhatsApp
  static Future<void> showAfterWhatsApp(BuildContext context, String action) async {
    final esPro = await _esPremium();
    if (esPro) return;

    await Future.delayed(const Duration(seconds: 2));
    showAd(context, 'Anuncio después de $action');
  }

  /// ✅ Anuncio en pantallas valiosas
  static Future<void> showOnValuableScreen(BuildContext context, String screenName) async {
    final esPro = await _esPremium();
    if (esPro) return;

    showAd(context, 'Pantalla: $screenName');
  }
}
