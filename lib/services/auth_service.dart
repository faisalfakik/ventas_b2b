import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;
  User? get firebaseUser => _auth.currentUser;
  bool get isAuthenticated => _auth.currentUser != null;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    try {
      // Esperar brevemente antes de intentar acceder a Firestore
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Buscar el documento del usuario en Firestore
      DocumentSnapshot doc = await _firestore.collection('users').doc(firebaseUser.uid).get();

      if (doc.exists) {
        // Si el documento existe, crea un modelo de usuario
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _currentUser = UserModel.fromMap(data, doc.id);
        print("Usuario autenticado con rol: ${_currentUser?.role}");
      } else {
        // Si el documento no existe, crea uno básico con el email
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'name': firebaseUser.displayName ?? 'Usuario',
          'email': firebaseUser.email ?? '',
          'role': 'client', // Rol predeterminado
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Recargar la información
        doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        _currentUser = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id
        );
      }
    } catch (e) {
      print('Error fetching user data: $e');
      // Crear un usuario básico para no interrumpir el flujo
      _currentUser = UserModel(
        id: firebaseUser.uid,
        name: firebaseUser.displayName ?? 'Usuario',
        email: firebaseUser.email ?? '',
        role: UserRole.client, // Rol predeterminado
      );
    }

    notifyListeners();
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password
      );
      
      // Esperar brevemente para asegurar que la autenticación se complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      return credential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? phoneNumber,
  }) async {
    try {
      // Crear usuario en Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password
      );

      // Crear usuario en Firestore con datos completos
      await _firestore.collection('users').doc(result.user!.uid).set({
        'name': name,
        'email': email,
        'role': _roleToString(role),
        'companyName': companyName,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result;
    } catch (e) {
      print('Error registering: $e');
      rethrow;
    }
  }

  String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.vendor:
        return 'vendor';
      case UserRole.client:
        return 'client';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
}
