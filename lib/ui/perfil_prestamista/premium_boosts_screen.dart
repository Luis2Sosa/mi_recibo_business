// lib/ui/perfil_prestamista/premium_boosts_screen.dart
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  final List<String> _qedu = [
    'Sube la tasa sólo a clientes puntuales.',
    'Reinvierte los intereses en préstamos pequeños.',
    'Ofrece 2% de descuento por pago adelantado.',
    'Automatiza recordatorios de pago.',
    'Segmenta por riesgo y asigna tasas por perfil.'
  ];

  final List<String> _finance = [
    'Nunca prestes más del 10% a un solo cliente.',
    'Mantén 15% de liquidez para emergencias.',
    'Recupera capital antes de maximizar interés.',
    'Evita renovar con clientes atrasados.',
    'Registra cada pago el mismo día.'
  ];

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

  Future<Map<String, dynamic>?> _obtenerContenidoDelDia(String tipo) async {
    try {
      debugPrint('📡 CONSULTA FIRESTORE INICIADA para tipo: $tipo');

      // 👇 quita todos los filtros, solo lee todo lo que haya en tu colección
      final snapshot = await FirebaseFirestore.instance
          .collection('potenciador_contenido')
          .get();

      debugPrint('📊 Total documentos encontrados: ${snapshot.docs.length}');
      for (final doc in snapshot.docs) {
        debugPrint('🧩 ${doc.id} → ${doc.data()}');
      }

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No se encontraron documentos en la colección.');
        return null;
      }

      // Selecciona un documento según el día
      final lista = snapshot.docs.map((d) => d.data()).toList();
      final index = (DateTime.now().day - 1) % lista.length;
      final data = lista[index];

      debugPrint('✅ Documento seleccionado: $data');
      return data;
    } catch (e, s) {
      debugPrint('❌ ERROR al obtener contenido: $e');
      debugPrint('STACKTRACE: $s');
      return null;
    }
  }





  // ===================== UI PRINCIPAL =====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 14,
        title: const HeaderBar(title: 'Potenciador Premium'),
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _bloqueLecturaDelDia(),
                const SizedBox(height: 25),
                // ======= QEDU del día (desde Firestore) =======
                FutureBuilder<Map<String, dynamic>?>(
                  future: _obtenerContenidoDelDia('QEDU'),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return _premiumCard(
                        icon: Icons.bolt_rounded,
                        title: 'QEDU del día',
                        subtitle: 'Cómo mejorar tu rendimiento',
                        text: 'Cargando sugerencia...',
                        chip: _chip('HOY', const Color(0xFFFFE082)),
                        color: const Color(0xFFBA9C2F),
                        miniChart: _miniChart(const Color(0xFF00E5FF)),
                      );
                    }

                    final data = snapshot.data!;
                    return _premiumCard(
                      icon: Icons.bolt_rounded,
                      title: data['titulo'] ?? 'QEDU del día',
                      subtitle: 'Cómo mejorar tu rendimiento',
                      text: data['contenido'] ?? '',
                      chip: _chip('HOY', const Color(0xFFFFE082)),
                      color: const Color(0xFFBA9C2F),
                      miniChart: _miniChart(const Color(0xFF00E5FF)),
                    );
                  },
                ),

                const SizedBox(height: 22),
                _premiumCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Consejo financiero',
                  subtitle: 'Gestión de riesgo y capital',
                  text: _finance[DateTime.now().day % _finance.length],
                  chip: _chip('PRO', const Color(0xFFD1C4E9)),
                  color: const Color(0xFF8E7CC3),
                  miniChart: _miniChart(const Color(0xFFB388EB)),
                ),
                const SizedBox(height: 22),
                _premiumCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Tendencia de crecimiento',
                  subtitle: 'Evolución de ganancias',
                  text: 'Analiza tu progreso y ajusta tus estrategias.',
                  chip: _chip('LIVE', const Color(0xFFB2F5EA)),
                  color: const Color(0xFF00E5FF),
                  miniChart: _miniChart(const Color(0xFF00FF88)),
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
      future: widget.docPrest.collection('estadisticas').doc('totales').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: Colors.white.withOpacity(0.05),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // === Datos base (solo para el efecto de energía visual) ===
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final totalGanancia = ((data['totalGanancia'] ?? 0) as num).toDouble();

        // === 30 frases financieras ===
        final frases = [
          {"autor": "Warren Buffett", "texto": "La regla número uno es no perder dinero. La regla número dos es no olvidar la regla número uno."},
          {"autor": "Robert Kiyosaki", "texto": "El dinero no te hace rico. La educación financiera sí."},
          {"autor": "Benjamin Franklin", "texto": "Un pequeño gasto puede arruinar una gran fortuna. Vigila las fugas pequeñas."},
          {"autor": "Napoleon Hill", "texto": "Piensa en grande. Lo que la mente puede concebir y creer, lo puede lograr."},
          {"autor": "Peter Lynch", "texto": "Invertir sin investigar es como jugar póker sin mirar las cartas."},
          {"autor": "John D. Rockefeller", "texto": "No tengas miedo de renunciar a lo bueno para ir tras lo grandioso."},
          {"autor": "Charlie Munger", "texto": "Invierte siempre en lo que entiendes. El conocimiento compone intereses igual que el dinero."},
          {"autor": "George S. Clason", "texto": "Haz que tu dinero trabaje para ti. Cada moneda debe convertirse en un obrero más."},
          {"autor": "Suze Orman", "texto": "Cada dólar que gastas hoy es un dólar menos de libertad mañana."},
          {"autor": "Dave Ramsey", "texto": "Vive por debajo de tus posibilidades y podrás vivir sin deudas."},
          {"autor": "Elon Musk", "texto": "El riesgo viene de no saber lo que estás haciendo. Aprende antes de invertir."},
          {"autor": "Grant Cardone", "texto": "Ahorra para invertir, no para acumular. El dinero guardado pierde poder."},
          {"autor": "Ray Dalio", "texto": "Quien no entiende los ciclos económicos, está destinado a sufrirlos."},
          {"autor": "Mark Cuban", "texto": "Trabaja como si alguien quisiera quitarte todo lo que tienes."},
          {"autor": "Jim Rohn", "texto": "La disciplina pesa gramos. El arrepentimiento pesa toneladas."},
          {"autor": "Tony Robbins", "texto": "Tu libertad financiera no depende del salario, sino de cómo lo administras."},
          {"autor": "Andrew Carnegie", "texto": "El hombre que muere rico, muere en desgracia. La riqueza se debe poner a trabajar."},
          {"autor": "Morgan Housel", "texto": "El dinero es el mejor espejo del comportamiento humano."},
          {"autor": "Thomas J. Stanley", "texto": "Los verdaderos millonarios gastan menos de lo que ganan y ahorran más de lo que parece."},
          {"autor": "Jeff Bezos", "texto": "Si duplicas el número de experimentos, duplicas tus oportunidades de éxito."},
          {"autor": "Bill Gates", "texto": "Está bien celebrar el éxito, pero es más importante aprender de los fracasos."},
          {"autor": "Paul Samuelson", "texto": "Invertir debería ser como ver la pintura secarse. Si quieres emoción, ve a Las Vegas."},
          {"autor": "Henry Ford", "texto": "El fracaso es simplemente la oportunidad de comenzar de nuevo, pero más inteligentemente."},
          {"autor": "Phil Knight", "texto": "No pares. Nunca te conformes con menos de lo que sabes que puedes lograr."},
          {"autor": "Earl Nightingale", "texto": "El éxito es la realización progresiva de un ideal digno."},
          {"autor": "Bodo Schäfer", "texto": "La libertad financiera comienza cuando dejas de trabajar solo por dinero."},
          {"autor": "Jim Collins", "texto": "La grandeza no es una circunstancia, es una elección."},
          {"autor": "Stephen Covey", "texto": "Empieza con un fin en mente. Las finanzas también se planean con propósito."},
          {"autor": "Howard Marks", "texto": "Ser consciente del riesgo es más importante que buscar el beneficio."},
          {"autor": "Carlos Slim", "texto": "El éxito no está en vencer siempre, sino en no desanimarse nunca."},
        ];

        final lecturaDelDia = frases[(DateTime.now().day - 1) % frases.length];

        final colorLinea =
        totalGanancia > 0 ? const Color(0xFF00E676) : Colors.amberAccent;

        // === BLOQUE VISUAL PREMIUM ===
        return AnimatedContainer(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1E2A78), Color(0xFF431F91)],
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
              // === TÍTULO PREMIUM ===
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

              // === CONTENIDO ANIMADO ===
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

              // === PEQUEÑO GRÁFICO DECORATIVO ===
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
                          6,
                              (i) => FlSpot(
                            i.toDouble(),
                            (sin(i * 0.9) * 1.5 + 2.5),
                          ),
                        ),
                      ),
                    ],
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
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.2),
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
                border: Border.all(color: Colors.white.withOpacity(0.25)),
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
            child: Text('Actualizado diariamente',
                style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5)),
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

  // ===================== MINIGRÁFICOS =====================
  Widget _miniChart(Color color) {
    final random = (List<double>.generate(
        6, (i) => (1 + i + (i % 2 == 0 ? 0.3 : 0.6)) + i / 3));
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
                  colors: [color.withOpacity(0.4), color.withOpacity(0.0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: List.generate(
                random.length,
                    (i) => FlSpot(i.toDouble(), random[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _noDataCard() {
  return Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      color: Colors.white.withOpacity(0.05),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_flat_rounded,
                color: Colors.white70, size: 26),
            const SizedBox(width: 10),
            Text(
              'Resumen de crecimiento',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Aún no hay datos suficientes para calcular el crecimiento mensual.',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(.9),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}
