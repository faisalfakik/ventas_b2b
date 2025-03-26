import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import './store_seller_screen.dart';

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
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso Vendedores de Tienda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/logo.png', // Asegúrate de tener este archivo
                height: 120,
              ),
              const SizedBox(height: 40),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Correo Electrónico',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingrese su contraseña';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Iniciar Sesión',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Intentar iniciar sesión
      await authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

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
      setState(() {
        _errorMessage = e.toString().contains('Exception:')
            ? e.toString().split('Exception: ')[1]
            : 'Error al iniciar sesión. Verifica tus credenciales.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 