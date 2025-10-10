import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'notifications_plus.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Aquí podrías registrar métricas o logging si necesitas
}

class PushService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Handler background (top-level)
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);

    // Permisos (Android 13 requiere POST_NOTIFICATIONS en el Manifest)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // iOS: mostrar alert/badge/sound aunque la app esté en foreground
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );
    }

    // Token actual + guardar zona local
    await _saveTokenAndLocalZone(await _messaging.getToken());

    // Token refresh (multi-dispositivo)
    _messaging.onTokenRefresh.listen(_saveTokenAndLocalZone);

    // Mensaje con app en foreground
    FirebaseMessaging.onMessage.listen((msg) {
      // 1) Si viene data estructurada desde backend → mostrar bonito
      if (msg.data.isNotEmpty) {
        NotificationsPlus.handleFcmData(msg.data);
        return;
      }
      // 2) Fallback: usar título/cuerpo de la notificación
      final title = msg.notification?.title?.trim();
      final body  = msg.notification?.body?.trim();
      final pieces = [title, body].where((s) => (s ?? '').isNotEmpty).cast<String>();
      final text = pieces.join(' · ');
      if (text.isNotEmpty) NotificationsPlus.showForeground(text);
    });

    // Usuario toca la notificación y abre la app (desde background)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      if (msg.data.isNotEmpty) {
        NotificationsPlus.handleFcmData(msg.data);
        return;
      }
      final title = msg.notification?.title?.trim();
      final body  = msg.notification?.body?.trim();
      final pieces = [title, body].where((s) => (s ?? '').isNotEmpty).cast<String>();
      final text = pieces.join(' · ');
      if (text.isNotEmpty) NotificationsPlus.showForeground(text);
    });

    // App abierta por notificación desde estado TERMINATED
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      if (initial.data.isNotEmpty) {
        NotificationsPlus.handleFcmData(initial.data);
      } else {
        final title = initial.notification?.title?.trim();
        final body  = initial.notification?.body?.trim();
        final pieces = [title, body].where((s) => (s ?? '').isNotEmpty).cast<String>();
        final text = pieces.join(' · ');
        if (text.isNotEmpty) NotificationsPlus.showForeground(text);
      }
    }

    // Guardar al menos la zona local aunque el token no cambie
    await _saveTokenAndLocalZone(null);
  }

  /// Guarda el token FCM (si viene) y la zona local del dispositivo:
  /// - utcOffsetMin (ej: -240 para UTC-4)
  /// - tzAbbr (abreviatura, p.ej. "AST", "CET" o "GMT-4")
  static Future<void> _saveTokenAndLocalZone(String? token) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final now = DateTime.now();
      final int utcOffsetMin = now.timeZoneOffset.inMinutes;
      final String tzAbbr = now.timeZoneName;

      final Map<String, dynamic> metaUpdate = {
        'utcOffsetMin': utcOffsetMin,
        'tzAbbr': tzAbbr,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      };

      // Compat + multi-dispositivo
      if (token != null && token.trim().isNotEmpty) {
        final t = token.trim();
        metaUpdate['fcmToken'] = t;
        metaUpdate['fcmTokens'] = FieldValue.arrayUnion([t]);
      }

      await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .set({'meta': metaUpdate}, SetOptions(merge: true));
    } catch (_) {
      // Evitar que un error de red rompa el flujo de inicio
    }
  }
}