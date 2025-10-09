import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home_screen.dart';
import '../widgets/charts_common.dart';

import '../theme/app_theme.dart';

import './ganancias_screen.dart';
import './estadisticas_views.dart';
import './ganancia_clientes_screen.dart';

class PerfilPrestamistaScreen extends StatefulWidget {
  const PerfilPrestamistaScreen({super.key});
  @override
  State<PerfilPrestamistaScreen> createState() => _PerfilPrestamistaScreenState();
}

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
  static const kpiGray = Color(0xFFE5E7EB);
  static const kpiBlue = Color(0xFFDBEAFE);
  static const kpiGreen = Color(0xFFDCFCE7);
  static const kpiPurple = Color(0xFFEDE9FE);
  static const purple = Color(0xFF6D28D9);
  static const divider = Color(0xFFD7E1EE);
}

class _PerfilPrestamistaScreenState extends State<PerfilPrestamistaScreen> {
  // ---- Inputs premium
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
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))
        ],
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

  // ---- Layout superior
  static const double _logoTop = -48;
  static const double _logoH = 230;
  static const double _gapBelowLogo = -48;

  // Tabs
  int _tab = 1; // 0 Perfil | 1 Estadísticas

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

  // Stats (actual)
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
  bool _historico = false;

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
      if (c == 3 && i != 0) { b.write(','); c = 0; }
    }
    return '\$${b.toString().split('').reversed.join()}';
  }


  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtFecha(DateTime d) => '${_two(d.day)} ${[
    'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
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
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(snack);
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
      if (_lockEnabled != newLock) {
        _lockEnabled = newLock;
        needSetState = true;
      }
      if (_backup != newBackup) {
        _backup = newBackup;
        needSetState = true;
      }
      if (_notif != newNotif) {
        _notif = newNotif;
        needSetState = true;
      }

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

  // ===== Stats
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
      final monthsList = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
      final Map<String, int> porMes = {
        for (final m in monthsList) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0
      };

      int sumPagos = 0;
      int sumIntereses = 0;
      int countPagos = 0;
      DateTime? firstPay, lastPay;
      String topMesKey = '';
      int topMesVal = -1;

      double sumaRates = 0.0;
      int nRates = 0;

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

        final pagos = await d.reference.collection('pagos').get();
        for (final p in pagos.docs) {
          final mp = p.data();
          final ts = mp['fecha'];
          final int totalPagado = (mp['totalPagado'] ?? 0) as int;
          final int pagoInteres = (mp['pagoInteres'] ?? 0) as int;
          final int saldoAnterior = (mp['saldoAnterior'] ?? 0) as int;

          if (ts is Timestamp) {
            final dt = ts.toDate();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            porMes[key] = (porMes[key] ?? 0) + totalPagado;

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

      totalPrestado = prestado;
      totalPendiente = pendiente;
      totalRecuperado = prestado - pendiente;

      pagosMes = [];
      pagosMesLabels = [];
      const mesesTxt = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
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

      mayorNombre = maxSaldo >= 0 ? maxNombre : '—';
      mayorSaldo = maxSaldo;
      promInteres = (nRates > 0) ? '${(sumaRates / nRates).toStringAsFixed(0)}%' : '—';
      proximoVenc = proxVenc == null ? '—' : _fmtFecha(proxVenc!);

      clientesAlDia = alDia;
      clientesPagando = pagando;
      clientesVencidos = vencidos;

      try {
        final doc = await _docPrest!.collection('metrics').doc('summary').get();
        final data = doc.data();

        final int baseGanancia = sumIntereses;
        final int basePromedio = countPagos == 0 ? 0 : (sumPagos / countPagos).round();

        if (data != null) {
          lifetimePrestado = (data['lifetimePrestado'] ?? totalPrestado) as int;
          lifetimeRecuperado = (data['lifetimeRecuperado'] ?? totalRecuperado) as int;
          lifetimeGanancia = (data['lifetimeGanancia'] ?? baseGanancia) as int;
          lifetimePagosProm = (data['lifetimePagosProm'] ?? basePromedio) as int;
        } else {
          lifetimePrestado = totalPrestado;
          lifetimeRecuperado = totalRecuperado;
          lifetimeGanancia = baseGanancia;
          lifetimePagosProm = basePromedio;
        }
      } catch (_) {
        lifetimePrestado = totalPrestado;
        lifetimeRecuperado = totalRecuperado;
        lifetimeGanancia = sumIntereses;
        lifetimePagosProm = countPagos == 0 ? 0 : (sumPagos / countPagos).round();
      }

      histPrimerPago = firstPay == null ? '—' : _fmtFecha(firstPay!);
      histUltimoPago = lastPay == null ? '—' : _fmtFecha(lastPay!);
      histMesTop = topMesVal <= 0 ? '—' : '$topMesKey (${_rd(topMesVal)})';
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  // ===== UI
  @override
  Widget build(BuildContext context) {
    final contentTop = _logoTop + _logoH + _gapBelowLogo;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_Brand.gradTop, _Brand.gradBottom]),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: _logoTop,
                left: 0,
                right: 0,
                child: Center(child: Image.asset('assets/images/logoB.png', height: _logoH, fit: BoxFit.contain)),
              ),
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
                            if (_tab == 0)
                              (_loadingProfile ? _skeleton() : _perfilContent())
                            else
                              (_loadingStats ? _skeleton() : _statsContent()),
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
      child: Row(
        children: [
          Expanded(child: _tabChip('Perfil', _tab == 0, () => setState(() => _tab = 0))),
          const SizedBox(width: 10),
          Expanded(child: _tabChip('Estadísticas', _tab == 1, () => setState(() => _tab = 1))),
        ],
      ),
    );
  }

  Widget _tabChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: Offset(0, 4))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.inter(
              textStyle: TextStyle(color: selected ? _Brand.ink : Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
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
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
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
                  await _docPrest?.set({'settings': {'backupHabilitado': false}, 'lastBackupAt': null}, SetOptions(merge: true));
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

  // ===== ESTADÍSTICAS =====
  Widget _statsContent() {
    // Toggle Actual / Histórico
    final toggle = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E1F2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _segChip('Actual', !_historico, () => setState(() => _historico = false))),
          const SizedBox(width: 8),
          Expanded(child: _segChip('Histórico', _historico, () => setState(() => _historico = true))),
        ],
      ),
    );

    // Banner histórico
    final bannerHistorico = _historico
        ? Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE1A8)),
      ),
      child: Row(children: const [
        Text('✨  ', style: TextStyle(fontSize: 14)),
        Expanded(
          child: Text('       Vista histórica - Acumulado historico          ✨',
              style: TextStyle(fontWeight: FontWeight.w800, color: _Brand.ink)),
        ),
      ]),
    )
        : const SizedBox.shrink();

    // Top stats (cuadritos o resumen histórico)
    final statsTop = _historico
        ? EstadisticasHistoricoView(
      lifetimePrestado: lifetimePrestado,
      lifetimeRecuperado: lifetimeRecuperado,
      histPrimerPago: histPrimerPago,
      histUltimoPago: histUltimoPago,
      histMesTop: histMesTop,
      onOpenGanancias: _openGanancias,
      onOpenGananciaClientes: _openGananciaClientes,
      rd: _rd,
    )
        : EstadisticasActualView(
      totalPrestado: totalPrestado,
      totalRecuperado: totalRecuperado,
      totalPendiente: totalPendiente,
      mayorNombre: mayorNombre,
      mayorSaldo: mayorSaldo,
      promInteres: promInteres,
      proximoVenc: proximoVenc,
      rd: _rd,
    );

    // Gráficos
    final chartsCard = _card(
      child: LayoutBuilder(builder: (c, cs) {
        final leftTitle = _historico ? 'Pagos históricos por mes' : 'Pagos recibidos por mes';
        if (_historico) {
          return _chartBlock(leftTitle, _barChart(values: pagosMes, labels: pagosMesLabels));
        }
        final isWide = cs.maxWidth > 560;
        final left = _chartBlock(leftTitle, _barChart(values: pagosMes, labels: pagosMesLabels));
        final right = _chartBlock('Distribución de clientes', _donutSection());
        return isWide
            ? Row(children: [Expanded(child: left), const SizedBox(width: 12), Expanded(child: right)])
            : Column(children: [left, const SizedBox(height: 12), right]);
      }),
    );

    // Botón "Borrar histórico" (solo en Histórico) — PREMIUM abajo
    final borrarHistoricoCard = _historico
        ? Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gradTop.withOpacity(.95),
            AppTheme.gradBottom.withOpacity(.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gradTop.withOpacity(.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
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
              child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Borrar histórico',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Elimina solo los acumulados históricos. No borra clientes ni pagos.',
            style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _confirmBorrarHistorico,
              icon: const Icon(Icons.shield_moon_outlined, size: 18),
              label: const Text('Borrar histórico'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE11D48),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    )
        : const SizedBox.shrink();

    // Layout final: KPIs/top -> gráficos -> (si histórico) botón premium
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toggle,
        bannerHistorico,
        statsTop,
        const SizedBox(height: 12),
        chartsCard,
        if (_historico) ...[
          const SizedBox(height: 12),
          borrarHistoricoCard,
        ],
      ],
    );
  }

  // ===== Dona usando widget común
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
            center: Text(
              '$total',
              style: GoogleFonts.inter(textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _Brand.ink)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: const [
            LegendDot('Al día', _Brand.success),
            LegendDot('Vencidos', _Brand.softRed),
            LegendDot('Pagando', _Brand.primary),
          ],
        )
      ],
    );
  }

  // ===== key/value + switches + chips + skeleton
  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: _Brand.inkDim))),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: _Brand.ink)),
          ),
        ),
      ],
    );
  }

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

  Widget _segChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFE9F0FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFFBFD4FA) : const Color(0xFFD6E1F2), width: selected ? 1.6 : 1.2),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 6))]
              : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .2, color: selected ? _Brand.ink : _Brand.inkDim)),
        ),
      ),
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => GananciaClientesScreen(docPrest: _docPrest!)));
  }

  void _openGanancias() {
    if (_docPrest == null) {
      _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => GananciasScreen(docPrest: _docPrest!)));
  }

  // ===== Helpers de UI (estos se QUEDAN en este archivo)
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

  Widget _divider() => Container(height: 1.2, color: _Brand.divider, margin: const EdgeInsets.symmetric(vertical: 12));

  Widget _title(String t) => Text(
    t,
    style: GoogleFonts.inter(textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _Brand.ink)),
  );

  // Bloque contenedor para cada gráfico (título + contenido)
  Widget _chartBlock(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // ====== BORRAR HISTÓRICO (restaurado)
  Future<void> _confirmBorrarHistorico() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: _Brand.softRed),
            SizedBox(width: 8),
            Text('¿Borrar histórico?'),
          ],
        ),
        content: const Text(
          'Esto elimina los datos históricos acumulados (no borra clientes ni pagos). '
              'Podrás seguir generando histórico con nuevos pagos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Borrar', style: TextStyle(color: _Brand.softRed, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) await _borrarHistorico();
  }

  Future<void> _borrarHistorico() async {
    if (_docPrest == null) return;
    try {
      await _docPrest!.collection('metrics').doc('summary').delete();
    } catch (_) {
      // si no existe, ignorar
    }
    setState(() {
      lifetimePrestado = 0;
      lifetimeRecuperado = 0;
      lifetimeGanancia = 0;
      lifetimePagosProm = 0;
      histPrimerPago = '—';
      histUltimoPago = '—';
      histMesTop = '—';
    });
    _toast('Histórico borrado', color: _Brand.softRed, icon: Icons.delete_outline);
  }

  // Placeholder cuando no hay datos
  Widget _emptyChart(String t) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(t, style: const TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
    );
  }

  // Gráfico de barras simple con eje Y y guías
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
          // Eje Y con etiquetas
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
                          child: Text(
                            tickLabels[i],
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: _Brand.inkDim, height: 1),
                          ),
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
                          return Positioned(
                            left: 0,
                            right: 0,
                            top: y,
                            child: Container(height: 1, color: const Color(0xFFE6ECF5)),
                          );
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
                                  boxShadow: [
                                    BoxShadow(color: _Brand.primary.withOpacity(.18), blurRadius: 10, offset: const Offset(0, 4))
                                  ],
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
}
