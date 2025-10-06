import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // 👈 cerrar sesión / reautenticación Google
import 'home_screen.dart';

import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/app_frame.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ para abrir WhatsApp


class PerfilPrestamistaScreen extends StatefulWidget {
  const PerfilPrestamistaScreen({super.key});
  @override
  State<PerfilPrestamistaScreen> createState() => _PerfilPrestamistaScreenState();
}

class _Brand {
  // Base
  static const gradTop = Color(0xFF2458D6);
  static const gradBottom = Color(0xFF0A9A76);
  static const primary = Color(0xFF2563EB); // azul
  static const success = Color(0xFF22C55E); // verde recibo
  static const successDark = Color(0xFF16A34A);
  static const softRed = Color(0xFFE11D48); // rojo suave
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const card = Color(0xFFFFFFFF);
  static const glassAlpha = 0.12;

  // KPIs
  static const kpiGray = Color(0xFFE5E7EB);   // total prestado (fondo suave)
  static const kpiBlue = Color(0xFFDBEAFE);   // total pendiente
  static const kpiGreen = Color(0xFFDCFCE7);  // total recuperado

  // Extra acentos históricos
  static const kpiPurple = Color(0xFFEDE9FE);
  static const purple = Color(0xFF6D28D9);

  // Divisor estilo recibo
  static const divider = Color(0xFFD7E1EE);
}

class _PerfilPrestamistaScreenState extends State<PerfilPrestamistaScreen> {

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
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _Brand.ink),
        decoration: InputDecoration(
          labelText: label,  // 👈 aparece arriba
          labelStyle: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
          floatingLabelStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Icon(icon, color: _Brand.inkDim),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  // Logo
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
  bool _lockEnabled = false, _backup = false, _notif = true; // 👈 ÚNICO SWITCH
  DateTime? _lastBackup;

  // 🔴 NUEVO: listener realtime del perfil
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

  // NUEVO: métricas históricas solicitadas
  int lifetimeGanancia = 0;     // suma de pagoInteres (histórico)
  int lifetimePagosProm = 0;    // promedio de totalPagado

  String histPrimerPago = '—';
  String histUltimoPago = '—';
  String histMesTop = '—';
  bool _historico = false; // conmutador Actual/Histórico

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    _listenPerfilRealtime(); // 👈 NUEVO: actualiza inputs al vuelo si el perfil cambia
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
    _perfilSub?.cancel(); // 👈 NUEVO
    _nombreCtrl.dispose();
    _telCtrl.dispose();
    _empCtrl.dispose();
    _dirCtrl.dispose();
    super.dispose();
  }

  // ===== Util =====
  String _rd(int v) {
    if (v <= 0) return 'RD\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write('.');
        c = 0;
      }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtFecha(DateTime d) => '${_two(d.day)} ${[
    'ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'
  ][d.month-1]} ${d.year}';

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

  // ===== Perfil =====
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
      // 👇 Unificamos: si cualquiera está ON, el switch aparece ON
      _lockEnabled = (s['lockEnabled'] == true) ||
          (s['pinEnabled'] == true) ||
          (s['biometria'] == true);
      _backup = s['backupHabilitado'] == true;
      _notif = (s['notifVenc'] ?? true) as bool;

      final lb = d['lastBackupAt'];
      if (lb is Timestamp) _lastBackup = lb.toDate();
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  // 🔴 NUEVO: escuchar perfil en tiempo real para reflejar cambios al instante
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
      if (_telCtrl.text.trim()    != tel)    _telCtrl.text = tel;
      if (_empCtrl.text.trim()    != emp)    _empCtrl.text = emp;
      if (_dirCtrl.text.trim()    != dir)    _dirCtrl.text = dir;

      final s = (d['settings'] as Map?) ?? {};
      final newLock   = (s['lockEnabled'] == true) || (s['pinEnabled'] == true) || (s['biometria'] == true);
      final newBackup = s['backupHabilitado'] == true;
      final newNotif  = (s['notifVenc'] ?? true) as bool;

      bool needSetState = false;
      if (_lockEnabled != newLock)   { _lockEnabled = newLock;   needSetState = true; }
      if (_backup      != newBackup) { _backup      = newBackup; needSetState = true; }
      if (_notif       != newNotif)  { _notif       = newNotif;  needSetState = true; }

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
      'nombreCompleto': full.isEmpty ? null : full, // 👈 NUEVO
      'telefono': _telCtrl.text.trim(),
      'empresa': _empCtrl.text.trim().isEmpty ? null : _empCtrl.text.trim(),
      'direccion': _dirCtrl.text.trim().isEmpty ? null : _dirCtrl.text.trim(),
      'settings': {
        // 👇 Escribimos las tres llaves por compatibilidad total
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

  // ===== Stats =====
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

      // últimos 6 meses
      final now = DateTime.now();
      final monthsList = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
      final Map<String, int> porMes = {
        for (final m in monthsList) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0
      };

      // acumulados históricos
      int sumPagos = 0;       // totalPagado sum
      int sumIntereses = 0;   // GANANCIA (pagoInteres)
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
          // ✅ NO contar clientes sin 'proximaFecha'
          final ts = m['proximaFecha'];
          if (ts is! Timestamp) {
            // ignoramos para estados y próximo vencimiento
          } else {
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
          sumIntereses += pagoInteres; // acumulamos ganancia
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

      // preparar series por mes y mes top
      pagosMes = [];
      pagosMesLabels = [];
      const mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
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

      // === Leer resumen lifetime si existe (incluye ganancia/promedio)
      try {
        final doc = await _docPrest!.collection('metrics').doc('summary').get();
        final data = doc.data();

        // Bases por si no existe el doc
        final int baseGanancia = sumIntereses; // suma de pagoInteres
        final int basePromedio = countPagos == 0 ? 0 : (sumPagos / countPagos).round();

        if (data != null) {
          lifetimePrestado   = (data['lifetimePrestado']   ?? totalPrestado) as int;
          lifetimeRecuperado = (data['lifetimeRecuperado'] ?? totalRecuperado) as int;
          lifetimeGanancia   = (data['lifetimeGanancia']   ?? baseGanancia) as int; // histórico
          lifetimePagosProm  = (data['lifetimePagosProm']  ?? basePromedio) as int;
        } else {
          lifetimePrestado   = totalPrestado;
          lifetimeRecuperado = totalRecuperado;
          lifetimeGanancia   = baseGanancia;
          lifetimePagosProm  = basePromedio;
        }
      } catch (_) {
        lifetimePrestado   = totalPrestado;
        lifetimeRecuperado = totalRecuperado;
        lifetimeGanancia   = sumIntereses;
        lifetimePagosProm  = countPagos == 0 ? 0 : (sumPagos / countPagos).round();
      }

      // ⛔️ No sobreescribimos lifetimeGanancia ni lifetimePagosProm aquí.
      histPrimerPago = firstPay == null ? '—' : _fmtFecha(firstPay!);
      histUltimoPago = lastPay == null ? '—' : _fmtFecha(lastPay!);
      histMesTop = topMesVal <= 0 ? '—' : '$topMesKey (${_rd(topMesVal)})';
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  // ===== UI =====
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
              textStyle: TextStyle(
                color: selected ? _Brand.ink : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==== Acciones de cuenta: SALIR + ELIMINAR
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
              // 👇 Cerrar sesión real antes de navegar
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {}
              try {
                await GoogleSignIn().signOut();
              } catch (_) {}
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (r) => false,
              );
            },
            child: const Text('Salir'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(  // 👈 de Outlined a Elevated
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,          // 👈 fondo blanco
              foregroundColor: _Brand.softRed,        // 👈 texto rojo
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
              elevation: 0, // 👈 sin sombra para plano
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
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Eliminar', style: TextStyle(color: _Brand.softRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _deleteAccount();
  }

  // ========= Reautenticación Google (NECESARIA para poder borrar el usuario) =========
  Future<void> _reauthWithGoogleIfNeeded(User user) async {
    final google = GoogleSignIn();
    final current = await google.signInSilently();
    final acct = current ?? await google.signIn();
    if (acct == null) {
      throw FirebaseAuthException(code: 'aborted-by-user', message: 'Reautenticación cancelada');
    }
    final auth = await acct.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
      accessToken: auth.accessToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> _deleteAccount() async {
    if (_docPrest == null || _user == null) return;
    try {
      Future<void> _wipeCollection(CollectionReference col) async {
        final batchSize = 300;
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

      // Borrar datos del usuario en Firestore (clientes y subcolecciones)
      final clientes = await _docPrest!.collection('clientes').get();
      for (final c in clientes.docs) {
        await _wipeCollection(c.reference.collection('pagos'));
        // 🔽 Si manejas otras subcolecciones por cliente, descomenta:
        // await _wipeCollection(c.reference.collection('recibos'));
        // await _wipeCollection(c.reference.collection('tokens'));
        await c.reference.delete();
      }

      // Borrar subcolecciones del prestamista
      await _wipeCollection(_docPrest!.collection('backups'));
      await _wipeCollection(_docPrest!.collection('historial'));
      await _wipeCollection(_docPrest!.collection('metrics'));
      // 🔽 Si añadiste otras subcolecciones al doc del prestamista, descomenta:
      // await _wipeCollection(_docPrest!.collection('notificaciones'));
      // await _wipeCollection(_docPrest!.collection('tokens'));

      // Borrar documento del prestamista
      await _docPrest!.delete();

      // Reautenticar ANTES de eliminar el usuario (evita requires-recent-login)
      await _reauthWithGoogleIfNeeded(_user!);

      // Borrar usuario Auth
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
    } catch (e) {
      _toast('No se pudo eliminar. Reintenta.', color: _Brand.softRed, icon: Icons.error_outline);
    }
  }

  // ===== PERFIL =====
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
                  icon: Image.asset(
                    'assets/images/logo_whatsapp.png',
                    width: 18,
                    height: 18,
                    fit: BoxFit.contain,
                  ),
                  label: const Text(
                    'Compartir dirección del negocio',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: const BorderSide(color: _Brand.primary),
                    foregroundColor: _Brand.primary,
                    backgroundColor: Colors.white,
                  ),
                  onPressed: _compartirDireccionNegocio,
                ),
              ),
              const SizedBox(height: 12),


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
                  // 👇 Guardamos las tres llaves por compatibilidad
                  await _docPrest?.set(
                    {'settings': {'lockEnabled': v, 'pinEnabled': v, 'biometria': v}},
                    SetOptions(merge: true),
                  );
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
    // Toggle Actual / Histórico (más contraste y profundidad)
    final toggle = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF), // antes: 0xFFF2F6FD
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E1F2)), // antes: 0xFFE1E8F5
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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

    // Cálculos comunes
    final displayPrestado = _historico ? lifetimePrestado : totalPrestado;
    final displayRecuperado = _historico ? lifetimeRecuperado : totalRecuperado;
    final recRate = displayPrestado > 0 ? (displayRecuperado * 100 / displayPrestado) : 0.0;
    final recColor = recRate >= 50 ? _Brand.successDark : _Brand.softRed;

    // ===== KPIs =====

    final kpis = GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.55, // ← antes 1.7 (un poco más alto = más espacio vertical)
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: _historico
          ? [
        // ⭐️ PREMIUM TAP – GANANCIAS TOTALES
        _kpiPremiumTappable(
          onTap: _openGanancias,
          title: 'Ganancias totales',
          subtitle: 'Toca para ver',
          gradient: const [Color(0xFFDFFCEF), Color(0xFFC5F5FF)],
          accent: _Brand.success,
          centerAll: true, // 👈 Título centrado completo
          bigTitle: true,  // 👈 Más grande
          leadingIcon: Icons.trending_up_rounded,
        ),
        _kpi(
          'Recuperado histórico',
          _rd(displayRecuperado),
          bg: _Brand.kpiGreen,
          accent: _Brand.successDark,
        ),
        _kpi(
          'Prestado histórico',
          _rd(displayPrestado),
          bg: _Brand.kpiPurple,
          accent: _Brand.purple,
        ),
        // ⭐️ PREMIUM TAP – GANANCIA POR CLIENTE
        _kpiPremiumTappable(
          onTap: _openGananciaClientes,
          title: 'Ganancia por cliente',
          subtitle: 'Toca para ver',
          gradient: const [Color(0xFFE7EAFF), Color(0xFFDDEBFF)],
          accent: _Brand.primary,
          centerAll: true,  // centrado
          bigTitle: false,  // un poco menor que el anterior
          leadingIcon: Icons.people_alt_rounded,
        ),
      ]
          : [
        _kpi('Total prestado', _rd(displayPrestado), bg: _Brand.kpiGray, accent: _Brand.ink),
        _kpi('Total recuperado', _rd(displayRecuperado), bg: _Brand.kpiGreen, accent: _Brand.successDark),
        _kpi('Total pendiente', _rd(totalPendiente), bg: _Brand.kpiBlue, accent: _Brand.primary),
        _kpi(
          'Recuperación',
          displayPrestado > 0 ? '${recRate.toStringAsFixed(0)}%' : '—',
          bg: const Color(0xFFF2F6FD),
          accent: recColor,
        ),
      ],
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

    // Tarjeta inferior
    final bottomCard = _card(
      child: _historico
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv('Primer pago registrado', histPrimerPago),
          _divider(),
          _kv('Último pago registrado', histUltimoPago),
          _divider(),
          _kv('Mes con más cobros', histMesTop),
          _divider(),
          _kv('Recuperación histórica',
              displayPrestado > 0 ? '${(displayRecuperado * 100 / displayPrestado).toStringAsFixed(0)}%' : '—'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Borrar historial'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _Brand.softRed,
                side: const BorderSide(color: _Brand.softRed),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              onPressed: _confirmBorrarHistorico,
            ),
          ),
        ],
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, color: _Brand.inkDim),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mayorNombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: _Brand.ink),
                ),
              ),
              const SizedBox(width: 10),
              Text(mayorSaldo >= 0 ? _rd(mayorSaldo) : '—',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: _Brand.ink)),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Cliente con más deuda',
              style: TextStyle(color: _Brand.inkDim, fontSize: 12.5, fontWeight: FontWeight.w600)),
          _divider(),
          _kv('Promedio de interés cobrado', promInteres),
          _divider(),
          _kv('Próximo vencimiento', proximoVenc),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toggle,
        bannerHistorico,
        kpis,
        const SizedBox(height: 12),
        chartsCard,
        const SizedBox(height: 12),
        bottomCard,
      ],
    );
  }

  // ===== PREMIUM KPI (tappable) =====
  Widget _kpiPremiumTappable({
    required VoidCallback onTap,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required Color accent,
    bool centerAll = true,
    bool bigTitle = false,
    IconData? leadingIcon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12), // ← antes 16
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 16, offset: const Offset(0, 6)),
            BoxShadow(color: accent.withOpacity(.20), blurRadius: 24, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          // ← Auto-escala todo el contenido si el alto es justo (evita overflow)
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: centerAll ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null)
                  Icon(leadingIcon, size: 18, color: accent.withOpacity(.95)), // ← 20 → 18
                if (leadingIcon != null) const SizedBox(height: 4),
                Text(
                  title,
                  textAlign: centerAll ? TextAlign.center : TextAlign.start,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    textStyle: TextStyle(
                      color: _Brand.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: bigTitle ? 17.5 : 16, // ← un toque más pequeño
                      letterSpacing: .2,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // ← 6 → 4
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(.35)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app_rounded, size: 14, color: _Brand.inkDim), // ← 16 → 14
                      const SizedBox(width: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: accent,
                          fontSize: 12.5, // ← 13.5 → 12.5
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


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

  // ===== bloques comunes / estilo =====
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

  Widget _kpi(String title, String value, {required Color bg, required Color accent}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(textStyle: const TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700, fontSize: 14))),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.inter(
                textStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartBlock(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.inter(textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _emptyChart(String t) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Text(t, style: const TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
    );
  }

  // ===== Bar chart con eje Y y guías =====
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
          // eje Y
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

          // área barras
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
                            left: 0, right: 0, top: y,
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

  // ===== Dona =====
  Widget _donutSection() {
    final total = clientesAlDia + clientesPagando + clientesVencidos;
    if (total == 0) return _emptyChart('Sin datos aún');
    return Column(
      children: [
        SizedBox(
          height: 170,
          child: CustomPaint(
            painter: _DonutPainter([
              _Slice(color: _Brand.success, value: clientesAlDia),
              _Slice(color: _Brand.softRed, value: clientesVencidos),
              _Slice(color: _Brand.primary, value: clientesPagando),
            ]),
            child: Center(
              child: Text(
                '$total',
                style: GoogleFonts.inter(textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _Brand.ink)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: const [
            _LegendDot('Al día', _Brand.success),
            _LegendDot('Vencidos', _Brand.softRed),
            _LegendDot('Pagando', _Brand.primary),
          ],
        )
      ],
    );
  }

  // ===== key/value + switches =====
  Widget _kv(String k, String v) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: _Brand.inkDim))),
        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(v, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900, color: _Brand.ink)),
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
          color: selected ? Colors.white : const Color(0xFFE9F0FF), // fondo más visible al inactivo
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFBFD4FA) : const Color(0xFFD6E1F2),
            width: selected ? 1.6 : 1.2,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
              color: selected ? _Brand.ink : _Brand.inkDim,
            ),
          ),
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

  // ======= Navegación a pantallas =======
  void _openGananciaClientes() {
    if (_docPrest == null) {
      _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GananciaClientesScreen(docPrest: _docPrest!),
      ),
    );
  }

  void _openGanancias() {
    if (_docPrest == null) {
      _toast('No hay usuario autenticado', color: _Brand.softRed, icon: Icons.error_outline);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GananciasScreen(docPrest: _docPrest!),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: _Brand.inkDim)),
    ]);
  }
}

class _Slice {
  final Color color;
  final int value;
  const _Slice({required this.color, required this.value});
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  _DonutPainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (p, s) => p + s.value);
    if (total == 0) return;
    final center = (Offset.zero & size).center;
    final radius = size.shortestSide * 0.42;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round;

    double start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi;
      paint.color = s.color;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += sweep;
    }
    final inner = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius - 18, inner);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.slices != slices;
}

// ===================== NUEVA PANTALLA (en el mismo archivo): Ganancia por cliente =====================
class GananciaClientesScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const GananciaClientesScreen({super.key, required this.docPrest});

  @override
  State<GananciaClientesScreen> createState() => _GananciaClientesScreenState();
}

class _GananciaClientesScreenState extends State<GananciaClientesScreen> {
  late Future<List<_ClienteGanancia>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarGanancias();
  }

  Future<List<_ClienteGanancia>> _cargarGanancias() async {
    final cs = await widget.docPrest.collection('clientes').get();

    final List<_ClienteGanancia> rows = [];
    for (final c in cs.docs) {
      final data = c.data();

      final int saldo = (data['saldoActual'] ?? 0) as int;
      if (saldo <= 0) continue;

      final int capitalInicial = (data['capitalInicial'] ?? 0) as int;
      final String producto = (data['producto'] ?? '').toString().trim();

      final pagos = await c.reference.collection('pagos').get();
      int ganancia = 0;
      int totalPagos = 0;
      int pagadoCapital = 0;

      for (final p in pagos.docs) {
        final m = p.data();
        ganancia += (m['pagoInteres'] ?? 0) as int;
        totalPagos += (m['totalPagado'] ?? 0) as int;
        pagadoCapital += (m['pagoCapital'] ?? 0) as int;
      }

      if (ganancia == 0 && producto.isNotEmpty) {
        ganancia = capitalInicial;
      }

      final int totalHistorico = saldo + pagadoCapital;

      final nombre = '${(data['nombre'] ?? '').toString().trim()} ${(data['apellido'] ?? '').toString().trim()}'.trim();
      final display = nombre.isEmpty ? (data['telefono'] ?? 'Cliente') : nombre;

      rows.add(_ClienteGanancia(
        id: c.id,
        nombre: display,
        ganancia: ganancia,
        saldo: saldo,
        totalPagado: totalPagos,
        capitalInicial: totalHistorico,
      ));
    }

    rows.sort((a, b) => b.ganancia.compareTo(a.ganancia));
    return rows;
  }

  String _rd(int v) {
    if (v <= 0) return 'RD\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write('.');
        c = 0;
      }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: _HeaderBar(title: 'Ganancia por cliente'),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: FutureBuilder<List<_ClienteGanancia>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return _loading();
                }
                final list = snap.data ?? const <_ClienteGanancia>[];
                if (list.isEmpty) {
                  return _empty();
                }
                final total = list.fold<int>(0, (p, e) => p + e.ganancia);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _resumen(total, list.length),
                    const SizedBox(height: 12),
                    Expanded(child: _lista(list)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumen(int total, int n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFE1E8F5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ganancia total (activos)', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                _rd(total),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.gradBottom,
                ),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E8F5)),
            ),
            child: Text(
              '$n clientes',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.gradTop),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<_ClienteGanancia> list) {
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final it = list[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.96),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8EEF8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, size: 18, color: Color(0xFF0F172A)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            it.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: _Colors.ink,
                                height: 2,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    _textoMonto('Total histórico:', _rd(it.capitalInicial), AppTheme.gradTop),
                    const SizedBox(height: 6),
                    _textoMonto('Pendiente:', _rd(it.saldo), it.saldo > 0 ? Colors.red : Colors.green),
                    const SizedBox(height: 6),
                    _textoMonto('Pagado:', _rd(it.totalPagado), const Color(0xFF2F9655)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Ganancia', style: TextStyle(fontSize: 16, color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                  Text(
                    _rd(it.ganancia),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.gradBottom,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _textoMonto(String label, String valor, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
        children: [
          TextSpan(text: '$label '),
          TextSpan(text: valor, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _loading() => const Center(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        SizedBox(width: 10),
        Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Widget _empty() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.96),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EEF8)),
    ),
    child: const Center(
      child: Text('No hay clientes activos con ganancias',
          style: TextStyle(fontWeight: FontWeight.w800, color: _Colors.inkDim)),
    ),
  );
}

// ===================== NUEVA PANTALLA (en el mismo archivo): Ganancias (total histórico) =====================
class GananciasScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const GananciasScreen({super.key, required this.docPrest});

  @override
  State<GananciasScreen> createState() => _GananciasScreenState();
}

class _GananciasScreenState extends State<GananciasScreen> {
  late Future<_GananciasResumen> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarGananciasGlobal();
  }

  // ✅ Lee la ganancia histórica persistente desde metrics/summary
  Future<_GananciasResumen> _cargarGananciasGlobal() async {
    final doc = await widget.docPrest.collection('metrics').doc('summary').get();
    final data = doc.data() ?? const <String, dynamic>{};

    final int lifetimeGanancia = (data['lifetimeGanancia'] ?? 0) as int;

    return _GananciasResumen(
      clientesActivos: 0,
      gananciaActiva: lifetimeGanancia,
      pagosContados: 0,
    );
  }

  String _rd(int v) {
    if (v <= 0) return 'RD\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write('.');
        c = 0;
      }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _fmtFecha(DateTime d) => '${_two(d.day)} ${[
    'ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'
  ][d.month - 1]} ${d.year}';

  Future<void> _refresh() async {
    setState(() {
      _future = _cargarGananciasGlobal();
    });
  }

  // ====== PREMIUM: abrir pantalla tras anuncio recompensado ======
  Future<void> _openPremium() async {
    // TODO: integrar anuncio recompensado real aquí (google_mobile_ads).
    // final ok = await Ads.showRewarded();
    // if (!ok) return;

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumBoostsScreen(docPrest: widget.docPrest),
      ),
    );
  }

  // Tarjeta Premium (versión pro: sin overflow, ocupando más espacio, diseño limpio y elegante)
  Widget _premiumCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.gradTop.withOpacity(0.98),
            AppTheme.gradBottom.withOpacity(0.98),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.gradTop.withOpacity(.28),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 🏅 Ícono premium arriba izquierda
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(.15),
                  border: Border.all(color: Colors.white.withOpacity(.45), width: 1.3),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Potenciador Premium',
                  style: GoogleFonts.inter(
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 📌 Contenido vertical elegante
          _bullet('QEDU del día'),
          const SizedBox(height: 10),
          _bullet('Estadística avanzada'),
          const SizedBox(height:10),
          _bullet('Consejo pro'),
          const SizedBox(height: 16),

          Text(
            'Contenido exclusivo que rota automáticamente cada día para maximizar tus ganancias.',
            style: TextStyle(
              color: Colors.white.withOpacity(.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 15),

          // 🎯 Botón Ver abajo derecha
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _openPremium,
              icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
              label: const Text('Ver ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.gradTop,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

// ✅ Helper para bullets estilizados
  Widget _bullet(String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16.5,
              letterSpacing: .1,
            ),
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const _HeaderBar(title: 'Ganancias totales'),
          child: FutureBuilder<_GananciasResumen>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                      SizedBox(width: 10),
                      Text('Cargando…', style: TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }
              final res = snap.data ?? _GananciasResumen.empty();

              final String serial = widget.docPrest.id.toUpperCase().padRight(6, '0').substring(0, 6);
              final String fecha = _fmtFecha(DateTime.now());

              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  children: [
                    // ======== TARJETA DE GANANCIAS HISTÓRICAS ========
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.96),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE1E8F5), width: 1.2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 16, offset: const Offset(0, 8)),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: LinearGradient(colors: [AppTheme.gradTop, AppTheme.gradBottom]),
                                ),
                                child: const Text(
                                  'DATOS VERIFICADOS',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .6),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(colors: [AppTheme.gradBottom, AppTheme.gradTop]),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.gradTop.withOpacity(.25), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 22),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ✅ Título
                          Text(
                            'Ganancias totales históricas',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _Brand.inkDim,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Monto histórico
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.trending_up_rounded, color: AppTheme.gradBottom.withOpacity(.95), size: 28),
                                const SizedBox(width: 8),
                                Text(
                                  _rd(res.gananciaActiva),
                                  style: GoogleFonts.inter(
                                    textStyle: TextStyle(
                                      fontSize: 44,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      letterSpacing: 0.2,
                                      color: AppTheme.gradBottom,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          Container(
                            height: 1.2,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFEAF0FA), Color(0xFFDDE6F6), Color(0xFFEAF0FA)],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(child: _metaChip(label: 'SERIAL', value: '#$serial')),
                              const SizedBox(width: 10),
                              Expanded(child: _metaChip(label: 'FECHA', value: fecha)),
                            ],
                          ),
                          const SizedBox(height: 10),


                        ],
                      ),
                    ),

                    // ======== TARJETA PREMIUM (atractiva) ========
                    _premiumCard(),

                    const SizedBox(height: 16),

                    // ======== BOTÓN: Ver ganancia por cliente (AL FINAL) ========
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GananciaClientesScreen(docPrest: widget.docPrest),
                            ),
                          );
                        },
                        icon: const Icon(Icons.people_alt_rounded),
                        label: const Text(
                          'Ver ganancia por cliente',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gradTop,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _metaChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EEF8)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _Brand.ink, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}

// Pill para chips de la tarjeta premium
class _ChipPill extends StatelessWidget {
  final String text;
  const _ChipPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12.5,
          letterSpacing: .2,
        ),
      ),
    );
  }
}


// ===================== NUEVA PANTALLA: Premium Boosts =====================
class PremiumBoostsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const PremiumBoostsScreen({super.key, required this.docPrest});

  @override
  State<PremiumBoostsScreen> createState() => _PremiumBoostsScreenState();
}

class _PremiumBoostsScreenState extends State<PremiumBoostsScreen> {
  // Contenido local (fallback) con rotación diaria
  static const List<String> _qedu = [
    'Sube el interés solo a clientes puntuales (riesgo bajo).',
    'Reinviértelos pagos de interés en nuevos préstamos pequeños.',
    'Ofrece descuento por pago adelantado para acelerar recuperaciones.',
    'Automatiza recordatorios 72/24/6 horas antes del vencimiento.',
    'Segmenta por riesgo y asigna tasas por perfil, no por persona.',
  ];
  static const List<String> _finance = [
    'Nunca prestes más del 10% de tu capital a un solo cliente.',
    'Lleva un colchón de liquidez del 15% para imprevistos.',
    'Prioriza recuperar capital antes que maximizar interés.',
    'Evita renovaciones automáticas con clientes atrasados.',
    'Registra cada pago el mismo día. Disciplina = datos precisos.',
  ];

  // 🔥 NUEVO: contenido del día desde Firestore
  _PotContent? _qeduDoc;
  _PotContent? _financeDoc;
  _PotContent? _statsDoc;

  int _qIndex = 0, _fIndex = 0;
  bool _loading = true;

  // Serie para mini-chart (últimos 6 meses)
  List<int> _vals = [];
  List<String> _labs = [];

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _rotateDailyIndices();
    await _loadMiniStats();
    await _loadPotenciadorFromFirestore(); // 👈 carga QEDU / Estadística / Consejo desde Firestore
    if (mounted) setState(() => _loading = false);
  }

  // ================= Firestore: potenciador_contenido =================
  String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á','a')
      .replaceAll('é','e')
      .replaceAll('í','i')
      .replaceAll('ó','o')
      .replaceAll('ú','u');

  Future<_PotContent?> _pickByTypeFromQuery(QuerySnapshot<Map<String, dynamic>> qs, String wanted) async {
    final w = _norm(wanted);
    for (final d in qs.docs) {
      final tipo = _norm((d['tipo'] ?? '').toString());
      if (tipo == w) {
        return _PotContent(
          tipo: (d['tipo'] ?? '').toString(),
          titulo: (d['titulo'] ?? '').toString(),
          contenido: (d['contenido'] ?? '').toString(),
        );
      }
    }
    return null;
  }

  Future<_PotContent?> _getDocForToday(String tipo) async {
    final base = FirebaseFirestore.instance
        .collection('config')
        .doc('(default)')
        .collection('potenciador_contenido');

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    // del día
    try {
      final day = await base
          .where('activo', isEqualTo: true)
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('fecha', isLessThan: Timestamp.fromDate(end))
          .orderBy('fecha')
          .get();
      final hit = await _pickByTypeFromQuery(day, tipo);
      if (hit != null) return hit;
    } catch (_) {
      // si falta índice, seguimos al fallback
    }

    // último activo
    try {
      final last = await base
          .where('activo', isEqualTo: true)
          .orderBy('fecha', descending: true)
          .limit(12)
          .get();
      return await _pickByTypeFromQuery(last, tipo);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadPotenciadorFromFirestore() async {
    final q = await _getDocForToday('qedu');
    final e = await _getDocForToday('estadistica'); // admite "estadística/estadistico"
    final c = await _getDocForToday('consejo');

    _qeduDoc = q;
    _statsDoc = e;
    _financeDoc = c;
  }
  // ===============================================================

  // Rota 1 tip por día y persiste en Firestore (para fallback local)
  Future<void> _rotateDailyIndices() async {
    final dailyRef = widget.docPrest.collection('metrics').doc('daily');
    final snap = await dailyRef.get();
    final data = snap.data() ?? {};
    final last = (data['lastDate'] ?? '') as String;
    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    int q = (data['qeduIndex'] ?? 0) as int;
    int f = (data['financeIndex'] ?? 0) as int;

    if (last != todayKey) {
      q = (q + 1) % _qedu.length;
      f = (f + 1) % _finance.length;
      await dailyRef.set({'qeduIndex': q, 'financeIndex': f, 'lastDate': todayKey}, SetOptions(merge: true));
    }

    _qIndex = q;
    _fIndex = f;
  }

  // Mini estadística: suma de pagos por mes (últimos 6 meses)
  Future<void> _loadMiniStats() async {
    final mesesTxt = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - (5 - i), 1));
    final Map<String, int> porMes = {
      for (final m in months) '${m.year}-${m.month.toString().padLeft(2, '0')}': 0
    };

    final cs = await widget.docPrest.collection('clientes').get();
    for (final c in cs.docs) {
      final pagos = await c.reference.collection('pagos').get();
      for (final p in pagos.docs) {
        final mp = p.data();
        final ts = mp['fecha'];
        final total = (mp['totalPagado'] ?? 0) as int;
        if (ts is Timestamp) {
          final d = ts.toDate();
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
          if (porMes.containsKey(key)) porMes[key] = (porMes[key] ?? 0) + total;
        }
      }
    }

    _vals = [];
    _labs = [];
    for (final m in months) {
      _labs.add(mesesTxt[m.month - 1]);
      _vals.add(porMes['${m.year}-${m.month.toString().padLeft(2, '0')}'] ?? 0);
    }
  }

  String _rd(int v) {
    if (v <= 0) return 'RD\$0';
    final s = v.toString();
    final b = StringBuffer();
    int c = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      b.write(s[i]);
      c++;
      if (c == 3 && i != 0) {
        b.write('.');
        c = 0;
      }
    }
    return 'RD\$${b.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: AppFrame(
          header: const _HeaderBar(title: 'Potenciadores Pro'),
          child: _loading
              ? const Center(
            child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
          )
              : ListView(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              _proBadge(),
              const SizedBox(height: 12),
              _cardQEDU(),
              const SizedBox(height: 12),
              _cardChart(),
              const SizedBox(height: 12),
              _cardFinance(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [AppTheme.gradTop.withOpacity(.95), AppTheme.gradBottom.withOpacity(.95)]),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.white),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Contenido premium desbloqueado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('PRO', style: TextStyle(color: AppTheme.gradTop, fontWeight: FontWeight.w900)),
          )
        ],
      ),
    );
  }

  Widget _cardQEDU() {
    final titulo = (_qeduDoc?.titulo?.trim().isNotEmpty ?? false) ? _qeduDoc!.titulo : 'QEDU del día';
    final text = (_qeduDoc?.contenido?.trim().isNotEmpty ?? false) ? _qeduDoc!.contenido : _qedu[_qIndex];
    return _glassCard(
      leading: Icons.bolt_rounded,
      title: titulo,
      subtitle: 'Cómo mejorar tu rendimiento',
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: _Brand.ink)),
      footer: const Text('Se actualiza cada día', style: TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
    );
  }

  Widget _cardFinance() {
    final titulo = (_financeDoc?.titulo?.trim().isNotEmpty ?? false) ? _financeDoc!.titulo : 'Consejo financiero';
    final text = (_financeDoc?.contenido?.trim().isNotEmpty ?? false) ? _financeDoc!.contenido : _finance[_fIndex];
    return _glassCard(
      leading: Icons.account_balance_wallet_rounded,
      title: titulo,
      subtitle: 'Gestión de riesgo y capital',
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: _Brand.ink)),
      footer: const Text('Nuevo consejo cada día', style: TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
    );
  }

  Widget _cardChart() {
    final int total = _vals.fold(0, (p, v) => p + v);
    return _glassCard(
      leading: Icons.insights_rounded,
      title: _statsDoc?.titulo?.trim().isNotEmpty == true ? _statsDoc!.titulo : 'Estadística avanzada',
      subtitle: 'Pagos últimos 6 meses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_statsDoc?.contenido?.trim().isNotEmpty == true) ...[
            Text(_statsDoc!.contenido, style: const TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          _miniBar(values: _vals, labels: _labs),
          const SizedBox(height: 8),
          Text('Total recibido: ${_rd(total)}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: _Brand.ink)),
        ],
      ),
      footer: const Text('Tendencia mensual agregada', style: TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
    );
  }

  // ---- helpers UI ----
  Widget _glassCard({
    required IconData leading,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE1E8F5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF2F6FD),
                border: Border.all(color: const Color(0xFFE1E8F5)),
              ),
              child: Icon(leading, color: AppTheme.gradTop),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _Brand.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w700, color: _Brand.inkDim)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          child,
          if (footer != null) ...[
            const SizedBox(height: 8),
            footer,
          ],
        ],
      ),
    );
  }

  // Mini bar chart simple
  Widget _miniBar({required List<int> values, required List<String> labels}) {
    if (values.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE9EEF5)),
        ),
        child: const Text('Sin datos', style: TextStyle(color: _Brand.inkDim, fontWeight: FontWeight.w700)),
      );
    }

    const double h = 160;
    final maxV = values.reduce((a,b)=>a>b?a:b).toDouble().clamp(1.0, 999999.0);
    return SizedBox(
      height: h,
      child: LayoutBuilder(builder: (c, cs) {
        final barW = (cs.maxWidth / (values.length * 2)).clamp(16, 26);
        return Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(values.length, (i) {
                    final bh = (values[i] / maxV) * (h - 40);
                    return Container(
                      width: barW.toDouble(),
                      height: bh,
                      decoration: BoxDecoration(
                        color: AppTheme.gradTop,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: AppTheme.gradTop.withOpacity(.18), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(labels.length, (i) =>
                  SizedBox(width: barW.toDouble()+8, child: Text(labels[i], textAlign: TextAlign.center, style: const TextStyle(color: _Brand.inkDim)))),
            ),
          ],
        );
      }),
    );
  }
}


class _HistRow {
  final String cliente;
  final int interes;
  final DateTime fecha;
  const _HistRow({required this.cliente, required this.interes, required this.fecha});
}


class _GananciasResumen {
  final int clientesActivos;
  final int gananciaActiva;
  final int pagosContados;

  const _GananciasResumen({
    required this.clientesActivos,
    required this.gananciaActiva,
    required this.pagosContados,
  });

  factory _GananciasResumen.empty() => const _GananciasResumen(
    clientesActivos: 0,
    gananciaActiva: 0,
    pagosContados: 0,
  );
}

class _ClienteGanancia {
  final String id;
  final String nombre;
  final int ganancia;
  final int saldo;
  final int totalPagado;
  final int capitalInicial;

  _ClienteGanancia({
    required this.id,
    required this.nombre,
    required this.ganancia,
    required this.saldo,
    required this.totalPagado,
    required this.capitalInicial,
  });
}

class _PotContent {
  final String tipo;
  final String titulo;
  final String contenido;
  const _PotContent({required this.tipo, required this.titulo, required this.contenido});
}

class _HeaderBar extends StatelessWidget {
  final String title;
  const _HeaderBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(AppTheme.gradTop.withOpacity(.9)),
            shape: MaterialStateProperty.all(const CircleBorder()),
            padding: MaterialStateProperty.all(const EdgeInsets.all(8)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _Colors {
  static const ink = Color(0xFF111827);
  static const inkDim = Color(0xFF6B7280);
}
