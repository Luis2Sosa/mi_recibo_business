import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mi_recibo/ui/theme/app_theme.dart';
import 'package:mi_recibo/ui/widgets/app_frame.dart';
import 'package:mi_recibo/ui/perfil_prestamista/premium_boosts_screen.dart';
import 'package:mi_recibo/ui/perfil_prestamista/ganancia_clientes_screen.dart';

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

  Future<void> _refresh() async {
    setState(() {
      _future = _cargarGananciasGlobal();
    });
  }

  Future<void> _openPremium() async {
    // Aquí va el rewarded ad real (google_mobile_ads) cuando lo integres.
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PremiumBoostsScreen(docPrest: widget.docPrest)));
  }

  // -------- UI --------
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
                  physics: const NeverScrollableScrollPhysics(), // 👈 sin scroll
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

                          // Título
                          Text(
                            'Ganancias totales históricas',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: _BrandX.inkDim,
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

                    // ======== TARJETA PREMIUM ========
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

  // ---- helpers ----
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
          Text(label, style: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: _BrandX.ink, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _premiumCard() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.gradTop.withOpacity(0.98), AppTheme.gradBottom.withOpacity(0.98)],
        ),
        boxShadow: [BoxShadow(color: AppTheme.gradTop.withOpacity(.28), blurRadius: 25, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
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
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 30),
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
          _bullet('QEDU del día'),
          const SizedBox(height: 10),
          _bullet('Estadística avanzada'),
          const SizedBox(height: 10),
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
                textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5, letterSpacing: .1),
          ),
        ),
      ],
    );
  }
}

// ===== Tipos locales de esta pantalla =====
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

// Header local (privado) para esta pantalla
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
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        ),
      ],
    );
  }
}

// Colores locales mínimos (evitamos depender de _Brand privado de otro archivo)
class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
}
