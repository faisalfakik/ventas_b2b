import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

// Modelo de usuario simplificado
enum UserRole { admin, vendor, client }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? companyName;
  final String? phoneNumber;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyName,
    this.phoneNumber,
  });
}

class MockAuthService extends ChangeNotifier {
  UserModel? _currentUser;
  
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // Método de inicio de sesión simulado
  Future<bool> signIn(String email, String password) async {
    // Simular retraso de red
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (email == "admin@gtronic.com" && password == "123456") {
      _currentUser = UserModel(
        id: "admin-123",
        name: "Administrador",
        email: email,
        role: UserRole.admin,
      );
      notifyListeners();
      return true;
    } else if (email == "vendor@gtronic.com" && password == "123456") {
      _currentUser = UserModel(
        id: "vendor-123",
        name: "Vendedor",
        email: email,
        role: UserRole.vendor,
        companyName: "GTRONIC",
      );
      notifyListeners();
      return true;
    } else if (email.isNotEmpty && password.length >= 6) {
      _currentUser = UserModel(
        id: "client-123",
        name: "Cliente",
        email: email,
        role: UserRole.client,
      );
      notifyListeners();
      return true;
    }
    
    return false;
  }

  Future<void> signOut() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _currentUser = null;
    notifyListeners();
  }
}
