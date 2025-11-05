import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';


import '../home_screen.dart';
import '../widgets/charts_common.dart';
import '../theme/app_theme.dart';
import './ganancias_screen.dart';
import './estadisticas_views.dart';


// 👇 Conexión a mini-dashboards (sin tocar lógica)
import './prestamo_estadistica.dart';
import './producto_estadistica.dart';
import './alquiler_estadistica.dart';
import 'ganancia_prestamo_screen.dart';

// === Categorías de los filtros
enum PerfilCategoria { prestamos, productos, alquiler }

class PerfilPrestamistaScreen extends StatefulWidget {
  const PerfilPrestamistaScreen({super.key});
  @override
  State<PerfilPrestamistaScreen> createState() => _PerfilPrestamistaScreenState();
}

// Paleta local (consistente con tu app)
class _Brand {
  static const gradTop = Color(0xFF2458D6);
  static const gradBottom = Color(0xFF0A9A76);
  static const primary = Color(0xFF2563EB);
  static const success = Color(0xFF22C55E);
  static const successDark = Color(0xFF16A34A);
  static const softRed = Color(0xFFE11D48);
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const card = Color(0xFFFFFFFF);
  static const glassAlpha = 0.12;
  static const divider = Color(0xFFD7E1EE);
}

// ================================================================
//                 PERFIL DEL PRESTAMISTA (PREMIUM)
// ================================================================
class _PerfilPrestamistaScreenState extends State<PerfilPrestamistaScreen> {
  // ============== Inputs premium (solo UI) ==============
  Widget _inputPremium({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))],
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _Brand.ink),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
          floatingLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
          prefixIcon: Icon(icon, color: _Brand.inkDim),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // ============== Botón circular premium (filtros) ==============
  // Íconos siempre blancos; brillo sutil al estar activo.
  Widget _botonCircularPremiumV7({
    required IconData icon,
    required String label,
    required List<Color> gradienteBase,
    required VoidCallback onTap,
    bool activo = false,
  }) {
    final grad = gradienteBase;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: Colors.white.withOpacity(activo ? 0.95 : 0.7), width: activo ? 2.0 : 1.2),
              boxShadow: [if (activo) BoxShadow(color: grad.last.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 5))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: Colors.white),
                const SizedBox(height: 3),
                Icon(Icons.touch_app_rounded, size: 14, color: Colors.white.withOpacity(0.9)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,      // 🔹 un punto más grande
              letterSpacing: .3, // 🔹 más aire tipográfico
            ),
          ),
        ],
      ),
    );
  }

  // Tabs
  int _tab = 1; // 0 Perfil | 1 General

  // Filtro categoría
  PerfilCategoria? _catSel; // sin selección por defecto

  // Firebase
  final _db = FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;
  DocumentReference<Map<String, dynamic>>? get _docPrest =>
      _user == null ? null : _db.collection('prestamistas').doc(_user!.uid);

  // Perfil
  final _nombreCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _empCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  bool _lockEnabled = false, _backup = false, _notif = true;
  DateTime? _lastBackup;

  // Realtime perfil
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _perfilSub;
  bool _syncingFromFirestore = false;

  // Stats (Actual)
  bool _loadingProfile = true, _loadingStats = true;
  int totalPrestado = 0, totalPendiente = 0, totalRecuperado = 0;
  List<int> pagosMes = [];
  List<String> pagosMesLabels = [];
  int clientesAlDia = 0, clientesPagando = 0, clientesVencidos = 0;
  String mayorNombre = '—';
  int mayorSaldo = -1;
  String promInteres = '—', proximoVenc = '—';

  // Histórico (lifetime)
  int lifetimePrestado = 0;
  int lifetimeRecuperado = 0;
  int lifetimeGanancia = 0;
  int lifetimePagosProm = 0;
  String histPrimerPago = '—';
  String histUltimoPago = '—';
  String histMesTop = '—';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    _listenPerfilRealtime();
  }

  Future<void> _abrirWhatsAppConTexto(String texto) async {
    final encoded = Uri.encodeComponent(texto);
    final uriApp = Uri.parse('whatsapp://send?text=$encoded');
    final uriBiz = Uri.parse('whatsapp-business://send?text=$encoded');
    final uriWeb = Uri.parse('https://wa.me/?text=$encoded');
    try {
      if (await canLaunchUrl(uriApp)) {
        final ok = await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      if (await canLaunchUrl(uriBiz)) {
        final ok = await launchUrl(uriBiz, mode: LaunchMode.externalApplication);
        if (ok) return;
      }
      await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast('No se pudo abrir WhatsApp', color: _Brand.softRed, icon: Icons.error_outline);
    }
  }

  Future<void> _compartirDireccionNegocio() async {
    final dir = _dirCtrl.text.trim();
    if (dir.isEmpty) {
      _toast('No tienes dirección guardada', color: _Brand.softRed, icon: Icons.location_off_rounded);
      return;
    }
    final empresa = _empCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();
    final header = empresa.isNotEmpty ? empresa : (nombre.isNotEmpty ? nombre : 'Mi negocio');
    final mensaje = '📍 Dirección del negocio ($header):\n$dir';
    await _abrirWhatsAppConTexto(mensaje);
  }

  Future<void> _cargarTodo() async {
    await Future.wait([_loadProfile(), _loadStats()]);
  }

  @override
  void dispose() {
    _perfilSub?.cancel();
    _nombreCtrl.dispose();
    _telCtrl.dispose();
    _empCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  // ===== Utils
  String _rd(int v) {
    if (v <= 0) return '\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write(',');
        c = 0;
      }
    }
    return '\$${b.toString().split('').reversed.join()}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtFecha(DateTime d) => '${_two(d.day)} ${[
    'ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'
  ][d.month - 1]} ${d.year}';

  void _toast(String msg, {Color color = _Brand.success, IconData icon = Icons.check_circle}) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      ]),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

  // ===== Perfil
  Future<void> _loadProfile() async {
    try {
      final ref = _docPrest;
      if (ref == null) return;
      final snap = await ref.get();
      final d = snap.data() ?? {};

      _nombreCtrl.text = ([d['nombre'], d['apellido']]
          .where((e) => (e ?? '').toString().trim().isNotEmpty)
          .map((e) => e.toString().trim()))
          .join(' ');
      _telCtrl.text = (d['telefono'] ?? '').toString().trim();
      _empCtrl.text = (d['empresa'] ?? '').toString().trim();
      _dirCtrl.text = (d['direccion'] ?? '').toString().trim();

      final s = (d['settings'] as Map?) ?? {};
      _lockEnabled = (s['lockEnabled'] == true) || (s['pinEnabled'] == true) || (s['biometria'] == true);
      _backup = s['backupHabilitado'] == true;
      _notif = (s['notifVenc'] ?? true) as bool;

      final lb = d['lastBackupAt'];
      if (lb is Timestamp) _lastBackup = lb.toDate();
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  void _listenPerfilRealtime() {
    final ref = _docPrest;
    if (ref == null) return;

    _perfilSub = ref.snapshots().listen((snap) {
      if (!snap.exists) return;
      final d = snap.data() ?? {};
      if (_syncingFromFirestore) return;
      _syncingFromFirestore = true;

      final nombre = ([d['nombre'], d['apellido']]
          .where((e) => (e ?? '').toString().trim().isNotEmpty)
          .map((e) => e.toString().trim()))
          .join(' ');
      final tel = (d['telefono'] ?? '').toString().trim();
      final emp = (d['empresa'] ?? '').toString().trim();
      final dir = (d['direccion'] ?? '').toString().trim();

      if (_nombreCtrl.text.trim() != nombre) _nombreCtrl.text = nombre;
      if (_telCtrl.text.trim() != tel) _telCtrl.text = tel;
      if (_empCtrl.text.trim() != emp) _empCtrl.text = emp;
      if (_dirCtrl.text.trim() != dir) _dirCtrl.text = dir;

      final s = (d['settings'] as Map?) ?? {};
      final newLock = (s['lockEnabled'] == true) || (s['pinEnabled'] == true) || (s['biometria'] == true);
      final newBackup = s['backupHabilitado'] == true;
      final newNotif = (s['notifVenc'] ?? true) as bool;

      bool needSetState = false;
      if (_lockEnabled != newLock) { _lockEnabled = newLock; needSetState = true; }
      if (_backup != newBackup) { _backup = newBackup; needSetState = true; }
      if (_notif != newNotif) { _notif = newNotif; needSetState = true; }

      final lb = d['lastBackupAt'];
      final newLB = lb is Timestamp ? lb.toDate() : null;
      if (newLB?.toIso8601String() != _lastBackup?.toIso8601String()) {
        _lastBackup = newLB;
        needSetState = true;
      }

      if (needSetState && mounted) setState(() {});
      _syncingFromFirestore = false;
    });
  }

  Future<void> _saveProfile() async {
    if (_docPrest == null) return;

    final full = _nombreCtrl.text.trim();
    String nombre = '', apellido = '';
    if (full.isNotEmpty) {
      final parts = full.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        nombre = parts.first;
      } else {
        apellido = parts.removeLast();
        nombre = parts.join(' ');
      }
    }

    await _docPrest!.set({
      'nombre': nombre,
      'apellido': apellido,
      'nombreCompleto': full.isEmpty ? null : full,
      'telefono': _telCtrl.text.trim(),
      'empresa': _empCtrl.text.trim().isEmpty ? null : _empCtrl.text.trim(),
      'direccion': _dirCtrl.text.trim().isEmpty ? null : _dirCtrl.text.trim(),
      'settings': {
        'lockEnabled': _lockEnabled,
        'pinEnabled': _lockEnabled,
        'biometria': _lockEnabled,
        'backupHabilitado': _backup,
        'notifVenc': _notif,
      },
      'lastBackupAt': _lastBackup == null ? null : Timestamp.fromDate(_lastBackup!),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _toast('Perfil actualizado ✅');
  }

  Future<void> _hacerBackup() async {
    if (_docPrest == null) return;
    final clientes = await _docPrest!.collection('clientes').get();
    final List<Map<String, dynamic>> pack = [];
    for (final c in clientes.docs) {
      final data = c.data();
      final pagos = await c.reference.collection('pagos').get();
      data['pagos'] = pagos.docs.map((e) => e.data()).toList();
      pack.add(data);
    }
    await _docPrest!.collection('backups').add({
      'createdAt': FieldValue.serverTimestamp(),
      'clientes': pack,
      'version': 1,
    });
    _lastBackup = DateTime.now();
    await _docPrest!.set({'lastBackupAt': Timestamp.fromDate(_lastBackup!)}, SetOptions(merge: true));
    if (mounted) setState(() {});
    _toast('Copia realizada ✅');
  }

  // ===== Stats (cálculos)
  Future<void> _loadStats() async {
    try {
      if (_docPrest == null) return;
      final cs = await _docPrest!.collection('clientes').get();

      int prestado = 0, pendiente = 0;
      int alDia = 0, pagando = 0, vencidos = 0;
      String maxNombre = '';
      int maxSaldo = -1;
      DateTime? proxVenc;

      final hoy = DateTime.now();
      final hoyOnly = DateTime(hoy.year, hoy.month, hoy.day);
      final now = DateTime.now();

      int sumPagos = 0;
      int sumIntereses = 0;
      int countPagos = 0;
      DateTime? firstPay, lastPay;
      String topMesKey = '';
      int topMesVal = -1;

      double sumaRates = 0.0;
      int nRates = 0;

      // 🔹 Recorrer clientes y sus pagos
      for (final d in cs.docs) {
        final m = d.data();
        final cap = (m['capitalInicial'] ?? 0) as int;
        final sal = (m['saldoActual'] ?? 0) as int;
        prestado += cap;
        pendiente += sal;

        if (sal > 0 && sal > maxSaldo) {
          maxSaldo = sal;
          final nombre = '${(m['nombre'] ?? '').toString().trim()} ${(m['apellido'] ?? '').toString().trim()}'.trim();
          maxNombre = nombre.isEmpty ? (m['telefono'] ?? 'Cliente') : nombre;
        }

        if (sal > 0) {
          final ts = m['proximaFecha'];
          if (ts is Timestamp) {
            final td = ts.toDate();
            final f = DateTime(td.year, td.month, td.day);
            final diff = f.difference(hoyOnly).inDays;
            if (diff < 0) {
              vencidos++;
            } else if (diff <= 2) {
              pagando++;
            } else {
              alDia++;
            }
            if (!f.isBefore(hoyOnly)) {
              if (proxVenc == null || f.isBefore(proxVenc)) proxVenc = f;
            }
          }
        }

        // 🔹 Pagos reales (solo estos activan el histórico)
        final pagos = await d.reference.collection('pagos').get();
        for (final p in pagos.docs) {
          final mp = p.data();
          final ts = mp['fecha'];
          final int totalPagado = (mp['totalPagado'] ?? 0) as int;
          final int pagoInteres = (mp['pagoInteres'] ?? 0) as int;
          final int saldoAnterior = (mp['saldoAnterior'] ?? 0) as int;

          if (ts is Timestamp) {
            final dt = ts.toDate();
            if (firstPay == null || dt.isBefore(firstPay!)) firstPay = dt;
            if (lastPay == null || dt.isAfter(lastPay!)) lastPay = dt;
          }

          sumPagos += totalPagado;
          sumIntereses += pagoInteres;
          countPagos++;

          if (pagoInteres > 0 && saldoAnterior > 0) {
            sumaRates += (pagoInteres / saldoAnterior) * 100.0;
            nRates++;
          }
        }
      }

      // =====================================================
      // 🔹 Construcción premium de meses dinámicos (Ene–Dic)
      // =====================================================
      const mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

      // 🔸 Si hay pagos, el año base y mes base será el del primer pago
      final baseYear = firstPay?.year ?? now.year;
      final baseMonth = firstPay?.month ?? now.month;

      // 🔸 Generamos los 12 meses del año, pero rotando para comenzar desde el mes del primer pago
      final allMonths = List.generate(12, (i) => DateTime(baseYear, i + 1, 1));
      final monthsList = [
        ...allMonths.sublist(baseMonth - 1),
        ...allMonths.sublist(0, baseMonth - 1)
      ];

      // 🔸 Mapa vacío con todos los meses
      final Map<String, int> porMes = {
        for (final m in monthsList) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0
      };

      // 🔸 Recontar los pagos por mes
      for (final d in cs.docs) {
        final pagos = await d.reference.collection('pagos').get();
        for (final p in pagos.docs) {
          final mp = p.data();
          final ts = mp['fecha'];
          final int totalPagado = (mp['totalPagado'] ?? 0) as int;
          if (ts is Timestamp) {
            final dt = ts.toDate();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            if (porMes.containsKey(key)) {
              porMes[key] = (porMes[key] ?? 0) + totalPagado;
            }
          }
        }
      }

      // =====================================================
      // 🔹 Cálculos de totales y etiquetas
      // =====================================================
      totalPrestado = prestado;
      totalPendiente = pendiente;
      totalRecuperado = prestado - pendiente;

      pagosMes = [];
      pagosMesLabels = [];

      for (final m in monthsList) {
        final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
        final val = porMes[key] ?? 0;
        pagosMes.add(val);
        pagosMesLabels.add(mesesTxt[m.month - 1]);
        if (val > topMesVal) {
          topMesVal = val;
          topMesKey = '${mesesTxt[m.month - 1]} ${m.year}';
        }
      }

      // =====================================================
      // 🔹 Estadísticas generales premium
      // =====================================================
      mayorNombre = maxSaldo >= 0 ? maxNombre : '—';
      mayorSaldo = maxSaldo;
      promInteres = (nRates > 0) ? '${(sumaRates / nRates).toStringAsFixed(0)}%' : '—';
      proximoVenc = proxVenc == null ? '—' : _fmtFecha(proxVenc!);

      clientesAlDia = alDia;
      clientesPagando = pagando;
      clientesVencidos = vencidos;

      // =====================================================
      // 🔹 Resumen histórico
      // =====================================================
      if (countPagos > 0) {
        histPrimerPago = firstPay == null ? '—' : _fmtFecha(firstPay!);
        histUltimoPago = lastPay == null ? '—' : _fmtFecha(lastPay!);
        histMesTop = topMesVal <= 0 ? '—' : '$topMesKey (${_rd(topMesVal)})';
      } else {
        histPrimerPago = '—';
        histUltimoPago = '—';
        histMesTop = '—';
      }
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }



  // ====================== UI ======================
  @override
  Widget build(BuildContext context) {
    const contentTop = 8.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_Brand.gradTop, _Brand.gradBottom]),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: contentTop),
                child: Center(
                  child: Material(
                    color: Colors.white.withOpacity(_Brand.glassAlpha),
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _tabs(),
                            const SizedBox(height: 12),
                            if (_tab == 0) (_loadingProfile ? _skeleton() : _perfilContent())
                            else (_loadingStats ? _skeleton() : _generalContent()),
                            const SizedBox(height: 16),
                            if (_tab == 0) _accountActions(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título pequeño para dar más peso visual arriba
          Text(
            'Panel de control',
            style: GoogleFonts.inter(
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: .2,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Grupo segmentado grande
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
            ),
            child: Row(
              children: [
                Expanded(child: _tabChip('Perfil', _tab == 0, () => setState(() => _tab = 0))),
                const SizedBox(width: 10),
                Expanded(child: _tabChip('Resumen', _tab == 1, () { setState(() { _tab = 1; _catSel = null; }); })),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _tabChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 56), // ← antes 44
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), // ← más alto
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
              : null,
          border: selected ? null : Border.all(color: Colors.white.withOpacity(0.20), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              label == 'Perfil' ? Icons.person_outline : Icons.insights_rounded,
              size: 18,
              color: selected ? _Brand.ink : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                textStyle: TextStyle(
                  color: selected ? _Brand.ink : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ==== Acciones de cuenta
  Widget _accountActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _Brand.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              elevation: 3,
            ),
            onPressed: () async {
              try { await FirebaseAuth.instance.signOut(); } catch (_) {}
              try { await GoogleSignIn().signOut(); } catch (_) {}
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
            },
            child: const Text('Salir'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _Brand.softRed,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              elevation: 0,
            ),
            onPressed: _confirmDeleteAccount,
            child: const Text('Eliminar cuenta'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text('Esto borrará tus datos y tu usuario. Esta acción no se puede deshacer. ¿Deseas continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: _Brand.softRed))),
        ],
      ),
    );
    if (ok != true) return;
    await _deleteAccount();
  }

  Future<void> _reauthWithGoogleIfNeeded(User user) async {
    final google = GoogleSignIn();
    final current = await google.signInSilently();
    final acct = current ?? await google.signIn();
    if (acct == null) {
      throw FirebaseAuthException(code: 'aborted-by-user', message: 'Reautenticación cancelada');
    }
    final auth = await acct.authentication;
    final credential = GoogleAuthProvider.credential(idToken: auth.idToken, accessToken: auth.accessToken);
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _deleteAccount() async {
    if (_docPrest == null || _user == null) return;
    try {
      Future<void> _wipeCollection(CollectionReference col) async {
        const batchSize = 300;
        while (true) {
          final snap = await col.limit(batchSize).get();
          if (snap.docs.isEmpty) break;
          final batch = _db.batch();
          for (final d in snap.docs) {
            batch.delete(d.reference);
          }
          await batch.commit();
          if (snap.docs.length < batchSize) break;
        }
      }

      final clientes = await _docPrest!.collection('clientes').get();
      for (final c in clientes.docs) {
        await _wipeCollection(c.reference.collection('pagos'));
        await c.reference.delete();
      }

      await _wipeCollection(_docPrest!.collection('backups'));
      await _wipeCollection(_docPrest!.collection('historial'));
      await _wipeCollection(_docPrest!.collection('metrics'));

      await _docPrest!.delete();
      await _reauthWithGoogleIfNeeded(_user!);
      await _user!.delete();

      _toast('Cuenta eliminada', color: _Brand.softRed, icon: Icons.delete_forever);
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _toast('Por seguridad, vuelve a autenticarte e intenta de nuevo.', color: _Brand.softRed, icon: Icons.lock_outline);
      } else if (e.code == 'aborted-by-user') {
        _toast('Reautenticación cancelada', color: _Brand.softRed, icon: Icons.error_outline);
      } else {
        _toast('No se pudo eliminar: ${e.code}', color: _Brand.softRed, icon: Icons.error_outline);
      }
    } catch (_) {
      _toast('No se pudo eliminar. Reintenta.', color: _Brand.softRed, icon: Icons.error_outline);
    }
  }

  // ===== PERFIL (vista)
  Widget _perfilContent() {
    return Column(
      children: [
        _card(
          child: Column(
            children: [
              _inputPremium(icon: Icons.person, label: 'Nombre completo (Nombre y Apellido)', controller: _nombreCtrl),
              const SizedBox(height: 12),
              _inputPremium(icon: Icons.phone, label: 'Teléfono (obligatorio)', controller: _telCtrl, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _inputPremium(icon: Icons.business, label: 'Nombre de la Empresa (opcional)', controller: _empCtrl),
              const SizedBox(height: 12),
              _inputPremium(icon: Icons.home, label: 'Dirección (opcional)', controller: _dirCtrl),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: Image.asset('assets/images/logo_whatsapp.png', width: 18, height: 18, fit: BoxFit.contain),
                  label: const Text('Compartir dirección del negocio', style: TextStyle(fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: _Brand.primary),
                    foregroundColor: _Brand.primary,
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _compartirDireccionNegocio,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _Brand.primary,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    elevation: 3,
                    shadowColor: _Brand.primary.withOpacity(.35),
                  ),
                  onPressed: () async {
                    if (_nombreCtrl.text.trim().isEmpty || _telCtrl.text.trim().isEmpty) {
                      _toast('Completa nombre y teléfono', color: _Brand.softRed, icon: Icons.error_outline);
                      return;
                    }
                    await _saveProfile();
                  },
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Seguridad'),
              const SizedBox(height: 8),
              _switchRow(
                title: 'Bloqueo con seguridad del dispositivo',
                value: _lockEnabled,
                onChanged: (v) async {
                  _lockEnabled = v;
                  await _docPrest?.set({
                    'settings': {'lockEnabled': v, 'pinEnabled': v, 'biometria': v}
                  }, SetOptions(merge: true));
                  if (mounted) setState(() {});
                  _toast(v ? 'Bloqueo activado ✅' : 'Bloqueo desactivado');
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Respaldo en la nube'),
              const SizedBox(height: 6),
              Text(
                _backup
                    ? 'Respaldo: Activado · Última copia: ${_lastBackup == null ? '—' : _fmtFecha(_lastBackup!)} ${_two(_lastBackup?.hour ?? 0)}:${_two(_lastBackup?.minute ?? 0)}'
                    : 'Respaldo: Desactivado',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        if (_backup) {
                          _toast('El respaldo ya está activado');
                          return;
                        }
                        _backup = true;
                        await _docPrest?.set({'settings': {'backupHabilitado': true}}, SetOptions(merge: true));
                        if (mounted) setState(() {});
                        _toast('Respaldo activado ✅');
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _Brand.primary),
                        foregroundColor: _Brand.primary,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Activar respaldo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _backup ? () async => _hacerBackup() : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _backup ? _Brand.primary : Colors.grey.shade300),
                        foregroundColor: _backup ? _Brand.primary : Colors.grey,
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Hacer copia ahora'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _backup
                    ? () async {
                  _backup = false;
                  _lastBackup = null;
                  await _docPrest?.set({
                    'settings': {'backupHabilitado': false},
                    'lastBackupAt': null
                  }, SetOptions(merge: true));
                  if (mounted) setState(() {});
                  _toast('Respaldo desactivado');
                }
                    : null,
                child: const Text('Desactivar respaldo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _title('Notificaciones'),
              const SizedBox(height: 8),
              _switchRow(
                title: 'Recordatorios de vencimientos',
                value: _notif,
                onChanged: (v) async {
                  _notif = v;
                  await _docPrest?.set({'settings': {'notifVenc': v}}, SetOptions(merge: true));
                  if (mounted) setState(() {});
                  _toast(v ? 'Recordatorios activados ✅' : 'Recordatorios desactivados');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===== GENERAL =====
  Widget _generalContent() {

    // 🌟 Tarjeta Premium horizontal delgada — transparente, elegante y alineada con los KPI
    Widget _categoriaCard({
      required IconData icon,
      required String title,
      required Color color,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.15),
          highlightColor: Colors.white.withOpacity(0.05),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔹 Ícono circular colorido
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.9),
                        color.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),

                const SizedBox(height: 5),

                // 🔹 Título
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.8,
                  ),
                ),

                const SizedBox(height: 3),

                // 🔹 Ícono del dedo táctil
                Icon(
                  Icons.touch_app_rounded,
                  color: Colors.white.withOpacity(0.85),
                  size: 13.5,
                ),
              ],
            ),
          ),
        ),
      );
    }

// 🔹 Fila de botones ajustada al ancho exacto de los KPI
    final filtrosRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _categoriaCard(
            icon: Icons.request_quote_rounded,
            title: 'Préstamos',
            color: const Color(0xFF2563EB),
            onTap: () {
              setState(() => _catSel = PerfilCategoria.prestamos);
              _openPrestamos();
            },
          ),
          _categoriaCard(
            icon: Icons.shopping_bag_rounded,
            title: 'Productos',
            color: const Color(0xFF10B981),
            onTap: () {
              setState(() => _catSel = PerfilCategoria.productos);
              _openProductos();
            },
          ),
          _categoriaCard(
            icon: Icons.house_rounded,
            title: 'Alquiler',
            color: const Color(0xFFF59E0B),
            onTap: () {
              setState(() => _catSel = PerfilCategoria.alquiler);
              _openAlquiler();
            },
          ),
        ],
      ),
    );

    final bloqueHistorico = EstadisticasHistoricoView(
      lifetimePrestado: totalPrestado,
      lifetimeRecuperado: totalRecuperado,
      histPrimerPago: histPrimerPago,
      histUltimoPago: histUltimoPago,
      histMesTop: histMesTop,
      onOpenGanancias: _openGanancias,
      onOpenGananciaClientes: _openGananciaClientes,
      rd: _rd,
      mayorNombre: mayorNombre,
      mayorSaldo: mayorSaldo,
    );



    final chartsCard = Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF2FF), Color(0xFFDCE6F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // 📊 PAGO MENSUAL (gráfico moderno)
          // ==========================================
          Text(
            'Pagos recibidos por mes',
            style: GoogleFonts.inter(
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20000,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 20000,
                      reservedSize: 42,
                      getTitlesWidget: (value, _) => Text(
                        '\$${value ~/ 1000}k',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < pagosMesLabels.length) {
                          return Text(
                            pagosMesLabels[idx],
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: pagosMes.isEmpty ? 5 : pagosMes.length - 1,
                minY: 0,
                maxY: (pagosMes.isEmpty
                    ? 60000
                    : pagosMes.reduce((a, b) => a > b ? a : b) * 1.2)
                    .clamp(20000, 100000)
                    .toDouble(),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF2563EB),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 3,
                        strokeColor: const Color(0xFF2563EB),
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2563EB).withOpacity(0.3),
                          const Color(0xFF60A5FA).withOpacity(0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    spots: [
                      for (int i = 0; i < pagosMes.length; i++)
                        FlSpot(i.toDouble(), pagosMes[i].toDouble()),
                    ],
                  ),
                ],
              ),
            ),
          ),


          const SizedBox(height: 28),

          // =======================================
          // 🟢 DISTRIBUCIÓN DE CLIENTES (moderna)
          // =======================================
          Text(
            'Distribución de clientes',
            style: GoogleFonts.inter(
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _donutSection(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );



    // Card borrar histórico
    final borrarHistoricoCard = Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          AppTheme.gradTop.withOpacity(.95),
          AppTheme.gradBottom.withOpacity(.95),
        ]),
        boxShadow: [BoxShadow(color: AppTheme.gradTop.withOpacity(.25), blurRadius: 16, offset: const Offset(0, 6))],
        border: Border.all(color: Colors.white.withOpacity(.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(.15),
                border: Border.all(color: Colors.white.withOpacity(.45), width: 1.2),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Borrar historial', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              'Reinicia tus totales acumulados (como el capital recuperado). No borra clientes ni pagos.',
              style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _confirmBorrarHistorial,
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              label: const Text('Borrar historial'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 6,
                shadowColor: const Color(0xFFE11D48).withOpacity(0.4),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        filtrosRow,
        const SizedBox(height: 10),

        // 🔹 Primero el bloqueHistorico (para mostrar los KPIs)
        bloqueHistorico,
        const SizedBox(height: 12),

        chartsCard,
        const SizedBox(height: 12),
        borrarHistoricoCard,
      ],
    );

  }

  // ===== Dona
  Widget _donutSection() {
    final total = clientesAlDia + clientesPagando + clientesVencidos;
    if (total == 0) return _emptyChart('Sin datos aún');
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: DonutChart(
            slices: [
              DonutSlice(color: _Brand.success, value: clientesAlDia),
              DonutSlice(color: _Brand.softRed, value: clientesVencidos),
              DonutSlice(color: _Brand.primary, value: clientesPagando),
            ],
            center: Text('$total', style: GoogleFonts.inter(textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _Brand.ink))),
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            LegendDot('Al día', _Brand.success),
            LegendDot('Vencidos', _Brand.softRed),
            LegendDot('Pagando', _Brand.primary),
          ],
        )
      ],
    );
  }

  // ===== key/value + switches + skeleton
  Widget _switchRow({required String title, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: _Brand.primary,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFFE5E7EB),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _skeleton() => _card(
    child: SizedBox(
      height: 140,
      child: Center(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
          SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          SizedBox(width: 10),
          Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );

  // ======= Navegación a pantallas
  void _openGananciaClientes() {
    if (_docPrest == null) {
      _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GananciaPrestamoScreen(docPrest: _docPrest!),
      ),
    );

  }

  void _openGanancias() {
    if (_docPrest == null) {
      _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => GananciasScreen(docPrest: _docPrest!)));
  }

  // Abrir mini-dashboards desde los filtros
  void _openPrestamos() {
    if (_docPrest == null) { _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PanelPrestamosScreen()));

  }

  void _openProductos() {
    if (_docPrest == null) { _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline); return; }Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductoEstadisticaScreen()));

  }

  void _openAlquiler() {
    if (_docPrest == null) { _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline); return; }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AlquilerEstadisticaScreen()));

  }

  // ===== Helpers de UI
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Brand.card.withOpacity(.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  Widget _title(String t) => Text(t, style: GoogleFonts.inter(textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _Brand.ink)));

  Widget _chartBlock(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF6F8FB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9EEF5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Future<void> _confirmBorrarHistorial() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: const [
              Icon(Icons.delete_sweep_rounded, color: Color(0xFFE11D48), size: 56),
              SizedBox(height: 10),
              Text(
                '¿Borrar historial?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          content: const Text(
            'Esto reiniciará las métricas acumuladas (como el capital recuperado o promedios), '
                'pero no eliminará clientes ni pagos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Color(0xFF475569)),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: const StadiumBorder(),
              ),
              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                shape: const StadiumBorder(),
              ),
              child: const Text('Borrar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );

    if (ok == true) await _borrarHistorico();
  }

  Future<void> _borrarHistorico() async {
    if (_docPrest == null) return;

    try {
      // 🔹 1. Eliminar resumen anterior (summary)
      await _docPrest!.collection('metrics').doc('summary').delete();

      // 🔹 2. Reiniciar los campos principales
      final refSummary = _docPrest!.collection('metrics').doc('summary');
      await refSummary.set({
        'totalCapitalRecuperado': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final refTotales = _docPrest!.collection('estadisticas').doc('totales');
      await refTotales.set({
        'totalCapitalRecuperado': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 🔹 3. Reiniciar gráfico de pagos mensuales (12 meses planos)
      setState(() {
        pagosMes = List.filled(12, 0);
        pagosMesLabels = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
      });

    } catch (e) {
      print('Error al borrar histórico: $e');
    }

    // 🔹 4. Refrescar métricas visuales
    setState(() {
      lifetimePrestado = 0;
      lifetimeRecuperado = 0;
      lifetimePagosProm = 0;
      histPrimerPago = '—';
      histUltimoPago = '—';
      histMesTop = '—';
    });

    // 🔹 5. Feedback visual tipo dashboard premium
    _toast(
      'Histórico restablecido correctamente',
      color: _Brand.softRed,
      icon: Icons.check_circle_outline_rounded,
    );
  }





  // Placeholder sin datos
  Widget _emptyChart(String t) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(t, style: const TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
    );
  }

  // Gráfico de barras simple
  Widget _barChart({required List<int> values, required List<String> labels}) {
    if (values.isEmpty) return _emptyChart('Sin datos aún');

    const double chartH = 185;
    const double axisLeftW = 60;
    const double bottomLabelH = 24;
    const double topPad = 8;

    final maxV = values.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 999999.0);

    double niceMax;
    if (maxV <= 20000) {
      niceMax = 20000;
    } else if (maxV <= 40000) {
      niceMax = 40000;
    } else if (maxV <= 60000) {
      niceMax = 60000;
    } else if (maxV <= 100000) {
      niceMax = 100000;
    } else {
      niceMax = (maxV / 10000.0).ceil() * 10000;
    }
    final ticks = [0.2, 0.4, 0.6, 1.0];
    final tickLabels = ticks.map((t) => _rd((niceMax * t).round())).toList();

    return SizedBox(
      height: chartH,
      child: Row(
        children: [
          // Eje Y
          SizedBox(
            width: axisLeftW,
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (c, cs) {
                    return Stack(
                      children: List.generate(ticks.length, (i) {
                        final y = (1 - ticks[i]) * (cs.maxHeight - bottomLabelH - topPad) + topPad;
                        return Positioned(
                          left: 0,
                          right: 6,
                          top: y - 8,
                          child: Text(tickLabels[i], textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11, color: _Brand.inkDim, height: 1)),
                        );
                      }),
                    );
                  }),
                ),
                const SizedBox(height: bottomLabelH),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Área de barras
          Expanded(
            child: LayoutBuilder(builder: (c, cs) {
              final barAreaH = cs.maxHeight - bottomLabelH - topPad;
              final barW = math.max(18.0, cs.maxWidth / (values.length * 1.8));

              return Column(
                children: [
                  SizedBox(
                    height: barAreaH,
                    child: Stack(
                      children: [
                        ...List.generate(ticks.length, (i) {
                          final y = (1 - ticks[i]) * barAreaH;
                          return Positioned(left: 0, right: 0, top: y, child: Container(height: 1, color: const Color(0xFFE6ECF5)));
                        }),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(values.length, (i) {
                              final h = (values[i] / niceMax) * barAreaH;
                              return Container(
                                height: h.clamp(0, barAreaH),
                                width: barW,
                                decoration: BoxDecoration(
                                  color: _Brand.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [BoxShadow(color: _Brand.primary.withOpacity(.18), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: bottomLabelH,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(labels.length, (i) {
                        return SizedBox(
                          width: barW + 8,
                          child: Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: _Brand.inkDim)),
                        );
                      }),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // Botón de filtro premium con pill “Toca para ver” (FIX: agrega texto del pill)
  Widget _filtroBoton({
    required String label,
    required IconData icon,
    required bool activo,
    required VoidCallback onTap,
    required List<Color> gradiente,
  }) {
    final bool isActive = activo == true;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(colors: gradiente) : const LinearGradient(colors: [Colors.white, Color(0xFFF1F5F9)]),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: isActive ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [if (isActive) BoxShadow(color: gradiente.last.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: isActive ? Colors.white : const Color(0xFF475569)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isActive ? Colors.white : const Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? Colors.white.withOpacity(.95) : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: isActive ? Colors.white : const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.touch_app_outlined, size: 10, color: isActive ? gradiente.first : const Color(0xFF2563EB)),
                const SizedBox(width: 4),
                Text('Toca para ver', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isActive ? gradiente.first : const Color(0xFF1E293B))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// 🎨 Mini gráfico de líneas suaves (Pagos por mes)
// =======================================================
class _MiniLineChartPainter extends CustomPainter {
  final List<int> values;
  _MiniLineChartPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 999999.0);
    final paintLine = Paint()
      ..strokeWidth = 3
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal) * (size.height - 10);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }

    // Línea principal
    canvas.drawPath(path, paintLine);

    // Puntos decorativos sutiles
    final dotPaint = Paint()..color = const Color(0xFF2563EB);
    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - (values[i] / maxVal) * (size.height - 10);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

