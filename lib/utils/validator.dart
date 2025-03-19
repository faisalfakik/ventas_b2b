// lib/utils/validators.dart
class Validators {
  // Validar que el campo no esté vacío
  static String? validateNotEmpty(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Este campo es obligatorio';
    }
    return null;
  }

  // Validar que el monto sea un número válido mayor que cero
  static String? validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresa un monto';
    }

    // Reemplazar coma por punto para manejar diferentes formatos
    value = value.replaceAll(',', '.');

    try {
      final amount = double.parse(value);
      if (amount <= 0) {
        return 'El monto debe ser mayor que cero';
      }
    } catch (e) {
      return 'Ingresa un número válido';
    }

    return null;
  }

  // Validar que sea un email válido
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Permitir email vacío
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingresa un email válido';
    }

    return null;
  }

  // Validar que sea un número de teléfono válido
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Permitir teléfono vacío
    }

    final phoneRegex = RegExp(r'^\d{8,15}$');
    if (!phoneRegex.hasMatch(value.replaceAll(RegExp(r'\D'), ''))) {
      return 'Ingresa un número de teléfono válido';
    }

    return null;
  }
}