// 📂 lib/core/premium_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final InAppPurchase _iap = InAppPurchase.instance;

  static const String _productId = 'premium-mensual';

  // FIX: nullable en lugar de late — evita LateInitializationError si
  // cerrarListener() se llama antes de iniciarListenerCompras()
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // ===============================
  // INICIAR ESCUCHA DE COMPRAS
  // ===============================
  void iniciarListenerCompras(BuildContext context) {
    _subscription = _iap.purchaseStream.listen(
          (List<PurchaseDetails> purchases) {
        for (final purchase in purchases) {
          _procesarCompra(context, purchase);
        }
      },
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        print('❌ Error compra: $error');
      },
    );
  }

  // ===============================
  // VERIFICAR PREMIUM (una sola vez)
  // ===============================
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

      return activo && fechaFin.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // ===============================
  // STREAM EN TIEMPO REAL DEL ESTADO PREMIUM
  // ===============================
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

      return activo && fechaFin.isAfter(DateTime.now());
    });
  }

  // ===============================
  // ACTIVAR PREMIUM REAL (GOOGLE PLAY)
  // ===============================
  Future<void> activarPremium(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final bool disponible = await _iap.isAvailable();
    if (!disponible) {
      _mostrarBanner(
        context,
        texto: 'Google Play no disponible',
        color: const Color(0xFFE11D48),
      );
      return;
    }

    final ProductDetailsResponse response =
    await _iap.queryProductDetails({_productId});

    if (response.productDetails.isEmpty) {
      _mostrarBanner(
        context,
        texto: 'Producto no encontrado en Google Play',
        color: const Color(0xFFE11D48),
      );
      return;
    }

    final ProductDetails product = response.productDetails.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // ===============================
  // PROCESAR COMPRA CONFIRMADA POR GOOGLE
  // ===============================
  Future<void> _procesarCompra(
      BuildContext context,
      PurchaseDetails purchase,
      ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored) {
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
        'producto': _productId,
        'metodo': 'google_play',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _iap.completePurchase(purchase);

      _mostrarBanner(
        context,
        texto: '✅ Premium activado correctamente',
        color: const Color(0xFF34D399),
      );
    }

    if (purchase.status == PurchaseStatus.error) {
      _mostrarBanner(
        context,
        texto: '❌ Error en la compra',
        color: const Color(0xFFE11D48),
      );
    }

    if (purchase.status == PurchaseStatus.canceled) {
      _mostrarBanner(
        context,
        texto: '⚠️ Compra cancelada',
        color: Colors.orange,
      );
    }
  }

  // ===============================
  // DESACTIVAR PREMIUM
  // ===============================
  Future<void> desactivarPremium(String uid) async {
    await _db
        .collection('prestamistas')
        .doc(uid)
        .collection('premium')
        .doc('status')
        .set({
      'activo': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ===============================
  // BANNER PROFESIONAL
  // ===============================
  void _mostrarBanner(
      BuildContext context, {
        required String texto,
        required Color color,
      }) {
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

  // ===============================
  // CERRAR LISTENER
  // ===============================
  void cerrarListener() {
    // FIX: uso de ?. — seguro aunque iniciarListenerCompras() nunca fue llamado
    _subscription?.cancel();
  }
}