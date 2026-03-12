// lib/ui/perfil_prestamista/premium_boosts_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class HeaderBar extends StatelessWidget {
  final String title;
  const HeaderBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          style: ButtonStyle(
            backgroundColor:
            MaterialStateProperty.all(Colors.white.withOpacity(0.15)),
            shape: MaterialStateProperty.all(const CircleBorder()),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: .2)),
      ],
    );
  }
}

class PremiumBoostsScreen extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> docPrest;
  const PremiumBoostsScreen({super.key, required this.docPrest});

  @override
  State<PremiumBoostsScreen> createState() => _PremiumBoostsScreenState();
}

class _PremiumBoostsScreenState extends State<PremiumBoostsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// ===================== UI PRINCIPAL =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          'Potenciador Premium',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: .2,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1E2A78), Color(0xFF431F91)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
              : FadeTransition(
            opacity: _fadeAnim,
            child: ListView(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _bloqueLecturaDelDia(),
                const SizedBox(height: 25),

                // ======= QEDU del día (desde Firestore) =======
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('config')
                      .doc('(default)')
                      .collection('potenciador_contenido')
                      .where('tipo', isEqualTo: 'QEDU')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white),
                      );
                    }

                    if (snapshot.hasError) {
                      return _premiumCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Error al cargar QEDU',
                        subtitle: 'Verifica la conexión con la base de datos',
                        text: '⚠️ No se pudo obtener el QEDU del día.',
                        chip: _chip('ERROR', Colors.redAccent),
                        color: Colors.redAccent,
                        miniChart:
                        _miniChart(Colors.redAccent, tipo: 'qedu'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _premiumCard(
                        icon: Icons.bolt_rounded,
                        title: 'QEDU del día',
                        subtitle: 'Cómo mejorar tu rendimiento',
                        text: '⚡ No hay QEDU activo en este momento.',
                        chip: _chip('VACÍO', const Color(0xFFFFE082)),
                        color: const Color(0xFFBA9C2F),
                        miniChart: _miniChart(const Color(0xFF00E5FF),
                            tipo: 'qedu'),
                      );
                    }

                    final activos =
                    docs.where((d) => d['activo'] == true).toList();
                    if (activos.isEmpty) {
                      return _premiumCard(
                        icon: Icons.bolt_rounded,
                        title: 'QEDU del día',
                        subtitle: 'Cómo mejorar tu rendimiento',
                        text: '⚡ No hay QEDU activo en este momento.',
                        chip: _chip('INACTIVO', const Color(0xFFFFE082)),
                        color: const Color(0xFFBA9C2F),
                        miniChart: _miniChart(const Color(0xFF00E5FF),
                            tipo: 'qedu'),
                      );
                    }

                    final index = DateTime.now().day % activos.length;
                    final contenido =
                        activos[index]['contenido'] ?? 'Sin contenido';
                    return _premiumCard(
                      icon: Icons.bolt_rounded,
                      title: 'QEDU del día',
                      subtitle: 'Cómo mejorar tu rendimiento',
                      text: contenido,
                      chip: _chip('HOY', const Color(0xFFFFE082)),
                      color: const Color(0xFFBA9C2F),
                      miniChart:
                      _miniChart(const Color(0xFF00E5FF), tipo: 'qedu'),
                    );
                  },
                ),

                const SizedBox(height: 22),

                // ======= Consejo financiero (desde Firestore) =======
                FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('config')
                      .doc('(default)')
                      .collection('potenciador_contenido')
                      .where('tipo', isEqualTo: 'FIN')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white),
                      );
                    }

                    if (snapshot.hasError) {
                      return _premiumCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Consejo financiero',
                        subtitle: 'Gestión de riesgo y capital',
                        text: '⚠️ Error al conectar con la base de datos.',
                        chip: _chip('ERROR', Colors.redAccent),
                        color: Colors.redAccent,
                        miniChart: _miniChart(Colors.redAccent,
                            tipo: 'finance'),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _premiumCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Consejo financiero',
                        subtitle: 'Gestión de riesgo y capital',
                        text: '📭 No hay consejos financieros activos.',
                        chip: _chip('VACÍO', const Color(0xFFFFE082)),
                        color: const Color(0xFF8E7CC3),
                        miniChart: _miniChart(const Color(0xFFB388EB),
                            tipo: 'finance'),
                      );
                    }

                    final activos =
                    docs.where((d) => d['activo'] == true).toList();
                    if (activos.isEmpty) {
                      return _premiumCard(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Consejo financiero',
                        subtitle: 'Gestión de riesgo y capital',
                        text: '⚡ No hay consejos financieros activos.',
                        chip: _chip('INACTIVO', const Color(0xFFFFE082)),
                        color: const Color(0xFF8E7CC3),
                        miniChart: _miniChart(const Color(0xFFB388EB),
                            tipo: 'finance'),
                      );
                    }

                    final index = DateTime.now().day % activos.length;
                    final contenido =
                        activos[index]['contenido'] ?? 'Sin contenido';
                    return _premiumCard(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Consejo financiero',
                      subtitle: 'Gestión de riesgo y capital',
                      text: contenido,
                      chip: _chip('PRO', const Color(0xFFD1C4E9)),
                      color: const Color(0xFF8E7CC3),
                      miniChart: _miniChart(const Color(0xFFB388EB),
                          tipo: 'finance'),
                    );
                  },
                ),

                const SizedBox(height: 22),

                // ======= Tendencia de crecimiento dinámica =======
                StreamBuilder<DocumentSnapshot>(
                  stream: widget.docPrest
                      .collection('estadisticas')
                      .doc('totales')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _premiumCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Tendencia de crecimiento',
                        subtitle: 'Progreso mensual inteligente',
                        text: 'Cargando datos de tu progreso...',
                        chip: _chip('SYNC', const Color(0xFF80DEEA)),
                        color: const Color(0xFF00E5FF),
                        miniChart:
                        const _AnimatedGrowthBackgroundVisible(0),
                      );
                    }

                    final rawData = snapshot.data?.data();
                    if (rawData == null || rawData is! Map) {
                      return _premiumCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Tendencia de crecimiento',
                        subtitle: 'Progreso mensual inteligente',
                        text:
                        'Aún no hay datos disponibles en tu cuenta.',
                        chip: _chip('OFF', const Color(0xFFFFE082)),
                        color: const Color(0xFF00E5FF),
                        miniChart: const _AnimatedGrowthBackground(0),
                      );
                    }

                    final Map<String, dynamic> data =
                    Map<String, dynamic>.from(rawData);
                    final rawHistorico = data['historialGanancias'];

                    final Map<String, dynamic> historico =
                    rawHistorico is Map
                        ? Map<String, dynamic>.fromEntries(
                      rawHistorico.entries.map(
                            (e) => MapEntry(
                            e.key.toString(), e.value),
                      ),
                    )
                        : {};

                    if (historico.isEmpty) {
                      return _premiumCard(
                        icon: Icons.trending_up_rounded,
                        title: 'Tendencia de crecimiento',
                        subtitle: 'Progreso mensual inteligente',
                        text:
                        'Aún no hay datos suficientes para calcular tu progreso mensual.',
                        chip: _chip('OFF', const Color(0xFFFFE082)),
                        color: const Color(0xFF00E5FF),
                        miniChart: const _AnimatedGrowthBackground(0),
                      );
                    }

                    final meses = historico.keys.toList()..sort();
                    final ultimoMes = meses.last;
                    final penultimoMes =
                    meses.length > 1 ? meses[meses.length - 2] : null;

                    final totalUltimo = (historico[ultimoMes] is Map)
                        ? ((historico[ultimoMes] as Map)['total'] ?? 0)
                        : 0;

                    final totalAnterior = (penultimoMes != null &&
                        historico[penultimoMes] is Map)
                        ? ((historico[penultimoMes] as Map)['total'] ?? 0)
                        : 0;

                    double cambio = 0;
                    if (totalAnterior > 0) {
                      cambio = ((totalUltimo - totalAnterior) /
                          totalAnterior) *
                          100;
                    }

                    final mensaje = cambio > 20
                        ? '🚀 Crecimiento sobresaliente de ${cambio.toStringAsFixed(1)} %. ¡Estás en tu mejor momento!'
                        : cambio > 10
                        ? '🌟 Tus ganancias subieron un ${cambio.toStringAsFixed(1)} %. Excelente gestión este mes.'
                        : cambio > 0
                        ? '📈 Pequeña mejora (${cambio.toStringAsFixed(1)} %) respecto al mes pasado.'
                        : cambio < 0
                        ? '📉 Bajaron ${cambio.abs().toStringAsFixed(1)} %. Revisa cobros y renovaciones.'
                        : '⚖️ Tus ganancias se mantienen estables este mes.';

                    return _premiumCard(
                      icon: Icons.trending_up_rounded,
                      title: 'Tendencia de crecimiento',
                      subtitle: 'Progreso mensual inteligente',
                      text: mensaje,
                      chip: _chip('LIVE', const Color(0xFFB2F5EA)),
                      color: const Color(0xFF00E5FF),
                      miniChart: _AnimatedGrowthBackgroundVisible(cambio),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===================== BLOQUE PREMIUM "LECTURA DEL DÍA" =====================
  Widget _bloqueLecturaDelDia() {
    return FutureBuilder<DocumentSnapshot>(
      future: widget.docPrest
          .collection('estadisticas')
          .doc('totales')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _premiumCard(
            icon: Icons.trending_up_rounded,
            title: 'Tendencia de crecimiento',
            subtitle: 'Progreso mensual inteligente',
            text: 'Cargando datos de tu progreso...',
            chip: _chip('SYNC', const Color(0xFF80DEEA)),
            color: const Color(0xFF00E5FF),
            miniChart: const _AnimatedGrowthBackground(0),
          );
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final totalGanancia =
        ((data['totalGanancia'] ?? 0) as num).toDouble();

        final frases = [
          {
            "autor": "Warren Buffett",
            "texto":
            "La regla número uno es no perder dinero. La regla número dos es no olvidar la regla número uno."
          },
          {
            "autor": "Robert Kiyosaki",
            "texto": "El dinero no te hace rico. La educación financiera sí."
          },
          {
            "autor": "Benjamin Franklin",
            "texto":
            "Un pequeño gasto puede arruinar una gran fortuna. Vigila las fugas pequeñas."
          },
          {
            "autor": "Napoleon Hill",
            "texto":
            "Piensa en grande. Lo que la mente puede concebir y creer, lo puede lograr."
          },
          {
            "autor": "Peter Lynch",
            "texto":
            "Invertir sin investigar es como jugar póker sin mirar las cartas."
          },
          {
            "autor": "John D. Rockefeller",
            "texto":
            "No tengas miedo de renunciar a lo bueno para ir tras lo grandioso."
          },
          {
            "autor": "Charlie Munger",
            "texto":
            "Invierte siempre en lo que entiendes. El conocimiento compone intereses igual que el dinero."
          },
          {
            "autor": "George S. Clason",
            "texto":
            "Haz que tu dinero trabaje para ti. Cada moneda debe convertirse en un obrero más."
          },
          {
            "autor": "Suze Orman",
            "texto":
            "Cada dólar que gastas hoy es un dólar menos de libertad mañana."
          },
          {
            "autor": "Dave Ramsey",
            "texto":
            "Vive por debajo de tus posibilidades y podrás vivir sin deudas."
          },
          {
            "autor": "Elon Musk",
            "texto":
            "El riesgo viene de no saber lo que estás haciendo. Aprende antes de invertir."
          },
          {
            "autor": "Grant Cardone",
            "texto":
            "Ahorra para invertir, no para acumular. El dinero guardado pierde poder."
          },
          {
            "autor": "Ray Dalio",
            "texto":
            "Quien no entiende los ciclos económicos, está destinado a sufrirlos."
          },
          {
            "autor": "Mark Cuban",
            "texto":
            "Trabaja como si alguien quisiera quitarte todo lo que tienes."
          },
          {
            "autor": "Jim Rohn",
            "texto":
            "La disciplina pesa gramos. El arrepentimiento pesa toneladas."
          },
          {
            "autor": "Tony Robbins",
            "texto":
            "Tu libertad financiera no depende del salario, sino de cómo lo administras."
          },
          {
            "autor": "Andrew Carnegie",
            "texto":
            "El hombre que muere rico, muere en desgracia. La riqueza se debe poner a trabajar."
          },
          {
            "autor": "Morgan Housel",
            "texto":
            "El dinero es el mejor espejo del comportamiento humano."
          },
          {
            "autor": "Thomas J. Stanley",
            "texto":
            "Los verdaderos millonarios gastan menos de lo que ganan y ahorran más de lo que parece."
          },
          {
            "autor": "Jeff Bezos",
            "texto":
            "Si duplicas el número de experimentos, duplicas tus oportunidades de éxito."
          },
          {
            "autor": "Bill Gates",
            "texto":
            "Está bien celebrar el éxito, pero es más importante aprender de los fracasos."
          },
          {
            "autor": "Paul Samuelson",
            "texto":
            "Invertir debería ser como ver la pintura secarse. Si quieres emoción, ve a Las Vegas."
          },
          {
            "autor": "Henry Ford",
            "texto":
            "El fracaso es simplemente la oportunidad de comenzar de nuevo, pero más inteligentemente."
          },
          {
            "autor": "Phil Knight",
            "texto":
            "No pares. Nunca te conformes con menos de lo que sabes que puedes lograr."
          },
          {
            "autor": "Earl Nightingale",
            "texto": "El éxito es la realización progresiva de un ideal digno."
          },
          {
            "autor": "Bodo Schäfer",
            "texto":
            "La libertad financiera comienza cuando dejas de trabajar solo por dinero."
          },
          {
            "autor": "Jim Collins",
            "texto": "La grandeza no es una circunstancia, es una elección."
          },
          {
            "autor": "Stephen Covey",
            "texto":
            "Empieza con un fin en mente. Las finanzas también se planean con propósito."
          },
          {
            "autor": "Howard Marks",
            "texto":
            "Ser consciente del riesgo es más importante que buscar el beneficio."
          },
          {
            "autor": "Carlos Slim",
            "texto":
            "El éxito no está en vencer siempre, sino en no desanimarse nunca."
          },
        ];

        final lecturaDelDia =
        frases[(DateTime.now().day - 1) % frases.length];
        final colorLinea =
        totalGanancia > 0 ? const Color(0xFF00E676) : Colors.amberAccent;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0D1B2A),
                Color(0xFF1E2A78),
                Color(0xFF431F91)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_stories_rounded,
                      color: Colors.white, size: 26),
                  const SizedBox(width: 10),
                  Text(
                    "Lectura del día 💰",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                builder: (context, value, _) {
                  return Opacity(
                    opacity: value,
                    child: Padding(
                      padding: EdgeInsets.only(top: 8 * (1 - value)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '"${lecturaDelDia["texto"]}"',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 15.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "- ${lecturaDelDia["autor"]}",
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 90,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color: colorLinea,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            colors: [
                              colorLinea.withOpacity(0.3),
                              colorLinea.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        spots: List.generate(
                          7,
                              (i) {
                            final random =
                            Random(DateTime.now().day + i);
                            return FlSpot(
                              i.toDouble(),
                              (sin(i * 0.8) * 1.4 +
                                  2.2 +
                                  random.nextDouble() * 0.8),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Actualizado diariamente',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ===================== TARJETAS PREMIUM =====================
  Widget _premiumCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String text,
    required Widget chip,
    required Color color,
    required Widget miniChart,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(
            color: Colors.white.withOpacity(0.12), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
                border:
                Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(.75),
                          fontSize: 13)),
                ],
              ),
            ),
            chip
          ]),
          const SizedBox(height: 16),
          miniChart,
          const SizedBox(height: 16),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(.95),
              fontWeight: FontWeight.w700,
              fontSize: 15.2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              title == 'Tendencia de crecimiento'
                  ? 'Actualizado mensualmente'
                  : 'Actualizado diariamente',
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(.6),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
    );
  }

  /// ===================== MINIGRÁFICOS CON VARIACIÓN DIARIA =====================
  Widget _miniChart(Color color, {String tipo = 'qedu'}) {
    final int seed =
        DateTime.now().day + DateTime.now().month * 31;
    final random = Random(seed);

    List<FlSpot> spots;

    switch (tipo) {
      case 'qedu':
        spots = List.generate(
          7,
              (i) => FlSpot(
            i.toDouble(),
            (sin(i * 0.9 + random.nextDouble() * 0.8) * 1.3 + 3.0),
          ),
        );
        break;
      case 'finance':
        spots = List.generate(
          7,
              (i) => FlSpot(
            i.toDouble(),
            (sin(i * 0.8 + random.nextDouble() * 1.2) * 1.2 + 2.8),
          ),
        );
        break;
      case 'growth':
        spots = List.generate(
          7,
              (i) => FlSpot(
            i.toDouble(),
            (pow(i, 0.9) * 0.8 +
                1.6 +
                sin(i * 0.5 + random.nextDouble()) * 1.0),
          ),
        );
        break;
      default:
        spots = List.generate(
          7,
              (i) => FlSpot(
            i.toDouble(),
            (2.0 + sin(i * 0.8 + random.nextDouble() * 0.5) * 1.0),
          ),
        );
    }

    return SizedBox(
      height: 90,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withOpacity(0.35),
                    color.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: spots,
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================
// 🌊 ANIMACIÓN SUAVE DE CRECIMIENTO (FUNCIONAL Y VISIBLE)
// ======================================================
class _AnimatedGrowthBackground extends StatefulWidget {
  final double cambio;
  const _AnimatedGrowthBackground(this.cambio);

  @override
  State<_AnimatedGrowthBackground> createState() =>
      _AnimatedGrowthBackgroundState();
}

class _AnimatedGrowthBackgroundState extends State<_AnimatedGrowthBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _WavePainter(
            progress: _controller.value,
            cambio: widget.cambio,
          ),
          child: Container(
            height: 90,
            width: double.infinity,
            color: Colors.transparent,
          ),
        );
      },
    );
  }
}

// ======================================================
// 🎨 PINTOR DE ONDA (SUAVE Y SIEMPRE VISIBLE)
// ======================================================
class _WavePainter extends CustomPainter {
  final double progress;
  final double cambio;

  _WavePainter({required this.progress, required this.cambio});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final midY = size.height / 2;
    const amplitude = 10.0;
    const frequency = 1.3;

    final Color colorBase = cambio > 0
        ? const Color(0xFF00E676)
        : cambio < 0
        ? const Color(0xFFFF5252)
        : const Color(0xFF64B5F6);

    final double inclinacion =
    cambio > 0 ? -3 : cambio < 0 ? 3 : 0;

    for (double x = 0; x <= size.width; x++) {
      final y = midY +
          sin((x / size.width * frequency * 2 * pi) +
              (progress * 2 * pi)) *
              amplitude +
          inclinacion;
      if (x == 0) {
        path.moveTo(0, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          colorBase.withOpacity(0.3),
          colorBase.withOpacity(0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = colorBase.withOpacity(0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ======================================================
// 💫 ENVOLTORIO SIMPLE (para mantener bordes redondeados)
// ======================================================
class _AnimatedGrowthBackgroundVisible extends StatelessWidget {
  final double cambio;
  const _AnimatedGrowthBackgroundVisible(this.cambio);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: _AnimatedGrowthBackground(cambio),
    );
  }
}