import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import '../models/payment_model.dart';
import '../models/client_model.dart';
import '../services/payment_service.dart';
import '../services/client_service.dart';
import '../services/notification_service.dart';

class PaymentRegisterScreen extends StatefulWidget {
  final String vendorId;
  final String? clientId; // Opcional, para preseleccionar un cliente

  const PaymentRegisterScreen({
    Key? key,
    required this.vendorId,
    this.clientId,
  }) : super(key: key);

  @override
  _PaymentRegisterScreenState createState() => _PaymentRegisterScreenState();
}

class _PaymentRegisterScreenState extends State<PaymentRegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final PaymentService _paymentService = PaymentService();
  final ClientService _clientService = ClientService();
  final NotificationService _notificationService = NotificationService();
  final ImagePicker _imagePicker = ImagePicker();
  final Location _location = Location();

  String? _selectedClientId;
  String _paymentMethod = 'cash'; // Solo efectivo o depósito bancario
  bool _isLoading = false;
  File? _proofImage;
  List<Client> _clients = [];
  LocationData? _currentLocation;
  bool _isLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    // AÑADE ESTE LOG AQUÍ, justo después de super.initState()
    print("DEBUG: PaymentRegisterScreen inicializada con vendorId: ${widget.vendorId}");
    _selectedClientId = widget.clientId;
    _setupLocation();
    _loadClients();
  }

  Future<void> _setupLocation() async {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        // El usuario no habilitó el servicio de ubicación
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El servicio de ubicación es necesario para registrar abonos')),
        );
        return;
      }
    }

    // Verificar permisos de ubicación
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        // El usuario no concedió el permiso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de ubicación para registrar abonos')),
        );
        return;
      }
    }

    setState(() {
      _isLocationEnabled = true;
    });

    // Obtener ubicación actual
    try {
      _currentLocation = await _location.getLocation();
    } catch (e) {
      print('Error al obtener ubicación: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
    }
  }

  Future<void> _loadClients() async {
    // AÑADE ESTE LOG AQUÍ, al inicio del método
    print("DEBUG: Iniciando carga de clientes");
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await _clientService.getClientsByVendor(widget.vendorId);
      // AÑADE ESTE LOG AQUÍ, después de obtener los clientes
      print("DEBUG: Clientes cargados: ${clients.length}");

      setState(() {
        _clients = clients;
        _isLoading = false;
      });

      // Si se proporcionó un clientId, seleccionarlo automáticamente
      if (widget.clientId != null) {
        // AÑADE ESTE LOG AQUÍ
        print("DEBUG: Preseleccionando cliente con ID: ${widget.clientId}");
        setState(() {
          _selectedClientId = widget.clientId;
        });
      }
    } catch (e) {
      // REEMPLAZA ESTE PRINT
      print("DEBUG: Error al cargar clientes: $e");
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar clientes: $e')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error al tomar foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al tomar foto: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _proofImage = File(image.path);
        });
      }
    } catch (e) {
      print('Error al seleccionar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al seleccionar imagen: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final fileName = path.basename(imageFile.path);
      final destination = 'payment_receipts/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final ref = FirebaseStorage.instance.ref().child(destination);
      await ref.putFile(imageFile);

      return await ref.getDownloadURL();
    } catch (e) {
      print('Error al subir imagen: $e');
      return null;
    }
  }

  Future<void> _registerPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un cliente')),
      );
      return;
    }

    // Validar que tenemos ubicación si es pago en efectivo
    if (_paymentMethod == 'cash' && !_isLocationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere acceso a la ubicación para registrar abonos en efectivo')),
      );
      return;
    }

    // Validar que hay imagen si es depósito
    if (_paymentMethod == 'deposit' && _proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor adjunta el comprobante del depósito')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Subir imagen si es depósito
      String? receiptUrl;
      if (_paymentMethod == 'deposit' && _proofImage != null) {
        // AÑADE ESTE LOG AQUÍ
        print("DEBUG: Subiendo imagen de comprobante");
        receiptUrl = await _uploadImage(_proofImage!);

        if (receiptUrl == null) {
          // AÑADE ESTE LOG AQUÍ
          print("DEBUG: Error al subir imagen de comprobante");
          throw Exception('Error al subir el comprobante');
        }
        // AÑADE ESTE LOG AQUÍ
        print("DEBUG: Imagen subida con éxito: $receiptUrl");
      }

      // Obtener el monto
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      // AÑADE ESTE LOG AQUÍ
      print("DEBUG: Registrando pago: monto=$amount, método=$_paymentMethod, clienteId=$_selectedClientId");

      // Crear y registrar el pago
      final paymentId = await _paymentService.registerPayment(
        clientId: _selectedClientId!,
        vendorId: widget.vendorId,
        amount: amount,
        method: _paymentMethod,
        notes: _notesController.text.trim(),
        latitude: _currentLocation?.latitude,
        longitude: _currentLocation?.longitude,
        paymentProof: _proofImage,
        receiptUrl: receiptUrl,
      );

      // AÑADE ESTE LOG AQUÍ
      print("DEBUG: Pago registrado con ID: $paymentId");

      // Añadir esto para mostrar la confirmación
      if (paymentId != null) {
        // Enviar notificaciones
        await _notificationService.sendPaymentNotification(
          clientId: _selectedClientId!,
          vendorId: widget.vendorId,
          amount: amount,
          paymentMethod: _paymentMethod == 'deposit' ? 'depósito bancario' : 'efectivo',
          paymentId: paymentId,
        );

        setState(() {
          _isLoading = false;
        });

        // Mostrar confirmación
        _showPaymentConfirmation(paymentId, amount);
      } else {
        throw Exception('No se pudo registrar el pago');
      }
    } catch (e) {
      // REEMPLAZA ESTE PRINT
      print("DEBUG: Error detallado al registrar pago: $e");
      print("DEBUG: Stack trace: ${StackTrace.current}");
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar pago: $e')),
        );
      }
    }
  }

  void _showPaymentConfirmation(String paymentId, double amount) {
    // Buscar el nombre del cliente
    final Client? client = _clients.firstWhere(
          (c) => c.id == _selectedClientId,
      orElse: () => Client(
        id: '',
        name: 'Cliente',
        businessName: 'Empresa',
        email: '',
        phone: '',
        address: '',
        clientType: '',
        priceLevel: '',
        createdAt: DateTime.now(),
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('¡Pago Registrado!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se ha registrado el pago de:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.business, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    client?.businessName ?? 'Cliente',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  client?.name ?? 'Contacto',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now()),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Se ha enviado una notificación al cliente y a la administración.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar el diálogo
              Navigator.pop(context); // Regresar a la pantalla anterior
            },
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.receipt_long),
            label: const Text('Ver Recibo'),
            onPressed: () async {
              // Aquí se podría mostrar o compartir el recibo
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Abono', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Tarjeta de información
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.payments_outlined,
                            color: Colors.purple.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Registra un abono de cliente con su ubicación exacta',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Se enviará una notificación automática al cliente, al vendedor y a la administración con los detalles del pago.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Selección de cliente
            const Text(
              'Cliente',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedClientId,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              hint: const Text('Selecciona un cliente'),
              isExpanded: true,
              items: _clients.map((Client client) {
                return DropdownMenuItem<String>(
                  value: client.id,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        client.businessName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        client.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  _selectedClientId = value;
                });
              },
            ),

            const SizedBox(height: 24),

            // Monto del abono
            const Text(
              'Monto del Abono',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                hintText: '0.00',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingresa un monto';
                }

                try {
                  final amount = double.parse(value.replaceAll(',', '.'));
                  if (amount <= 0) {
                    return 'El monto debe ser mayor a cero';
                  }
                } catch (e) {
                  return 'Ingresa un monto válido';
                }

                return null;
              },
            ),

            const SizedBox(height: 24),

            // Método de pago (solo efectivo o depósito)
            const Text(
              'Tipo de Abono',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildPaymentMethodChip(
                  method: 'cash',
                  label: 'Efectivo',
                  icon: Icons.payments,
                ),
                _buildPaymentMethodChip(
                  method: 'deposit',
                  label: 'Depósito bancario',
                  icon: Icons.account_balance,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Notas adicionales
            const Text(
              'Notas Adicionales',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                hintText: _paymentMethod == 'deposit'
                    ? 'Banco, número de transferencia, etc.'
                    : 'Ej. Abono por factura #12345',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              maxLines: 3,
              validator: _paymentMethod == 'deposit' ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Por favor proporciona detalles del depósito';
                }
                return null;
              } : null,
            ),

            const SizedBox(height: 24),

            // Comprobante de pago (solo para depósito)
            if (_paymentMethod == 'deposit') ...[
              const Text(
                'Comprobante de Depósito',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildImagePicker(),
              const SizedBox(height: 24),
            ],

            // Botón de registro
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _registerPayment,
                icon: const Icon(Icons.check_circle),
                label: const Text(
                  'Registrar Abono',
                  style: TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip({
    required String method,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == method;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _paymentMethod = method;
          });
        }
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: Colors.purple,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        InkWell(
          onTap: _takePhoto,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _proofImage != null
                ? Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _proofImage!,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: (0.1 * 255).toDouble()),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        setState(() {
                          _proofImage = null;
                        });
                      },
                    ),
                  ),
                ),
              ],
            )
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 36,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tomar foto del comprobante',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '(requerido)',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImageFromGallery,
          icon: const Icon(Icons.photo_library),
          label: const Text('Seleccionar de la galería'),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}