// lib/utils/helpers.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- Formateadores (Usando Intl) ---

// Para inicializar la localización de intl (¡LLAMAR EN main.dart!)
// Asegúrate de haber corrido `flutter pub add intl`
// y llama a esta función en tu main() antes de runApp:
// await initializeDateFormatting('es_VE', null); // O 'es' si prefieres formato español general
Future<void> initializeFormatting() async {
  try {
    // Intenta inicializar para Venezuela, si falla, usa español genérico
    await initializeDateFormatting('es_VE', null);
  } catch (_) {
    try {
      await initializeDateFormatting('es', null);
    } catch (e) {
      print("Error inicializando formato de fechas: $e");
      // Considera un fallback a 'en_US' si es necesario
      // await initializeDateFormatting('en_US', null);
    }
  }
  // Establecer locale por defecto para NumberFormat si es necesario
  // NumberFormat.defaultLocale = 'es_VE'; // O 'es'
}

/// Formatea una fecha DateTime a un formato legible corto (ej: Vie, 25 Abr)
String formatDateShort(DateTime? date) {
  if (date == null) return 'N/A';
  // 'es' o 'es_VE' deben estar inicializados con initializeDateFormatting
  try {
    return DateFormat.MMMEd('es').format(date);
  } catch (e) {
    // Fallback si la localización no funcionó
    return DateFormat.yMMMd().format(date);
  }
}

/// Formatea una cantidad como moneda en dólares con formato latino (ej: $5.000,00)
String formatCurrency(double? amount, {int decimalDigits = 2}) {
  if (amount == null) return '\$ N/A';
  final format = NumberFormat.currency(
    locale: 'es',        // ✅ Español, formato: 5.000,00
    symbol: '\$',        // ✅ Símbolo de dólar
    decimalDigits: decimalDigits,
  );
  try {
    return format.format(amount);
  } catch (e) {
    return '\$${amount.toStringAsFixed(decimalDigits)}';
  }
}

/// Formatea de forma compacta (ej: $5,4K / $1,2M) con formato latino
String formatCurrencyCompact(double? amount) {
  if (amount == null) return '\$ N/A';
  final format = NumberFormat.compactCurrency(
    locale: 'es',        // ✅ Español = 1,2K
    symbol: '\$',        // ✅ Símbolo de dólar
    decimalDigits: 1,    // ✅ Redondea a 1 decimal: 5,4K
  );
  try {
    return format.format(amount);
  } catch (e) {
    return '\$${amount.toStringAsFixed(1)}';
  }
}


// --- Lanzador de URLs ---

/// Abre una URL externa de forma segura (tel, http, mailto, mapa, etc.)
/// Muestra un SnackBar si falla.
Future<void> launchExternalUrl(String urlString, BuildContext context) async {
  final Uri uri = Uri.parse(urlString);
  try {
    // Verifica si se puede lanzar antes de intentar
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        // Abre fuera de la app
        mode: LaunchMode.externalApplication,
      );
    } else {
      print('No se pudo lanzar la URL (canLaunchUrl falló): $urlString');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo abrir el enlace: $urlString'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  } catch (e) {
    print('Error al lanzar URL: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al abrir: $urlString'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}

// --- Validadores (Ejemplos básicos) ---

/// Verifica si un String es un email válido (expresión regular simple)
bool isValidEmail(String? email) {
  if (email == null || email.isEmpty) return false;
  // Expresión regular básica (puedes usar una más compleja si necesitas)
  final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return emailRegex.hasMatch(email);
}

/// Verifica si un String parece un RIF venezolano válido (formato simple)
bool isValidRif(String? rif) {
  if (rif == null || rif.isEmpty) return false;
  // Formato básico: Letra (V, E, J, G, P) - 8 o 9 dígitos - 1 dígito verificador
  // Esta es una validación de FORMATO, no de si el RIF existe en el SENIAT.
  final rifRegex = RegExp(r'^[VEJPGvejpg]{1}-\d{8,9}-\d{1}$');
  return rifRegex.hasMatch(rif);
}

// Puedes añadir más helpers según necesites (ej. formatear teléfono, etc.)