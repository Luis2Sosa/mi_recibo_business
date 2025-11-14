// 📂 lib/core/ads/ads_manager.dart
import 'dart:async';
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

      final premiumService = PremiumService();
      final activo = await premiumService.esPremiumActivo(user.uid);

      debugPrint("💎 Premium activo?: $activo"); // 👈 VERIFICACIÓN REAL

      return activo;
    } catch (e) {
      debugPrint("❌ Error Premium: $e");
      return false;
    }
  }


  /// 👉 Función MAESTRA
  /// Regla: 1 anuncio → 3 entradas libres → anuncio → repetir
  static Future<void> showEveryFiveEntries(
      BuildContext context, String screenName) async {

    final esPro = await _esPremium();
    if (esPro) return; // Premium NO ve anuncios

    // Inicializar contador si no existe
    _entradas.putIfAbsent(screenName, () => 0);

    // Incrementar contador
    _entradas[screenName] = _entradas[screenName]! + 1;
    final int count = _entradas[screenName]!;
    debugPrint("📌 Entradas en $screenName: $count");

    // 1️⃣ Primera entrada → anuncio después de 3 segundos
    if (count == 1) {
      Future.delayed(const Duration(seconds: 3), () {
        showAd(context, 'Primer acceso: $screenName');
      });
      return;
    }

    // 2️⃣ Entradas 2, 3 y 4 → NO ANUNCIO
    if (count >= 2 && count <= 4) {
      return;
    }

    // 3️⃣ Entrada 5 → anuncio + reinicio del ciclo
    if (count == 5) {
      Future.delayed(const Duration(seconds: 3), () {
        showAd(context, 'Reingreso #5: $screenName');
      });

      // RESET SEGURO (vuelve a 0)
      _entradas[screenName] = 0;
    }
  }


  /// 👉 Mostrar anuncio (simulado)
  static Future<void> showAd(BuildContext context, String adName) async {
    final esPro = await _esPremium();
    if (esPro) return;

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
    showAd(context, 'Anuncio después de $action');
  }

  /// 👉 Anuncio en pantallas valiosas
  static Future<void> showOnValuableScreen(
      BuildContext context, String screenName) async {

    final esPro = await _esPremium();
    if (esPro) return;

    showAd(context, 'Pantalla: $screenName');
  }
}
