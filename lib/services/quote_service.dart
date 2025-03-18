import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quote_model.dart';
import '../models/quote_item.dart'; // O item_model.dart según corresponda
import '../models/product_model.dart';

class QuoteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collectionName = 'quotes';

  // Obtener todas las cotizaciones de un vendedor
  Future<List<Quote>> getQuotesByVendor(String vendorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('vendorId', isEqualTo: vendorId)
          .orderBy('createdAt', descending: true)
          .get();

      return _processQuoteSnapshots(querySnapshot);
    } catch (e) {
      print('Error obteniendo cotizaciones del vendedor: $e');
      return [];
    }
  }

  // Obtener cotizaciones de un cliente específico
  Future<List<Quote>> getQuotesByClient(String clientId) async {
    try {
      final querySnapshot = await _firestore
          .collection(collectionName)
          .where('clientId', isEqualTo: clientId)
          .orderBy('createdAt', descending: true)
          .get();

      return _processQuoteSnapshots(querySnapshot);
    } catch (e) {
      print('Error obteniendo cotizaciones del cliente: $e');
      return [];
    }
  }

  // Obtener una cotización por ID
  Future<Quote?> getQuoteById(String quoteId) async {
    try {
      final docSnapshot = await _firestore
          .collection(collectionName)
          .doc(quoteId)
          .get();

      if (!docSnapshot.exists) {
        return null;
      }

      // Obtener los detalles de los productos
      final data = docSnapshot.data() as Map<String, dynamic>;
      final items = await _createQuoteItemsFromData(data);

      return Quote.fromMap(data, docSnapshot.id, items);
    } catch (e) {
      print('Error obteniendo cotización: $e');
      return null;
    }
  }

  // Crear una nueva cotización
  Future<String?> createQuote(Quote quote) async {
    try {
      final docRef = await _firestore
          .collection(collectionName)
          .add(quote.toMap());

      return docRef.id;
    } catch (e) {
      print('Error creando cotización: $e');
      return null;
    }
  }

  // Actualizar estado de cotización
  Future<bool> updateQuoteStatus(String quoteId, String newStatus) async {
    try {
      await _firestore
          .collection(collectionName)
          .doc(quoteId)
          .update({'status': newStatus});

      return true;
    } catch (e) {
      print('Error actualizando estado de cotización: $e');
      return false;
    }
  }

  // Método auxiliar para procesar snapshots de cotizaciones
  Future<List<Quote>> _processQuoteSnapshots(QuerySnapshot querySnapshot) async {
    List<Quote> quotes = [];

    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Obtener los detalles de los productos para cada item
      final items = await _createQuoteItemsFromData(data);

      quotes.add(Quote.fromMap(data, doc.id, items));
    }

    return quotes;
  }

  // Método auxiliar para crear QuoteItems a partir de datos de Firestore
  Future<List<QuoteItem>> _createQuoteItemsFromData(Map<String, dynamic> data) async {
    List<QuoteItem> items = [];

    if (data['items'] != null) {
      for (var itemData in data['items']) {
        // En un caso real, aquí obtendrías los detalles del producto desde Firestore
        // Por ahora, creamos un producto dummy
        final product = Product(
          id: itemData['productId'] ?? '',
          name: 'Producto', // En un caso real obtendrías el nombre real
          price: 0, // El precio se obtiene del item, no del producto
          category: '',
          description: '',
          imageUrl: '',
          stock: 0,
        );

        items.add(QuoteItem(
          product: product,
          quantity: itemData['quantity'] ?? 1,
          price: (itemData['price'] ?? 0).toDouble(),
          discount: (itemData['discount'] ?? 0).toDouble(),
        ));
      }
    }

    return items;
  }
}