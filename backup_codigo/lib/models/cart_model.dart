import 'package:flutter/foundation.dart';
import 'product_model.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final double? discountPercentage;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    this.discountPercentage,
  });

  double get totalPrice {
    if (discountPercentage != null) {
      final discountedPrice = price * (1 - (discountPercentage! / 100));
      return discountedPrice * quantity;
    }
    return price * quantity;
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl,
      discountPercentage: discountPercentage,
    );
  }
}

class Cart with ChangeNotifier {
  Map<String, CartItem> _items = {};
  String? _specialInstructions;

  Map<String, CartItem> get items {
    return {..._items};
  }

  // Nueva propiedad para instrucciones especiales
  String? get specialInstructions => _specialInstructions;

  // Nuevo método para establecer instrucciones especiales
  void setSpecialInstructions(String? instructions) {
    _specialInstructions = instructions;
    notifyListeners();
  }

  int get itemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  int get uniqueItemCount {
    return _items.length;
  }

  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  // Getter para compatibilidad con el checkout screen
  double get totalPrice => totalAmount;

  void addProduct(Product product) {
    if (_items.containsKey(product.id)) {
      // Incrementar cantidad
      _items.update(
        product.id,
            (existingItem) => existingItem.copyWith(
          quantity: existingItem.quantity + 1,
        ),
      );
    } else {
      // Añadir nuevo item
      _items.putIfAbsent(
        product.id,
            () => CartItem(
          id: product.id,
          name: product.name,
          price: product.price,
          quantity: 1,
          imageUrl: product.imageUrl,
          discountPercentage: product.discountPercentage,
        ),
      );
    }
    notifyListeners();
  }

  void removeSingleItem(String productId) {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId]!.quantity > 1) {
      _items.update(
        productId,
            (existingItem) => existingItem.copyWith(
          quantity: existingItem.quantity - 1,
        ),
      );
    } else {
      _items.remove(productId);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void updateItemQuantity(String productId, int newQuantity) {
    if (!_items.containsKey(productId)) {
      return;
    }

    if (newQuantity <= 0) {
      _items.remove(productId);
    } else {
      _items.update(
        productId,
            (existingItem) => existingItem.copyWith(
          quantity: newQuantity,
        ),
      );
    }
    notifyListeners();
  }

  void clear() {
    _items = {};
    _specialInstructions = null; // Limpiar también las instrucciones especiales
    notifyListeners();
  }
}