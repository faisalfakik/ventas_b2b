import 'product_model.dart';

class QuoteItem {
  final Product product;
  int quantity;
  double price;
  double discount; // Porcentaje de descuento

  QuoteItem({
    required this.product,
    this.quantity = 1,
    required this.price,
    this.discount = 0,
  });
}