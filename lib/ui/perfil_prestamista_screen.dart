import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

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
  // Logo
  static const double _logoTop = -48;
  static const double _logoH = 340;
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
  bool _pin = false, _bio = false, _backup = false, _notif = true;
  DateTime? _lastBackup;

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
  int lifetimeGanancia = 0;     // suma de pagoInteres
  int lifetimePagosProm = 0;    // promedio de totalPagado

  String histPrimerPago = '—';
  String histUltimoPago = '—';
  String histMesTop = '—';
  bool _historico = false; // conmutador Actual/Histórico

  @override
  void initState() {
    super.initState();
    _cargarTodo();
  }

  Future<void> _cargarTodo() async {
    await Future.wait([_loadProfile(), _loadStats()]);
  }

  @override
  void dispose() {
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
      _pin = s['pinEnabled'] == true;
      _bio = s['biometria'] == true;
      _backup = s['backupHabilitado'] == true;
      _notif = (s['notifVenc'] ?? true) as bool;

      final lb = d['lastBackupAt'];
      if (lb is Timestamp) _lastBackup = lb.toDate();
    } finally {
      if (mounted) setState(() => _loadingProfile = false);
    }
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
      'telefono': _telCtrl.text.trim(),
      'empresa': _empCtrl.text.trim().isEmpty ? null : _empCtrl.text.trim(),
      'direccion': _dirCtrl.text.trim().isEmpty ? null : _dirCtrl.text.trim(),
      'settings': {
        'pinEnabled': _pin,
        'biometria': _bio,
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
          DateTime f = hoyOnly;
          final ts = m['proximaFecha'];
          if (ts is Timestamp) {
            final td = ts.toDate();
            f = DateTime(td.year, td.month, td.day);
          }
          final diff = f.difference(hoyOnly).inDays;
          if (diff < 0) vencidos++;
          else if (diff <= 2) pagando++;
          else alDia++;

          if (!f.isBefore(hoyOnly)) {
            if (proxVenc == null || f.isBefore(proxVenc)) proxVenc = f;
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
          lifetimeGanancia   = (data['lifetimeGanancia']   ?? baseGanancia) as int; // NUEVO
          lifetimePagosProm  = (data['lifetimePagosProm']  ?? basePromedio) as int; // NUEVO
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

      // completar históricos calculados en runtime (según tu app actual)
      lifetimeGanancia = sumIntereses; // GANANCIA = intereses cobrados
      lifetimePagosProm = countPagos == 0 ? 0 : (sumPagos / countPagos).round();
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
            onPressed: () {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
            },
            child: const Text('Salir'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(  // 👈 cámbialo de OutlinedButton a ElevatedButton
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,          // 👈 fondo blanco
              foregroundColor: _Brand.softRed,        // 👈 texto rojo
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
              elevation: 0, // 👈 sin sombra para que parezca plano
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
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: _Brand.softRed))),
        ],
      ),
    );
    if (ok != true) return;
    await _deleteAccount();
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

      final clientes = await _docPrest!.collection('clientes').get();
      for (final c in clientes.docs) {
        await _wipeCollection(c.reference.collection('pagos'));
        await c.reference.delete();
      }

      await _wipeCollection(_docPrest!.collection('backups'));
      await _wipeCollection(_docPrest!.collection('historial'));
      await _wipeCollection(_docPrest!.collection('metrics'));

      await _docPrest!.delete();
      await _user!.delete();

      _toast('Cuenta eliminada', color: _Brand.softRed, icon: Icons.delete_forever);
      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
      }
    } catch (e) {
      _toast('No se pudo eliminar. Vuelve a iniciar sesión y reintenta.', color: _Brand.softRed, icon: Icons.error_outline);
    }
  }

  // ===== PERFIL =====
  Widget _perfilContent() {
    return Column(
      children: [
        _card(
          child: Column(
            children: [
              _input('Nombre completo (Nombre y Apellido)', _nombreCtrl),
              const SizedBox(height: 12),
              _input('Teléfono (obligatorio)', _telCtrl, keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _input('Empresa (opcional)', _empCtrl),
              const SizedBox(height: 12),
              _input('Dirección (opcional)', _dirCtrl),
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
                title: 'Bloquear con PIN',
                value: _pin,
                onChanged: (v) async {
                  _pin = v;
                  await _docPrest?.set({'settings': {'pinEnabled': v}}, SetOptions(merge: true));
                  if (mounted) setState(() {});
                  _toast(v ? 'PIN activado ✅' : 'PIN desactivado');
                },
              ),
              _divider(),
              _switchRow(
                title: 'Usar huella / biometría',
                value: _bio,
                onChanged: (v) async {
                  _bio = v;
                  await _docPrest?.set({'settings': {'biometria': v}}, SetOptions(merge: true));
                  if (mounted) setState(() {});
                  _toast(v ? 'Biometría activada ✅' : 'Biometría desactivada');
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
        color: const Color(0xFFF2F6FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E8F5)),
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
        Text('✨  ', style: TextStyle(fontSize: 16)),
        Expanded(
          child: Text('Vista histórica · Acumulado de por vida',
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

    // KPIs
    final kpis = GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 1.7,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: _historico
          ? [
        _kpi('Prestado histórico', _rd(displayPrestado), bg: _Brand.kpiPurple, accent: _Brand.purple),
        _kpi('Recuperado histórico', _rd(displayRecuperado), bg: _Brand.kpiGreen, accent: _Brand.successDark),
        _kpi('Ganancia', _rd(lifetimeGanancia), bg: _Brand.kpiGray, accent: _Brand.ink),
        _kpi('Pagos promedio', _rd(lifetimePagosProm), bg: const Color(0xFFF2F6FD), accent: _Brand.primary),
      ]
          : [
        _kpi('Total prestado', _rd(displayPrestado), bg: _Brand.kpiGray, accent: _Brand.ink),
        _kpi('Total recuperado', _rd(displayRecuperado), bg: _Brand.kpiGreen, accent: _Brand.successDark),
        _kpi('Total pendiente', _rd(totalPendiente), bg: _Brand.kpiBlue, accent: _Brand.primary),
        _kpi('Recuperación', displayPrestado > 0 ? '${recRate.toStringAsFixed(0)}%' : '—',
            bg: const Color(0xFFF2F6FD), accent: recColor),
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
    // reset de los mostrados en pantalla
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

  Widget _input(String label, TextEditingController c, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

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
                                  boxShadow: [BoxShadow(color: _Brand.primary.withOpacity(.18), blurRadius: 10, offset: Offset(0, 4))],
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
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