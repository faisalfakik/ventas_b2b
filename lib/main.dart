import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/cart_model.dart';
import 'screens/login_screen.dart'; // Importa la pantalla de login
// import 'screens/home_screen.dart'; // Comenta o elimina esta línea si no la necesitas

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Cart()),
      ],
      child: const MyApp(),
    ),
  );
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
      home: const LoginScreen(), // Cambia a LoginScreen
      debugShowCheckedModeBanner: false,
    );
  }
}
