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

  final List<String> _consejos = [
    "Confirma el número del cliente antes de registrarlo.",
    "Evita duplicar clientes: revisa tu lista antes de agregar uno nuevo.",
    "Usa nombres completos para evitar confusiones futuras.",
    "Verifica que el cliente tenga un número actualizado.",
    "Actualiza los datos del cliente cuando cambien.",
    "Revisa si ya existe un cliente con nombre parecido.",
    "No agregues clientes con información incompleta.",
    "Mantén notas claras de cada cliente para evitar confusión.",
    "Comprueba si el cliente ya existe en otra categoría.",
    "Clientes con datos claros son más fáciles de manejar.",
    "Verifica el nombre antes de guardar el registro.",
    "Evita usar apodos como nombre principal.",
    "Diferencia clientes con nombres iguales usando notas.",
    "Usa siempre un contacto confiable del cliente.",
    "Actualiza el número o dirección cuando cambien.",
    "Revisa la información antes de agregar un nuevo cliente.",
    "Organiza tus clientes para encontrarlos más rápido.",
    "Evita registrar números inventados o incompletos.",
    "Usa notas para detalles importantes del cliente.",
    "Clientes con referencias claras evitan confusión.",
    "Datos incompletos pueden causar errores más adelante.",
    "Usa mayúsculas correctamente para mejor lectura.",
    "Mantén tu lista limpia y sin duplicados.",
    "Notas actualizadas evitan problemas futuros.",
    "No dejes campos importantes vacíos.",
    "Si dos clientes se parecen, agrega una nota.",
    "Verifica siempre el teléfono y la dirección.",
    "Evita registrar clientes sin historial claro.",
    "Revisa el registro antes de confirmar.",
    "Clientes bien registrados facilitan tu trabajo.",
  ];

  String get _consejoDelDia {
    final now = DateTime.now();
    final index = now.day % 30;
    return _consejos[index];
  }

  @override
  void initState() {
    super.initState();

    _controller1 =
        AnimationController(
            vsync: this, duration: const Duration(milliseconds: 550));
    _controller2 =
        AnimationController(
            vsync: this, duration: const Duration(milliseconds: 650));
    _controller3 =
        AnimationController(
            vsync: this, duration: const Duration(milliseconds: 750));

    _fade1 = CurvedAnimation(parent: _controller1, curve: Curves.easeOutCubic);
    _fade2 = CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic);
    _fade3 = CurvedAnimation(parent: _controller3, curve: Curves.easeOutCubic);

    _slide1 = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _controller1, curve: Curves.easeOutCubic));
    _slide2 = Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _controller2, curve: Curves.easeOutCubic));
    _slide3 = Tween<Offset>(begin: const Offset(0, 0.40), end: Offset.zero)
        .animate(
        CurvedAnimation(parent: _controller3, curve: Curves.easeOutCubic));

    Future.delayed(
        const Duration(milliseconds: 200), () => _controller1.forward());
    Future.delayed(
        const Duration(milliseconds: 400), () => _controller2.forward());
    Future.delayed(
        const Duration(milliseconds: 600), () => _controller3.forward());
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
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
              Color(0xFF0A2F4E),
              Color(0xFF0E4D8F),
              Color(0xFF007EA7),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 👉 pequeño por ancho (Android chico ~360dp)
              final bool isSmall = constraints.maxWidth < 380;

              final contenido = Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: isSmall ? 4 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: isSmall ? 0 : 20),

                    // --- Préstamo ---
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
                          compact: isSmall,
                          onTap: () =>
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (
                                      _) => const AgregarClientePrestamoScreen(),
                                ),
                              ),
                        ),
                      ),
                    ),

                    SizedBox(height: isSmall ? 2 : 28),

                    // --- Producto / Fiado ---
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
                          compact: isSmall,
                          onTap: () =>
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const AgregarClienteProductoScreen(),
                                ),
                              ),
                        ),
                      ),
                    ),

                    SizedBox(height: isSmall ? 4 : 28),

                    // --- Alquiler ---
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
                          compact: isSmall,
                          onTap: () =>
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const AgregarClienteAlquilerScreen(),
                                ),
                              ),
                        ),
                      ),
                    ),

                    SizedBox(height: isSmall ? 4 : 24),

                    _bloqueWebInfo(isSmall),

                    SizedBox(height: isSmall ? 2 : 14),
                  ],
                ),
              );

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 60),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: contenido,
                ),
              );


            },
          ),
        ),
      ),
    );
  }


  Widget _tarjetaPremium(BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: compact ? 12 : 30, // ✅ MÁS BAJO EN PEQUEÑO
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.25), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: compact ? 42 : 52, // ✅ MÁS PEQUEÑO
              height: compact ? 42 : 52, // ✅ MÁS PEQUEÑO
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Icon(icon, color: Colors.white, size: compact ? 22 : 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 15 : 17, // ✅
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: compact ? 11 : 13.0, // ✅
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: compact ? 14 : 18, // ✅
            ),
          ],
        ),
      ),
    );
  }


  Widget _bloqueWebInfo(bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 10 : 32, // ✅ MUCHO MÁS BAJO
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4D82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: compact ? 40 : 58,
            height: compact ? 40 : 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: Colors.white,
              size: compact ? 20 : 26,
            ),
          ),
          SizedBox(height: compact ? 6 : 18),
          Text(
            "Consejo rápido",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: compact ? 14 : 18,
            ),
          ),
          SizedBox(height: compact ? 4 : 12),
          Text(
            _consejoDelDia,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: compact ? 12 : 15,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
