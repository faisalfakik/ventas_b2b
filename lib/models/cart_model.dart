// lib/models/cart_model.dart
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'product_model.dart'; // Asegúrate que usa tu modelo Product final

class Cart with ChangeNotifier {
  Map<String, CartItem> _items = {};
  
  Map<String, CartItem> get items {
    return {..._items};
  }
  
  int get itemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }
  
  double get totalAmount {
    return _items.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }
  
  void addItem(String productId, Product product, int quantity) {
    if (_items.containsKey(productId)) {
      // Change quantity
      _items.update(
        productId,
        (existingCartItem) => existingCartItem.copyWith(
          quantity: existingCartItem.quantity + quantity,
        ),
      );
    } else {
      _items.putIfAbsent(
        productId,
        () => CartItem(
          productId: productId,
          product: product,
          quantity: quantity,
        ),
      );
    }
    notifyListeners();
  }
  
  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }
  
  void clear() {
    _items = {};
    notifyListeners();
  }
}

@immutable
class CartItem {
  final String productId;
  final Product product; // Guardar el objeto Product completo
  final int quantity;

  const CartItem({
    required this.productId,
    required this.product,
    required this.quantity,
  });

  // Getters para fácil acceso
  double get unitSalePrice => product.salePrice; // Precio unitario de venta (con descuento)
  double get subtotal => unitSalePrice * quantity;

  // CopyWith
  CartItem copyWith({
    String? productId,
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  // Para persistencia (opcional)
  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'product': product.toMap(), // Guardar el producto como mapa
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    if (json['productId'] == null || json['quantity'] == null || json['product'] == null) {
      throw const FormatException("Faltan campos requeridos en CartItem JSON");
    }
    return CartItem(
      productId: json['productId'],
      quantity: (json['quantity'] as num).toInt(),
      product: Product.fromMap(json['product']), // Reconstruir producto
    );
  }

  // Igualdad
  @override
  bool operator ==(Object other) => identical(this, other) || other is CartItem && runtimeType == other.runtimeType && productId == other.productId;
  @override
  int get hashCode => productId.hashCode;
}