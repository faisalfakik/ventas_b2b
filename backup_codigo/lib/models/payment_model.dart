import 'package:cloud_firestore/cloud_firestore.dart';

class Payment {
  final String id;
  final String clientId;
  final String vendorId;
  final String invoiceId; // Opcional, puede ser null si no está asociado a una factura
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? notes;
  final GeoPoint? location; // Ubicación donde se registró el pago
  final String? paymentProofUrl; // URL a imagen de comprobante de pago
  final String? receiptUrl; // URL a recibo generado
  final DateTime createdAt;
  final bool notificationSent; // Si ya se envió notificación

  // Propiedades adicionales que se necesitan
  final String? receiverName;
  final String? receiverId;
  final String? receiverPhone;
  final String? photoUrl;

  Payment({
    required this.id,
    required this.clientId,
    required this.vendorId,
    this.invoiceId = '',
    required this.amount,
    required this.date,
    required this.method,
    this.status = PaymentStatus.pending,
    this.notes,
    this.location,
    this.paymentProofUrl,
    this.receiptUrl,
    required this.createdAt,
    this.notificationSent = false,
    this.receiverName,
    this.receiverId,
    this.receiverPhone,
    this.photoUrl,
  });

  // Getters para compatibilidad con código existente
  PaymentMethod get paymentMethod => method;
  String? get receiptImageUrl => receiptUrl;
  double get latitude => location?.latitude ?? 0;
  double get longitude => location?.longitude ?? 0;

  // Crear una copia con cambios específicos
  Payment copyWith({
    String? id,
    String? clientId,
    String? vendorId,
    String? invoiceId,
    double? amount,
    DateTime? date,
    PaymentMethod? method,
    PaymentStatus? status,
    String? notes,
    GeoPoint? location,
    String? paymentProofUrl,
    String? receiptUrl,
    DateTime? createdAt,
    bool? notificationSent,
    String? receiverName,
    String? receiverId,
    String? receiverPhone,
    String? photoUrl,
  }) {
    return Payment(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      vendorId: vendorId ?? this.vendorId,
      invoiceId: invoiceId ?? this.invoiceId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      method: method ?? this.method,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      createdAt: createdAt ?? this.createdAt,
      notificationSent: notificationSent ?? this.notificationSent,
      receiverName: receiverName ?? this.receiverName,
      receiverId: receiverId ?? this.receiverId,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }

  // Convertir a Map para Firestore
  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'vendorId': vendorId,
      'invoiceId': invoiceId,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'method': method.toString().split('.').last,
      'status': status.toString().split('.').last,
      'notes': notes,
      'location': location,
      'paymentProofUrl': paymentProofUrl,
      'receiptUrl': receiptUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'notificationSent': notificationSent,
      'receiverName': receiverName,
      'receiverId': receiverId,
      'receiverPhone': receiverPhone,
      'photoUrl': photoUrl,
    };
  }

  // Crear desde Map de Firestore - Mantenemos por compatibilidad
  factory Payment.fromMap(Map<String, dynamic> map, String documentId) {
    return Payment(
      id: documentId,
      clientId: map['clientId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      invoiceId: map['invoiceId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      method: _parsePaymentMethod(map['method'] ?? 'cash'),
      status: _parsePaymentStatus(map['status'] ?? 'pending'),
      notes: map['notes'],
      location: map['location'],
      paymentProofUrl: map['paymentProofUrl'],
      receiptUrl: map['receiptUrl'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      notificationSent: map['notificationSent'] ?? false,
      receiverName: map['receiverName'],
      receiverId: map['receiverId'],
      receiverPhone: map['receiverPhone'],
      photoUrl: map['photoUrl'],
    );
  }

  // Crear desde DocumentSnapshot de Firestore
  static Payment fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Payment(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      invoiceId: data['invoiceId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      method: _parsePaymentMethod(data['method'] ?? 'cash'),
      status: _parsePaymentStatus(data['status'] ?? 'pending'),
      notes: data['notes'],
      location: data['location'] as GeoPoint?,
      paymentProofUrl: data['paymentProofUrl'],
      receiptUrl: data['receiptUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notificationSent: data['notificationSent'] ?? false,
      receiverName: data['receiverName'],
      receiverId: data['receiverId'],
      receiverPhone: data['receiverPhone'],
      photoUrl: data['photoUrl'],
    );
  }

  // Método único para convertir strings a PaymentMethod
  static PaymentMethod _parsePaymentMethod(String methodStr) {
    switch (methodStr.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      case 'transfer':
        return PaymentMethod.transfer;
      case 'check':
        return PaymentMethod.check;
      default:
        return PaymentMethod.cash;
    }
  }

  // Método único para convertir strings a PaymentStatus
  static PaymentStatus _parsePaymentStatus(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'completed':
        return PaymentStatus.completed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      case 'delivered':
        return PaymentStatus.delivered;
      default:
        return PaymentStatus.pending;
    }
  }

  // Método para convertir PaymentMethod a string legible
  static String paymentMethodToString(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Efectivo';
      case PaymentMethod.card:
        return 'Tarjeta';
      case PaymentMethod.transfer:
        return 'Transferencia';
      case PaymentMethod.check:
        return 'Cheque';
      default:
        return 'Desconocido';
    }
  }

  // Método para convertir PaymentStatus a string legible
  static String paymentStatusToString(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pendiente';
      case PaymentStatus.completed:
        return 'Completado';
      case PaymentStatus.cancelled:
        return 'Cancelado';
      case PaymentStatus.delivered:
        return 'Entregado';
      default:
        return 'Desconocido';
    }
  }
}

enum PaymentMethod {
  cash,
  card,
  transfer,
  check,
}

enum PaymentStatus {
  pending,
  completed,
  cancelled,
  delivered,
}