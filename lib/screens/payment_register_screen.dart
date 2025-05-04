import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/payment_model.dart';
import '../models/customer_model.dart' as cust;
import '../services/payment_service.dart';
import '../services/customer_service.dart';
import 'package:cross_file/cross_file.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import '../services/notification_service.dart';
import '../services/email_service.dart'; // Asegúrate de tener este servicio o crea uno

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
  final CustomerService _customerService = CustomerService();
  final NotificationService _notificationService = NotificationService();
  final EmailService _emailService = EmailService();
  final ImagePicker _imagePicker = ImagePicker();
  final Location _location = Location();

  String? _selectedCustomerId;
  String _paymentMethod = 'cash'; // Solo efectivo o depósito bancario
  bool _isLoading = false;
  List<File> _selectedImages = [];
  bool _showUploadProgress = false;
  List<cust.Customer> _clients = [];
  LocationData? _currentLocation;
  bool _isLocationEnabled = false;
  Payment? _lastRegisteredPayment;
  cust.Customer? _selectedCustomer;

  // Variables adicionales necesarias
  String? _lastRegisteredPaymentId;
  String? _receiptFilePath;

  @override
  void initState() {
    super.initState();
    print("DEBUG: PaymentRegisterScreen inicializada con vendorId: ${widget.vendorId}");
    _loadClients();
  }

  Future<void> _setupLocation() async {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        // El usuario no habilitó el servicio de ubicación
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El servicio de ubicación es necesario para registrar abonos')),
          );
        }
        return;
      }
    }

    // Verificar permisos de ubicación
    PermissionStatus permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        // El usuario no concedió el permiso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se necesita permiso de ubicación para registrar abonos')),
          );
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener ubicación: $e')),
        );
      }
    }
  }

  Future<void> _loadClients() async {
    print("DEBUG: Iniciando carga de clientes");
    setState(() {
      _isLoading = true;
    });

    try {
      final clients = await _customerService.getAllClients();
      print("DEBUG: Clientes cargados: ${clients.length}");

      setState(() {
        _clients = clients;
        _isLoading = false;
      });

      if (widget.clientId != null) {
        print("DEBUG: Preseleccionando cliente con ID: ${widget.clientId}");
        final selectedClient = clients.firstWhere(
          (client) => client.id == widget.clientId,
          orElse: () => cust.Customer(
            id: '',
            businessName: '',
            name: '',
            email: '',
            phone: '',
            address: ''
          ),
        );

        if (selectedClient.id.isNotEmpty) {
          setState(() {
            _selectedCustomerId = widget.clientId;
            _selectedCustomer = selectedClient;
          });
        }
      }
    } catch (e) {
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
          _selectedImages.add(File(image.path));
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
          _selectedImages.add(File(image.path));
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

  Future<List<String>> _uploadImages() async {
    try {
      setState(() {
        _showUploadProgress = true;
      });

      List<String> imageUrls = [];
      final uuid = Uuid();

      for (int i = 0; i < _selectedImages.length; i++) {
        final fileName = 'payment_images/${widget.vendorId}/${uuid.v4()}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);

        // Subir imagen con metadata
        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'date': DateTime.now().toIso8601String(),
            'clientId': _selectedCustomerId ?? '',
            'vendorId': widget.vendorId,
            'type': i == 0 ? 'main_proof' : 'additional_photo',
          },
        );

        await ref.putFile(_selectedImages[i], metadata);
        final downloadUrl = await ref.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      return imageUrls;
    } catch (e) {
      print('Error al subir imágenes: $e');
      return [];
    } finally {
      setState(() {
        _showUploadProgress = false;
      });
    }
  }

  Future<void> _registerPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione un cliente')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Subir imágenes si hay alguna
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await _uploadImages();
      }

      // Registrar el pago
      final paymentId = await _paymentService.registerPayment(
        clientId: _selectedCustomer!.id,
        vendorId: widget.vendorId,
        amount: double.parse(_amountController.text),
        method: _paymentMethod,
        notes: _notesController.text,
        latitude: _currentLocation?.latitude,
        longitude: _currentLocation?.longitude,
        imageUrls: imageUrls,
      );

      if (paymentId == null) {
        throw 'Error al registrar el pago';
      }

      // Obtener el pago registrado
      final registeredPayment = await _paymentService.getPaymentById(paymentId);

      if (registeredPayment == null) {
        throw 'No se pudo recuperar el pago registrado';
      }

      setState(() {
        _lastRegisteredPayment = registeredPayment;
        _lastRegisteredPaymentId = paymentId;
      });

      // Generar y guardar el recibo PDF
      final String? receiptPath = await _generateAndUploadReceipt(registeredPayment);

      setState(() {
        _receiptFilePath = receiptPath;
      });

      // Enviar notificación por correo al cliente y a la administración
      if (_selectedCustomer != null && _selectedCustomer!.email != null && _selectedCustomer!.email!.isNotEmpty) {
        await _sendNotificationEmails(registeredPayment, _selectedCustomer!, imageUrls);
      }

      setState(() {
        _isLoading = false;
      });

      // Mostrar confirmación
      if (mounted) {
        _showPaymentConfirmation(registeredPayment, double.parse(_amountController.text));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar el pago: $e')),
      );
    }
  }

  // Genera el recibo en PDF y devuelve la ruta del archivo
  Future<String> _generateReceiptPdf(Payment payment, cust.Customer Customer) async {
    final pdf = pw.Document();

    // Agregar página con recibo
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RECIBO DE PAGO',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple800,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Fecha: ${DateFormat('dd/MM/yyyy').format(payment.createdAt)}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                        ),
                      ),
                      pw.Text(
                        'Folio: REC-${payment.id.substring(0, math.min(payment.id.length, 8))}',
                        style: const pw.TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'GTRONIC',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.purple800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'contacto@gtronic.com',
                        style: const pw.TextStyle(
                          fontSize: 10,
                        ),
                      ),
                      pw.Text(
                        'Tel: +52 (123) 456-7890',
                        style: const pw.TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Datos del cliente
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DATOS DEL CLIENTE',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: PdfColors.purple800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      Customer.businessName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Contacto: ${Customer.name}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    if (_selectedCustomer?.email?.isNotEmpty == true) pw.SizedBox(height: 2),
                    if (_selectedCustomer?.email?.isNotEmpty == true) pw.Text(
                      'Email: ${_selectedCustomer?.email ?? ''}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    if (_selectedCustomer?.phone?.isNotEmpty == true) pw.SizedBox(height: 2),
                    if (_selectedCustomer?.phone?.isNotEmpty == true) pw.Text(
                      'Teléfono: ${_selectedCustomer?.phone ?? ''}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    if (_selectedCustomer?.address?.isNotEmpty == true) pw.SizedBox(height: 2),
                    if (_selectedCustomer?.address?.isNotEmpty == true) pw.Text(
                      'Dirección: ${_selectedCustomer?.address ?? ''}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Detalles del pago
              pw.Container(
                padding: const pw.EdgeInsets.all(15),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'DETALLES DEL PAGO',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                        color: PdfColors.purple800,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text('Fecha y Hora:'),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt)),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text('Método de Pago:'),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(payment.method == 'cash' ? 'Efectivo' : 'Depósito bancario'),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          flex: 2,
                          child: pw.Text('Monto:'),
                        ),
                        pw.Expanded(
                          flex: 3,
                          child: pw.Text(
                              '\$${payment.amount.toStringAsFixed(2)}',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)
                          ),
                        ),
                      ],
                    ),
                    if (payment.notes?.isNotEmpty == true) ...[
                      pw.SizedBox(height: 8),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text('Notas:'),
                          ),
                          pw.Expanded(
                            flex: 3,
                            child: pw.Text(payment.notes ?? ''),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              pw.SizedBox(height: 40),

              // Firma
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 150,
                        height: 0.5,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Firma de quien recibe',
                        style: const pw.TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 150,
                        height: 0.5,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        'Sello',
                        style: const pw.TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Pie de página
              pw.Spacer(),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Este documento es un comprobante de pago válido',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'GTRONIC - Todos los derechos reservados ${DateTime.now().year}',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/recibo_${payment.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  Future<String?> _generateAndUploadReceipt(Payment payment) async {
    try {
      // Obtener datos del cliente
      final cust.Customer? Customer = await _customerService.getClientById(payment.clientId);
      if (Customer == null) {
        throw 'No se pudo obtener la información del cliente';
      }

      // Generar el PDF del recibo
      final String pdfPath = await _generateReceiptPdf(payment, Customer);

      // Subir el PDF a Firebase Storage - MODIFICADO PARA CORREGIR EL ERROR
      final String fileName = 'receipts/${payment.id}.pdf';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);

      // Añadir metadata explícitamente para evitar el error de null
      final SettableMetadata metadata = SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'paymentId': payment.id,
          'clientId': payment.clientId,
          'date': payment.createdAt.toIso8601String(),
        },
      );

      // Usar putFile con metadata explícita
      final UploadTask uploadTask = ref.putFile(File(pdfPath), metadata);
      final TaskSnapshot taskSnapshot = await uploadTask;
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Actualizar el documento del pago con la URL del recibo
      await FirebaseFirestore.instance
          .collection('payments')
          .doc(payment.id)
          .update({'receiptUrl': downloadUrl});

      return pdfPath;
    } catch (e) {
      print('Error al generar o subir el recibo: $e');
      // Retornar el pdfPath aunque falle la subida a Storage
      return File('${(await getTemporaryDirectory()).path}/recibo_${payment.id}_${DateTime.now().millisecondsSinceEpoch}.pdf').path;
    }
  }

  Future<void> _sendNotificationEmails(Payment payment, cust.Customer Customer, List<String> imageUrls) async {
    try {
      // Correos de administración (puedes ajustar según tu estructura)
      final List<String> adminEmails = ['admin@tuempresa.com'];

      // Crear el cuerpo del mensaje
      final String messageBody = '''
Estimado cliente,

Se ha registrado un abono a su cuenta con los siguientes detalles:

Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt)}
Monto: \$${payment.amount.toStringAsFixed(2)}
Método: ${payment.method == 'cash' ? 'Efectivo' : 'Depósito bancario'}
Vendedor: ${widget.vendorId}

${payment.notes != null && payment.notes!.isNotEmpty ? 'Notas: ${payment.notes}' : ''}

Este es un mensaje automático, por favor no responda a este correo.

Atentamente,
Departamento de Cobranza
    ''';

      // Enviar al cliente
      if (Customer.email != null && Customer.email!.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: Customer.email!,
          subject: 'Confirmación de Abono - ${Customer.businessName}',
          body: messageBody,
          attachmentUrls: imageUrls.isNotEmpty ? [imageUrls[0]] : null,
        );
      }

      // Enviar a administración
      for (String adminEmail in adminEmails) {
        await _emailService.sendEmail(
          toEmail: adminEmail,
          subject: 'Nuevo Abono - ${Customer.businessName}',
          body: '''
Nuevo abono registrado por el vendedor:

Cliente: ${Customer.businessName} (${Customer.name})
Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt)}
Monto: \$${payment.amount.toStringAsFixed(2)}
Método: ${payment.method == 'cash' ? 'Efectivo' : 'Depósito bancario'}
${payment.notes != null && payment.notes!.isNotEmpty ? 'Notas: ${payment.notes}' : ''}
''',
          attachmentUrls: imageUrls,
        );
      }
    } catch (e) {
      print('Error al enviar notificaciones por correo: $e');
      // No interrumpimos el flujo principal por errores en notificaciones
    }
  }

  Future<void> _sendReceiptByEmail(
      Payment payment,
      String receiptPath,
      String clientName,
      String vendorName) async {
    try {
      // Obtener el correo del cliente
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(payment.clientId)
          .get();
      final clientData = clientDoc.data();
      final String? clientEmail = clientData?['email'];

      // Verificar si el cliente tiene correo
      if (clientEmail == null || clientEmail.isEmpty) {
        print('El cliente no tiene correo electrónico');
        return;
      }

      // Correo para administración
      String adminEmail = 'admin@empresa.com'; // Email por defecto

      // Preparar correo
      final subject = 'Recibo de pago - $clientName';

      // Usar tu servicio de email para enviar
      await _emailService.sendReceiptEmail(
        clientEmail: clientEmail,
        adminEmail: adminEmail,
        vendorEmail: '', // Opcional
        subject: subject,
        body: 'Adjunto encontrará el recibo del pago realizado.',
        attachmentPath: receiptPath,
      );

      print('Correo enviado exitosamente');
    } catch (e) {
      print('Error al enviar el correo: $e');
    }
  }

  Future<void> _viewReceiptPdf([Payment? payment, cust.Customer? Customer]) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Caso 1: Se proporcionan payment y Customer directamente
      if (payment != null && Customer != null) {
        // Generar el PDF
        final pdfPath = await _generateReceiptPdf(payment, Customer);

        setState(() {
          _isLoading = false;
        });

        // Compartir el PDF
        await Share.shareXFiles(
          [XFile(pdfPath)],
          subject: 'Recibo de Pago - ${Customer.businessName}',
          text: 'Adjunto encontrará el recibo de pago por \$${payment.amount.toStringAsFixed(2)}. Gracias por su pago.',
        );
      }
      // Caso 2: Se usa el último pago registrado
      else {
        if (_lastRegisteredPaymentId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay recibo disponible')),
          );
          return;
        }

        setState(() => _isLoading = true);

        try {
          // Si ya tenemos la ruta del archivo
          if (_receiptFilePath != null) {
            await Share.shareXFiles([XFile(_receiptFilePath!)], text: 'Recibo de pago');
          } else {
            // Obtener el pago para generar el recibo
            final payment = await _paymentService.getPaymentById(_lastRegisteredPaymentId!);

            if (payment == null) {
              throw 'No se pudo recuperar el pago';
            }

            // Generar el recibo
            final receiptPath = await _generateAndUploadReceipt(payment);

            if (receiptPath == null) {
              throw 'No se pudo generar el recibo';
            }

            // Compartir el recibo
            await Share.shareXFiles([XFile(receiptPath)], text: 'Recibo de pago');

            setState(() {
              _receiptFilePath = receiptPath;
            });
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al mostrar el recibo: $e')),
          );
        } finally {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("DEBUG: Error al mostrar recibo: $e");
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al mostrar el recibo: $e')),
        );
      }
    }
  }

  void _showPaymentConfirmation(Payment payment, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pago Registrado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50),
              const SizedBox(height: 10),
              Text('Se ha registrado un pago de \$${amount.toStringAsFixed(2)}'),
              const SizedBox(height: 20),
              const Text('¿Qué desea hacer con el recibo?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (_lastRegisteredPayment != null) {
                  // Obtener el cliente
                  final cust.Customer? Customer = await _customerService.getClientById(_lastRegisteredPayment!.clientId);
                  if (Customer != null) {
                    _viewReceiptPdf(_lastRegisteredPayment!, Customer);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No se pudo obtener información del cliente')),
                    );
                  }
                } else {
                  _viewReceiptPdf();
                }
              },
              child: const Text('Ver Recibo'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _sendReceiptPdf();
              },
              child: const Text('Reenviar por Correo'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetForm();
              },
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendReceiptPdf() async {
    if (_lastRegisteredPaymentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay recibo disponible')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Obtener el pago
      final payment = await _paymentService.getPaymentById(_lastRegisteredPaymentId!);

      if (payment == null) {
        throw 'No se pudo recuperar el pago';
      }

      // Si no tenemos la ruta del archivo, generar el recibo
      if (_receiptFilePath == null) {
        final receiptPath = await _generateAndUploadReceipt(payment);

        if (receiptPath == null) {
          throw 'No se pudo generar el recibo';
        }

        setState(() {
          _receiptFilePath = receiptPath;
        });
      }

      // Obtener datos del cliente
      final cust.Customer? Customer = await _customerService.getClientById(payment.clientId);
      final String clientName = Customer?.businessName ?? Customer?.name ?? 'Cliente';

      // Obtener datos del vendedor
      final vendorSnapshot = await FirebaseFirestore.instance
          .collection('vendors')
          .doc(payment.vendorId)
          .get();
      final vendorData = vendorSnapshot.data();
      final String vendorName = vendorData?['name'] ?? 'Vendedor';

      // Enviar el recibo por correo
      await _sendReceiptByEmail(payment, _receiptFilePath!, clientName, vendorName);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recibo enviado por correo electrónico')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar el recibo: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedCustomer = null;
      _amountController.clear();
      _notesController.clear();
      _paymentMethod = 'Efectivo';
      _lastRegisteredPaymentId = null;
      _receiptFilePath = null;
    });
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
            // Nuevo selector de clientes con búsqueda
            Container( // Contenedor que envuelve DropdownSearch
              height: 60, // Altura del contenedor
              // TODO: Deshabilitado temporalmente por incompatibilidad con dropdown_search 6.0.2. Revisar en la versión 1.2.
              /*
              child: DropdownSearch<cust.Customer>( // Inicio del Widget DropdownSearch
                // --- Propiedades del Popup (Menú desplegable) ---
                popupProps: PopupProps.menu(
                  showSearchBox: true, // Muestra la caja de búsqueda
                  searchFieldProps: TextFieldProps( // Propiedades del campo de búsqueda
                    decoration: InputDecoration(
                      hintText: 'Buscar cliente...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  itemBuilder: (BuildContext context, cust.Customer customer, bool isSelected, bool isEnabled) {
                    return ListTile(
                      title: Text(customer.businessName),
                      subtitle: Text(customer.name),
                      selected: isSelected,
                      enabled: isEnabled,
                    );
                  },
                ),

                // --- Decoración y estilo del campo principal ---

                // --- Constructor personalizado para el campo ---
                dropdownBuilder: (context, selectedItem) {
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Text(
                      selectedItem == null
                          ? "Seleccionar Cliente"
                          : "${selectedItem.businessName} - ${selectedItem.name}",
                      style: TextStyle(
                        color: selectedItem == null ? Colors.grey : Colors.black,
                      ),
                    ),
                  );
                },

                // --- Datos y Configuración Principal ---
                asyncItems: (String? filter) async {
                  return _clients;
                },

                // --- Cómo mostrar el item seleccionado y en la lista ---
                itemAsString: (cust.Customer customer) => "${customer.businessName} - ${customer.name}",

                // --- Acción al cambiar la selección ---
                onChanged: (cust.Customer? customer) {
                  if (customer != null) {
                    setState(() {
                      _selectedCustomerId = customer.id;
                      _selectedCustomer = customer;
                    });
                    print("DEBUG: Cliente seleccionado: ${customer.name} (${customer.id})");
                  } else {
                    setState(() {
                      _selectedCustomerId = null;
                      _selectedCustomer = null;
                    });
                  }
                },

                // --- El item que está seleccionado actualmente ---
                selectedItem: _selectedCustomer,
              ), // Fin del Widget DropdownSearch
              */
            ), // Fin del Container

            const SizedBox(height: 24),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título y descripción
        Row(
          children: [
            Icon(
              Icons.photo_camera,
              size: 18,
              color: Colors.grey.shade700,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar fotos del pago',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    _paymentMethod == 'cash'
                        ? 'Toma fotos de los billetes recibidos'
                        : 'Adjunta comprobante de depósito',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Grid de imágenes seleccionadas
        if (_selectedImages.isNotEmpty) ...[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImages[index],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedImages.removeAt(index);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // Botones de acción
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Galería'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Mensaje si no hay imágenes
        if (_selectedImages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _paymentMethod == 'deposit'
                  ? 'Es necesario adjuntar comprobante para depósitos'
                  : 'Recomendado: Toma fotos de los billetes como evidencia',
              style: TextStyle(
                color: _paymentMethod == 'deposit' ? Colors.red.shade700 : Colors.blue.shade700,
                fontSize: 13,
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