// lib/models/sales_goal_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesGoal {
  final String id; // ID podría ser generado por Firestore o ser "vendorId_año_mes"
  final String vendorId;
  final int year;
  final int month;
  final double targetAmount;
  final double currentAmount;

  SalesGoal({
    required this.id, required this.vendorId, required this.year,
    required this.month, required this.targetAmount, required this.currentAmount,
  });

  double get completionPercentage {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount * 100).clamp(0.0, 100.0);
  }

  factory SalesGoal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return SalesGoal(
      id: doc.id,
      vendorId: data['vendorId'] ?? '',
      year: data['year'] as int? ?? DateTime.now().year,
      month: data['month'] as int? ?? DateTime.now().month,
      targetAmount: (data['targetAmount'] ?? 0.0).toDouble(),
      currentAmount: (data['currentAmount'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId, 'year': year, 'month': month,
      'targetAmount': targetAmount, 'currentAmount': currentAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  SalesGoal copyWith({
    String? id, String? vendorId, int? year, int? month, double? targetAmount, double? currentAmount,
  }) {
    return SalesGoal(
      id: id ?? this.id, vendorId: vendorId ?? this.vendorId, year: year ?? this.year,
      month: month ?? this.month, targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
    );
  }
}