// lib/ui/adaptive_icons.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// =====================================================
/// ICONOS ADAPTATIVOS
/// =====================================================
/// Uso:
/// platformIcon(context, md: Icons.house, ios: CupertinoIcons.house_fill)
///
/// Automáticamente detecta si el dispositivo es Android o iOS
/// y muestra el ícono correspondiente.
/// =====================================================

Icon platformIcon(
    BuildContext context, {
      required IconData md,
      IconData? ios,
      double size = 22,
      Color? color,
    }) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  final iconData = isIOS ? (ios ?? _iosIconForMaterial(md)) : md;
  return Icon(iconData, size: size, color: color);
}

/// =====================================================
/// MAPEO BÁSICO DE ICONOS DE MATERIAL → CUPERTINO
/// =====================================================
/// Si no se especifica el ícono iOS manualmente, se busca aquí.
/// Si no se encuentra, usa un círculo genérico.
/// =====================================================
IconData _iosIconForMaterial(IconData md) {
  if (md == Icons.house_rounded) return CupertinoIcons.house_fill;
  if (md == Icons.shopping_bag_rounded) return CupertinoIcons.bag_fill;
  if (md == Icons.request_quote_rounded) return CupertinoIcons.money_dollar_circle;
  if (md == Icons.phone_rounded) return CupertinoIcons.phone_fill;
  if (md == Icons.email_rounded) return CupertinoIcons.envelope_fill;
  if (md == Icons.location_on_rounded) return CupertinoIcons.location_solid;
  if (md == Icons.calendar_today_rounded) return CupertinoIcons.calendar;
  if (md == Icons.person_rounded) return CupertinoIcons.person_fill;
  if (md == Icons.people_alt_rounded) return CupertinoIcons.person_2_fill;
  if (md == Icons.warning_amber_rounded) return CupertinoIcons.exclamationmark_triangle_fill;
  if (md == Icons.check_circle_rounded) return CupertinoIcons.checkmark_seal_fill;
  if (md == Icons.check_rounded) return CupertinoIcons.check_mark;
  if (md == Icons.lock_clock_rounded) return CupertinoIcons.lock_fill;
  if (md == Icons.timer_rounded) return CupertinoIcons.time;
  if (md == Icons.alarm_rounded) return CupertinoIcons.bell_fill;
  if (md == Icons.analytics_rounded) return CupertinoIcons.chart_bar_fill;
  if (md == Icons.file_download_rounded) return CupertinoIcons.arrow_down_circle_fill;
  if (md == Icons.share_rounded) return CupertinoIcons.share_up;
  if (md == Icons.print_rounded) return CupertinoIcons.doc_text_fill;
  if (md == Icons.sms_rounded) return CupertinoIcons.bubble_right_fill;
  if (md == Icons.attach_money_rounded) return CupertinoIcons.money_dollar_circle;
  if (md == Icons.info_outline) return CupertinoIcons.info;
  if (md == Icons.add_rounded) return CupertinoIcons.add;
  return CupertinoIcons.circle; // Fallback genérico
}
