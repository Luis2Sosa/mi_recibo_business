import 'package:flutter/material.dart';
import 'cliente_detalle_screen.dart';
import 'perfil_prestamista_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'agregar_cliente_screen.dart';

// 🔥 Firestore + Auth
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  // Vencimientos
  bool _resaltarVencimientos = true;

  // Bienvenida y back doble
  bool _bienvenidaMostrada = false;
  DateTime? _lastBackTime;

  // ===== Datos del prestamista para el recibo =====
  String _empresa = '';
  String _servidor = '';
  String _telefonoServidor = '';

  // ===== Filtro por chips =====
  FiltroClientes _filtro = FiltroClientes.todos;

  @override
  void initState() {
    super.initState();
    _cargarPerfilPrestamista();
  }

  // 👇 AHORA lee prestamistas/ID-1 (documento fijo que creaste en Firestore)
  Future<void> _cargarPerfilPrestamista() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc('ID-1')
          .get();

      final data = doc.data() ?? {};
      final nombre = (data['nombre'] ?? '').toString().trim();
      final apellido = (data['apellido'] ?? '').toString().trim();

      setState(() {
        _empresa = (data['empresa'] ?? '').toString().trim();
        _servidor =
            [nombre, apellido].where((s) => s.isNotEmpty).join(' ').trim();
        _telefonoServidor = (data['telefono'] ?? '').toString().trim();
      });
    } catch (_) {
      // si falla, simplemente quedan strings vacíos
    }
  }

  // ---- Banner bonito (2s) ----
  void _showBanner(String texto,
      {Color color = const Color(0xFF11A7A0),
        IconData icon = Icons.check_circle}) {
    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style:
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(snack);
  }

  // Back doble
  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackTime == null ||
        now.difference(_lastBackTime!) > const Duration(seconds: 2)) {
      _lastBackTime = now;
      _showBanner('Presiona atrás otra vez para salir',
          color: const Color(0xFF2563EB), icon: Icons.info);
      return false;
    }
    return true;
  }

  int _diasHasta(DateTime d) {
    final hoy = DateTime.now();
    final a = DateTime(hoy.year, hoy.month, hoy.day);
    final b = DateTime(d.year, d.month, d.day);
    return b.difference(a).inDays;
  }

  _EstadoVenc _estadoDe(_Cliente c) {
    final d = _diasHasta(c.proximaFecha);
    if (d < 0) return _EstadoVenc.vencido;
    if (d == 0) return _EstadoVenc.hoy;
    if (d <= 2) return _EstadoVenc.pronto;
    return _EstadoVenc.alDia;
  }

  bool _esSaldado(_Cliente c) => c.saldoActual <= 0;

  // Orden: primero NO saldados; luego saldados. Dentro: por proximaFecha; si empatan, por nombre.
  int _compareClientes(_Cliente a, _Cliente b) {
    final sa = _esSaldado(a);
    final sb = _esSaldado(b);
    if (sa != sb) return sa ? 1 : -1; // saldados al final
    final fa = a.proximaFecha;
    final fb = b.proximaFecha;
    if (fa != fb) return fa.compareTo(fb);
    return a.nombreCompleto.compareTo(b.nombreCompleto);
  }

  // ---------- Acciones ----------
  void _abrirEditarCliente(_Cliente c) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarClienteScreen(
          id: c.id,
          initNombre: c.nombre,
          initApellido: c.apellido,
          initTelefono: c.telefono,
          initDireccion: c.direccion,
          initProducto: c.producto,
          initCapital: c.capitalInicial,
          initTasa: c.tasaInteres,
          initPeriodo: c.periodo,
          initProximaFecha: c.proximaFecha,
        ),
      ),
    );

    if (result == null || result is! Map) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 👇 NUEVO: usamos el capital que vino del form para decidir estado/saldo
    final int nuevoCapital = result['capital'] as int? ?? c.capitalInicial;
    final DateTime nuevaProx =
        result['proximaFecha'] as DateTime? ?? c.proximaFecha;

    // Campos base (siempre)
    final Map<String, dynamic> update = {
      'nombre': (result['nombre'] as String).trim(),
      'apellido': (result['apellido'] as String).trim(),
      'telefono': (result['telefono'] as String).trim(),
      'direccion': ((result['direccion'] as String?)?.trim().isEmpty ?? true)
          ? null
          : (result['direccion'] as String).trim(),
      'producto': ((result['producto'] as String?)?.trim().isEmpty ?? true)
          ? null
          : (result['producto'] as String).trim(),
      'capitalInicial': nuevoCapital,
      'tasaInteres': result['tasa'] as double? ?? c.tasaInteres,
      'periodo': result['periodo'] as String? ?? c.periodo,
      'proximaFecha': Timestamp.fromDate(nuevaProx),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 👇 Si hay nuevo préstamo (>0), el cliente vuelve a "al día".
    //    Si capital = 0, queda saldado.
    if (nuevoCapital > 0) {
      update.addAll({
        'saldoActual': nuevoCapital,
        'saldado': false,
        'estado': 'al_dia',
      });
    } else {
      update.addAll({
        'saldoActual': 0,
        'saldado': true,
        'estado': 'saldado',
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection('prestamistas')
          .doc(uid)
          .collection('clientes')
          .doc(result['id'] ?? c.id)
          .set(update, SetOptions(merge: true));

      _showBanner('Cliente actualizado ✅');
    } catch (e) {
      _showBanner('Error al actualizar: $e',
          color: const Color(0xFFE11D48), icon: Icons.error);
    }
  }

  String _codigoDesdeId(String docId) {
    final base = docId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final cut = base.length >= 6 ? base.substring(0, 6) : base.padRight(6, '0');
    return 'CL-${cut.toUpperCase()}';
  }

  Future<void> _abrirAgregarCliente() async {
    final res = await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AgregarClienteScreen()));
    if (res is Map) {
      _showBanner('Cliente agregado correctamente ✅');
    }
  }

  void _confirmarEliminar(_Cliente c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Seguro que deseas eliminar a ${c.nombreCompleto}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final scaffoldCtx = context;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              try {
                await FirebaseFirestore.instance
                    .collection('prestamistas')
                    .doc(uid)
                    .collection('clientes')
                    .doc(c.id)
                    .delete();
                Navigator.pop(scaffoldCtx);
                if (mounted) {
                  _showBanner('Cliente eliminado',
                      color: const Color(0xFFE11D48), icon: Icons.delete);
                }
              } catch (e) {
                Navigator.pop(scaffoldCtx);
                if (mounted) {
                  _showBanner('Error al eliminar: $e',
                      color: const Color(0xFFE11D48), icon: Icons.error);
                }
              }
            },
            child:
            const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _mostrarOpcionesCliente(_Cliente c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Acciones',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              const Divider(height: 0, color: Color(0xFFE5E7EB)),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF2563EB)),
                title: const Text('Editar'),
                onTap: () {
                  Navigator.pop(context);
                  _abrirEditarCliente(c);
                },
              ),
              const Divider(height: 0, color: Color(0xFFE5E7EB)),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Eliminar',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmarEliminar(c);
                },
              ),
              const Divider(height: 0, color: Color(0xFFE5E7EB)),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtFecha(DateTime d) {
    const meses = [
      'ene.',
      'feb.',
      'mar.',
      'abr.',
      'may.',
      'jun.',
      'jul.',
      'ago.',
      'sept.',
      'oct.',
      'nov.',
      'dic.'
    ];
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bienvenidaMostrada) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final nombre = (args['bienvenidaNombre'] as String?)?.trim();
        final empresa = (args['bienvenidaEmpresa'] as String?)?.trim();
        if (nombre != null && nombre.isNotEmpty) {
          _bienvenidaMostrada = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final texto = (empresa != null && empresa.isNotEmpty)
                ? '¡Bienvenido, $nombre! ($empresa)'
                : '¡Bienvenido, $nombre!';
            _showBanner(texto,
                color: const Color(0xFF22C55E), icon: Icons.verified);
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double logoTop = -90;
    const double logoHeight = 300;
    const double contentTop = 95;

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2458D6), Color(0xFF0A9A76)]),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // ===== Columna principal =====
                Padding(
                  padding: const EdgeInsets.only(top: contentTop),
                  child: Column(
                    children: [
                      // ===== Tarjeta principal (título + buscador + lista) =====
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(28), // ⬆️ sutil
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 20, // ⬆️ suave
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Column(
                                children: [
                                  // Título
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 14,
                                      left: 16,
                                      right: 16,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      'CLIENTES',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.playfair(
                                        color: Colors.white,
                                        fontSize: 24, // ⬆️ +2pt
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),

                                  // Buscador + botón agregar
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 10, 16, 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 48, // ⬆️
                                            decoration: BoxDecoration(
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.08),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: TextField(
                                              controller: _searchCtrl,
                                              onChanged: (_) => setState(() {}),
                                              decoration: InputDecoration(
                                                hintText: 'Buscar',
                                                hintStyle: const TextStyle(
                                                  color: Color(0xFF111827),
                                                ),
                                                prefixIcon: Icon(
                                                  Icons.search,
                                                  color: Colors.black
                                                      .withOpacity(0.7),
                                                ),
                                                filled: true,
                                                fillColor: Colors.white
                                                    .withOpacity(0.92),
                                                contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(18),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        SizedBox(
                                          width: 48, // ⬆️
                                          height: 48, // ⬆️
                                          child: Material(
                                            color: const Color(0xFF22C55E),
                                            borderRadius:
                                            BorderRadius.circular(14),
                                            elevation: 2,
                                            child: InkWell(
                                              borderRadius:
                                              BorderRadius.circular(14),
                                              onTap: _abrirAgregarCliente,
                                              child: const Icon(Icons.add,
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // === Chips de filtro ===
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 6),
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        ChoiceChip(
                                          label: const Text('Todos'),
                                          selected:
                                          _filtro == FiltroClientes.todos,
                                          onSelected: (_) => setState(() =>
                                          _filtro = FiltroClientes.todos),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.85),
                                          selectedColor: Colors.white,
                                          side: const BorderSide(
                                              color: Color(0xFFE5E7EB)),
                                          labelStyle: TextStyle(
                                            color: _filtro ==
                                                FiltroClientes.todos
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Text('Pendientes'),
                                          selected: _filtro ==
                                              FiltroClientes.pendientes,
                                          onSelected: (_) => setState(() =>
                                          _filtro =
                                              FiltroClientes.pendientes),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.85),
                                          selectedColor: Colors.white,
                                          side: const BorderSide(
                                              color: Color(0xFFE5E7EB)),
                                          labelStyle: TextStyle(
                                            color: _filtro ==
                                                FiltroClientes.pendientes
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        ChoiceChip(
                                          label: const Text('Saldados'),
                                          selected: _filtro ==
                                              FiltroClientes.saldados,
                                          onSelected: (_) => setState(() =>
                                          _filtro = FiltroClientes.saldados),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.85),
                                          selectedColor: Colors.white,
                                          side: const BorderSide(
                                              color: Color(0xFFE5E7EB)),
                                          labelStyle: TextStyle(
                                            color: _filtro ==
                                                FiltroClientes.saldados
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF0F172A),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ===== Lista desde Firestore (tiempo real) =====
                                  Expanded(
                                    child: uid == null
                                        ? const Center(
                                        child: Text(
                                            'No hay sesión. Inicia sesión.',
                                            style: TextStyle(
                                                color: Colors.white)))
                                        : StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('prestamistas')
                                          .doc(uid)
                                          .collection('clientes')
                                          .orderBy('proximaFecha',
                                          descending: false)
                                          .snapshots(),
                                      builder: (context, snap) {
                                        if (snap.connectionState ==
                                            ConnectionState.waiting) {
                                          return const Center(
                                            child:
                                            CircularProgressIndicator(
                                                color: Colors.white),
                                          );
                                        }
                                        if (snap.hasError) {
                                          return Center(
                                            child: Text(
                                              'Error: ${snap.error}',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          );
                                        }
                                        final docs =
                                            snap.data?.docs ?? [];

                                        // Mapear a modelo _Cliente
                                        final lista = docs.map((d) {
                                          final data = d.data()
                                          as Map<String, dynamic>;
                                          final codigoGuardado =
                                          (data['codigo']
                                          as String?)
                                              ?.trim();
                                          final codigoVisible =
                                          (codigoGuardado != null &&
                                              codigoGuardado
                                                  .isNotEmpty)
                                              ? codigoGuardado
                                              : _codigoDesdeId(d.id);
                                          return _Cliente(
                                            id: d.id,
                                            codigo: codigoVisible,
                                            nombre: (data['nombre'] ?? '')
                                            as String,
                                            apellido:
                                            (data['apellido'] ?? '')
                                            as String,
                                            telefono:
                                            (data['telefono'] ?? '')
                                            as String,
                                            direccion:
                                            data['direccion']
                                            as String?,
                                            producto:
                                            (data['producto']
                                            as String?)
                                                ?.trim(),
                                            capitalInicial:
                                            (data['capitalInicial'] ??
                                                0) as int,
                                            saldoActual:
                                            (data['saldoActual'] ??
                                                0) as int,
                                            tasaInteres:
                                            (data['tasaInteres'] ??
                                                0.0)
                                                .toDouble(),
                                            periodo: (data['periodo'] ??
                                                'Mensual') as String,
                                            proximaFecha:
                                            (data['proximaFecha']
                                            is Timestamp)
                                                ? (data[
                                            'proximaFecha']
                                            as Timestamp)
                                                .toDate()
                                                : DateTime.now(),
                                          );
                                        }).toList();

                                        // Filtro búsqueda
                                        final q = _searchCtrl.text
                                            .toLowerCase();
                                        var filtered = lista.where((c) {
                                          return c.codigo
                                              .toLowerCase()
                                              .contains(q) ||
                                              c.nombreCompleto
                                                  .toLowerCase()
                                                  .contains(q) ||
                                              c.telefono.contains(q);
                                        }).toList();

                                        // Filtro por chips
                                        filtered = filtered
                                            .where((c) {
                                          switch (_filtro) {
                                            case FiltroClientes.todos:
                                              return true;
                                            case FiltroClientes
                                                .pendientes:
                                              return c.saldoActual >
                                                  0;
                                            case FiltroClientes
                                                .saldados:
                                              return c.saldoActual <=
                                                  0;
                                          }
                                        })
                                            .toList()
                                          ..sort(_compareClientes);

                                        if (filtered.isEmpty) {
                                          return const Center(
                                            child: Text('No hay clientes',
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    color:
                                                    Colors.white)),
                                          );
                                        }

                                        return ListView.builder(
                                          physics:
                                          const BouncingScrollPhysics(), // ⬅️ feel premium
                                          padding:
                                          const EdgeInsets.fromLTRB(
                                              12, 8, 12, 24),
                                          itemCount: filtered.length,
                                          itemBuilder: (_, i) {
                                            final c = filtered[i];
                                            final estado = _estadoDe(c);
                                            final codigoCorto =
                                                'ID-${i + 1}';
                                            return GestureDetector(
                                              onTap: () =>
                                                  _abrirDetalleYGuardar(
                                                      c, codigoCorto),
                                              onLongPress: () =>
                                                  _mostrarOpcionesCliente(
                                                      c),
                                              child: _ClienteCard(
                                                cliente: c,
                                                resaltar:
                                                _resaltarVencimientos,
                                                estado: estado,
                                                diasHasta: _diasHasta(
                                                    c.proximaFecha),
                                                codigoCorto: codigoCorto,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== Barra mínima (perfil) =====
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PerfilPrestamistaScreen(),
                            ),
                          );
                        },
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child:
                          Icon(Icons.person, color: Color(0xFF2458D6)),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // ===== Logo (independiente) =====
                const Positioned(
                  top: logoTop,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Image(
                        image: AssetImage('assets/images/logoB.png'),
                        height: logoHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Abrir detalle y pasar datos del prestamista al recibo
  void _abrirDetalleYGuardar(_Cliente c, String codigoCorto) async {
    final estadoAntes = _estadoDe(c);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClienteDetalleScreen(
          // -------- cliente ----------
          id: c.id,
          codigo: codigoCorto,
          nombreCompleto: c.nombreCompleto,
          telefono: c.telefono,
          direccion: c.direccion,
          saldoActual: c.saldoActual,
          tasaInteres: c.tasaInteres,
          periodo: c.periodo,
          proximaFecha: c.proximaFecha,

          // -------- prestamista ------
          empresa: _empresa,
          servidor: _servidor,
          telefonoServidor: _telefonoServidor,

          // -------- producto ----------
          producto: c.producto ?? '',
        ),
      ),
    );

    if (result != null && result is Map && result['accion'] == 'pago') {
      final estadoDespues = _estadoDe(c);
      if (estadoDespues == _EstadoVenc.alDia &&
          estadoAntes != _EstadoVenc.alDia) {
        _showBanner('Pago registrado ✅ · Ahora al día');
      } else {
        _showBanner('Pago guardado correctamente ✅');
      }
    }
  }
}

enum FiltroClientes { todos, pendientes, saldados }
enum _EstadoVenc { vencido, hoy, pronto, alDia }

// ================= Tarjeta de cliente =================

class _ClienteCard extends StatelessWidget {
  final _Cliente cliente;
  final bool resaltar;
  final _EstadoVenc estado;
  final int diasHasta;
  final String? codigoCorto;

  const _ClienteCard({
    required this.cliente,
    this.resaltar = false,
    this.estado = _EstadoVenc.alDia,
    this.diasHasta = 0,
    this.codigoCorto,
    super.key,
  });

  String _monedaRD(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (count == 3 && i != 0) {
        buf.write('.');
        count = 0;
      }
    }
    return 'RD\$${buf.toString().split('').reversed.join()}';
  }

  // Colores según pedido (saldado: banda GRIS)
  Color _headerColor() {
    if (cliente.saldoActual <= 0) return const Color(0xFFCBD5E1); // gris
    if (!resaltar) return Colors.transparent;
    switch (estado) {
      case _EstadoVenc.vencido:
        return const Color(0xFFDC2626); // rojo más elegante
      case _EstadoVenc.hoy:
        return const Color(0xFFFB923C); // naranja cálido
      case _EstadoVenc.pronto:
        return const Color(0xFFFACC15); // amarillo
      case _EstadoVenc.alDia:
        return const Color(0xFF22C55E); // verde
    }
  }

  String _estadoTexto() {
    if (cliente.saldoActual <= 0) return 'Saldado';
    switch (estado) {
      case _EstadoVenc.vencido:
        return 'Vencido';
      case _EstadoVenc.hoy:
        return 'Vence hoy';
      case _EstadoVenc.pronto:
        return diasHasta == 1 ? 'Vence mañana' : 'Vence en $diasHasta días';
      case _EstadoVenc.alDia:
        return 'Al día';
    }
  }

  @override
  Widget build(BuildContext context) {
    final interesPeriodo =
    (cliente.saldoActual * (cliente.tasaInteres / 100)).round();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Banda superior con código visible y estado
            Container(
              height: 36,
              color: _headerColor(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    codigoCorto ?? cliente.codigo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  if (resaltar || cliente.saldoActual <= 0)
                    Text(
                      _estadoTexto(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, // semibold/strong
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Izquierda
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cliente.nombreCompleto,
                          style: const TextStyle(
                            fontSize: 19, // ⬆️ +1pt
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tel: ${cliente.telefono}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xDE000000), // 87% black
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Interés ${cliente.periodo.toLowerCase()}: ${_monedaRD(interesPeriodo)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xDE000000),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Derecha
                  Text(
                    'Saldo: ${_monedaRD(cliente.saldoActual)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cliente {
  final String id; // docId (interno)
  final String codigo; // código visible (CL-XXXXXX)
  final String nombre;
  final String apellido;
  final String telefono;
  final String? direccion;
  final String? producto;

  final int capitalInicial;
  final int saldoActual;
  final double tasaInteres;
  final String periodo;
  final DateTime proximaFecha;

  _Cliente({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    this.direccion,
    this.producto,
    required this.capitalInicial,
    required this.saldoActual,
    required this.tasaInteres,
    required this.periodo,
    required this.proximaFecha,
  });

  String get nombreCompleto => '$nombre $apellido';
}