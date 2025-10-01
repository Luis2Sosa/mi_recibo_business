import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'notifications_plus.dart';

@pragma('vm:entry-point')
Future<void> pushBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Aquí puedes registrar métricas si quieres
}

class PushService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Handler background
    FirebaseMessaging.onBackgroundMessage(pushBackgroundHandler);

    // Permisos (Android 13 requiere POST_NOTIFICATIONS en el Manifest)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Token actual
    await _saveToken(await _messaging.getToken());

    // Token refresh
    _messaging.onTokenRefresh.listen(_saveToken);

    // Mensaje con app en foreground
    FirebaseMessaging.onMessage.listen((msg) {
      final title = msg.notification?.title?.trim();
      final body  = msg.notification?.body?.trim();
      final text = [title, body].where((s) => s != null && s!.isNotEmpty).join(' · ');
      if (text.isNotEmpty) {
        NotificationsPlus.showForeground(text);
      }
    });

    // Usuario toca la notificación y abre la app (desde background)
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      // Aquí podrías navegar a alguna pantalla si hace falta
      // NotificationsPlus.showForeground('Notificación abierta');
    });

    // App abierta por notificación desde estado TERMINATED
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Igual que arriba: navegar o mostrar algo si quieres
      // NotificationsPlus.showForeground('Notificación inicial');
    }
  }

  static Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('prestamistas')
        .doc(uid)
        .set({
      'meta': {
        'fcmToken': token,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }
}