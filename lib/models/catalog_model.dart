// catalog_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum CatalogType {
  pdf,
  image,
  offer
}

class CatalogDocument {
  final String id;
  final String name;
  final String description;
  final String fileUrl;
  final String thumbnailUrl;
  final CatalogType type;
  final DateTime createdAt;
  final DateTime? expiryDate;
  final bool isActive;
  final List<String> visibleToRoles; // 'admin', 'vendor', 'client'

  CatalogDocument({
    required this.id,
    required this.name,
    required this.description,
    required this.fileUrl,
    required this.thumbnailUrl,
    required this.type,
    required this.createdAt,
    this.expiryDate,
    this.isActive = true,
    required this.visibleToRoles,
  });

  bool isExpired() {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool isVisibleToRole(String role) {
    return visibleToRoles.contains(role.toLowerCase());
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'type': type.toString().split('.').last,
      'createdAt': FieldValue.serverTimestamp(),
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'isActive': isActive,
      'visibleToRoles': visibleToRoles,
    };
  }

  static CatalogDocument fromMap(Map<String, dynamic> map, String documentId) {
    return CatalogDocument(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      thumbnailUrl: map['thumbnailUrl'] ?? '',
      type: _typeFromString(map['type'] ?? 'pdf'),
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      isActive: map['isActive'] ?? true,
      visibleToRoles: List<String>.from(map['visibleToRoles'] ?? ['admin', 'vendor']),
    );
  }

  static CatalogType _typeFromString(String typeStr) {
    switch (typeStr.toLowerCase()) {
      case 'pdf':
        return CatalogType.pdf;
      case 'image':
        return CatalogType.image;
      case 'offer':
        return CatalogType.offer;
      default:
        return CatalogType.pdf;
    }
  }
}