import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Servicio centralizado para la gestión de Firebase
class FirebaseService {
  // Instancias de servicios Firebase
  static late FirebaseAuth _auth;
  static late FirebaseFirestore _firestore;
  static late FirebaseStorage _storage;

  // Getters para exponer servicios inicializados
  static FirebaseAuth get auth => _auth;
  static FirebaseFirestore get firestore => _firestore;
  static FirebaseStorage get storage => _storage;

  /// Inicializa todos los servicios de Firebase
  static Future<void> initialize() async {
    try {
      // Inicializar Firebase Core
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
              apiKey: "AIzaSyCsfdTQG279IY1S2n9G0qbn4k5AOgHpuoI",
              authDomain: "ventas-b2b-6fc4b.firebaseapp.com",
              projectId: "ventas-b2b-6fc4b",
              storageBucket: "ventas-b2b-6fc4b.firebasestorage.app",
              messagingSenderId: "665168840720",
              appId: "1:665168840720:web:3b61a2ac2e31914bc3a295",
              measurementId: "G-3TS3V8YRG8"
          ),
        );
      } else {
        await Firebase.initializeApp();
      }

      // Inicializar servicios
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;

      // Configurar Firestore para uso offline
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      print("✅ Firebase inicializado correctamente");

      // Verificar estado de autenticación
      _auth.authStateChanges().listen((User? user) {
        print("Estado de autenticación cambió: ${user != null ? 'Usuario autenticado' : 'No hay usuario'}");
      });
    } catch (e) {
      print("❌ Error al inicializar Firebase: $e");
      throw Exception("No se pudo inicializar Firebase: $e");
    }
  }

  /// Verifica la conectividad con Firestore
  static Future<bool> checkFirestoreConnection() async {
    try {
      // Intenta una operación simple para verificar la conexión
      await _firestore.collection('_connection_test').doc('test').set({
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Elimina el documento de prueba
      await _firestore.collection('_connection_test').doc('test').delete();

      print("✅ Conexión a Firestore verificada");
      return true;
    } catch (e) {
      print("❌ Error al verificar conexión a Firestore: $e");
      return false;
    }
  }

  /// Cierra la sesión del usuario actual
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
      print("✅ Sesión cerrada correctamente");
    } catch (e) {
      print("❌ Error al cerrar sesión: $e");
      throw Exception("No se pudo cerrar la sesión: $e");
    }
  }
}