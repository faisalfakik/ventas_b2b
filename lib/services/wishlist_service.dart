// lib/services/wishlist_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WishlistService extends ChangeNotifier {
  // Clave única para guardar en SharedPreferences
  static const _storageKey = 'user_wishlist_v1';

  // Usar un Set para almacenar IDs de productos (evita duplicados y búsqueda rápida)
  Set<String> _wishlistProductIds = {};

  bool _isLoaded = false; // Flag para saber si ya se cargó desde storage

  // Constructor: Inicia la carga desde el almacenamiento
  WishlistService() {
    _loadWishlist();
  }

  // --- Getters Públicos ---

  /// Devuelve una copia inmodificable del Set de IDs de productos en la lista.
  Set<String> get wishlistProductIds => Set.unmodifiable(_wishlistProductIds);

  /// Devuelve el número de items en la lista.
  int get itemCount => _wishlistProductIds.length;

  /// Indica si la lista de deseos ha sido cargada desde el almacenamiento.
  bool get isLoaded => _isLoaded;

  // --- Métodos Públicos ---

  /// Verifica si un producto está en la lista. Asegura que se haya cargado primero.
  Future<bool> isProductInWishlist(String productId) async {
    // Si no se ha cargado, esperar a que cargue
    if (!_isLoaded) {
      await _loadWishlist();
    }
    return _wishlistProductIds.contains(productId);
  }

  /// Añade un producto a la lista si no estaba, o lo quita si ya estaba.
  /// Devuelve `true` si el producto quedó en la lista, `false` si quedó fuera.
  Future<bool> toggleWishlistStatus(String productId) async {
    // Asegurar que la lista esté cargada antes de modificar
    if (!_isLoaded) {
      await _loadWishlist();
    }

    bool added;
    if (_wishlistProductIds.contains(productId)) {
      _wishlistProductIds.remove(productId);
      added = false;
    } else {
      _wishlistProductIds.add(productId);
      added = true;
    }

    // Notificar a los listeners y guardar los cambios
    notifyListeners();
    await _saveWishlist();

    return added;
  }

  /// Añade un producto explícitamente (si no existe ya).
  Future<void> addToWishlist(String productId) async {
    if (!_isLoaded) await _loadWishlist();
    if (_wishlistProductIds.add(productId)) { // .add devuelve true si se añadió
      notifyListeners();
      await _saveWishlist();
    }
  }

  /// Quita un producto explícitamente (si existe).
  Future<void> removeFromWishlist(String productId) async {
    if (!_isLoaded) await _loadWishlist();
    if (_wishlistProductIds.remove(productId)) { // .remove devuelve true si se quitó
      notifyListeners();
      await _saveWishlist();
    }
  }


  /// Limpia completamente la lista de deseos.
  Future<void> clearWishlist() async {
    if (_wishlistProductIds.isNotEmpty) {
      _wishlistProductIds.clear();
      notifyListeners();
      await _saveWishlist();
    }
  }

  // --- Métodos Privados de Persistencia ---

  Future<void> _loadWishlist() async {
    // Evitar cargas múltiples si ya se está cargando o ya cargó
    if (_isLoaded && _wishlistProductIds.isNotEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? itemsList = prefs.getStringList(_storageKey); // Guardar como lista de Strings

      if (itemsList != null) {
        _wishlistProductIds = Set.from(itemsList); // Crear Set desde la lista
        print("✅ Wishlist cargada desde SharedPreferences (${_wishlistProductIds.length} items).");
      } else {
        print("ℹ️ No se encontró Wishlist guardada.");
      }
    } catch (e, s) {
      print("❌ Error al cargar Wishlist: $e\n$s");
      // Considerar loggear a Crashlytics: FirebaseCrashlytics.instance.recordError(e, s);
    } finally {
      // Marcar como cargado incluso si hubo error o estaba vacía
      _isLoaded = true;
      // Notificar por si acaso algo cambió (ej: carga inicial vacía)
      // aunque usualmente se notifica al añadir/quitar
      notifyListeners();
    }
  }

  Future<void> _saveWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convertir el Set a List para guardarlo
      await prefs.setStringList(_storageKey, _wishlistProductIds.toList());
      // print("💾 Wishlist guardada en SharedPreferences."); // Log opcional
    } catch (e, s) {
      print("❌ Error al guardar Wishlist: $e\n$s");
      // FirebaseCrashlytics.instance.recordError(e, s);
    }
  }
}