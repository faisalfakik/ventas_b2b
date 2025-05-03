import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import '../main_navigation.dart'; // Para clientes
import 'vendor_dashboard/vendor_dashboard_screen.dart'; // Para vendedores
import 'admin_dashboard_screen.dart'; // Para administradores
import 'store_seller_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('🔍 DEBUG LOGIN: Botón de inicio de sesión presionado');
        String email = _emailController.text.trim();
        String password = _passwordController.text.trim();

        // Simulación de inicio de sesión - En una app real, verificaríamos con un servidor
        await Future.delayed(const Duration(milliseconds: 800)); // Simular retraso de red

        if (email == "admin@gtronic.com" && password == "123456") {
          print('🔍 DEBUG LOGIN: Inicio de sesión exitoso, preparando navegación');
          debugPrint("🔍 NAV: ANTES de Navigator.push/pushReplacement");
          // Navegar al panel de administrador
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
          debugPrint("🔍 NAV: DESPUÉS de Navigator.push/pushReplacement");
          print('🔍 DEBUG LOGIN: Navegación iniciada');
        }
        // Verificación para vendedor
        else if (email == "vendor@gtronic.com" && password == "123456") {
          print('🔍 DEBUG LOGIN: Inicio de sesión exitoso, preparando navegación');
          // Guardar el ID del vendedor en SharedPreferences
          final vendorId = 'V001';
          await _saveVendorId(vendorId);

          debugPrint("🔍 NAV: ANTES de Navigator.push/pushReplacement");
          // Navegar al panel de vendedor
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VendorDashboardScreen(vendorId: vendorId),
            ),
          );
          debugPrint("🔍 NAV: DESPUÉS de Navigator.push/pushReplacement");
          print('🔍 DEBUG LOGIN: Navegación iniciada');
        }
        // Cliente normal
        else if (email == "cliente@gtronic.com" && password == "123456") {
          print('🔍 DEBUG LOGIN: Inicio de sesión exitoso, preparando navegación');
          debugPrint("🔍 NAV: ANTES de Navigator.push/pushReplacement");
          // Navegar a la navegación principal para cliente
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
          debugPrint("🔍 NAV: DESPUÉS de Navigator.push/pushReplacement");
          print('🔍 DEBUG LOGIN: Navegación iniciada');
        }
        else {
          // Mostrar mensaje de error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Correo o contraseña incorrectos')),
          );
        }
      } catch (e) {
        print('❌ ERROR LOGIN: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.only(top: 40.0, bottom: 40.0),
                    child: Image.asset(
                      'assets/logo.png',
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        // Si no encuentra la imagen, muestra un icono
                        return Icon(
                          Icons.shopping_bag,
                          size: 120,
                          color: Colors.green.shade700,
                        );
                      },
                    ),
                  ),

                  // Título
                  Text(
                    'Bienvenido a GTRONIC',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Campo de correo electrónico
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: const Icon(Icons.email, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu correo';
                      }
                      if (!RegExp(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$")
                          .hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Campo de contraseña
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock, color: Colors.green),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor, ingresa tu contraseña';
                      }
                      if (value.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón de iniciar sesión
                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.green))
                      : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Botón de Registro
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen())
                      );
                    },
                    child: const Text('¿No tienes cuenta? Regístrate aquí'),
                  ),

                  // Botón para vendedores de tienda
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoreSellerLoginScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                    ),
                    child: const Text('Acceso Vendedores de Tienda'),
                  ),

                  // Mensaje informativo
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      'Para la demostración:\nAdmin: admin@gtronic.com\nVendedor: vendor@gtronic.com\nCliente: cliente@gtronic.com\nContraseña: 123456',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

// Método para guardar el ID del vendedor en SharedPreferences
  Future<void> _saveVendorId(String vendorId) async {
    debugPrint("  ➡️ DEBUG SP: Entrando a _saveVendorId...");
    try {
      debugPrint("  ➡️ DEBUG SP: Obteniendo instancia de SharedPreferences...");
      final prefs = await SharedPreferences.getInstance();
      debugPrint("  ➡️ DEBUG SP: Instancia obtenida. Guardando string...");
      await prefs.setString('current_vendor_id', vendorId);
      debugPrint("  ➡️ DEBUG SP: String guardado OK.");
      print("DEBUG: vendorId guardado en SharedPreferences: $vendorId");
    } catch (e, s) {
      debugPrint("  ❌ ERROR SP: Error dentro de _saveVendorId: $e");
      debugPrint(s.toString());
      rethrow;
    }
    debugPrint("  ➡️ DEBUG SP: Saliendo de _saveVendorId...");
  }
}