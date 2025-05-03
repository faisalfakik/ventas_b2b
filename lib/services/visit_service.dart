import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint
import 'package:flutter/material.dart'; // Para DateUtils

// Ajusta rutas a tus modelos y viewmodel (para enums/query results)
import '../models/visit_model.dart';
import '../screens/vendor_dashboard/viewmodels/vendor_dashboard_viewmodel.dart' show VisitQueryResult, VisitFilterType;

class VisitService {
  late final FirebaseFirestore _db;
  // IMPORTANTE: Crear esta colección 'visits' en Firestore
  late final CollectionReference<Map<String, dynamic>> _visitsCollection;
  final String _collectionName = 'visits';

  VisitService({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
    _visitsCollection = _db.collection(_collectionName);
  }

  // Obtener visitas paginadas y filtradas
  Future<VisitQueryResult> getUpcomingVisitsByVendorId(
      String vendorId, {
        required int limit,
        DocumentSnapshot? startAfterDoc,
        VisitFilterType filter = VisitFilterType.upcoming,
      }) async {
    if (vendorId.isEmpty) {
      return VisitQueryResult(visits: [], hasMore: false, lastDocument: null);
    }
    print("DEBUG: Fetching visits for vendor $vendorId, filter: $filter, limit: $limit, after: ${startAfterDoc?.id}");

    try {
      Query<Map<String, dynamic>> query = _visitsCollection
          .where('vendorId', isEqualTo: vendorId);

      // --- Aplicar Filtros ---
      // Nota: Firestore tiene limitaciones en filtros compuestos.
      // Puede que necesites crear índices compuestos en la consola de Firebase.
      // Firestore te avisará en el log si falta un índice.
      final now = DateTime.now();
      final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final todayEnd = Timestamp.fromDate(todayStart.toDate().add(const Duration(days: 1)));
      final weekStart = Timestamp.fromDate(todayStart.toDate().subtract(Duration(days: now.weekday - 1)));
      final weekEnd = Timestamp.fromDate(weekStart.toDate().add(const Duration(days: 7)));

      switch (filter) {
        case VisitFilterType.today:
          query = query.where('date', isGreaterThanOrEqualTo: todayStart)
              .where('date', isLessThan: todayEnd);
          // Ordenar por fecha es implícito por el filtro de rango, pero añadir explícitamente es buena práctica
          query = query.orderBy('date');
          break;
        case VisitFilterType.thisWeek:
          query = query.where('date', isGreaterThanOrEqualTo: weekStart)
              .where('date', isLessThan: weekEnd);
          query = query.orderBy('date');
          break;
        case VisitFilterType.alerts:
          query = query.where('isAdminAlert', isEqualTo: true)
              .where('isAlertActive', isEqualTo: true);
          // Necesitarás un índice compuesto para esto O ordenar por otro campo
          query = query.orderBy('date'); // Ordenar alertas por fecha
          break;
        case VisitFilterType.upcoming:
        default:
        // Próximas visitas (incluyendo hoy) O alertas activas
        // Este filtro es complejo para hacer en una sola query eficiente en Firestore
        // Opción 1: Query simple de próximas visitas y filtrar alertas en cliente (menos eficiente si hay muchas alertas pasadas)
          query = query.where('date', isGreaterThanOrEqualTo: Timestamp.now());
          query = query.orderBy('date');
          // Opción 2: Hacer dos queries y combinarlas (más complejo)
          // Opción 3: Modelar datos diferente (ej. campo 'isUpcomingOrActiveAlert')
          print("WARN: Filtro 'upcoming' simplificado. No incluye alertas pasadas activas.");
          break;
      }

      // Aplicar Paginación
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }
      final snapshot = await query.limit(limit).get();

      final visits = snapshot.docs.map((doc) => Visit.fromFirestore(doc)).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = visits.length == limit;

      print("DEBUG: Fetched ${visits.length} visits. HasMore: $hasMore. LastDoc: ${lastDoc?.id}");
      return VisitQueryResult(visits: visits, lastDocument: lastDoc, hasMore: hasMore);

    } catch (e, s) {
      print('ERROR en getUpcomingVisitsByVendorId (paginado): $e\n$s');
      // Podrías devolver un resultado vacío o relanzar
      return VisitQueryResult(visits: [], hasMore: false, lastDocument: null);
      // rethrow;
    }
  }

  // Desactivar la alerta visual de una visita
  Future<void> deactivateAlert(String visitId) async {
    print("DEBUG: Firestore - Deactivating alert for visit $visitId");
    try {
      await _visitsCollection.doc(visitId).update({
        'isAlertActive': false,
        // Opcional: Cambiar status? Ej: si era 'Alerta Pendiente' -> 'Programada'
        // 'status': 'Programada'
      });
    } catch (e, s) {
      print("ERROR en deactivateAlert $visitId: $e\n$s");
      rethrow;
    }
  }

  // Contar visitas para hoy (para stats)
  Future<int> countVisitsForToday(String vendorId) async {
    print("DEBUG: Counting visits for today for vendor $vendorId");
    try {
      final now = DateTime.now();
      final todayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final todayEnd = Timestamp.fromDate(todayStart.toDate().add(const Duration(days: 1)));

      final snapshot = await _visitsCollection
          .where('vendorId', isEqualTo: vendorId)
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .where('date', isLessThan: todayEnd)
      // Podrías añadir filtro de status si solo cuentas programadas vs completadas
      // .where('status', isEqualTo: 'Programada')
          .count()
          .get();
      final count = snapshot.count ?? 0;
      print("DEBUG: Found $count visits for today.");
      return count;
    } catch (e, s) {
      print("ERROR en countVisitsForToday: $e\n$s");
      return 0;
    }
  }

} // Fin VisitService