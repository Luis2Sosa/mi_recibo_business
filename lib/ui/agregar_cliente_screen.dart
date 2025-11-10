// 📂 lib/agregar_cliente_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'clientes/agregar_cliente_prestamo.dart';
import 'clientes/agregar_cliente_producto_screen.dart';
import 'clientes/agregar_cliente_alquiler_screen.dart';

class AgregarClienteScreen extends StatefulWidget {
  const AgregarClienteScreen({super.key});

  @override
  State<AgregarClienteScreen> createState() => _AgregarClienteScreenState();
}

class _AgregarClienteScreenState extends State<AgregarClienteScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;
  late Animation<double> _fade1;
  late Animation<double> _fade2;
  late Animation<double> _fade3;
  late Animation<Offset> _slide1;
  late Animation<Offset> _slide2;
  late Animation<Offset> _slide3;

  @override
  void initState() {
    super.initState();

    _controller1 =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _controller2 =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _controller3 =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

    _fade1 = CurvedAnimation(parent: _controller1, curve: Curves.easeOutCubic);
    _fade2 = CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic);
    _fade3 = CurvedAnimation(parent: _controller3, curve: Curves.easeOutCubic);

    _slide1 = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller1, curve: Curves.easeOutCubic));
    _slide2 = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic));
    _slide3 = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller3, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 200), () => _controller1.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _controller2.forward());
    Future.delayed(const Duration(milliseconds: 600), () => _controller3.forward());
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // 👈 hace que el degradado cubra toda la pantalla
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Agregar Cliente",
          style: GoogleFonts.playfairDisplay(
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 26,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0A2F4E), // azul marino profundo (inicio)
              Color(0xFF0E4D8F), // azul business moderno
              Color(0xFF007EA7), // toque turquesa elegante (final)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // --- Tarjeta Préstamo ---
                FadeTransition(
                  opacity: _fade1,
                  child: SlideTransition(
                    position: _slide1,
                    child: _tarjetaPremium(
                      context,
                      color: const Color(0xFF0B60D8),
                      icon: Icons.account_balance_rounded,
                      title: "Préstamo",
                      subtitle: "Registrar cliente con préstamo activo",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AgregarClientePrestamoScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // --- Tarjeta Producto / Fiado ---
                FadeTransition(
                  opacity: _fade2,
                  child: SlideTransition(
                    position: _slide2,
                    child: _tarjetaPremium(
                      context,
                      color: const Color(0xFF00A86B),
                      icon: Icons.shopping_bag_rounded,
                      title: "Producto / Fiado",
                      subtitle: "Registrar cliente con producto o venta fiada",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AgregarClienteProductoScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // --- Tarjeta Alquiler ---
                FadeTransition(
                  opacity: _fade3,
                  child: SlideTransition(
                    position: _slide3,
                    child: _tarjetaPremium(
                      context,
                      color: const Color(0xFFFFA000),
                      icon: Icons.home_work_rounded,
                      title: "Alquiler",
                      subtitle: "Registrar cliente de alquiler o arriendo",
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AgregarClienteAlquilerScreen(),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // --- Bloque Mi Recibo Business ---
                _bloqueWebInfo(),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // --- Tarjeta premium con fondo suave y animación moderna ---
  Widget _tarjetaPremium(
      BuildContext context, {
        required Color color,
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  // --- Bloque web final ---
  Widget _bloqueWebInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4D82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFF0B60D8),
              shape: BoxShape.circle,
            ),
            child:
            const Icon(Icons.language_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            "Mi Recibo Business",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "También puedes usarlo en versión web para gestionar tus clientes y recibos desde cualquier dispositivo.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () async {
              final url = Uri.parse('https://www.mirecibobusiness.com');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              padding:
              const EdgeInsets.symmetric(vertical: 13, horizontal: 34),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0B60D8), Color(0xFF00AEEF)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_new_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Visitar página web",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
