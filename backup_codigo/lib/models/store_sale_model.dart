import 'package:cloud_firestore/cloud_firestore.dart';

class StoreSale {
  final String id;
  final String storeId;
  final String sellerId;
  final String productId;
  final String productSerial;
  final String invoiceImageUrl;
  final String serialImageUrl;
  final DateTime saleDate;
  final double salePrice;
  final String status;
  final Map<String, dynamic> productDetails;

  StoreSale({
    required this.id,
    required this.storeId,
    required this.sellerId,
    required this.productId,
    required this.productSerial,
    required this.invoiceImageUrl,
    required this.serialImageUrl,
    required this.saleDate,
    required this.salePrice,
    required this.status,
    required this.productDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'sellerId': sellerId,
      'productId': productId,
      'productSerial': productSerial,
      'invoiceImageUrl': invoiceImageUrl,
      'serialImageUrl': serialImageUrl,
      'saleDate': Timestamp.fromDate(saleDate),
      'salePrice': salePrice,
      'status': status,
      'productDetails': productDetails,
    };
  }

  factory StoreSale.fromMap(Map<String, dynamic> map) {
    return StoreSale(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      productId: map['productId'] ?? '',
      productSerial: map['productSerial'] ?? '',
      invoiceImageUrl: map['invoiceImageUrl'] ?? '',
      serialImageUrl: map['serialImageUrl'] ?? '',
      saleDate: (map['saleDate'] as Timestamp).toDate(),
      salePrice: map['salePrice']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'pending',
      productDetails: map['productDetails'] ?? {},
    );
  }

  StoreSale copyWith({
    String? id,
    String? storeId,
    String? sellerId,
    String? productId,
    String? productSerial,
    String? invoiceImageUrl,
    String? serialImageUrl,
    DateTime? saleDate,
    double? salePrice,
    String? status,
    Map<String, dynamic>? productDetails,
  }) {
    return StoreSale(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      sellerId: sellerId ?? this.sellerId,
      productId: productId ?? this.productId,
      productSerial: productSerial ?? this.productSerial,
      invoiceImageUrl: invoiceImageUrl ?? this.invoiceImageUrl,
      serialImageUrl: serialImageUrl ?? this.serialImageUrl,
      saleDate: saleDate ?? this.saleDate,
      salePrice: salePrice ?? this.salePrice,
      status: status ?? this.status,
      productDetails: productDetails ?? this.productDetails,
    );
  }
} 