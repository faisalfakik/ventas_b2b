// lib/services/notification_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';
import 'client_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClientService _clientService = ClientService();

  // Enviar notificación de abono
  Future<void> sendPaymentNotification({
    required String clientId,
    required String vendorId,
    required double amount,
    required String paymentMethod,
    required String paymentId,
  }) async {
    try {
      // Obtener información del cliente
      final Client? clientDoc = await _clientService.getClientById(clientId);
      // Usar el operador ?? para manejar el caso de que clientDoc sea null
      final Client client = clientDoc ?? Client(id: '', name: '', email: '', phone: '', address: '', businessName: '');

      // Crear notificación para el admin
      await _firestore.collection('notifications').add({
        'title': 'Nuevo abono registrado',
        'body': 'Se ha recibido un abono de \$${amount.toStringAsFixed(2)} ' +
            'por ${paymentMethod} de ${client.name}',
        'type': 'payment',
        'recipientType': 'admin',
        'recipientId': 'admin', // Puede ser un ID específico de administrador
        'senderId': vendorId,
        'paymentId': paymentId,
        'clientId': clientId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Crear notificación para el cliente (si tiene token)
      if (client.fcmToken != null && client.fcmToken!.isNotEmpty) {
        await _firestore.collection('notifications').add({
          'title': 'Abono registrado',
          'body': 'Se ha registrado su abono de \$${amount.toStringAsFixed(2)} por ${paymentMethod}',
          'type': 'payment',
          'recipientType': 'client',
          'recipientId': clientId,
          'senderId': vendorId,
          'paymentId': paymentId,
          'amount': amount,
          'paymentMethod': paymentMethod,
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // También se puede implementar el envío de notificaciones push usando Firebase Cloud Messaging
    } catch (e) {
      print('Error al enviar notificación: $e');
      throw Exception('Error al enviar notificación: $e');
    }
  }
}