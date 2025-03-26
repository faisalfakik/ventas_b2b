// lib/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Comentado temporalmente
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';
import 'client_service.dart';

// Constantes mock para reemplazar enums de flutter_local_notifications
const int IMPORTANCE_HIGH = 3;
const int IMPORTANCE_MAX = 4;
const int PRIORITY_HIGH = 1;

// Clases mock para reemplazar flutter_local_notifications
class MockNotificationDetails {
  final MockAndroidNotificationDetails? android;

  const MockNotificationDetails({this.android});
}

class MockAndroidNotificationDetails {
  final String channelId;
  final String channelName;
  final String? channelDescription;
  final int importance;
  final int priority;

  const MockAndroidNotificationDetails(
      this.channelId,
      this.channelName,
      {this.channelDescription,
        this.importance = IMPORTANCE_MAX,
        this.priority = PRIORITY_HIGH});
}

class MockFlutterLocalNotificationsPlugin {
  Future<void> initialize(dynamic settings) async {
    print("MOCK: Plugin de notificaciones locales inicializado");
  }

  Future<void> show(int id, String? title, String? body, MockNotificationDetails details, {String? payload}) async {
    print("MOCK NOTIFICATION: [$id] $title - $body");
  }

  dynamic resolvePlatformSpecificImplementation<T>() {
    return MockAndroidFlutterLocalNotificationsPlugin();
  }
}

class MockAndroidFlutterLocalNotificationsPlugin {
  Future<void> createNotificationChannel(dynamic channel) async {
    print("MOCK: Canal de notificaciones creado: ${channel.channelId}");
  }
}

class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final MockFlutterLocalNotificationsPlugin _localNotifications = MockFlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClientService _clientService = ClientService();

  NotificationService() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Configurar notificaciones locales
    const MockAndroidNotificationDetails initializationSettingsAndroid =
    MockAndroidNotificationDetails('@mipmap/ic_launcher', 'App Notifications');

    const initializationSettings = {'android': initializationSettingsAndroid};

    await _localNotifications.initialize(initializationSettings);

    // Configurar canales de notificación
    await _createNotificationChannels();

    // Solicitar permisos
    await _requestPermissions();

    // Configurar manejadores de mensajes
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);
  }

  Future<void> _createNotificationChannels() async {
    final quoteChannel = MockAndroidNotificationDetails(
      'quote_channel',
      'Cotizaciones',
      channelDescription: 'Notificaciones relacionadas con cotizaciones',
      importance: IMPORTANCE_HIGH,
    );

    final paymentChannel = MockAndroidNotificationDetails(
      'payment_channel',
      'Pagos',
      channelDescription: 'Notificaciones relacionadas con pagos',
      importance: IMPORTANCE_HIGH,
    );

    final orderChannel = MockAndroidNotificationDetails(
      'order_channel',
      'Pedidos',
      channelDescription: 'Notificaciones relacionadas con pedidos',
      importance: IMPORTANCE_HIGH,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<MockAndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(quoteChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<MockAndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(paymentChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<MockAndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(orderChannel);
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permisos de notificación concedidos');
    } else {
      print('Permisos de notificación denegados');
    }
  }

  Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  Future<void> saveToken(String userId, String userType) async {
    final token = await getToken();
    if (token != null) {
      await _firestore.collection('user_tokens').doc(userId).set({
        'token': token,
        'userType': userType,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  void _handleForegroundMessage(RemoteMessage message) async {
    print('Mensaje recibido en primer plano: ${message.messageId}');
    await _showLocalNotification(
      title: message.notification?.title ?? 'Nueva notificación',
      body: message.notification?.body ?? '',
      payload: message.data.toString(),
      channelId: _getChannelId(message.data['type']),
    );
  }

  void _handleBackgroundMessage(RemoteMessage message) {
    print('Mensaje recibido en segundo plano: ${message.messageId}');
    // Aquí puedes manejar la navegación cuando se toca la notificación
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    required String channelId,
  }) async {
    final androidDetails = MockAndroidNotificationDetails(
      'default_channel',
      'Notificaciones',
      channelDescription: 'Notificaciones generales',
      importance: IMPORTANCE_MAX,
      priority: PRIORITY_HIGH,
    );

    final platformDetails = MockNotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  String _getChannelId(String? type) {
    switch (type) {
      case 'quote':
        return 'quote_channel';
      case 'payment':
        return 'payment_channel';
      case 'order':
        return 'order_channel';
      default:
        return 'default_channel';
    }
  }

  // Enviar notificación de nueva cotización
  Future<void> sendQuoteNotification({
    required String clientId,
    required String vendorId,
    required String quoteId,
    required double amount,
  }) async {
    try {
      print("MOCK: Enviando notificación de cotización al cliente $clientId por \$${amount.toStringAsFixed(2)}");

      final tokenDoc = await _firestore.collection('user_tokens').doc(clientId).get();
      if (!tokenDoc.exists) return;

      final token = tokenDoc.data()?['token'];
      if (token == null) return;

      // Mostrar notificación local para desarrollo
      await _showLocalNotification(
        title: "Nueva cotización",
        body: "Has recibido una cotización por \$${amount.toStringAsFixed(2)}",
        channelId: "quote_channel",
      );

      // Aquí implementarías la lógica para enviar la notificación usando Firebase Cloud Messaging
      // Esto requeriría un servidor backend o Cloud Functions
    } catch (e) {
      print('Error sending quote notification: $e');
    }
  }

  // Enviar notificación de pago recibido
  Future<void> sendPaymentNotification({
    required String clientId,
    required String vendorId,
    required double amount,
    required String paymentMethod,
    required String paymentId,
  }) async {
    try {
      print("MOCK: Enviando notificación de pago al cliente $clientId por \$${amount.toStringAsFixed(2)} con método $paymentMethod");

      final tokenDoc = await _firestore.collection('user_tokens').doc(clientId).get();
      if (!tokenDoc.exists) return;

      final token = tokenDoc.data()?['token'];
      if (token == null) return;

      // Mostrar notificación local para desarrollo
      await _showLocalNotification(
        title: "Pago registrado",
        body: "Se ha registrado un pago por \$${amount.toStringAsFixed(2)} via $paymentMethod",
        channelId: "payment_channel",
      );

      // Aquí implementarías la lógica para enviar la notificación usando Firebase Cloud Messaging
      // Esto requeriría un servidor backend o Cloud Functions
    } catch (e) {
      print('Error sending payment notification: $e');
    }
  }

  // Enviar notificación de actualización de pedido
  Future<void> sendOrderUpdateNotification({
    required String clientId,
    required String orderId,
    required String status,
  }) async {
    try {
      print("MOCK: Enviando notificación de actualización de pedido $orderId al cliente $clientId - Estado: $status");

      final tokenDoc = await _firestore.collection('user_tokens').doc(clientId).get();
      if (!tokenDoc.exists) return;

      final token = tokenDoc.data()?['token'];
      if (token == null) return;

      // Mostrar notificación local para desarrollo
      await _showLocalNotification(
        title: "Pedido actualizado",
        body: "Tu pedido #$orderId ha sido actualizado a: $status",
        channelId: "order_channel",
      );

      // Aquí implementarías la lógica para enviar la notificación usando Firebase Cloud Messaging
      // Esto requeriría un servidor backend o Cloud Functions
    } catch (e) {
      print('Error sending order update notification: $e');
    }
  }

  // Enviar notificación de vendedor cercano
  Future<void> sendNearbyVendorNotification({
    required String clientId,
    required String vendorName,
    required double distance,
  }) async {
    try {
      print("MOCK: Enviando notificación de vendedor cercano ($vendorName) al cliente $clientId - Distancia: ${distance.toStringAsFixed(1)}km");

      final tokenDoc = await _firestore.collection('user_tokens').doc(clientId).get();
      if (!tokenDoc.exists) return;

      final token = tokenDoc.data()?['token'];
      if (token == null) return;

      // Mostrar notificación local para desarrollo
      await _showLocalNotification(
        title: "Vendedor cercano",
        body: "$vendorName está a ${distance.toStringAsFixed(1)}km de tu ubicación",
        channelId: "default_channel",
      );

      // Aquí implementarías la lógica para enviar la notificación usando Firebase Cloud Messaging
      // Esto requeriría un servidor backend o Cloud Functions
    } catch (e) {
      print('Error sending nearby vendor notification: $e');
    }
  }
}