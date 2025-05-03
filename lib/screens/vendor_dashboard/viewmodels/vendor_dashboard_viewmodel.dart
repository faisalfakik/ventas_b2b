import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:collection/collection.dart';

import '../../../models/vendor_model.dart' as vend;
import '../../../models/customer_model.dart' as cust;
import '../../../models/visit_model.dart';
import '../../../models/sales_goal_model.dart';

import '../../../services/vendor_service.dart';
import '../../../services/visit_service.dart';
import '../../../services/customer_service.dart';
import 'package:ventas_b2b/utils/helpers.dart'; // Si tienes helpers

// --- Enums para Filtros ---
enum VisitFilterType { upcoming, today, thisWeek, alerts }
enum CustomerFilterType { all, news } // TODO: Implementar más filtros

// --- Clases auxiliares ---
class VisitQueryResult {
  final List<Visit> visits;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;
  VisitQueryResult({required this.visits, this.lastDocument, required this.hasMore});
}

// --- ViewModel ---
class VendorDashboardViewModel extends ChangeNotifier {
  // --- Dependencias ---
  final String vendorId;
  final VendorService _vendorService = VendorService(); // TODO: Inyectar
  final VisitService _visitService = VisitService();     // TODO: Inyectar
  final CustomerService _customerService = CustomerService(); // TODO: Inyectar

  // --- Estado Interno ---
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOffline = false;
  bool _initialLoadComplete = false;
  vend.Vendor? _vendor;
  SalesGoal? _currentGoal;
  List<Visit> _visits = [];
  List<cust.Customer> _customers = [];
  Map<String, cust.Customer> _customerCache = {};
  DocumentSnapshot? _lastVisitDoc;
  DocumentSnapshot? _lastCustomerDoc;
  bool _hasMoreVisits = true;
  bool _hasMoreCustomers = true;
  bool _isFetchingMoreVisits = false;
  bool _isFetchingMoreCustomers = false;
  VisitFilterType _selectedVisitFilter = VisitFilterType.upcoming;
  CustomerFilterType _selectedCustomerFilter = CustomerFilterType.all; // Placeholder
  StreamSubscription? _connectivitySubscription;
  int _visitsTodayCount = 0;
  int _newCustomersCount = 0;
  double _salesToday = 0;

  // --- Getters Públicos ---
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOffline => _isOffline;
  bool get initialLoadComplete => _initialLoadComplete;
  vend.Vendor? get vendor => _vendor;
  SalesGoal? get currentGoal => _currentGoal;
  List<Visit> get displayVisits => List.unmodifiable(_visits);
  List<cust.Customer> get displayCustomers => List.unmodifiable(_customers);
  cust.Customer? getCachedCustomer(String id) => _customerCache[id];
  bool get isFetchingMoreVisits => _isFetchingMoreVisits;
  bool get isFetchingMoreCustomers => _isFetchingMoreCustomers;
  bool get hasMoreVisits => _hasMoreVisits;
  bool get hasMoreCustomers => _hasMoreCustomers;
  VisitFilterType get selectedVisitFilter => _selectedVisitFilter;
  CustomerFilterType get selectedCustomerFilter => _selectedCustomerFilter;
  int get visitsTodayCount => _visitsTodayCount;
  int get newCustomersCount => _newCustomersCount;
  double get salesToday => _salesToday;

  // --- Constructor e Inicialización ---
  VendorDashboardViewModel({required this.vendorId}) {
    debugPrint("🔍 VIEWMODEL: Constructor START (VendorID: $vendorId)");
    print("ViewModel Initialized for Vendor: $vendorId");
    _initialize();
  }

  Future<void> _initialize() async {
    loadInitialData(); // <-- DEBE ESTAR DESCOMENTADA
    // _listenToConnectivity(); // <-- DEBE SEGUIR COMENTADA
  }

  @override
  void dispose() {
    print("ViewModel Disposed");
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // --- Lógica Principal ---
  Future<void> loadInitialData({bool refresh = false}) async {
    // Log inicial para verificar entrada y estado
    debugPrint("➡️ LOAD_INITIAL: Entrando. refresh=$refresh, _isLoading=$_isLoading, _initialLoadComplete=$_initialLoadComplete");

    // Condición corregida para permitir la primera carga y evitar re-entradas innecesarias
    if (!refresh && _initialLoadComplete) {
        debugPrint("➡️ LOAD_INITIAL: Saliendo temprano (no es refresh y carga inicial ya completada)");
        return;
    }

    debugPrint("➡️ LOAD_INITIAL: Procediendo con la carga...");

    // Asegurar estado de carga y notificar ANTES del trabajo async
    // Poner isLoading = true siempre al iniciar la carga efectiva
    _isLoading = true;
    if (refresh) {
       _errorMessage = null; // Limpiar error solo en refresh explícito
    }
    // Notificar siempre que se inicia una carga (para UI)
    notifyListeners();

    // Resetear paginación si es un refresh O la primera carga real
    if (refresh || !_initialLoadComplete) {
        debugPrint("➡️ LOAD_INITIAL: Reseteando flags de paginación.");
        _lastVisitDoc = null; _hasMoreVisits = true;
        _lastCustomerDoc = null; _hasMoreCustomers = true;
    }

    try {
        print('DEBUG VM: Iniciando Future.wait...');
        // Lista de llamadas CORRECTAS para Future.wait
        final results = await Future.wait([
          _vendorService.getVendorById(vendorId).then((_) { print('DEBUG VM: getVendorById COMPLETADO'); return _; }),
          _vendorService.getCurrentSalesGoalForVendor(vendorId).then((_) { print('DEBUG VM: getCurrentSalesGoal COMPLETADO'); return _; }),
          _loadInitialCustomers(10).then((_) { print('DEBUG VM: _loadInitialCustomers COMPLETADO'); return _; }),
          // _loadInitialVisits(10).then((_) { print('DEBUG VM: _loadInitialVisits COMPLETADO'); return _; }), // MANTENER COMENTADO POR AHORA
          _calculateStats().then((_) { print('DEBUG VM: _calculateStats COMPLETADO'); return _; }),
        ]).timeout(const Duration(seconds: 25)); // Mantener timeout razonable
        print('DEBUG VM: Future.wait COMPLETADO');

        // Procesar resultados (Asegúrate que los índices coincidan con la lista de arriba)
        _vendor = results[0] as vend.Vendor?;
        _currentGoal = results[1] as SalesGoal?;
        // results[2] es el resultado de _loadInitialCustomers, ya actualizó estado interno
        // results[3] es _loadInitialVisits, comentado
        // results[4] es _calculateStats, no devuelve valor relevante aquí

        if (_vendor == null && !refresh) { // Solo mostrar error si no es refresh y falla
            _errorMessage = "Vendedor no encontrado.";
        }

        // Marcar como completado DENTRO del try, después del wait exitoso
        _initialLoadComplete = true;

    } catch (e, s) {
        print("Error loading initial dashboard data: $e\n$s");
        _errorMessage = "Error al cargar datos. Verifica tu conexión.";
        // Resetear estado en caso de error grave para evitar inconsistencias
        _vendor = null; _currentGoal = null; _visits = []; _customers = []; _customerCache = {};
        _hasMoreCustomers = false; _hasMoreVisits = false;
        _initialLoadComplete = false; // Indicar que la carga inicial falló
    } finally {
        _isLoading = false; // Poner en false AL FINAL, haya éxito o error
        notifyListeners();
    }
  } // Fin loadInitialData CORRECTO

  ClientFilterType _mapCustomerToClientFilter(CustomerFilterType customerFilter) {
    switch (customerFilter) {
      case CustomerFilterType.news:
        return ClientFilterType.news;
      case CustomerFilterType.all:
      default:
        return ClientFilterType.all;
    }
  }

  Future<dynamic> _loadInitialCustomers(int limit) async {
    debugPrint("DEBUG VM: _loadInitialCustomers START"); // Log añadido
    try { // Añadir try-catch individual
      final result = await _customerService.getClientsByVendorId(
        vendorId,
        limit: limit,
        // Usar la función de mapeo para corregir el tipo del filtro:
        filter: _mapCustomerToClientFilter(_selectedCustomerFilter), // <-- CORRECCIÓN IMPORTANTE
      );
      _customers = result.clients;
      _customerCache = { for (var c in result.clients) c.id : c };
      _lastCustomerDoc = result.lastDocument;
      _hasMoreCustomers = result.hasMore;
      _sortLists(); // Llamar a sort después de actualizar datos
      debugPrint("DEBUG VM: _loadInitialCustomers OK - ${result.clients.length} clientes cargados"); // Log añadido
      return result; // Devolver el resultado por si se usa en Future.wait
    } catch (e, s) {
       debugPrint("❌ ERROR VM: Error en _loadInitialCustomers: $e\n$s");
       _customers = []; // Limpiar en caso de error
       _customerCache = {};
       _hasMoreCustomers = false;
       notifyListeners(); // Notificar el estado de error/vacío
       throw Exception("Error cargando clientes iniciales: $e"); // Re-lanzar para que Future.wait falle
    }
  }

  Future<VisitQueryResult> _loadInitialVisits(int limit) async {
    final result = await _visitService.getUpcomingVisitsByVendorId(
        vendorId, limit: limit, filter: _selectedVisitFilter // Pasa filtro
    );
    _visits = result.visits; // Establece la lista inicial
    _lastVisitDoc = result.lastDocument;
    _hasMoreVisits = result.hasMore;
    await _eagerLoadCustomersForVisits(_visits); // Carga clientes para estas visitas
    _sortLists(); // Ordena la lista inicial
    return result;
  }

  Future<void> loadMoreVisits() async {
    if (_isFetchingMoreVisits || !_hasMoreVisits || _isOffline) return;
    _isFetchingMoreVisits = true; notifyListeners();
    print("Attempting to load more visits after: ${_lastVisitDoc?.id}");
    try {
      final result = await _visitService.getUpcomingVisitsByVendorId( vendorId,
          limit: 10, startAfterDoc: _lastVisitDoc, filter: _selectedVisitFilter );
      await _eagerLoadCustomersForVisits(result.visits);
      _visits.addAll(result.visits); // Añade a la lista
      _lastVisitDoc = result.lastDocument; _hasMoreVisits = result.hasMore; _sortLists();
    } catch (e) { print("Error loading more visits: $e"); _errorMessage = "Error cargando más visitas."; }
    finally { _isFetchingMoreVisits = false; notifyListeners(); }
  }

  Future<dynamic> loadMoreCustomers() async {
    if (_isFetchingMoreCustomers || !_hasMoreCustomers || _isOffline) {
      return Future.value(null); // Salir si no aplica
    }
    _isFetchingMoreCustomers = true;
    notifyListeners();
    debugPrint("DEBUG VM: loadMoreCustomers START after: ${_lastCustomerDoc?.id}"); // Log añadido

    try { // Añadir try-catch
      final result = await _customerService.getClientsByVendorId(
        vendorId,
        limit: 10, // O el límite que uses para paginación
        startAfterDoc: _lastCustomerDoc,
        // Usar la función de mapeo para corregir el tipo del filtro:
        filter: _mapCustomerToClientFilter(_selectedCustomerFilter), // <-- CORRECCIÓN IMPORTANTE
      );
      _customers.addAll(result.clients);
      _customerCache.addAll({ for (var c in result.clients) c.id : c });
      _lastCustomerDoc = result.lastDocument;
      _hasMoreCustomers = result.hasMore;
      _sortLists(); // Llamar a sort después de añadir datos
      debugPrint("DEBUG VM: loadMoreCustomers OK - ${result.clients.length} clientes más cargados. hasMore=$_hasMoreCustomers"); // Log añadido
      return result; // Devolver resultado por si acaso
    } catch (e, s) {
        debugPrint("❌ ERROR VM: Error en loadMoreCustomers: $e\n$s");
        _errorMessage = "Error cargando más clientes.";
        // No necesariamente reseteamos _hasMoreCustomers aquí
    } finally {
        _isFetchingMoreCustomers = false;
        notifyListeners(); // Notificar fin de carga (con o sin error)
    }
    return Future.value(null); // Retornar algo si hubo error
  }

  Future<void> _eagerLoadCustomersForVisits(List<Visit> visits) async {
    final neededIds = visits.map((v) => v.customerId).where((id) => !_customerCache.containsKey(id)).toSet().toList();
    if (neededIds.isNotEmpty) {
      print("Eager loading customers: $neededIds");
      try {
        final fetched = await _customerService.getClientsByIds(neededIds);
        _customerCache.addAll(fetched);
        // No notificamos necesariamente, la UI usará la caché actualizada al renderizar VisitCard
      } catch (e) { print("Error eager loading customers: $e"); }
    }
  }

  Future<void> applyVisitFilter(VisitFilterType newFilter) async {
    if (_selectedVisitFilter == newFilter || _isLoading || _isFetchingMoreVisits) return; // Evita cambios durante carga
    _selectedVisitFilter = newFilter;
    print("Applying visit filter: $newFilter - Reloading data...");
    await loadInitialData(refresh: true); // Recarga todo al cambiar filtro por ahora
  }

  Future<void> applyCustomerFilter(CustomerFilterType newFilter) async {
    if (_selectedCustomerFilter == newFilter || _isLoading || _isFetchingMoreCustomers) return;
    _selectedCustomerFilter = newFilter;
    print("Applying customer filter: $newFilter - Reloading data...");
    await loadInitialData(refresh: true);
  }

  Future<void> acknowledgeNewCustomer(String customerId) async {
    if (_isOffline) { _showOfflineMessage("actualizar cliente"); return; }
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final original = _customers[index];
      // Actualización optimista
      _customers[index] = original.copyWith(
        acknowledgedByVendor: () => true,
        isNewlyAssigned: () => false,
      );
      _customerCache[customerId] = _customers[index]; _sortLists(); notifyListeners();
      try {
        await _customerService.acknowledgeAssignment(customerId, vendorId); await _calculateStats();
      } catch (e) { print("Error ack Customer: $e"); _errorMessage = "Error al act. cliente."; _customers[index] = original; _customerCache[customerId] = original; _sortLists(); notifyListeners(); }
    }
  }

  Future<void> deactivateVisitAlert(String visitId) async {
    if (_isOffline) { _showOfflineMessage("actualizar visita"); return; }
    final index = _visits.indexWhere((v) => v.id == visitId);
    if (index != -1) {
      final original = _visits[index];
      // Actualización optimista
      _visits[index] = original.copyWith(isAlertActive: false); _sortLists(); notifyListeners();
      try { await _visitService.deactivateAlert(visitId); await _calculateStats(); }
      catch (e) { print("Error deact alert: $e"); _errorMessage = "Error al act. visita."; _visits[index] = original; _sortLists(); notifyListeners(); }
    }
  }

  Future<void> _calculateStats() async {
    if (_isOffline) return;
    try {
      print('DEBUG VM: _calculateStats START - Calculando sync...');
      final today = DateTime.now();
      _visitsTodayCount = _visits.where((v) => v.date?.year == today.year && v.date?.month == today.month && v.date?.day == today.day).length;
      _newCustomersCount = _customers.where((c) => c.createdAt?.year == today.year && c.createdAt?.month == today.month && c.createdAt?.day == today.day).length;
      print('DEBUG VM: _calculateStats - Counts calculados. Llamando a getSalesAmountForPeriod...');
      _salesToday = await _vendorService.getSalesAmountForPeriod(vendorId, today);
      print('DEBUG VM: _calculateStats END - Sales obtenidas');
    } catch (e) {
      print("Error calculating stats: $e");
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _isOffline = result == ConnectivityResult.none;
      if (!_isOffline && _initialLoadComplete) {
        loadInitialData(refresh: true); // Recarga al recuperar conexión
      }
      notifyListeners();
    });
  }

  void _sortLists() {
    print('DEBUG VM: _sortLists START');
    // Ordenar visitas por fecha
    _visits.sort((a, b) => (a.date ?? DateTime.now()).compareTo(b.date ?? DateTime.now()));
    print('DEBUG VM: _sortLists - Visitas ordenadas');
    // Ordenar clientes por nombre
    _customers.sort((a, b) => (a.name ?? '').compareTo(b.name ?? ''));
    print('DEBUG VM: _sortLists - Clientes ordenados');
    notifyListeners();
    print('DEBUG VM: _sortLists END');
  }

  void _showOfflineMessage(String action) {
    _errorMessage = "No puedes $action sin conexión.";
    notifyListeners();
  }

  void clearErrorMessage() { if (_errorMessage != null) { _errorMessage = null; notifyListeners(); } }

} // Fin VendorDashboardViewModel

// --- Extensiones (Mover a utils/helpers.dart o models/*_extensions.dart) ---
extension VisitExtensions on Visit {
  bool get isAlertActiveReal => (isAdminAlert ?? false) && (isAlertActive ?? true);
}
extension CustomerExtensions on cust.Customer {
  bool get isPendingAcknowledgement => (isNewlyAssigned ?? false) || !(acknowledgedByVendor ?? true);
}