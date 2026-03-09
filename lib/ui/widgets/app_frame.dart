import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ===== Fondo con gradiente (azul + verde) y SafeArea =====
class AppGradientBackground extends StatelessWidget {
  final Widget child;

  const AppGradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.gradTop,
            AppTheme.gradBottom,
          ],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}

// ===== Marco translúcido reutilizable ADAPTABLE =====
class AppFrame extends StatelessWidget {
  final Widget child;
  final Widget? header;

  const AppFrame({super.key, required this.child, this.header});

  @override
  Widget build(BuildContext context) {
    // Detectamos el tamaño para ajustar márgenes
    final size = MediaQuery.of(context).size;
    final bool isSmallHeight = size.height < 700;

    return SizedBox.expand(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            // Ajustamos el padding vertical según el tamaño del celular
            padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: isSmallHeight ? 8 : 12
            ),
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
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (header != null) ...[
                        header!,
                        const SizedBox(height: 12),
                      ],
                      // CAMBIO CLAVE: Usamos Expanded con un SingleChildScrollView interno
                      // para que si el contenido es mucho, el usuario pueda deslizar.
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: child,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}