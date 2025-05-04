// lib/services/cart_service.dart
import 'package:flutter/foundation.dart';
import '../models/cart_model.dart'; // Importa el modelo CartItem
import '../models/product_model.dart'; // Importa el modelo Product

// Usa ChangeNotifier para notificar cambios a la UI vía Provider
class CartService extends ChangeNotifier {
  // Mapa privado para almacenar los items: ProductID -> CartItem
  final Map<String, CartItem> _items = {};

  // Propiedad para instrucciones especiales (como en tu código original)
  String? _specialInstructions;
  String? get specialInstructions => _specialInstructions;

  // --- Getters Públicos ---
  List<CartItem> get items => _items.values.toList(); // Lista de items
  Map<String, CartItem> get itemsMap => Map.unmodifiable(_items); // Mapa inmodificable
  int get uniqueItemCount => _items.length; // Número de productos distintos
  int get totalQuantity => _items.values.fold(0, (sum, item) => sum + item.quantity); // Cantidad total de unidades
  double get totalAmount => _items.values.fold(0.0, (sum, item) => sum + item.subtotal); // Suma de subtotales
  double get totalPrice => totalAmount; // Alias

  // --- Métodos para Modificar Carrito ---

  /// Añade un producto o incrementa su cantidad. Valida stock.
  void addToCart(Product product, {int quantity = 1}) {
    if (quantity <= 0) return;
    if (!product.inStock) throw Exception('Producto "${product.name}" sin stock');

    final existingItem = _items[product.id];

    if (existingItem != null) {
      // Ya existe: actualizar cantidad
      final newQuantity = existingItem.quantity + quantity;
      if (newQuantity > product.stock) {
        throw Exception('Stock insuficiente para "${product.name}". Máximo: ${product.stock}');
      }
      _items.update(product.id, (item) => item.copyWith(quantity: newQuantity));
    } else {
      // Nuevo item: añadir
      if (quantity > product.stock) {
        throw Exception('Stock insuficiente para "${product.name}". Máximo: ${product.stock}');
      }
      _items[product.id] = CartItem(
        productId: product.id,
        product: product, // Guardar el objeto Product
        quantity: quantity,
      );
    }
    _notifyAndUpdate();
  }

  /// Añade o actualiza la cantidad de un producto a un valor específico.
  void addOrUpdateCart(Product product, {required int quantity}) {
    if (quantity <= 0) {
      removeFromCart(product.id); // Eliminar si la cantidad es 0 o menos
      return;
    }
    if (!product.inStock) throw Exception('Producto "${product.name}" sin stock');
    if (quantity > product.stock) throw Exception('Stock insuficiente para "${product.name}". Máximo: ${product.stock}');

    // Crear o actualizar el item
    _items[product.id] = CartItem(
      productId: product.id,
      product: product,
      quantity: quantity,
    );
    _notifyAndUpdate();
  }


  /// Actualiza la cantidad de un item específico. Lo elimina si llega a 0 o menos.
  void updateCartItemQuantity(String productId, int newQuantity) {
    if (!_items.containsKey(productId)) return; // No existe

    if (newQuantity <= 0) {
      _items.remove(productId);
    } else {
      // Validar stock del producto asociado
      final productStock = _items[productId]!.product.stock;
      if (newQuantity > productStock) {
        throw Exception('Stock insuficiente para ${_items[productId]!.product.name}. Máximo: $productStock');
      }
      // Usar copyWith para actualizar la cantidad inmutablemente si CartItem es immutable
      _items.update(productId, (item) => item.copyWith(quantity: newQuantity));
      // Si CartItem fuera mutable: _items[productId]!.quantity = newQuantity;
    }
    _notifyAndUpdate();
  }

  /// Decrementa la cantidad de un item en 1. Lo elimina si llega a 0.
  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) return;
    final currentQuantity = _items[productId]!.quantity;
    if (currentQuantity > 1) {
      updateCartItemQuantity(productId, currentQuantity - 1);
    } else {
      _items.remove(productId);
      _notifyAndUpdate(); // Asegurar notificación al eliminar el último
    }
    // notifyListeners ya se llama en updateCartItemQuantity si > 1
  }

  /// Elimina un producto completamente del carrito.
  void removeFromCart(String productId) {
    if (_items.containsKey(productId)) {
      _items.remove(productId);
      _notifyAndUpdate();
    }
  }

  /// Vacía completamente el carrito.
  void clearCart() {
    if (_items.isNotEmpty) {
      _items.clear();
      _specialInstructions = null; // Limpiar instrucciones también
      _notifyAndUpdate();
    }
  }

  /// Establece instrucciones especiales.
  void setSpecialInstructions(String? instructions) {
    _specialInstructions = instructions;
    notifyListeners(); // Notificar aunque no se guarde permanentemente aquí
  }

  // --- Métodos de Consulta ---
  int getQuantityInCart(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  bool isInCart(String productId) {
    return _items.containsKey(productId);
  }

  // --- Persistencia (Opcional) y Notificación ---
  void _notifyAndUpdate() {
    notifyListeners(); // Notifica a los listeners (widgets usando Provider.watch/Consumer)
    // _saveCartToPrefs(); // TODO: Implementar guardado si se necesita persistencia
  }

// TODO: Implementar _saveCartToPrefs() y _loadCartFromPrefs() usando SharedPreferences
// y los métodos toJson/fromJson de CartItem si necesitas que el carrito persista
// entre sesiones de la app.
}