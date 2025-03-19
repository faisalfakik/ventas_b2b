import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/payment_model.dart';
import '../models/client_model.dart';
import '../services/client_service.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final ClientService _clientService = ClientService();
  final String _collection = 'payments';

  PaymentService() {
    _initializeNotifications();
  }

  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    _notifications.initialize(initializationSettings);
  }

  // Obtener todos los pagos
  Future<List<Payment>> getAllPayments() async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error al obtener pagos: $e');
      return [];
    }
  }

  // Obtener pagos de un cliente específico
  Future<List<Payment>> getPaymentsByClient(String clientId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('clientId', isEqualTo: clientId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error al obtener pagos del cliente: $e');
      return [];
    }
  }

  // Obtener pagos realizados por un vendedor
  Future<List<Payment>> getPaymentsByVendor(String vendorId) async {
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error al obtener pagos del vendedor: $e');
      return [];
    }
  }

  // Registrar un nuevo pago con geolocalización
  Future<String?> registerPayment({
    required String clientId,
    required String vendorId,
    String? invoiceId,
    required double amount,
    required String method,  // Cambiado de PaymentMethod a String
    String? notes,
    double? latitude,
    double? longitude,
    File? paymentProof,
    String? receiptUrl,
  }) async {
    // AÑADE ESTE LOG AL INICIO DEL MÉTODO
    print("DEBUG: PaymentService.registerPayment llamado con: clientId=$clientId, vendorId=$vendorId, method=$method");
    try {
      // Convertir el String a PaymentMethod
      PaymentMethod paymentMethod;
      if (method == 'cash') {
        paymentMethod = PaymentMethod.cash;
        // AÑADE ESTE LOG AQUÍ
        print("DEBUG: Método de pago: Efectivo");
      } else if (method == 'deposit') {
        paymentMethod = PaymentMethod.transfer;
        // AÑADE ESTE LOG AQUÍ
        print("DEBUG: Método de pago: Depósito/Transferencia");
      } else {
        paymentMethod = PaymentMethod.cash;
        // AÑADE ESTE LOG AQUÍ
        print("DEBUG: Método de pago desconocido, usando Efectivo");
      }

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

      // Crear el documento de pago
      final Payment payment = Payment(
        id: paymentId,
        clientId: clientId,
        vendorId: vendorId,
        invoiceId: invoiceId ?? '',
        amount: amount,
        date: DateTime.now(),
        method: paymentMethod,
        status: PaymentStatus.completed,
        notes: notes,
        location: location,
        paymentProofUrl: paymentProofUrl,
        createdAt: DateTime.now(),
      );

      // Guardar en Firestore
      await _firestore.collection(_collection).doc(paymentId).set(payment.toMap());

      // Enviar notificaciones
      await _sendPaymentNotifications(payment);

      // AÑADE ESTE LOG AQUÍ
      print("DEBUG: Pago creado con éxito, ID: $paymentId");
      return paymentId;
    } catch (e) {
      // REEMPLAZA ESTE PRINT
      print("DEBUG: Error en PaymentService.registerPayment: $e");
      print("DEBUG: Stack trace: ${StackTrace.current}");
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
        return;
      }

      // Notificación local para el vendedor
      _showLocalNotification(
        id: 1,
        title: 'Pago Registrado',
        body: 'Se ha registrado un pago de \$${payment.amount.toStringAsFixed(2)} de ${client.businessName}',
      );

      // Aquí se enviarían notificaciones por correo o SMS al cliente y administración
      // Esto requeriría servicios adicionales como Firebase Cloud Messaging,
      // un servicio de SMS o un servicio de correo electrónico
    } catch (e) {
      print('Error al enviar notificaciones: $e');
    }
  }

  // Mostrar notificación local
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'payment_channel',
      'Pagos y Abonos',
      channelDescription: 'Notificaciones de pagos y abonos',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
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

  // Obtener un pago específico por ID
  Future<Payment?> getPaymentById(String paymentId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection(_collection)
          .doc(paymentId)
          .get();

      if (doc.exists) {
        return Payment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener pago: $e');
      return null;
    }
  }

  // Actualizar estado de un pago
  Future<bool> updatePaymentStatus({
    required String paymentId,
    required PaymentStatus status,
    DateTime? deliveryDate
  }) async {
    try {
      await _firestore.collection(_collection).doc(paymentId).update({
        'status': status.toString().split('.').last,
        if (deliveryDate != null) 'deliveryDate': Timestamp.fromDate(deliveryDate),
      });

      return true;
    } catch (e) {
      print('Error al actualizar estado del pago: $e');
      return false;
    }
  }
}