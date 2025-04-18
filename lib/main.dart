import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'models/cart_model.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'main_navigation.dart';
import 'services/firebase_service.dart';
import 'utils/error_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb, PlatformDispatcher;

// Utilitario para manejar errores
class ErrorHandler {
  static void logError(String message, dynamic error, [StackTrace? stackTrace]) {
    print("❌ $message: $error");

    // Intentar registrar en Firebase Crashlytics si está disponible
    try {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    } catch (_) {
      // Si Crashlytics no está disponible o falla, no hacemos nada adicional
    }
  }

  static void showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// Modelo de usuario
class UserModel extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  String? get userId => _user?.uid;
  String? get vendorId => _userData?['isVendor'] == true ? _user?.uid : null;

  Future<void> checkCurrentUser() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = FirebaseAuth.instance.currentUser;

      if (_user != null) {
        await _fetchUserData();
      }

      _errorMessage = null;
    } catch (e) {
      _errorMessage = "Error al verificar usuario: $e";
      print("❌ $_errorMessage");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserData() async {
    try {
      if (_user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .get();

        if (doc.exists) {
          _userData = doc.data();
          print("✅ Datos de usuario cargados correctamente");
        } else {
          print("⚠️ No se encontraron datos para el usuario ${_user!.uid}");
        }
      }
    } catch (e) {
      print("❌ Error al cargar datos de usuario: $e");
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      _user = null;
      _userData = null;
      notifyListeners();
      print("✅ Cierre de sesión exitoso");
    } catch (e) {
      print("❌ Error al cerrar sesión: $e");
      throw e;
    }
  }
}

void main() async {
  // Esto debe ser lo primero siempre
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar la orientación de la pantalla
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    // Inicializar Firebase primero
    await FirebaseService.initialize();

    // Después configurar servicios que dependen de Firebase
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

    // Configurar Firebase Performance Monitoring
    FirebasePerformance.instance;

    // Configurar manejo de errores no capturados en zonas asíncronas
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Ejecutar la aplicación
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => Cart()),
          ChangeNotifierProvider(create: (_) => UserModel()..checkCurrentUser()),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    // Registrar error en Crashlytics si está disponible
    try {
      FirebaseCrashlytics.instance.recordError(e, stackTrace, fatal: true);
    } catch (_) {
      // Si Crashlytics no está disponible, solo registramos localmente
      print("Error crítico al iniciar la aplicación: $e");
    }

    // Muestra una aplicación de error
    runApp(ErrorApp(error: e.toString()));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GTRONIC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        primaryColor: Colors.green,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: Consumer<UserModel>(
        builder: (context, userModel, child) {
          // Mostrar spinner mientras verificamos el estado de autenticación
          if (userModel.isLoading) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Redirigir según el estado de autenticación
          return userModel.isLoggedIn ? const MainNavigation() : const LoginScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Pantalla para mostrar errores críticos
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 20),
                const Text(
                  'Error al iniciar la aplicación',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  error,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Intenta reiniciar la app
                    SystemNavigator.pop();
                  },
                  child: const Text('Reiniciar'),
                ),
              ],
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}