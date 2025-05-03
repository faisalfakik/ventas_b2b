// lib/services/customer_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Para debugPrint

// Ajusta la ruta a tu modelo Customer
import '../models/customer_model.dart' as cust; // Asegúrate que el archivo se llame así

// --- Clases y Enums Auxiliares (Puedes moverlos a un archivo común o al ViewModel) ---
// Necesario para el retorno de métodos paginados
class ClientQueryResult { // Renombrado de CustomerQueryResult
  final List<cust.Customer> clients;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  ClientQueryResult({required this.clients, this.lastDocument, required this.hasMore});
}
// Enum para filtros (Necesita coincidir con el usado en el ViewModel)
enum ClientFilterType { all, news, inactive, withNotes } // Renombrado de CustomerFilterType


// --- Servicio ---
class CustomerService {
  late final FirebaseFirestore _db;
  late final CollectionReference<Map<String, dynamic>> _clientsCollection;
  final String _collectionName = 'clients'; // Tu nombre de colección confirmado

  CustomerService({FirebaseFirestore? firestore}) {
    _db = firestore ?? FirebaseFirestore.instance;
    _clientsCollection = _db.collection(_collectionName);
  }

  // --- Métodos para el Dashboard (Adaptados y Nuevos) ---

  // Obtener clientes por Vendedor (PAGINADO y con FILTROS)
  Future<ClientQueryResult> getClientsByVendorId( // Renombrado de getCustomersByVendorId
      String vendorId, {
        required int limit,
        DocumentSnapshot? startAfterDoc,
        ClientFilterType? filter,
      }) async {
    if (vendorId.isEmpty) {
      return ClientQueryResult(clients: [], hasMore: false, lastDocument: null);
    }
    debugPrint("SERVICE: Fetching clients for vendor $vendorId, filter: $filter, limit: $limit, after: ${startAfterDoc?.id}");

    try {
      Query<Map<String, dynamic>> query = _clientsCollection
          .where('assignedVendorId', isEqualTo: vendorId); // Campo clave

      // --- Aplicar Filtros ---
      // Nota: La implementación real de filtros 'inactive' y 'withNotes' requiere
      // que tengas los campos correspondientes en Firestore (ej: lastActivityTimestamp, hasNotes)
      // y probablemente índices compuestos.
      switch(filter) {
        case ClientFilterType.news:
        // Asume campo bool 'acknowledgedByVendor' existe y es false para nuevos
          query = query.where('acknowledgedByVendor', isEqualTo: false);
          // Se necesita un orderBy si usas where en campo diferente al de startAfterDoc
          // Si no tienes un timestamp de asignación, ordena por nombre o ID
          query = query.orderBy('businessName'); // O por el campo que prefieras ordenar los nuevos
          break;
        case ClientFilterType.inactive:
          print("WARN: Filtro 'inactivo' no implementado completamente en CustomerService.");
          // Ejemplo: query = query.where('lastActivityTimestamp', isLessThan: Timestamp.fromDate(DateTime.now().subtract(Duration(days:90))));
          // query = query.orderBy('lastActivityTimestamp');
          query = query.orderBy('businessName'); // Orden por defecto temporal
          break;
        case ClientFilterType.withNotes:
          print("WARN: Filtro 'con notas' no implementado completamente en CustomerService.");
          // Ejemplo: query = query.where('hasNotes', isEqualTo: true);
          // query = query.orderBy('businessName');
          query = query.orderBy('businessName'); // Orden por defecto temporal
          break;
        case ClientFilterType.all:
        default:
        // Orden alfabético por defecto
          query = query.orderBy('businessName');
          break;
      }

      // Aplicar Paginación
      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snapshot = await query.limit(limit).get();
      final clients = snapshot.docs.map((doc) => cust.Customer.fromFirestore(doc)).toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      final hasMore = clients.length == limit;

      debugPrint("SERVICE: Fetched ${clients.length} clients. HasMore: $hasMore.");
      return ClientQueryResult(clients: clients, lastDocument: lastDoc, hasMore: hasMore);

    } catch (e, s) {
      print('ERROR en getClientsByVendorId: $e\n$s');
      rethrow; // Relanzar para que ViewModel lo maneje
    }
  }

  // Obtener múltiples clientes por sus IDs (Eager Loading para Visitas)
  Future<Map<String, cust.Customer>> getClientsByIds(List<String> clientIds) async {
    if (clientIds.isEmpty) return {};
    debugPrint("SERVICE: Fetching ${clientIds.length} clients by IDs.");

    final Map<String, cust.Customer> clientMap = {};
    const chunkSize = 30; // Límite de Firestore para consulta 'in'

    for (var i = 0; i < clientIds.length; i += chunkSize) {
      final chunk = clientIds.sublist(i, i + chunkSize > clientIds.length ? clientIds.length : i + chunkSize);
      if (chunk.isNotEmpty) {
        try {
          final snapshot = await _clientsCollection
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (var doc in snapshot.docs) {
            clientMap[doc.id] = cust.Customer.fromFirestore(doc);
          }
        } catch (e, s) {
          print("ERROR fetching Customer chunk ($chunk): $e\n$s");
          // Podrías decidir continuar o lanzar el error
        }
      }
    }
    debugPrint("SERVICE: Total clients fetched by IDs: ${clientMap.length}");
    return clientMap;
  }

  // Marcar asignación como vista
  Future<void> acknowledgeAssignment(String clientId, String vendorId) async {
    debugPrint("SERVICE: Firestore - Acknowledging assignment for Customer $clientId by vendor $vendorId");
    try {
      await _clientsCollection.doc(clientId).update({
        'acknowledgedByVendor': true,
        'isNewlyAssigned': false, // Actualizar ambos es buena idea
        'lastAcknowledgedBy': vendorId,
        'lastAcknowledgedTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, s) {
      print("ERROR en acknowledgeAssignment: $e\n$s");
      rethrow;
    }
  }

  // Contar asignaciones nuevas (para stats)
  Future<int> countNewAssignments(String vendorId) async {
    debugPrint("SERVICE: Counting new assignments for vendor $vendorId");
    try {
      // Asume que acknowledgedByVendor=false significa nuevo/pendiente
      final snapshot = await _clientsCollection
          .where('assignedVendorId', isEqualTo: vendorId)
          .where('acknowledgedByVendor', isEqualTo: false)
          .count()
          .get();
      final count = snapshot.count ?? 0;
      debugPrint("SERVICE: Found $count new assignments.");
      return count;
    } catch (e, s) {
      print("ERROR en countNewAssignments: $e\n$s");
      return 0;
    }
  }

  // --- Métodos CRUD Existentes (Adaptados y Mantenidos) ---

  Future<cust.Customer?> getClientById(String clientId) async { // Renombrado
    try {
      final doc = await _clientsCollection.doc(clientId).get();
      return doc.exists ? cust.Customer.fromFirestore(doc) : null;
    } catch (e, s) {
      print('ERROR en getClientById $clientId: $e\n$s');
      return null;
    }
  }

  // Dejé este método por si lo usas en OTRA parte de la app, si no, puedes borrarlo
  Future<List<cust.Customer>> getAllClients() async {
    try {
      final snapshot = await _clientsCollection.orderBy('businessName').get(); // Ordenar al obtener todos
      return snapshot.docs.map((doc) => cust.Customer.fromFirestore(doc)).toList();
    } catch (e, s) {
      print('ERROR en getAllClients: $e\n$s');
      return [];
    }
  }

  // Crear cliente (asegúrate que Customer tenga toMap())
  Future<String?> createCustomer(cust.Customer Customer) async {
    try {
      final docRef = await _clientsCollection.add(Customer.toMap());
      return docRef.id;
    } catch (e, s) {
      print('ERROR en createClient: $e\n$s');
      return null;
    }
  }

  // Actualizar cliente
  Future<bool> updateCustomer(cust.Customer Customer) async {
    try {
      // Usar update es más seguro que set para no borrar campos no incluidos en toMap
      await _clientsCollection.doc(Customer.id).update(Customer.toMap());
      return true;
    } catch (e, s) {
      print('ERROR en updateClient ${Customer.id}: $e\n$s');
      return false;
    }
  }

  // Eliminar cliente
  Future<bool> deleteCustomer(String clientId) async {
    try {
      await _clientsCollection.doc(clientId).delete();
      return true;
    } catch (e, s) {
      print('ERROR en deleteClient $clientId: $e\n$s');
      return false;
    }
  }

  // Búsqueda (mantenida, pero considera optimizar con campos Lower o búsqueda más avanzada)
  Future<List<cust.Customer>> searchClients(String query) async {
    try {
      query = query.toLowerCase().trim();
      if (query.isEmpty) return [];

      // Asume que tienes campos businessNameLower y nameLower en Firestore
      // y los índices compuestos necesarios.
      Query<Map<String, dynamic>> nameQuery = _clientsCollection
          .orderBy('businessNameLower')
          .where('businessNameLower', isGreaterThanOrEqualTo: query)
          .where('businessNameLower', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(15); // Limitar resultados

      Query<Map<String, dynamic>> contactQuery = _clientsCollection
          .orderBy('nameLower')
          .where('nameLower', isGreaterThanOrEqualTo: query)
          .where('nameLower', isLessThanOrEqualTo: query + '\uf8ff')
          .limit(15);

      // Ejecutar ambas consultas en paralelo
      final results = await Future.wait([nameQuery.get(), contactQuery.get()]);
      final nameSnapshot = results[0];
      final contactSnapshot = results[1];

      // Combinar sin duplicados
      final clientsMap = <String, cust.Customer>{};
      for (var doc in nameSnapshot.docs) { clientsMap[doc.id] = cust.Customer.fromFirestore(doc); }
      for (var doc in contactSnapshot.docs) { clientsMap.putIfAbsent(doc.id, () => cust.Customer.fromFirestore(doc)); }

      return clientsMap.values.toList();

    } catch (e, s) {
      print('ERROR en searchClients: $e\n$s');
      return [];
    }
  }

  // El método de migración puede quedarse si lo usas para desarrollo
  Future<void> migrateExampleDataToFirestore() async { /* ... tu código ... */ }

  Future<List<cust.Customer>> getClients() async {
    return await getAllClients();
  }

} // Fin CustomerService