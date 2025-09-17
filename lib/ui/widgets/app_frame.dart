import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ===== Fondo con gradiente (azul + verde) y SafeArea =====
class AppGradientBackground extends StatelessWidget {
  final Widget child;

  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.gradTop, AppTheme.gradBottom],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

// ===== Marco translúcido reutilizable =====
class AppFrame extends StatelessWidget {
  final Widget child;
  final Widget? header;

  const AppFrame({super.key, required this.child, this.header});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusFrame),
              boxShadow: [AppTheme.shadowFrame],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFrame),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (header != null) ...[
                      header!,
                      const SizedBox(height: 12),
                    ],
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}