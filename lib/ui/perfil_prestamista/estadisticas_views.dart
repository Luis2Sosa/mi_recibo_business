import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';

class _BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
}

/// ==== ACTUAL ====
class EstadisticasActualView extends StatelessWidget {
  final int totalPrestado;
  final int totalRecuperado;
  final int totalPendiente;

  final String mayorNombre;
  final int mayorSaldo;
  final String promInteres;
  final String proximoVenc;

  final String Function(int) rd;

  const EstadisticasActualView({
    super.key,
    required this.totalPrestado,
    required this.totalRecuperado,
    required this.totalPendiente,
    required this.mayorNombre,
    required this.mayorSaldo,
    required this.promInteres,
    required this.proximoVenc,
    required this.rd,
  });

  @override
  Widget build(BuildContext context) {
    final recRate = totalPrestado > 0 ? (totalRecuperado * 100 / totalPrestado) : 0.0;
    final recColor = recRate >= 50 ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
      ],
    );
  }
}

/// ==== HISTÓRICO ====
class EstadisticasHistoricoView extends StatelessWidget {
  final int lifetimePrestado;
  final int lifetimeRecuperado;

  final String histPrimerPago;
  final String histUltimoPago;
  final String histMesTop;

  final VoidCallback onOpenGanancias;
  final VoidCallback onOpenGananciaClientes;
  final String Function(int) rd;

  const EstadisticasHistoricoView({
    super.key,
    required this.lifetimePrestado,
    required this.lifetimeRecuperado,
    required this.histPrimerPago,
    required this.histUltimoPago,
    required this.histMesTop,
    required this.onOpenGanancias,
    required this.onOpenGananciaClientes,
    required this.rd,
  });

  @override
  Widget build(BuildContext context) {
    final recRate = lifetimePrestado > 0 ? (lifetimeRecuperado * 100 / lifetimePrestado) : 0.0;
    final recColor = recRate >= 50 ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _kpiPremium(
              title: 'Ganancias totales',
              subtitle: 'Toca para ver',
              leading: Icons.trending_up_rounded,
              onTap: onOpenGanancias,
              gradient: [const Color(0xFFDFFCEF), const Color(0xFFC5F5FF)],
            ),

            // KPI 2 — Total recuperado
            _kpi(
              'Total recuperado',
              rd(lifetimeRecuperado),
              bg: const Color(0xFFDCFCE7),
              accent: const Color(0xFF16A34A),
            ),

            // KPI 3 — Total pendiente
            _kpi(
              'Total pendiente',
              rd(lifetimePrestado - lifetimeRecuperado),
              bg: const Color(0xFFFEF3C7),
              accent: const Color(0xFFF59E0B),
            ),

            // KPI 4 — Total circulando
            _kpi(
              'Total circulando',
              rd(lifetimePrestado),
              bg: const Color(0xFFDBEAFE),
              accent: const Color(0xFF2563EB),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // KPI de Recuperación (nuevo profesional con porcentaje)
        _kpiRecuperacion(pct: recRate, color: recColor),

        const SizedBox(height: 20),

        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _kv('Primer pago registrado', histPrimerPago),
              _divider(),
              _kv('Último pago registrado', histUltimoPago),
              _divider(),
              _kv('Mes con más cobros', histMesTop),
              _divider(),
              _kv('Recuperación histórica', lifetimePrestado > 0 ? '${recRate.toStringAsFixed(0)}%' : '—'),
            ],
          ),
        ),
      ],
    );
  }
}

/// === KPI Recuperación Profesional ===
Widget _kpiRecuperacion({required double pct, required Color color}) {
  final porcentaje = pct.clamp(0, 100).toStringAsFixed(1);

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 6))],
      border: Border.all(color: const Color(0xFFE8EEF8)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.trending_up_rounded, color: color, size: 24),
            const SizedBox(width: 10),
            Text(
              'Recuperación',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: _BrandX.ink,
              ),
            ),
          ],
        ),
        Text(
          '$porcentaje%',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// ====== UI Helpers ======
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
        SizedBox(
          width: double.infinity,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              textStyle: const TextStyle(color: _BrandX.inkDim, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: GoogleFonts.inter(textStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: accent)),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _kpiPremium({
  required String title,
  required String subtitle,
  required IconData leading,
  required VoidCallback onTap,
  required List<Color> gradient,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.65), width: 1.4),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(leading, size: 18, color: AppTheme.gradTop),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  textStyle: const TextStyle(
                    color: _BrandX.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE1E8F5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 14, color: _BrandX.inkDim),
                    const SizedBox(width: 6),
                    Text(
                      subtitle,
                      style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.gradTop, fontSize: 12.5),
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

Widget _card({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.96),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 14, offset: const Offset(0, 6))],
      border: Border.all(color: const Color(0xFFE1E8F5)),
    ),
    child: child,
  );
}

Widget _divider() => Container(height: 1.2, color: _BrandX.divider, margin: const EdgeInsets.symmetric(vertical: 10));

Widget _kv(String k, String v) {
  return Row(
    children: [
      Expanded(child: Text(k, style: const TextStyle(color: _BrandX.inkDim))),
      Flexible(
        child: Align(
          alignment: Alignment.center,
          child: Text(
            v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900, color: _BrandX.ink),
          ),
        ),
      ),
    ],
  );
}

/// ===== Card premium público =====
class PremiumDeleteCard extends StatelessWidget {
  final VoidCallback? onTap;
  const PremiumDeleteCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Container(
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
          Row(
            children: [
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
              Expanded(
                child: Text(
                  'Borrar histórico',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Elimina solo los acumulados históricos. No borra clientes ni pagos.',
            style: TextStyle(color: Colors.white.withOpacity(.92), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: disabled ? null : onTap,
              icon: const Icon(Icons.shield_moon_outlined, size: 18),
              label: const Text('Borrar histórico'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE11D48),
                disabledBackgroundColor: Colors.white.withOpacity(.6),
                disabledForegroundColor: const Color(0xFFEF9AA9),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
