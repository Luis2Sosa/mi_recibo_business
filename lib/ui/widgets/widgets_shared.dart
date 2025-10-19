// lib/ui/widgets/widgets_shared.dart
import 'package:flutter/material.dart';
import 'package:mi_recibo/ui/theme/app_theme.dart';

// === Moneda y locale ===
import 'dart:io' show Platform;
import 'package:intl/intl.dart';

/// Formatea un monto con la moneda y separadores del país del dispositivo.
/// - Usa el locale del sistema (ej. es_PE, es_MX, es_DO, en_US, pt_BR).
/// - Caso especial: República Dominicana -> "RD$ 12,345.67".
/// - Permite forzar un locale con [localeOverride] (opcional) si en el futuro
///   ofreces selección de país en el perfil.
String monedaLocal(num valor, {String? localeOverride}) {
  try {
    // 1) Tomar locale: override > dispositivo
    String loc = (localeOverride != null && localeOverride.trim().isNotEmpty)
        ? localeOverride.trim()
        : Platform.localeName; // ej: es_PE, es_MX, es_DO, en_US

    // 2) Normalizar guión vs guion_bajo
    loc = loc.replaceAll('-', '_');

    // 3) Si viene solo idioma (sin país), elegir fallback sensato
    if (!loc.contains('_')) {
      if (loc.startsWith('es')) {
        loc = 'es_MX';
      } else if (loc.startsWith('pt')) {
        loc = 'pt_BR';
      } else if (loc.startsWith('en')) {
        loc = 'en_US';
      } else {
        // último recurso: MX por ser formato hispano estándar
        loc = 'es_MX';
      }
    }

    // 4) Caso especial RD: forzar RD$ y formato regional
    if (loc.toLowerCase().contains('_do')) {
      return 'RD\$ ${NumberFormat("#,##0.00", "es_DO").format(valor)}';
    }

    // 5) Formato local nativo
    return NumberFormat.simpleCurrency(locale: loc).format(valor);
  } catch (_) {
    // 6) Fallback final si intl falla por cualquier razón
    return 'RD\$ ${NumberFormat("#,##0.00", "en_US").format(valor)}';
  }
}

/// 🎨 Paleta y estilo base de componentes estadísticos
class BrandX {
  static const ink = Color(0xFF0F172A);
  static const inkDim = Color(0xFF64748B);
  static const divider = Color(0xFFD7E1EE);
  static const lightBg = Color(0xFFF9FAFB);
  static const subtleBorder = Color(0xFFE2E8F0);
}

/// 🔹 Encabezado estándar (todas las pantallas de estadísticas)
class StatsHeaderBar extends StatelessWidget {
  final String title;
  const StatsHeaderBar({super.key, required this.title});

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

/// 🧮 Tarjeta base con estilo limpio y sombreado suave
class StatCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const StatCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: BrandX.subtleBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 💡 Indicador KPI (título, valor y fondo)
class KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final Color bg;
  final Color accent;
  const KpiTile({
    super.key,
    required this.title,
    required this.value,
    this.bg = const Color(0xFFEFF6FF),
    this.accent = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BrandX.inkDim,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              )),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                color: accent,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              )),
        ],
      ),
    );
  }
}

/// 🩶 Estado vacío (cuando no hay datos)
class EmptyStateCard extends StatelessWidget {
  final String message;
  const EmptyStateCard({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrandX.subtleBorder),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: BrandX.inkDim,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 🟢 Etiqueta tipo "pill" (por estado o categoría)
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        border: Border.all(color: color.withOpacity(.35)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}
