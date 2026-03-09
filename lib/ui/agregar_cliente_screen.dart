// 📂 lib/agregar_cliente_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  late AnimationController _controller1, _controller2, _controller3;
  late Animation<double> _fade1, _fade2, _fade3;
  late Animation<Offset> _slide1, _slide2, _slide3;

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
    return _consejos[now.day % _consejos.length];
  }

  @override
  void initState() {
    super.initState();

    _controller1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _controller2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _controller3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));

    final curve = Curves.easeOutCubic;
    _fade1 = CurvedAnimation(parent: _controller1, curve: curve);
    _fade2 = CurvedAnimation(parent: _controller2, curve: curve);
    _fade3 = CurvedAnimation(parent: _controller3, curve: curve);

    _slide1 = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(_fade1);
    _slide2 = Tween<Offset>(begin: const Offset(0, 0.20), end: Offset.zero).animate(_fade2);
    _slide3 = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(_fade3);

    Future.delayed(const Duration(milliseconds: 100), () => _controller1.forward());
    Future.delayed(const Duration(milliseconds: 250), () => _controller2.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _controller3.forward());
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          "Agregar Cliente",
          style: GoogleFonts.playfairDisplay(
            textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 24),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A2F4E), Color(0xFF0E4D8F), Color(0xFF007EA7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // --- Préstamo ---
                          _animatedItem(_fade1, _slide1, _tarjetaPremium(
                            color: const Color(0xFF0B60D8),
                            icon: Icons.account_balance_rounded,
                            title: "Préstamo",
                            subtitle: "Registrar cliente con préstamo activo",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarClientePrestamoScreen())),
                          )),

                          const SizedBox(height: 18),

                          // --- Producto / Fiado ---
                          _animatedItem(_fade2, _slide2, _tarjetaPremium(
                            color: const Color(0xFF00A86B),
                            icon: Icons.shopping_bag_rounded,
                            title: "Producto / Fiado",
                            subtitle: "Registrar cliente con producto o venta fiada",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarClienteProductoScreen())),
                          )),

                          const SizedBox(height: 18),

                          // --- Alquiler ---
                          _animatedItem(_fade3, _slide3, _tarjetaPremium(
                            color: const Color(0xFFFFA000),
                            icon: Icons.home_work_rounded,
                            title: "Alquiler",
                            subtitle: "Registrar cliente de alquiler o arriendo",
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarClienteAlquilerScreen())),
                          )),

                          const Spacer(), // Empuja el consejo hacia abajo si hay espacio
                          const SizedBox(height: 24),
                          _bloqueWebInfo(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _animatedItem(Animation<double> opacity, Animation<Offset> position, Widget child) {
    return FadeTransition(opacity: opacity, child: SlideTransition(position: position, child: child));
  }

  Widget _tarjetaPremium({required Color color, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.25), width: 1.1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(textStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                  Text(subtitle, style: GoogleFonts.poppins(textStyle: TextStyle(color: Colors.white.withOpacity(0.80), fontSize: 12))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _bloqueWebInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1F4D82).withOpacity(0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.white.withOpacity(0.9), size: 28),
          const SizedBox(height: 10),
          const Text("Consejo rápido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(_consejoDelDia, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}