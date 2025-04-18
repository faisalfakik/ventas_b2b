import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import './store_seller_screen.dart';
import 'package:firebase_performance/firebase_performance.dart';
import './store_seller_registration_screen.dart';

class StoreSellerLoginScreen extends StatefulWidget {
  const StoreSellerLoginScreen({Key? key}) : super(key: key);

  @override
  State<StoreSellerLoginScreen> createState() => _StoreSellerLoginScreenState();
}

class _StoreSellerLoginScreenState extends State<StoreSellerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Verificar si hay credenciales guardadas
    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    // Implementar lógica para cargar credenciales guardadas
    // Ejemplo: usar SharedPreferences
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Cerrar el teclado
    FocusScope.of(context).unfocus();

    // Crear una traza de rendimiento
    final Trace loginTrace = FirebasePerformance.instance.newTrace("store_seller_login");

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Iniciar la traza
      await loginTrace.start();

      final authService = Provider.of<AuthService>(context, listen: false);

      // Añadir metadatos a la traza (opcional)
      loginTrace.putAttribute("login_method", "email_password");

      // Intentar iniciar sesión
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      // Incrementar métrica de inicio de sesión exitoso
      loginTrace.incrementMetric("successful_logins", 1);

      // Verificar si el usuario es un vendedor de tienda
      final isStoreSeller = await authService.isStoreSeller();

      if (!isStoreSeller) {
        throw Exception('No tienes permisos de vendedor de tienda');
      }

      // Obtener los datos del usuario de Firestore
      final userDoc = await authService.getCurrentUserData();

      if (!userDoc['isActive']) {
        throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
      }

      // Guardar credenciales si 'recordar sesión' está activado
      if (_rememberMe) {
        // Implementar lógica para guardar credenciales
        // Ejemplo: usar SharedPreferences o flutter_secure_storage
      }

      if (!mounted) return;

      // Navegar a la pantalla del vendedor
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StoreSellerScreen(
            storeId: userDoc['storeId'],
            sellerId: authService.firebaseUser!.uid,
            storeName: userDoc['storeName'],
            sellerName: userDoc['name'],
          ),
        ),
      );
    } catch (e) {
      // Incrementar métrica de inicio de sesión fallido
      loginTrace.incrementMetric("failed_logins", 1);

      setState(() {
        if (e.toString().contains('user-not-found')) {
          _errorMessage = 'Usuario no encontrado';
        } else if (e.toString().contains('wrong-password')) {
          _errorMessage = 'Contraseña incorrecta';
        } else if (e.toString().contains('Exception:')) {
          _errorMessage = e.toString().split('Exception: ')[1];
        } else {
          _errorMessage = 'Error al iniciar sesión. Verifica tus credenciales.';
        }
      });
    } finally {
      // Detener la traza
      await loginTrace.stop();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implementar lógica para enviar correo de recuperación
              final email = emailController.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                // authService.sendPasswordResetEmail(email);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Se ha enviado un correo de recuperación'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingresa un correo válido'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo
                Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 120,
                  ),
                ),
                const SizedBox(height: 40),
                // Título
                const Text(
                  'Acceso Vendedores',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                // Campo de correo
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su correo electrónico';
                    }
                    if (!value.contains('@')) {
                      return 'Por favor ingrese un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Campo de contraseña
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese su contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Checkbox "Recordar sesión"
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                    ),
                    const Text('Recordar sesión'),
                    const Spacer(),
                    TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Mensaje de error
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                // Botón de inicio de sesión
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                // Botón para crear cuenta nueva
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes una cuenta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoreSellerRegistrationScreen(),
                          ),
                        );
                      },
                      child: const Text('Regístrate aquí'),
                    ),
                  ],
                ),
              ],
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
}