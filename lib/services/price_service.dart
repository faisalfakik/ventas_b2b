import '../models/special_price.dart';

class PriceService {
  // En una implementación real, estos datos vendrían de una base de datos
  final List<SpecialPrice> _specialPrices = [
    SpecialPrice(
      id: 'SP001',
      productId: 'DGSX12CRNW',
      clientId: 'C001', // Para un cliente específico
      price: 210.00, // Precio especial
      discountPercentage: null,
      notes: 'Precio negociado para cliente mayorista',
    ),
    SpecialPrice(
      id: 'SP002',
      productId: 'DGSX18CRNW',
      clientId: null, // Para todos los clientes
      price: 350.00,
      discountPercentage: 5.0, // 5% de descuento
      minQuantity: 5, // Cuando compran 5 o más
      notes: 'Descuento por volumen',
    ),
    SpecialPrice(
      id: 'SP003',
      productId: 'DGSX24CRNW',
      clientId: null, // Para todos los clientes
      price: 420.00,
      discountPercentage: 10.0,
      startDate: DateTime.now().subtract(const Duration(days: 10)),
      endDate: DateTime.now().add(const Duration(days: 20)),
      notes: 'Promoción temporal',
    ),
  ];

  // Obtener todos los precios especiales
  List<SpecialPrice> getAllSpecialPrices() {
    return List.from(_specialPrices);
  }

  // Obtener precios especiales para un producto
  List<SpecialPrice> getSpecialPricesForProduct(String productId) {
    return _specialPrices.where((sp) => sp.productId == productId).toList();
  }

  // Obtener precios especiales para un cliente
  List<SpecialPrice> getSpecialPricesForClient(String clientId) {
    return _specialPrices.where((sp) =>
    sp.clientId == clientId || sp.clientId == null
    ).toList();
  }

  // Obtener precio especial para un cliente y producto específico
  SpecialPrice? getSpecialPriceForClientAndProduct(String clientId, String productId, {int quantity = 1}) {
    // Primero buscamos si hay un precio específico para este cliente y producto
    final clientSpecificPrices = _specialPrices.where((sp) =>
    sp.clientId == clientId &&
        sp.productId == productId &&
        sp.isActive() &&
        sp.appliesForQuantity(quantity)
    ).toList();

    if (clientSpecificPrices.isNotEmpty) {
      // Si hay varios, tomamos el que tenga el precio más bajo
      return clientSpecificPrices.reduce((a, b) => a.price < b.price ? a : b);
    }

    // Si no hay un precio específico para el cliente, buscamos precios generales
    final generalPrices = _specialPrices.where((sp) =>
    sp.clientId == null &&
        sp.productId == productId &&
        sp.isActive() &&
        sp.appliesForQuantity(quantity)
    ).toList();

    if (generalPrices.isNotEmpty) {
      return generalPrices.reduce((a, b) => a.price < b.price ? a : b);
    }

    return null;
  }

  // Agregar un nuevo precio especial
  void addSpecialPrice(SpecialPrice specialPrice) {
    _specialPrices.add(specialPrice);
  }

  // Actualizar un precio especial existente
  void updateSpecialPrice(SpecialPrice specialPrice) {
    final index = _specialPrices.indexWhere((sp) => sp.id == specialPrice.id);
    if (index >= 0) {
      _specialPrices[index] = specialPrice;
    }
  }

  // Eliminar un precio especial
  void deleteSpecialPrice(String id) {
    _specialPrices.removeWhere((sp) => sp.id == id);
  }
}