import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'home_screen.dart';
import 'vendor_dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class RouterScreen extends StatelessWidget {
  const RouterScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Mostrar un indicador de carga mientras se determina el estado de autenticación
    if (authService.isAuthenticated && authService.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Si no está autenticado, mostrar la pantalla de login
    if (!authService.isAuthenticated) {
      return const LoginScreen();
    }

    // Redireccionar según el rol
    final user = authService.currentUser!;
    switch (user.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();
      case UserRole.vendor:
        return VendorDashboardScreen(vendorId: user.id);
      case UserRole.client:
      default:
        return const HomeScreen();
    }
  }
}