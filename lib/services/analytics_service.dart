import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart'; // para kDebugMode
import '../models/product_model.dart'; // Asegúrate que usa el modelo unificado final

// TODO: Considerar usar un paquete de logging más robusto (ej: logger, Crashlytics non-fatals)
void _logError(String message, dynamic error, StackTrace? stackTrace) {
  // En modo debug, imprime. En producción, podría loggear a Crashlytics u otro servicio.
  if (kDebugMode) {
    print('$message: $error\n$stackTrace');
  }
  // FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
}

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // --- Constantes ---
  static const String _currencyCode = 'USD'; // O la moneda que uses
  static const String _defaultAffiliation = 'AppVentasB2B'; // Nombre de tu app o tienda

  // --- Identificación de Usuario ---

  /// Asocia los eventos futuros con un ID de usuario específico.
  /// Llamar después del login.
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      print('Analytics User ID set: $userId'); // Log local opcional
    } catch (e, s) {
      _logError('Error setting User ID', e, s);
    }
  }

  /// Limpia el ID de usuario asociado.
  /// Llamar en el logout.
  Future<void> clearUserId() async {
    try {
      await _analytics.setUserId(id: null);
      print('Analytics User ID cleared'); // Log local opcional
    } catch (e, s) {
      _logError('Error clearing User ID', e, s);
    }
  }

  /// Establece propiedades personalizadas del usuario para segmentación.
  Future<void> setUserProperties(Map<String, String?> properties) async {
    try {
      properties.forEach((key, value) async {
        // Limitar longitud de nombre y valor si es necesario según Firebase
        await _analytics.setUserProperty(name: key, value: value);
      });
      print('Analytics User Properties set: $properties'); // Log local opcional
    } catch (e, s) {
      _logError('Error setting User Properties', e, s);
    }
  }

  // --- Eventos de E-commerce ---

  /// Registrar vista de detalle de producto.
  Future<void> logProductView(Product product) async {
    try {
      // Asegurarse que los valores numéricos no sean infinitos o NaN si aplica
      final price = product.salePrice.isFinite ? product.salePrice : 0.0;

      await _analytics.logViewItem(
        currency: _currencyCode,
        value: price,
        items: [
          AnalyticsEventItem(
            itemId: product.id, // ID/SKU del producto
            itemName: product.name, // Nombre del producto
            itemCategory: product.category, // Categoría
            itemVariant: product.model ?? 'N/A', // Variante (ej: color, talla, modelo)
            itemBrand: product.brand ?? 'N/A', // Marca
            price: price, // Precio de venta unitario
            // quantity: 1, // No aplica para view_item usualmente
          ),
        ],
      );
    } catch (e, s) {
      _logError('Error logging Product View', e, s);
    }
  }

  /// Registrar añadir producto al carrito.
  Future<void> logAddToCart(Product product, int quantity) async {
    if (quantity <= 0) return; // No loggear si no se añade cantidad
    try {
      final price = product.salePrice.isFinite ? product.salePrice : 0.0;
      final value = (price * quantity).isFinite ? (price * quantity) : 0.0;

      await _analytics.logAddToCart(
        currency: _currencyCode,
        value: value, // Valor total de los items añadidos
        items: [
          AnalyticsEventItem(
            itemId: product.id,
            itemName: product.name,
            itemCategory: product.category,
            itemVariant: product.model ?? 'N/A',
            itemBrand: product.brand ?? 'N/A',
            price: price, // Precio unitario
            quantity: quantity,
          ),
        ],
      );
    } catch (e, s) {
      _logError('Error logging Add To Cart', e, s);
    }
  }

  // TODO: Considerar logRemoveFromCart si tienes esa acción explícita

  /// Registrar inicio del proceso de checkout (si aplica)
  Future<void> logBeginCheckout(double totalValue, int numberOfItems, List<AnalyticsEventItem> items) async {
    try {
      await _analytics.logBeginCheckout(
        value: totalValue,
        currency: _currencyCode,
        items: items,
        // coupon: '...' // Si aplica algún cupón
      );
    } catch (e, s) {
      _logError('Error logging Begin Checkout', e, s);
    }
  }


  /// Registrar compra completada.
  Future<void> logPurchase({
    required String transactionId, // ID único de la transacción/pedido
    required double value, // Valor total de la transacción (subtotal + tax + shipping - discount)
    double tax = 0.0, // Impuestos (calcular fuera de este servicio)
    double shipping = 0.0, // Costo de envío
    String? coupon, // Código de cupón si se usó
    required List<AnalyticsEventItem> items, // Lista de productos comprados
    String? affiliation, // Afiliación (ej: nombre de la tienda/app)
  }) async {
    try {
      // Validar que el valor sea finito
      final finalValue = value.isFinite ? value : 0.0;

      await _analytics.logPurchase(
        transactionId: transactionId,
        affiliation: affiliation ?? _defaultAffiliation,
        currency: _currencyCode,
        value: finalValue, // Valor total REAL de la transacción
        tax: tax,
        shipping: shipping,
        coupon: coupon,
        items: items,
      );
    } catch (e, s) {
      _logError('Error logging Purchase', e, s);
    }
  }

  // --- Otros Eventos Comunes ---

  /// Registrar término de búsqueda usado.
  Future<void> logSearch(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return;
    try {
      await _analytics.logSearch(searchTerm: searchTerm.trim());
    } catch (e, s) {
      _logError('Error logging Search', e, s);
    }
  }

  /// Registrar acción de compartir contenido.
  Future<void> logShareProduct({required String productId, String method = 'app_share_button'}) async {
    try {
      await _analytics.logShare(
        contentType: 'product', // Tipo de contenido compartido
        itemId: productId, // ID del producto
        method: method, // Método usado para compartir (ej: botón de la app, whatsapp, etc.)
      );
    } catch (e, s) {
      _logError('Error logging Share', e, s);
    }
  }

  /// Registrar selección de contenido (ej: clic en categoría, banner)
  Future<void> logSelectContent({required String contentType, required String itemId}) async {
    try {
      await _analytics.logSelectContent(contentType: contentType, itemId: itemId);
    } catch (e, s) {
      _logError('Error logging Select Content', e, s);
    }
  }

  /// Registrar un evento personalizado.
  Future<void> logCustomEvent({required String name, Map<String, Object>? parameters}) async {
    try {
      // Validar longitud de nombre y parámetros según límites de Firebase
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e, s) {
      _logError('Error logging Custom Event $name', e, s);
    }
  }
}