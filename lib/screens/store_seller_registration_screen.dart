import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StoreSellerRegistrationScreen extends StatefulWidget {
  const StoreSellerRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<StoreSellerRegistrationScreen> createState() => _StoreSellerRegistrationScreenState();
}

class _StoreSellerRegistrationScreenState extends State<StoreSellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _rifController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _selectedStoreType;

  // Tipos de tienda disponibles
  final List<String> _storeTypes = [
    'Tienda minorista',
    'Distribuidor autorizado',
    'Punto de venta especializado',
    'Otro'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _rifController.dispose();
    super.dispose();
  }

  // Validaciones específicas
  bool _isValidRif(String rif) {
    // Formato RIF: Una letra seguida de 9 dígitos
    final RegExp rifRegex = RegExp(r'^[A-Z][0-9]{9}$');
    return rifRegex.hasMatch(rif);
  }

  bool _isValidPhone(String phone) {
    // Validar formato de teléfono (ajustar según el formato deseado)
    final RegExp phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    return phoneRegex.hasMatch(phone);
  }

  bool _isValidEmail(String email) {
    // Expresión regular corregida sin comillas simples problemáticas
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // Método para realizar el registro
  Future<void> _register() async {
    // Validar el formulario
    if (!_formKey.currentState!.validate()) return;

    // Cerrar el teclado
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Crear usuario en Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 2. Crear documento para la tienda
      final storeRef = FirebaseFirestore.instance.collection('stores').doc();

      await storeRef.set({
        'name': _storeNameController.text.trim(),
        'address': _storeAddressController.text.trim(),
        'rif': _rifController.text.trim().toUpperCase(),
        'type': _selectedStoreType,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Crear documento para el vendedor
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': 'store_seller',
        'storeId': storeRef.id,
        'storeName': _storeNameController.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      });

      // 4. Actualizar el perfil en Firebase Auth
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // 5. Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro exitoso. Ahora puedes iniciar sesión.'),
            backgroundColor: Colors.green,
          ),
        );

        // 6. Navegar de regreso a la pantalla de inicio de sesión
        Navigator.of(context).pop();
      }
    } catch (e) {
      String errorMsg = 'Error al registrarse';

      // Manejar errores específicos de Firebase Auth
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMsg = 'Este correo electrónico ya está registrado';
            break;
          case 'weak-password':
            errorMsg = 'La contraseña es demasiado débil';
            break;
          case 'invalid-email':
            errorMsg = 'El correo electrónico no es válido';
            break;
          default:
            errorMsg = 'Error: ${e.message}';
        }
      }

      setState(() {
        _errorMessage = errorMsg;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Vendedor de Tienda'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título principal
                const Text(
                  'Crear Cuenta Nueva',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Sección: Información Personal
                _buildSectionTitle('Información Personal'),
                const SizedBox(height: 16),

                // Nombre completo
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingrese su nombre completo';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Correo electrónico
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingrese su correo electrónico';
                    }
                    if (!_isValidEmail(value.trim())) {
                      return 'Por favor ingrese un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Teléfono
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                    hintText: 'Ej: +584141234567',
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingrese su número de teléfono';
                    }
                    if (!_isValidPhone(value.trim())) {
                      return 'Por favor ingrese un número de teléfono válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sección: Información de la Tienda
                _buildSectionTitle('Información de la Tienda'),
                const SizedBox(height: 16),

                // Nombre de la tienda
                TextFormField(
                  controller: _storeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la tienda',
                    prefixIcon: Icon(Icons.store),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingrese el nombre de la tienda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Dirección de la tienda
                TextFormField(
                  controller: _storeAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de la tienda',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingrese la dirección de la tienda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // RIF
                TextFormField(
                  controller: _rifController,
                  decoration: const InputDecoration(
                    labelText: 'RIF de la tienda',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                    hintText: 'Ej: J123456789',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingrese el RIF de la tienda';
                    }
                    if (!_isValidRif(value.trim().toUpperCase())) {
                      return 'El RIF debe tener el formato: una letra seguida de 9 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Tipo de tienda
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Tipo de tienda',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Seleccione el tipo de tienda'),
                  value: _selectedStoreType,
                  items: _storeTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStoreType = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Por favor seleccione un tipo de tienda';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sección: Credenciales de acceso
                _buildSectionTitle('Credenciales de Acceso'),
                const SizedBox(height: 16),

                // Contraseña
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingrese una contraseña';
                    }
                    if (value.length < 6) {
                      return 'La contraseña debe tener al menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmar contraseña
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor confirme su contraseña';
                    }
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Mensaje de error
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Botón de registro
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'REGISTRARME',
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 16),

                // Enlace para volver a login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿Ya tienes una cuenta?'),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Iniciar sesión'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Nota de privacidad
                const Text(
                  'Al registrarte, aceptas nuestros términos y políticas de privacidad.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget para construir los títulos de sección
  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        const Divider(),
      ],
    );
  }
}