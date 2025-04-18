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
import '../models/client_model.dart';
import '../services/payment_service.dart';
import '../services/client_service.dart';
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
  final ClientService _clientService = ClientService();
  final NotificationService _notificationService = NotificationService();
  final EmailService _emailService = EmailService();
  final ImagePicker _imagePicker = ImagePicker();
  final Location _location = Location();

  String? _selectedClientId;
  String _paymentMethod = 'cash'; // Solo efectivo o depósito bancario
  bool _isLoading = false;
  List<File> _selectedImages = [];
  bool _showUploadProgress = false;
  List<Client> _clients = [];
  LocationData? _currentLocation;
  bool _isLocationEnabled = false;
  Payment? _lastRegisteredPayment;
  Client? _selectedClient; // Variable añadida aquí

  // Variables adicionales necesarias
  String? _lastRegisteredPaymentId;
  String? _receiptFilePath;

  @override
  void initState() {
    super.initState();
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
      final clients = await _clientService.getClientsByVendor(widget.vendorId);
      print("DEBUG: Clientes cargados: ${clients.length}");

      setState(() {
        _clients = clients;
        _isLoading = false;
      });

      // Si se proporcionó un clientId, seleccionarlo automáticamente
      if (widget.clientId != null) {
        print("DEBUG: Preseleccionando cliente con ID: ${widget.clientId}");
        // Buscar el cliente correspondiente al ID para tenerlo completo
        final selectedClient = clients.firstWhere(
              (client) => client.id == widget.clientId,
          orElse: () => Client(id: '', name: '', email: '', phone: '', address: ''),
        );

        if (selectedClient.id.isNotEmpty) {
          setState(() {
            _selectedClientId = widget.clientId;
            _selectedClient = selectedClient; // Inicializa _selectedClient
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
            'clientId': _selectedClientId ?? '',
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
    // Comprobar si tenemos el ID del cliente seleccionado
    if (_formKey.currentState!.validate() && _selectedClientId != null) {
      setState(() => _isLoading = true);

      try {
        // Obtener el cliente seleccionado
        final Client? client = _clients.firstWhere(
              (c) => c.id == _selectedClientId,
          orElse: () => Client(id: '', name: '', email: '', phone: '', address: ''),
        );

        if (client == null) {
          throw 'Cliente no encontrado';
        }

        // Verificar si hay al menos una imagen para depósito bancario
        if (_paymentMethod == 'deposit' && _selectedImages.isEmpty) {
          throw 'Debe incluir al menos una imagen del comprobante';
        }

        // Obtener monto
        final double amount = double.parse(
          _amountController.text.replaceAll(',', '.'),
        );

        // Subir imágenes y obtener URLs
        List<String> imageUrls = [];
        if (_selectedImages.isNotEmpty) {
          imageUrls = await _uploadImages();
          if (imageUrls.isEmpty && _paymentMethod == 'deposit') {
            throw 'Error al subir las imágenes';
          }
        }

        // Determinar la URL principal para compatibilidad
        String? paymentProofUrl = imageUrls.isNotEmpty ? imageUrls[0] : null;

        // Registrar el pago
        final String? paymentId = await _paymentService.registerPaymentWithImages(
          clientId: _selectedClientId!,
          vendorId: widget.vendorId,
          amount: amount,
          method: _paymentMethod, // 'cash' o 'deposit'
          notes: _notesController.text,
          latitude: _currentLocation?.latitude,
          longitude: _currentLocation?.longitude,
          paymentProofUrl: paymentProofUrl, // URL principal (para compatibilidad)
          imageUrls: imageUrls, // Todas las URLs
        );

        if (paymentId == null) {
          throw 'Error al registrar el pago';
        }

        // Obtener el pago registrado
        final payment = await _paymentService.getPaymentById(paymentId);

        if (payment == null) {
          throw 'No se pudo recuperar el pago registrado';
        }

        setState(() {
          _lastRegisteredPayment = payment;
          _lastRegisteredPaymentId = paymentId;
        });

        // Generar y guardar el recibo PDF
        final String? receiptPath = await _generateAndUploadReceipt(payment);

        setState(() {
          _receiptFilePath = receiptPath;
        });

        // Enviar notificación por correo al cliente y a la administración
        if (client.email != null && client.email!.isNotEmpty) {
          await _sendNotificationEmails(payment, client, imageUrls);
        }

        setState(() {
          _isLoading = false;
        });

        // Mostrar confirmación
        if (mounted) {
          _showPaymentConfirmation(payment, amount);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar el pago: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor complete todos los campos requeridos')),
      );
    }
  }

  // Genera el recibo en PDF y devuelve la ruta del archivo
  Future<String> _generateReceiptPdf(Payment payment, Client client) async {
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
                      client.businessName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Contacto: ${client.name}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    if (client.email.isNotEmpty) pw.SizedBox(height: 2),
                    if (client.email.isNotEmpty) pw.Text(
                      'Email: ${client.email}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    if (client.phone.isNotEmpty) pw.SizedBox(height: 2),
                    if (client.phone.isNotEmpty) pw.Text(
                      'Teléfono: ${client.phone}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                      ),
                    ),
                    if (client.address.isNotEmpty) pw.SizedBox(height: 2),
                    if (client.address.isNotEmpty) pw.Text(
                      'Dirección: ${client.address}',
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
      final Client? client = await _clientService.getClientById(payment.clientId);
      if (client == null) {
        throw 'No se pudo obtener la información del cliente';
      }

      // Generar el PDF del recibo
      final String pdfPath = await _generateReceiptPdf(payment, client);

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

// AÑADE AQUÍ EL MÉTODO _sendNotificationEmails
  Future<void> _sendNotificationEmails(Payment payment, Client client, List<String> imageUrls) async {
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
      if (client.email != null && client.email!.isNotEmpty) {
        await _emailService.sendEmail(
          toEmail: client.email!,
          subject: 'Confirmación de Abono - ${client.businessName}',
          body: messageBody,
          attachmentUrls: imageUrls.isNotEmpty ? [imageUrls[0]] : null,
        );
      }

      // Enviar a administración
      for (String adminEmail in adminEmails) {
        await _emailService.sendEmail(
          toEmail: adminEmail,
          subject: 'Nuevo Abono - ${client.businessName}',
          body: '''
Nuevo abono registrado por el vendedor:

Cliente: ${client.businessName} (${client.name})
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

// AÑADIR AQUÍ EL MÉTODO _sendReceiptByEmail
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

// Mostrar el recibo en PDF
  Future<void> _viewReceiptPdf([Payment? payment, Client? client]) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Caso 1: Se proporcionan payment y client directamente
      if (payment != null && client != null) {
        // Generar el PDF
        final pdfPath = await _generateReceiptPdf(payment, client);

        setState(() {
          _isLoading = false;
        });

        // Compartir el PDF
        await Share.shareFiles(
          [pdfPath],
          subject: 'Recibo de Pago - ${client.businessName}',
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
            await Share.shareFiles([_receiptFilePath!], text: 'Recibo de pago');
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
            await Share.shareFiles([receiptPath], text: 'Recibo de pago');

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
                  final Client? client = await _clientService.getClientById(_lastRegisteredPayment!.clientId);
                  if (client != null) {
                    _viewReceiptPdf(_lastRegisteredPayment!, client);
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


// Método para reenviar el recibo por correo
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
      final Client? client = await _clientService.getClientById(payment.clientId);
      final String clientName = client?.businessName ?? client?.name ?? 'Cliente';

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

// Método para limpiar el formulario
  void _resetForm() {
    setState(() {
      _selectedClient = null;
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
              Container(
                height: 60,
                child: DropdownSearch<Client>(
                  popupProps: PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        labelText: "Buscar cliente",
                        hintText: "Nombre del cliente",
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    itemBuilder: (context, client, isSelected) {
                      return ListTile(
                        title: Text(client.businessName),
                        subtitle: Text(client.name),
                        selected: isSelected,
                      );
                    },
                  ),
                  items: _clients,
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      labelText: "Seleccionar Cliente",
                      hintText: "Buscar o seleccionar cliente",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  itemAsString: (Client client) => "${client.businessName} - ${client.name}",
                  onChanged: (Client? client) {
                    if (client != null) {
                      setState(() {
                        _selectedClientId = client.id;
                        _selectedClient = client;
                      });
                      print("DEBUG: Cliente seleccionado: ${client.name} (${client.id})");
                    }
                  },
                  selectedItem: _selectedClient,
                ),
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

              // Sección de fotos para cualquier método de pago
              Text(
                _paymentMethod == 'deposit' ? 'Comprobante de Depósito' : 'Fotos de Billetes',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildImagePicker(),
              const SizedBox(height: 24),

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