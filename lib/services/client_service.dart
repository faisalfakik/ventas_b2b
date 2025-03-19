import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'clients';

  // Obtener todos los clientes
  Future<List<Client>> getClients() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection(_collection).get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Client.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error al obtener clientes: $e');
      // Si hay un error, devolver lista vacía o datos de fallback para evitar que la app se rompa
      return _getFallbackClients();
    }
  }

  // Método getAllClients que está siendo llamado desde otras clases
  Future<List<Client>> getAllClients() async {
    try {
      final querySnapshot = await _firestore.collection(_collection).get();
      return querySnapshot.docs
          .map((doc) => Client.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      print('Error getting all clients: $e');
      return [];
    }
  }

  // Obtener un cliente específico por ID
  Future<Client?> getClientById(String clientId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collection).doc(clientId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Client.fromMap(data, doc.id);
      }
      return null;
    } catch (e) {
      print('Error al obtener cliente $clientId: $e');
      return null;
    }
  }

  // Crear un nuevo cliente
  Future<String?> createClient(Client client) async {
    try {
      DocumentReference docRef = await _firestore.collection(_collection).add(client.toMap());
      return docRef.id;
    } catch (e) {
      print('Error al crear cliente: $e');
      return null;
    }
  }

  // Actualizar un cliente existente
  Future<bool> updateClient(Client client) async {
    try {
      await _firestore.collection(_collection).doc(client.id).update(client.toMap());
      return true;
    } catch (e) {
      print('Error al actualizar cliente ${client.id}: $e');
      return false;
    }
  }

  // Eliminar un cliente
  Future<bool> deleteClient(String clientId) async {
    try {
      await _firestore.collection(_collection).doc(clientId).delete();
      return true;
    } catch (e) {
      print('Error al eliminar cliente $clientId: $e');
      return false;
    }
  }

  // Buscar clientes por nombre o email
  Future<List<Client>> searchClients(String query) async {
    try {
      query = query.toLowerCase();

      // Búsqueda por nombre (más común)
      QuerySnapshot nameSnapshot = await _firestore
          .collection(_collection)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Búsqueda por email
      QuerySnapshot emailSnapshot = await _firestore
          .collection(_collection)
          .where('email', isGreaterThanOrEqualTo: query)
          .where('email', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      // Combinar resultados
      Set<String> processedIds = {};
      List<Client> results = [];

      for (var doc in nameSnapshot.docs) {
        if (!processedIds.contains(doc.id)) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          results.add(Client.fromMap(data, doc.id));
          processedIds.add(doc.id);
        }
      }

      for (var doc in emailSnapshot.docs) {
        if (!processedIds.contains(doc.id)) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          results.add(Client.fromMap(data, doc.id));
          processedIds.add(doc.id);
        }
      }

      return results;
    } catch (e) {
      print('Error al buscar clientes: $e');
      return [];
    }
  }

  // Obtener clientes por vendedor asignado
  Future<List<Client>> getClientsByVendor(String vendorId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(_collection)
          .where('assignedVendorId', isEqualTo: vendorId)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Client.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      print('Error al obtener clientes por vendedor $vendorId: $e');
      return [];
    }
  }

  // Datos de fallback en caso de error
  List<Client> _getFallbackClients() {
    return [
      Client(
        id: 'C001',
        name: 'Refrigeración Industrial S.A.',
        email: 'info@refrigeracionindustrial.com',
        phone: '555-123-4567',
        address: 'Av. Principal 1234, Ciudad Industrial',
      ),
      Client(
        id: 'C002',
        name: 'Hoteles Premium',
        email: 'compras@hotelespremium.com',
        phone: '555-987-6543',
        address: 'Calle Comercial 567, Zona Hotelera',
      ),
      Client(
        id: 'C003',
        name: 'Distribuidora del Norte',
        email: 'ventas@distnorte.com',
        phone: '555-456-7890',
        address: 'Blvd. Norte 890, Parque Industrial',
      ),
    ];
  }

  // Método para migrar datos de ejemplo a Firestore (útil para inicializar la base de datos)
  Future<void> migrateExampleDataToFirestore() async {
    try {
      // Verificar si ya hay datos
      QuerySnapshot existingData = await _firestore.collection(_collection).limit(1).get();
      if (existingData.docs.isNotEmpty) {
        print('Ya existen datos en la colección de clientes. Omitiendo migración.');
        return;
      }

      // Si no hay datos, agregar los ejemplos
      List<Client> exampleClients = _getFallbackClients();

      for (Client client in exampleClients) {
        await _firestore.collection(_collection).add(client.toMap());
      }

      print('Datos de ejemplo migrados correctamente a Firestore');
    } catch (e) {
      print('Error al migrar datos de ejemplo: $e');
    }
  }
}