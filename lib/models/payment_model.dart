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
    };
  }

  // Crear desde Map de Firestore
  factory Payment.fromMap(Map<String, dynamic> map, String documentId) {
    return Payment(
      id: documentId,
      clientId: map['clientId'] ?? '',
      vendorId: map['vendorId'] ?? '',
      invoiceId: map['invoiceId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      method: _methodFromString(map['method'] ?? 'cash'),
      status: _statusFromString(map['status'] ?? 'pending'),
      notes: map['notes'],
      location: map['location'],
      paymentProofUrl: map['paymentProofUrl'],
      receiptUrl: map['receiptUrl'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      notificationSent: map['notificationSent'] ?? false,
    );
  }

  static PaymentMethod _methodFromString(String methodStr) {
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

  static PaymentStatus _statusFromString(String statusStr) {
    switch (statusStr.toLowerCase()) {
      case 'pending':
        return PaymentStatus.pending;
      case 'completed':
        return PaymentStatus.completed;
      case 'cancelled':
        return PaymentStatus.cancelled;
      case 'delivered':  // Añadido para compatibilidad
        return PaymentStatus.completed;
      default:
        return PaymentStatus.pending;
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
  // Si necesitas un estado 'delivered', descomenta la siguiente línea
  // delivered,
}