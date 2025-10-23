// lib/ui/perfil_prestamista/ganancias_screen.dart
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';

class GananciasScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const GananciasScreen({super.key, required this.docPrest});

  @override
  State<GananciasScreen> createState() => _GananciasScreenState();
}

class _GananciasScreenState extends State<GananciasScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  int _displayedTotal = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _rd(int v) {
    final format = NumberFormat.currency(
      locale: 'es_DO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return format.format(v).replaceAll(',', '.');
  }

  Future<void> _borrarGananciasTotales() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final db = FirebaseFirestore.instance;

    // ✅ Aseguramos que cada categoría se actualice correctamente
    const categorias = ['prestamo', 'producto', 'alquiler'];

    for (final cat in categorias) {
      await db
          .collection('prestamistas')
          .doc(user.uid)
          .collection('estadisticas')
          .doc(cat)
          .set({
        'gananciaNeta': 0,
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
    }

    await db
        .collection('prestamistas')
        .doc(user.uid)
        .collection('estadisticas')
        .doc('totales')
        .set({
      'totalGanancia': 0,
      'updatedAt': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'Ganancias totales reiniciadas correctamente 💎',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.gradTop,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _confirmBorrarGananciasTotales() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: const [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFE11D48), size: 56),
            SizedBox(height: 10),
            Text('¿Eliminar ganancias totales?',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ],
        ),
        content: const Text(
          'Esto reiniciará todas tus ganancias acumuladas (Préstamos, Productos y Alquiler).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              shape: const StadiumBorder(),
            ),
            child: const Text('Cancelar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            child: const Text('Borrar',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok == true) await _borrarGananciasTotales();
  }

  Future<void> _openPremium() async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumBoostsScreen(docPrest: widget.docPrest),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Center(child: Text("No se ha iniciado sesión"));
    }

    final db = FirebaseFirestore.instance;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Ganancias totales',
            style: TextStyle(
                fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF233A77), Color(0xFF673AB7)],
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<DocumentSnapshot>>(
            stream: db
                .collection('prestamistas')
                .doc(user.uid)
                .collection('estadisticas')
                .where(FieldPath.documentId,
                whereIn: ['prestamo', 'producto', 'alquiler'])
                .snapshots()
                .map((q) => q.docs),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.white));
              }

              int ganPrestamo = 0, ganProducto = 0, ganAlquiler = 0;
              for (var doc in snap.data!) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                if (doc.id == 'prestamo') ganPrestamo = data['gananciaNeta'] ?? 0;
                if (doc.id == 'producto') ganProducto = data['gananciaNeta'] ?? 0;
                if (doc.id == 'alquiler') ganAlquiler = data['gananciaNeta'] ?? 0;
              }

              final total = ganPrestamo + ganProducto + ganAlquiler;

              if (_displayedTotal != total) {
                Timer.periodic(const Duration(milliseconds: 30), (timer) {
                  setState(() {
                    if (_displayedTotal < total) {
                      _displayedTotal += ((total - _displayedTotal) / 6).ceil();
                    } else {
                      _displayedTotal = total;
                      timer.cancel();
                    }
                  });
                });
              }

              return FadeTransition(
                opacity: _fadeAnim,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // === TARJETA PRINCIPAL SUAVIZADA ===
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withOpacity(0.07),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 6))
                        ],
                      ),
                      child: Column(
                        children: [
                          Text('Ganancias totales históricas',
                              style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(.9),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17)),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                  child: _kpiCard(
                                      'Préstamos',
                                      ganPrestamo,
                                      const Icon(Icons.request_quote_rounded,
                                          color: Colors.blueAccent))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _kpiCard(
                                      'Productos',
                                      ganProducto,
                                      const Icon(Icons.shopping_bag_rounded,
                                          color: Colors.green))),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _kpiCard(
                                      'Alquiler',
                                      ganAlquiler,
                                      const Icon(Icons.home_work_rounded,
                                          color: Colors.orange))),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(24),
                              border:
                              Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.trending_up_rounded,
                                    color: Colors.greenAccent, size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  _rd(_displayedTotal),
                                  style: GoogleFonts.poppins(
                                    textStyle: const TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 48,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // === SECCIÓN QEDU PREMIUM ELEGANTE ===
                    _qeduPremiumCard(),

                    const SizedBox(height: 35),
                    _botonBorrarGanancias(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _qeduPremiumCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.07),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Potenciador Premium',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: .6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _bullet('QEDU del día'),
          const SizedBox(height: 10),
          _bullet('Estadística avanzada'),
          const SizedBox(height: 10),
          _bullet('Consejo pro'),
          const SizedBox(height: 18),
          Text(
            'Contenido exclusivo que se actualiza cada día para multiplicar tus ganancias y mantenerte al nivel profesional más alto.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(.9),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton(
              onPressed: _openPremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16),
                elevation: 0,
              ),
              child: const Text('Ver ahora'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: .1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard(String label, int value, Icon icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          icon,
          const SizedBox(height: 8),
          Text(
            _rd(value),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
        ],
      ),
    );
  }

  Widget _botonBorrarGanancias() {
    return ElevatedButton.icon(
      onPressed: _confirmBorrarGananciasTotales,
      icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
      label: const Text('Borrar ganancias totales',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE11D48),
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        elevation: 10,
        shadowColor: Colors.redAccent.withOpacity(.4),
      ),
    );
  }
}
