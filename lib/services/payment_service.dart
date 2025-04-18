import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Temporalmente comentado
import '../models/payment_model.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';

// Añadir esta clase Mock para reemplazar las notificaciones
class MockNotificationsPlugin {
  void initialize(dynamic settings) {
    print("MOCK: Inicializando notificaciones");
  }

  Future<void> show(int id, String title, String body, dynamic details) async {
    print("MOCK NOTIFICATION: $title - $body");
  }
}

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // Reemplazar con la versión mock
  final MockNotificationsPlugin _notifications = MockNotificationsPlugin();
  final ClientService _clientService = ClientService();
  final String _collection = 'payments';

  PaymentService() {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    // Simplificar la inicialización
    _notifications.initialize(null);
  }

// Obtener todos los pagos
  Future<List<Payment>> getAllPayments({String? vendorId}) async {
    try {
      print('DEBUG: Obteniendo pagos' + (vendorId != null ? ' para vendedor: $vendorId' : ''));

      QuerySnapshot snapshot;

      if (vendorId != null) {
        // Si se proporciona vendorId, filtramos por él
        snapshot = await _firestore
            .collection(_collection)
            .where('vendorId', isEqualTo: vendorId)
            .orderBy('createdAt', descending: true)
            .get();
      } else {
        // Si no se proporciona vendorId, obtenemos todos los pagos
        snapshot = await _firestore
            .collection(_collection)
            .orderBy('createdAt', descending: true)
            .get();
      }

      print('DEBUG: Consulta de pagos: ${snapshot.docs.length} resultados');

      return snapshot.docs
          .map((doc) => Payment.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error al obtener pagos: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

// Método unificado para obtener pagos por cliente
  Future<List<Payment>> getPaymentsByClient(String clientId, {bool useStream = false}) async {
    try {
      print('DEBUG: Obteniendo pagos para cliente ID: $clientId');

      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .get();

      print('DEBUG: Consulta de pagos por cliente: ${snapshot.docs.length} resultados');

      return snapshot.docs
          .map((doc) => Payment.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error al obtener pagos del cliente: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

// Método unificado para obtener pagos por vendedor
  Future<List<Payment>> getPaymentsByVendor(String vendorId, {bool useStream = false}) async {
    try {
      print("DEBUG: Buscando pagos para vendedor ID: $vendorId");

      if (useStream) {
        // Obtener una snapshot de los datos usando Stream y convertirla a un Future<List>
        final snapshot = await _firestore
            .collection(_collection)
            .where('vendorId', isEqualTo: vendorId)
            .orderBy('createdAt', descending: true)
            .get();

        print("DEBUG: Documentos encontrados (stream): ${snapshot.docs.length}");
        return snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
      } else {
        // Consulta simplificada solo con where
        final QuerySnapshot snapshot = await _firestore
            .collection(_collection)
            .where('vendorId', isEqualTo: vendorId)
            .get();

        print("DEBUG: Documentos encontrados: ${snapshot.docs.length}");

        // Imprimir los IDs de los documentos encontrados
        for (var doc in snapshot.docs) {
          print("DEBUG: Documento ID: ${doc.id}");
          // Intenta extraer vendorId para verificar de forma segura
          final data = doc.data() as Map<String, dynamic>;
          print("DEBUG: vendorId en documento: ${data.containsKey('vendorId') ? data['vendorId'] : 'No encontrado'}");
        }

        return snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
      }
    } catch (e) {
      print('Error al obtener pagos del vendedor: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }


// Generar estado de cuenta en PDF
  Future<String?> generateAccountStatementPDF({
    required String vendorId,
    required String vendorName,
    required List<Payment> payments,
    List<Map<String, dynamic>>? deliveryTransactions,
  }) async {
    try {
      print('DEBUG: Generando PDF de estado de cuenta bancario para vendedor: $vendorId');

      // Crear el documento PDF
      final pdf = pw.Document();

      // Ordenar pagos por fecha
      payments.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Variables para el cálculo del saldo
      double saldoAcumulado = 0.0;

      // Lista para almacenar los datos procesados
      List<Map<String, dynamic>> estadoCuenta = [];

      // Procesar pagos para formato de estado de cuenta
      for (var payment in payments) {
        // Obtener descripción (cliente)
        String descripcion = "Cobro a cliente ${payment.clientId}";

        // Calcular montos según el estado
        double debito = payment.status == PaymentStatus.pending ? payment.amount : 0;
        double credito = payment.status == PaymentStatus.completed ? payment.amount : 0;

        // Actualizar saldo acumulado
        saldoAcumulado = saldoAcumulado + debito - credito;

        // Determinar estado para mostrar
        String estado = payment.status == PaymentStatus.pending ? "Pendiente por entregar" : "Entregado";

        // Agregar a la lista de estado de cuenta
        estadoCuenta.add({
          'fecha': payment.createdAt,
          'descripcion': descripcion,
          'debito': debito,
          'credito': credito,
          'saldo': saldoAcumulado,
          'estado': estado,
        });
      }

      // Procesar transacciones de entrega si existen
      if (deliveryTransactions != null && deliveryTransactions.isNotEmpty) {
        // Ordenar por fecha
        deliveryTransactions.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

        for (var transaction in deliveryTransactions) {
          // Agregar la entrega como una transacción adicional
          estadoCuenta.add({
            'fecha': transaction['date'] as DateTime,
            'descripcion': "Entrega en ${transaction['location']}",
            'debito': 0.0, // Las entregas no generan débitos
            'credito': transaction['amount'] as double, // Monto entregado como crédito
            'saldo': saldoAcumulado -= (transaction['amount'] as double), // Reducir el saldo
            'estado': "Entregado a oficina",
          });
        }

        // Re-ordenar todo por fecha después de agregar las entregas
        estadoCuenta.sort((a, b) => (a['fecha'] as DateTime).compareTo(b['fecha'] as DateTime));
      }

      // Generar el contenido del PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) {
            return pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Estado de Cuenta Bancario', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Text('Vendedor: $vendorName (ID: $vendorId)'),
                  pw.Text('Fecha: ${DateTime.now().toLocal().toString().substring(0, 16)}'),
                  pw.Divider(),
                ],
              ),
            );
          },
          footer: (context) {
            return pw.Footer(
              leading: pw.Text('Generado el ${DateTime.now().toLocal().toString().substring(0, 16)}'),
              trailing: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}'),
            );
          },
          build: (context) {
            return [
              // Tabla de estado de cuenta
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80), // Fecha
                  1: const pw.FlexColumnWidth(3),    // Descripción
                  2: const pw.FixedColumnWidth(80),  // Débito
                  3: const pw.FixedColumnWidth(80),  // Crédito
                  4: const pw.FixedColumnWidth(80),  // Saldo
                  5: const pw.FlexColumnWidth(2),    // Estado
                },
                children: [
                  // Encabezados
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: const PdfColor(0.8, 0.8, 0.8)),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Fecha', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Débito', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Crédito', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Saldo', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Estado', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),

                  // Filas de datos
                  ...estadoCuenta.map((item) {
                    // Determinar color de fila según tipo (pago o entrega)
                    final bool isDelivery = item['descripcion'].toString().contains('Entrega en');
                    final PdfColor rowColor = isDelivery
                        ? const PdfColor(0.9, 0.95, 0.9) // Verde claro para entregas
                        : const PdfColor(1, 1, 1);       // Blanco para pagos normales

                    return pw.TableRow(
                      decoration: pw.BoxDecoration(color: rowColor),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(DateFormat('dd/MM/yyyy').format(item['fecha'])),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item['descripcion']),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item['debito'] > 0 ? '\$${item['debito'].toStringAsFixed(2)}' : '',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            item['credito'] > 0 ? '\$${item['credito'].toStringAsFixed(2)}' : '',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '\$${item['saldo'].toStringAsFixed(2)}',
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item['estado']),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 20),

              // Resumen final
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: const PdfColor(0.95, 0.95, 0.95),
                  border: pw.Border.all(color: const PdfColor(0.5, 0.5, 0.5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Resumen de Cuenta', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Saldo actual pendiente por entregar:'),
                        pw.Text('\$${estadoCuenta.isEmpty ? 0.0 : estadoCuenta.last['saldo'].toStringAsFixed(2)}',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    // Agregar un subtítulo con la explicación del saldo
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Nota: Saldo positivo indica dinero pendiente de entrega en oficina. Saldo negativo o cero indica que está al día.',
                      style: const pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Guardar el PDF
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/estado_cuenta_$vendorId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('DEBUG: PDF generado exitosamente en: $filePath');

      return filePath;
    } catch (e) {
      print('ERROR: Error al generar PDF: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // Registrar un nuevo pago con geolocalización
  Future<String?> registerPayment({
    required String clientId,
    required String vendorId,
    String? invoiceId,
    required double amount,
    required String method,
    String? notes,
    double? latitude,
    double? longitude,
    File? paymentProof,
    String? receiptUrl,
    List<String>? imageUrls,
    // Campos nuevos:
    double? remainingAmount,
    double? deliveredAmount,
  }) async {
    print("DEBUG: PaymentService.registerPayment llamado con: clientId=$clientId, vendorId=$vendorId, method=$method");
    try {
      // Convertir el String a PaymentMethod usando el método del modelo
      PaymentMethod paymentMethod = Payment.parseMethod(method);
      print("DEBUG: Método de pago: ${method}");

      // Obtener ubicación si no se proporciona
      GeoPoint location;
      if (latitude != null && longitude != null) {
        location = GeoPoint(latitude, longitude);
      } else {
        final Position position = await _getCurrentPosition();
        location = GeoPoint(position.latitude, position.longitude);
      }

      // Generar un ID único para el pago
      final String paymentId = _firestore.collection(_collection).doc().id;

      // Subir comprobante de pago si se proporciona y no hay URL de comprobante
      String? paymentProofUrl = receiptUrl;
      if (paymentProof != null && paymentProofUrl == null) {
        final Reference ref = _storage.ref().child('payment_proofs/$paymentId.jpg');
        await ref.putFile(paymentProof);
        paymentProofUrl = await ref.getDownloadURL();
      }

      // Establecer los valores iniciales de montos restantes y entregados
      double actualRemainingAmount = remainingAmount ?? amount;
      double actualDeliveredAmount = deliveredAmount ?? 0.0;

      // Crear el documento de pago
      final Payment payment = Payment(
        id: paymentId,
        clientId: clientId,
        vendorId: vendorId,
        invoiceId: invoiceId ?? '',
        amount: amount,
        date: DateTime.now(),
        method: paymentMethod,
        status: PaymentStatus.pending, // Cambiado a "pending" por defecto
        notes: notes,
        location: location,
        paymentProofUrl: paymentProofUrl,
        receiptUrl: receiptUrl,
        createdAt: DateTime.now(),
        // Nuevos campos
        remainingAmount: actualRemainingAmount,
        deliveredAmount: actualDeliveredAmount,
        imageUrls: imageUrls ?? [],
      );

      // Guardar en Firestore
      await _firestore.collection(_collection).doc(paymentId).set(payment.toMap());

      // Enviar notificaciones
      await _sendPaymentNotifications(payment);

      print("DEBUG: Pago creado con éxito, ID: $paymentId");
      return paymentId;
    } catch (e) {
      print("DEBUG: Error en PaymentService.registerPayment: $e");
      print("DEBUG: Stack trace: ${StackTrace.current}");
      return null;
    }
  }

// Este método debe ir como un método independiente, al mismo nivel que registerPayment
  Future<String?> registerPaymentWithImages({
    required String clientId,
    required String vendorId,
    required double amount,
    required String method,
    String? notes,
    double? latitude,
    double? longitude,
    String? paymentProofUrl,
    List<String>? imageUrls,
  }) async {
    try {
      // Crear un nuevo documento de pago
      final DocumentReference paymentRef =
      _firestore.collection(_collection).doc();

      // Obtener fecha actual
      final DateTime now = DateTime.now();

      print('DEBUG: Registrando nuevo pago - Monto: $amount, Cliente: $clientId, Vendedor: $vendorId');

      // Crear objeto para guardar
      final Map<String, dynamic> paymentData = {
        'clientId': clientId,
        'vendorId': vendorId,
        'amount': amount,
        'method': method,
        'status': 'pending',
        'notes': notes,
        'createdAt': now,
        'updatedAt': now,
        'paymentProofUrl': paymentProofUrl,
        'imageUrls': imageUrls ?? [], // Lista de todas las imágenes
        'notificationSent': true, // Cambiado a true para asegurar que no cause problemas
        'remainingAmount': amount, // Asegurar que sea exactamente igual al amount
        'deliveredAmount': 0.0,    // Confirmar que sea 0.0
      };

      // Añadir ubicación si está disponible
      if (latitude != null && longitude != null) {
        paymentData['location'] = GeoPoint(latitude, longitude);
      }

      // Guardar en Firestore
      await paymentRef.set(paymentData);

      print('DEBUG: Pago registrado con ID: ${paymentRef.id}, remainingAmount: ${paymentData['remainingAmount']}');

      // Verificar explícitamente que se haya guardado correctamente
      DocumentSnapshot verifyDoc = await paymentRef.get();
      if (verifyDoc.exists) {
        Map<String, dynamic> data = verifyDoc.data() as Map<String, dynamic>;
        print('DEBUG: Verificación después de guardar - status: ${data['status']}, remainingAmount: ${data['remainingAmount']}');
      }

      // Enviar notificaciones
      final payment = await getPaymentById(paymentRef.id);
      if (payment != null) {
        await _sendPaymentNotifications(payment);
      }

      // Devolver el ID del pago
      return paymentRef.id;
    } catch (e) {
      print('Error en registerPaymentWithImages: $e');
      return null;
    }
  }

// Obtener la posición actual
  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si los servicios de ubicación están habilitados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Los servicios de ubicación están deshabilitados.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Los permisos de ubicación fueron denegados';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Los permisos de ubicación están permanentemente denegados, no podemos solicitarlos.';
    }

    // Una vez que tenemos los permisos, obtenemos la ubicación actual
    return await Geolocator.getCurrentPosition();
  }

// Enviar notificaciones a todas las partes involucradas
  Future<void> _sendPaymentNotifications(Payment payment) async {
    try {
      // Marcar como notificación enviada
      await _firestore.collection(_collection).doc(payment.id).update({
        'notificationSent': true,
      });

      // Obtener información del cliente
      final Client? client = await _clientService.getClientById(payment.clientId);

      if (client == null) {
        print('Cliente no encontrado para notificación');
        return; // Este return es válido en un Future<void>
      }

      // Notificación local para el vendedor
      _showLocalNotification(
        id: 1,
        title: 'Pago Registrado',
        body: 'Se ha registrado un pago de \$${payment.amount.toStringAsFixed(2)} de ${client.businessName}',
      );
    } catch (e) {
      print('Error al enviar notificaciones: $e');
      // No es necesario un return aquí, porque implícitamente devuelve un Future<void>
    }
  }

// Mostrar notificación local
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Usar la versión mock de notificaciones
    await _notifications.show(id, title, body, null);
  }

// Generar recibo para un pago
  Future<String?> generateReceiptForPayment(String paymentId) async {
    try {
      final Payment? payment = await getPaymentById(paymentId);

      if (payment == null) {
        throw 'Pago no encontrado';
      }

      // Aquí iría la lógica para generar un PDF de recibo
      // Usando la librería pdf de Flutter

      // Una vez generado, se subiría a Firebase Storage

      // Y se actualizaría el documento con la URL del recibo

      return 'URL_DEL_RECIBO';
    } catch (e) {
      print('Error al generar recibo: $e');
      return null;
    }
  }


// Crear un nuevo pago con foto
  Future<String?> createPaymentWithPhoto({
    required Payment payment,
    required File photoFile,
    required String receiverName,
    required String receiverId,
    required String receiverPhone,
  }) async {
    try {
      // Subir la foto a Firebase Storage
      final String photoUrl = await _uploadPaymentPhoto(photoFile, payment.id);

      // Crear el documento del pago con la URL de la foto
      final docRef = await _firestore.collection(_collection).add({
        ...payment.toMap(),
        'photoUrl': photoUrl,
        'receiverName': receiverName,
        'receiverId': receiverId,
        'receiverPhone': receiverPhone,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'remainingAmount': 0.0,               // Pago completado, no hay monto pendiente
        'deliveredAmount': payment.amount,    // Todo entregado
      });

      return docRef.id;
    } catch (e) {
      print('Error creating payment with photo: $e');
      return null;
    }
  }

// Subir foto del pago
  Future<String> _uploadPaymentPhoto(File photoFile, String paymentId) async {
    try {
      final ref = _storage.ref().child('payments/$paymentId.jpg');
      await ref.putFile(photoFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading payment photo: $e');
      rethrow;
    }
  }

// Obtener pagos por cliente
  Stream<List<Payment>> getPaymentsByClientStream(String clientId) {
    return _firestore
        .collection(_collection)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Payment.fromFirestore(doc))
          .toList();
    });
  }

// Obtener pagos por cliente y método de pago
  Future<List<Payment>> getPaymentsByClientAndMethod(String clientId, String method) async {
    try {
      print('DEBUG: Obteniendo pagos para cliente ID: $clientId con método: $method');

      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('clientId', isEqualTo: clientId)
          .where('method', isEqualTo: method)
          .orderBy('createdAt', descending: true)
          .get();

      print('DEBUG: Consulta de pagos por cliente y método: ${snapshot.docs.length} resultados');

      return snapshot.docs
          .map((doc) => Payment.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error al obtener pagos del cliente por método: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

// Obtener pagos por vendedor
  Stream<List<Payment>> getPaymentsByVendorStream(String vendorId) {
    return _firestore
        .collection(_collection)
        .where('vendorId', isEqualTo: vendorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Payment.fromFirestore(doc))
          .toList();
    });
  }

// Método para obtener pagos por vendedor y cliente
  Future<List<Payment>> getPaymentsByVendorAndClient(String vendorId, String clientId) async {
    try {
      print("DEBUG: Buscando pagos para vendedor ID: $vendorId y cliente ID: $clientId");

      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('vendorId', isEqualTo: vendorId)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .get();

      print("DEBUG: Documentos encontrados: ${snapshot.docs.length}");

      return snapshot.docs.map((doc) => Payment.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error al obtener pagos del vendedor por cliente: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

// Método unificado para obtener un pago específico por ID
  Future<Payment?> getPaymentById(String paymentId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(paymentId)
          .get();

      if (doc.exists) {
        return Payment.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error al obtener pago: $e');
      return null;
    }
  }

// Método unificado para actualizar el estado de un pago
  Future<bool> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    String? statusStr,
    DateTime? deliveryDate,
    String? deliveryLocation,
    double? deliveredAmount, // Nuevo parámetro
  }) async {
    try {
      // Si se proporciona statusStr, lo usamos, sino convertimos el enum
      final String finalStatus = statusStr ?? status.toString().split('.').last.toLowerCase();

      print("DEBUG: Actualizando pago ID: $paymentId a estado: $finalStatus");

      // Obtener los datos actuales del pago para actualizar correctamente los montos
      final payment = await getPaymentById(paymentId);
      if (payment == null) {
        throw 'Pago no encontrado';
      }

      // Calcular montos a actualizar
      double newDeliveredAmount = payment.deliveredAmount ?? 0.0;
      double newRemainingAmount = payment.remainingAmount ?? payment.amount;

      // Si hay un nuevo monto entregado, actualizarlo
      if (deliveredAmount != null && deliveredAmount > 0) {
        newDeliveredAmount += deliveredAmount;
        newRemainingAmount -= deliveredAmount;

        // Asegurar que no tengamos valores negativos
        if (newRemainingAmount < 0) newRemainingAmount = 0;
      }

      // SOLUCIÓN: Si el estado es 'completed', siempre forzar los montos correctos
      if (status == PaymentStatus.completed || finalStatus.toLowerCase() == 'completed') {
        newDeliveredAmount = payment.amount;
        newRemainingAmount = 0;
      }

      final Map<String, dynamic> updateData = {
        'status': finalStatus.toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
        'deliveredAmount': newDeliveredAmount,
        'remainingAmount': newRemainingAmount,
      };

      if (deliveryDate != null) {
        updateData['deliveryDate'] = Timestamp.fromDate(deliveryDate);
      }

      if (deliveryLocation != null) {
        updateData['deliveryLocation'] = deliveryLocation;
      }

      // Si el estado es "completed", registrar datos adicionales
      if (status == PaymentStatus.completed || finalStatus.toLowerCase() == 'completed') {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore.collection(_collection).doc(paymentId).update(updateData);

      print("DEBUG: Pago actualizado exitosamente. Nuevo estado: $finalStatus, Entregado: $newDeliveredAmount, Restante: $newRemainingAmount");
      return true;
    } catch (e) {
      print('Error al actualizar estado del pago: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }




// Este método se mantiene para compatibilidad
  Future<bool> updatePaymentStatusByString(String paymentId, String newStatus) async {
    return updatePaymentStatus(
        paymentId: paymentId,
        status: Payment.parseStatus(newStatus),
        statusStr: newStatus.toLowerCase()
    );
  }

  // Obtener estadísticas de pagos
  Future<Map<String, dynamic>> getPaymentStats(String vendorId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('vendorId', isEqualTo: vendorId)
          .get();

      double totalAmount = 0;
      int completedPayments = 0;
      int pendingPayments = 0;
      int failedPayments = 0;

      for (var doc in snapshot.docs) {
        final payment = Payment.fromFirestore(doc);
        totalAmount += payment.amount;

        switch (payment.status) {
          case PaymentStatus.completed:
            completedPayments++;
            break;
          case PaymentStatus.pending:
            pendingPayments++;
            break;
          case PaymentStatus.cancelled:
            failedPayments++;
            break;
          case PaymentStatus.delivered:
            completedPayments++; // Consideramos "delivered" como "completed"
            break;
        }
      }

      return {
        'totalAmount': totalAmount,
        'completedPayments': completedPayments,
        'pendingPayments': pendingPayments,
        'failedPayments': failedPayments,
        'totalPayments': snapshot.docs.length,
      };
    } catch (e) {
      print('Error getting payment stats: $e');
      return {
        'totalAmount': 0,
        'completedPayments': 0,
        'pendingPayments': 0,
        'failedPayments': 0,
        'totalPayments': 0,
      };
    }
  }

  // Método para migrar datos existentes y añadir campos faltantes
  Future<void> migrateExistingPayments() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();

      print('Iniciando migración de ${snapshot.docs.length} pagos...');

      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final bool hasRemainingAmount = data.containsKey('remainingAmount');
        final bool hasDeliveredAmount = data.containsKey('deliveredAmount');
        final bool hasImageUrls = data.containsKey('imageUrls');

        // Solo actualizar si faltan campos
        if (!hasRemainingAmount || !hasDeliveredAmount || !hasImageUrls) {
          final Map<String, dynamic> updateData = {};

          if (!hasRemainingAmount) {
            // Si el pago está completado, remainingAmount = 0, sino = amount
            final bool isCompleted = data['status'] == 'completed';
            updateData['remainingAmount'] = isCompleted ? 0.0 : (data['amount'] ?? 0.0);
          }

          if (!hasDeliveredAmount) {
            // Si el pago está completado, deliveredAmount = amount, sino = 0
            final bool isCompleted = data['status'] == 'completed';
            updateData['deliveredAmount'] = isCompleted ? (data['amount'] ?? 0.0) : 0.0;
          }

          if (!hasImageUrls) {
            updateData['imageUrls'] = [];
          }

          await _firestore.collection(_collection).doc(doc.id).update(updateData);
          count++;
        }
      }

      print('Migración completada. Se actualizaron $count documentos.');
    } catch (e) {
      print('Error al migrar pagos: $e');
    }
  }

  // Calcular saldo pendiente por entregar (teniendo en cuenta entregas realizadas)
  Future<double> getPendingBalance(String vendorId) async {
    try {
      print('DEBUG: Calculando saldo pendiente para vendedor ID: $vendorId');

      // 1. Verificar todos los pagos para diagnóstico
      final allPaymentsSnapshot = await _firestore
          .collection(_collection)
          .where('vendorId', isEqualTo: vendorId)
          .get();

      print('DEBUG: Total de pagos para el vendedor: ${allPaymentsSnapshot.docs.length}');

      for (var doc in allPaymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('DEBUG: Pago ID: ${doc.id}, Estado: ${data['status']}, Monto: ${data['amount']}');
      }

      // 2. Obtener solo los pagos pendientes
      final paymentsSnapshot = await _firestore
          .collection(_collection)
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'pending')
          .get();

      // Crear un mapa para rastrear montos pendientes por ID de pago
      Map<String, double> pendingByPaymentId = {};
      double totalPendingAmount = 0;

      print('DEBUG: Pagos pendientes encontrados: ${paymentsSnapshot.docs.length}');

      for (var doc in paymentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        double amount = (data['amount'] ?? 0).toDouble();
        print('DEBUG: Pago pendiente ID: ${doc.id}, Monto: $amount');
        pendingByPaymentId[doc.id] = amount;
        totalPendingAmount += amount;
      }

      print('DEBUG: Monto total de pagos pendientes: \$${totalPendingAmount.toStringAsFixed(2)}');

      // 3. Obtener todas las entregas parciales activas
      final deliveriesSnapshot = await _firestore
          .collection('delivery_transactions')
          .where('vendorId', isEqualTo: vendorId)
          .where('status', isEqualTo: 'active')
          .get();

      double deliveredAmount = 0;

      print('DEBUG: Entregas parciales encontradas: ${deliveriesSnapshot.docs.length}');

      // Mapa para trackear entregas por ID de pago
      Map<String, double> deliveredByPaymentId = {};

      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        String paymentId = data['paymentId'] as String? ?? '';
        double amount = (data['amount'] is int)
            ? (data['amount'] as int).toDouble()
            : (data['amount'] ?? 0.0);

        print('DEBUG: Entrega parcial para pago ID: $paymentId, Monto: $amount');

        // Solo considerar entregas para pagos que están actualmente pendientes
        if (pendingByPaymentId.containsKey(paymentId)) {
          deliveredByPaymentId[paymentId] = (deliveredByPaymentId[paymentId] ?? 0) + amount;
          deliveredAmount += amount;
        } else {
          print('DEBUG: Esta entrega es para un pago que ya no está pendiente o no existe, se ignora');
        }
      }

      print('DEBUG: Desglose de entregas por pago pendiente:');
      deliveredByPaymentId.forEach((paymentId, amount) {
        print('DEBUG: Pago ID: $paymentId - Entregado: \$${amount.toStringAsFixed(2)} de \$${pendingByPaymentId[paymentId]?.toStringAsFixed(2) ?? "N/A"}');
      });

      print('DEBUG: Monto total de entregas para pagos pendientes: \$${deliveredAmount.toStringAsFixed(2)}');

      // 4. Calcular saldo final
      final balance = totalPendingAmount - deliveredAmount;
      print('DEBUG: Saldo pendiente final calculado: \$${balance.toStringAsFixed(2)}');

      // 5. Asegurar que no sea negativo (protección adicional)
      return balance > 0 ? balance : 0;
    } catch (e) {
      print('ERROR: Error al calcular saldo pendiente: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      return 0;
    }
  }

  // Generar reporte de pagos
  Future<List<Map<String, dynamic>>> generatePaymentReport({
    required String vendorId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final payment = Payment.fromFirestore(doc);
        return {
          'id': payment.id,
          'clientId': payment.clientId,
          'amount': payment.amount,
          'status': payment.status,
          'createdAt': payment.createdAt,
          'receiverName': payment.receiverName,
          'receiverId': payment.receiverId,
          'receiverPhone': payment.receiverPhone,
          'photoUrl': payment.photoUrl,
        };
      }).toList();
    } catch (e) {
      print('Error generating payment report: $e');
      return [];
    }
  }
}