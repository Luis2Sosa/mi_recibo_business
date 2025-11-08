// 📂 lib/core/premium_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 🔹 Verifica si el usuario tiene Premium activo (una sola vez)
  Future<bool> esPremiumActivo(String uid) async {
    try {
      final doc = await _db
          .collection('prestamistas')
          .doc(uid)
          .collection('premium')
          .doc('status')
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      final activo = data['activo'] == true;
      final fechaFin = (data['fechaFin'] as Timestamp?)?.toDate();

      if (fechaFin == null) return activo;

      final ahora = DateTime.now();
      return activo && fechaFin.isAfter(ahora);
    } catch (e) {
      print('⚠️ Error verificando Premium: $e');
      return false;
    }
  }

  /// 🔹 Escucha cambios del estado Premium en tiempo real
  Stream<bool> streamEstadoPremium(String uid) {
    return _db
        .collection('prestamistas')
        .doc(uid)
        .collection('premium')
        .doc('status')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return false;

      final data = snap.data();
      if (data == null) return false;

      final activo = data['activo'] == true;
      final fechaFin = (data['fechaFin'] as Timestamp?)?.toDate();

      if (fechaFin == null) return activo;

      final ahora = DateTime.now();
      return activo && fechaFin.isAfter(ahora);
    });
  }

  /// 🔹 Activar Premium (ejecutado al pulsar “Desbloquear”)
  Future<void> activarPremium(BuildContext context) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Usuario no autenticado.');

      final fechaInicio = DateTime.now();
      final fechaFin = fechaInicio.add(const Duration(days: 30));

      await _db
          .collection('prestamistas')
          .doc(uid)
          .collection('premium')
          .doc('status')
          .set({
        'activo': true,
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'fechaFin': Timestamp.fromDate(fechaFin),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // ✅ Guardar en historial Premium
      await _db
          .collection('prestamistas')
          .doc(uid)
          .collection('premium')
          .doc('historial')
          .collection('activaciones')
          .add({
        'fechaInicio': Timestamp.fromDate(fechaInicio),
        'fechaFin': Timestamp.fromDate(fechaFin),
        'monto': 0.99,
        'moneda': 'USD',
        'metodo': 'manual',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ✅ Mostrar confirmación visual
      _mostrarBanner(context,
          texto: '✅ Premium activado correctamente.',
          color: const Color(0xFF34D399)); // Verde esmeralda

      print('✅ Premium activado correctamente.');
    } catch (e) {
      _mostrarBanner(context,
          texto: 'Error al activar Premium: $e',
          color: const Color(0xFFE11D48)); // Rojo
      print('⚠️ Error al activar Premium: $e');
    }
  }

  /// 🔹 Desactivar Premium
  Future<void> desactivarPremium(String uid) async {
    try {
      await _db
          .collection('prestamistas')
          .doc(uid)
          .collection('premium')
          .doc('status')
          .set({
        'activo': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('🔒 Premium desactivado correctamente.');
    } catch (e) {
      print('⚠️ Error al desactivar Premium: $e');
    }
  }

  /// 🌈 Banner profesional reutilizable
  void _mostrarBanner(BuildContext context,
      {required String texto, required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          texto,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
