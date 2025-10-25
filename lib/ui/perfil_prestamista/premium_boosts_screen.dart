// lib/ui/perfil_prestamista/premium_boosts_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';

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
  int _qIndex = 0, _fIndex = 0;
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
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _initAll();
  }

  Future<void> _initAll() async {
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              children: [
                _proBanner(),
                const SizedBox(height: 25),
                _premiumCard(
                  icon: Icons.bolt_rounded,
                  title: 'QEDU del día',
                  subtitle: 'Cómo mejorar tu rendimiento',
                  text: _qedu[_qIndex],
                  chip: _chip('HOY', const Color(0xFFFFE082)),
                  color: const Color(0xFFBA9C2F),
                  miniChart: _miniChart1(),
                ),
                const SizedBox(height: 22),
                _premiumCard(
                  icon: Icons.account_balance_wallet_rounded,
                  title: 'Consejo financiero',
                  subtitle: 'Gestión de riesgo y capital',
                  text: _finance[_fIndex],
                  chip: _chip('PRO', const Color(0xFFD1C4E9)),
                  color: const Color(0xFF8E7CC3),
                  miniChart: _miniChart2(),
                ),
                const SizedBox(height: 22),
                _premiumCard(
                  icon: Icons.trending_up_rounded,
                  title: 'Tendencia de crecimiento',
                  subtitle: 'Evolución de ganancias',
                  text: 'Analiza tu progreso y ajusta tus estrategias.',
                  chip: _chip('LIVE', const Color(0xFFB2F5EA)),
                  color: const Color(0xFF00E5FF),
                  miniChart: _miniChart3(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _proBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B6FDF), Color(0xFF8E54E9)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Contenido premium desbloqueado',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                height: 1.1,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.35)),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: .4,
              ),
            ),
          )
        ],
      ),
    );
  }

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

  // ===== MINIGRÁFICOS PREMIUM =====

  Widget _miniChart1() {
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
              color: const Color(0xFF00E5FF),
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00E5FF).withOpacity(0.4),
                    const Color(0xFF00FF88).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: const [
                FlSpot(0, 1.2),
                FlSpot(1, 1.8),
                FlSpot(2, 1.5),
                FlSpot(3, 2.2),
                FlSpot(4, 2.0),
                FlSpot(5, 2.8),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChart2() {
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
              color: const Color(0xFFB388EB),
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFB388EB).withOpacity(0.4),
                    const Color(0xFF7C4DFF).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: const [
                FlSpot(0, 1.5),
                FlSpot(1, 1.2),
                FlSpot(2, 1.9),
                FlSpot(3, 2.4),
                FlSpot(4, 1.8),
                FlSpot(5, 2.6),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniChart3() {
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
              color: const Color(0xFF00FF88),
              barWidth: 3,
              isStrokeCapRound: true,
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00FF88).withOpacity(0.4),
                    const Color(0xFF00E5FF).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              spots: const [
                FlSpot(0, 2.0),
                FlSpot(1, 2.3),
                FlSpot(2, 1.6),
                FlSpot(3, 2.8),
                FlSpot(4, 2.2),
                FlSpot(5, 3.1),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
