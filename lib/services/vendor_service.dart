import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

// Ajusta rutas a tus modelos
import 'package:ventas_b2b/models/visit_model.dart';
import 'package:ventas_b2b/models/sales_goal_model.dart';
import 'package:ventas_b2b/models/vendor_model.dart' as vend;

class VendorService {
  late final FirebaseFirestore _db;
  // OJO: Tu colección se llama 'vendor' (singular) según tu screenshot
  late final CollectionReference<Map<String, dynamic>> _vendorsCollection;
  final String _collectionName = 'vendor';

  VendorService({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
    _vendorsCollection = _db.collection(_collectionName);
  }

  // Obtener datos del vendedor por su ID (que usualmente es el UID de Firebase Auth)
  Future<vend.Vendor?> getVendorById(String vendorId) async {
    try {
      final doc = await _vendorsCollection.doc(vendorId).get();
      if (!doc.exists) return null;
      return vend.Vendor.fromFirestore(doc);
    } catch (e) {
      print('Error getting vendor: $e');
      return null;
    }
  }

  // Obtener la meta de ventas actual para el vendedor
  Future<SalesGoal?> getCurrentSalesGoalForVendor(String vendorId) async {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;
    // Asume que tienes una colección 'salesGoals' y los documentos tienen ID como 'vendorId_año_mes'
    // O podrías tener una subcolección bajo cada documento de 'vendor'
    final goalDocId = '${vendorId}_${year}_$month';
    print("DEBUG: Fetching sales goal for $goalDocId");

    try {
      // Cambia 'salesGoals' por el nombre real de tu colección de metas
      final doc = await _db.collection('salesGoals').doc(goalDocId).get();
      if (doc.exists) {
        return SalesGoal.fromFirestore(doc); // Asume que SalesGoal tiene fromFirestore
      } else {
        print("WARN: SalesGoal document not found for ID: $goalDocId");
        // Considera devolver una meta por defecto (ej. 0) o null
        return null;
        // O: return SalesGoal(year: year, month: month, targetAmount: 0, currentAmount: 0);
      }
    } catch (e, s) {
      print('ERROR en getCurrentSalesGoalForVendor $goalDocId: $e\n$s');
      // Devolver null o una meta por defecto en caso de error
      return null;
    }
  }

  // Obtener ventas agregadas para un periodo (EJEMPLO - Necesita adaptación)
  Future<double> getSalesAmountForPeriod(String vendorId, DateTime date) async {
    // Esta función es compleja y depende MUCHO de cómo almacenas las ventas/pagos.
    // Podría requerir consultar la colección 'payments' o una colección 'orders'.
    // Hacer sumas en el cliente puede ser ineficiente/costoso.
    // Considera usar Cloud Functions para calcular y guardar agregados.
    print("DEBUG: Calculating sales amount for vendor $vendorId on $date (simulated)");

    // --- SIMULACIÓN --- (Reemplazar con lógica real)
    final todayStart = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final todayEnd = Timestamp.fromDate(todayStart.toDate().add(const Duration(days: 1)));

    try {
      // Ejemplo MUY BÁSICO si tienes colección 'payments'
      final snapshot = await _db.collection('payments')
          .where('vendorId', isEqualTo: vendorId)
          .where('createdAt', isGreaterThanOrEqualTo: todayStart)
          .where('createdAt', isLessThan: todayEnd)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['amount'] ?? 0.0).toDouble();
      }
      print("DEBUG: Calculated sales: $total");
      return total;

    } catch (e, s) {
      print("ERROR calculando sales amount: $e\n$s");
      return 0.0; // Devolver 0 en caso de error
    }
    // --- FIN SIMULACIÓN ---
  }

} // Fin VendorService