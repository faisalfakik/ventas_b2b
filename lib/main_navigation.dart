import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/product_catalog_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'services/product_service.dart';
import 'package:provider/provider.dart';
import 'services/cart_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  int _cartItemCount = 0;

  // Claves para los navegadores anidados
  final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _catalogNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _cartNavigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _profileNavigatorKey = GlobalKey<NavigatorState>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('🔍 DEBUG NAV: Cargando pantalla principal');
    _loadCartItemCount();
  }

  void _loadCartItemCount() {
    print('🔍 DEBUG NAV: Iniciando carga de datos iniciales');
    final cartService = context.read<CartService>();
    setState(() {
      _cartItemCount = cartService.uniqueItemCount;
    });
    print('🔍 DEBUG NAV: Datos iniciales cargados correctamente');
  }

  void _onItemTapped(int index) {
    // Si se presiona el índice 4 (búsqueda), mostramos el modal en lugar de navegar
    if (index == 4) {
      _showSearchModal();
      return;
    }

    // Si se presiona Home (index == 0), asegurarse de volver a la pantalla inicial
    if (index == 0) {
      // Aseguramos que se vaya a la pantalla Home inicial (primera ruta)
      _homeNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    // Actualizar contador de carrito antes de cambiar de pantalla
    if (index == 2) { // Si estamos navegando al carrito
      _loadCartItemCount();
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _showSearchModal() {
    // Animación mejorada para el panel de búsqueda
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Buscar",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation1,
          curve: Curves.easeInOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation1,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.9,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  // Desactivamos el autofocus para evitar que se abra el teclado
                  child: const DepartmentsTopSheet(autoFocus: false),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Manejar el botón de regreso
      onWillPop: () async {
        final isFirstRouteInCurrentTab = !await _getNavigatorKey().currentState!.maybePop();

        if (isFirstRouteInCurrentTab) {
          // Si estamos en la ruta inicial, permitir salir de la app
          return true;
        }

        // Si no estamos en la ruta inicial, manejamos la navegación dentro de la pestaña
        return false;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // Home
            Navigator(
              key: _homeNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const HomeScreen(),
                settings: settings,
              ),
            ),

            // Catalog
            Navigator(
              key: _catalogNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const ProductCatalogScreen(
                    categoryFilter: null,
                    title: 'Catálogo'
                ),
                settings: settings,
              ),
            ),

            // Cart
            Navigator(
              key: _cartNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const CartScreen(),
                settings: settings,
              ),
            ),

            // Profile
            Navigator(
              key: _profileNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const ProfileScreen(),
                settings: settings,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.green.shade700,
            unselectedItemColor: Colors.grey.shade600,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_outlined),
                activeIcon: Icon(Icons.grid_view),
                label: 'Catálogo',
              ),
              BottomNavigationBarItem(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_cart_outlined),
                    if (_cartItemCount > 0)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 1,
                                  spreadRadius: 0,
                                )
                              ]
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            _cartItemCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: const Icon(Icons.shopping_cart),
                label: 'Carrito',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Perfil',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.search),
                activeIcon: Icon(Icons.search),
                label: 'Búsqueda',
              ),
            ],
            elevation: 0,
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  // Obtener la clave de navegador activa
  GlobalKey<NavigatorState> _getNavigatorKey() {
    switch (_selectedIndex) {
      case 0:
        return _homeNavigatorKey;
      case 1:
        return _catalogNavigatorKey;
      case 2:
        return _cartNavigatorKey;
      case 3:
        return _profileNavigatorKey;
      default:
        return _homeNavigatorKey;
    }
  }
}

// Widget para el panel de departamentos desde arriba
class DepartmentsTopSheet extends StatefulWidget {
  final bool autoFocus;

  const DepartmentsTopSheet({Key? key, this.autoFocus = true}) : super(key: key);

  @override
  _DepartmentsTopSheetState createState() => _DepartmentsTopSheetState();
}

class _DepartmentsTopSheetState extends State<DepartmentsTopSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;
  final ProductService _productService = ProductService();
  final FocusNode _searchFocusNode = FocusNode();

  // Map para mantener el estado de expansión de los departamentos
  final Map<String, bool> _expandedDepartments = {};

  // Datos de muestra para departamentos y subdepartamentos
  final Map<String, List<String>> _departmentsData = {
    'AIRES ACONDICIONADOS': ['SPLIT', 'AIRE DE VENTANA', 'AIRES PORTÁTILES'],
    'EQUIPOS DE ENFRIAMIENTO': ['DESHUMIDIFICADORES', 'CONGELADORES'],
    'ACCESORIOS': ['PROTECTORES', 'MANTENIMIENTO'],
    'REPUESTOS': ['COMPRESORES', 'TARJETAS', 'TURBINAS'],
    'HERRAMIENTAS': ['SOLDADURA', 'MEDICIÓN', 'CORTE'],
  };

  @override
  void initState() {
    super.initState();

    // Inicializar todos los departamentos como no expandidos
    for (var dept in _departmentsData.keys) {
      _expandedDepartments[dept] = false;
    }

    // Solo enfocar el campo de búsqueda si autoFocus es true
    if (widget.autoFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _toggleExpanded(String department) {
    setState(() {
      _expandedDepartments[department] = !(_expandedDepartments[department] ?? false);
    });
  }

  void _navigateToCategory(BuildContext context, String category) {
    Navigator.pop(context); // Cerrar el modal

    // Navegar a la categoría manteniendo la barra de navegación
    final mainNavState = context.findAncestorStateOfType<_MainNavigationState>();
    if (mainNavState != null) {
      // Cambia a la pestaña de catálogo y luego navega a la categoría
      mainNavState._onItemTapped(1);

      // Da tiempo para que la transición ocurra
      Future.delayed(const Duration(milliseconds: 100), () {
        Navigator.push(
          mainNavState._catalogNavigatorKey.currentContext!,
          MaterialPageRoute(
            builder: (context) => ProductCatalogScreen(
              categoryFilter: category,
              title: category,
            ),
          ),
        );
      });
    }
  }

  void _showAllProducts(BuildContext context) {
    Navigator.pop(context); // Cerrar el modal

    // Navegar a todos los productos manteniendo la barra de navegación
    final mainNavState = context.findAncestorStateOfType<_MainNavigationState>();
    if (mainNavState != null) {
      mainNavState._onItemTapped(1); // Cambiar a la pestaña de catálogo
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar departamentos según la búsqueda
    Map<String, List<String>> filteredDepartments = {};

    if (_searchQuery.isEmpty) {
      filteredDepartments = _departmentsData;
    } else {
      final query = _searchQuery.toLowerCase();
      _departmentsData.forEach((dept, subdepts) {
        if (dept.toLowerCase().contains(query)) {
          filteredDepartments[dept] = subdepts;
        } else {
          final matchingSubdepts = subdepts.where(
                  (subdept) => subdept.toLowerCase().contains(query)
          ).toList();
          if (matchingSubdepts.isNotEmpty) {
            filteredDepartments[dept] = matchingSubdepts;
          }
        }
      });
    }

    return Column(
      children: [
        // Barra de título con manejador de cierre
        Container(
          padding: const EdgeInsets.only(left: 8, right: 16, top: 16, bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 24,
                splashRadius: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      hintText: 'Buscar departamentos o productos',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onTap: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Categorías recientes o populares
        if (_searchQuery.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'CATEGORÍAS POPULARES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      _buildPopularCategoryChip(context, 'SPLIT'),
                      _buildPopularCategoryChip(context, 'AIRES PORTÁTILES'),
                      _buildPopularCategoryChip(context, 'MANTENIMIENTO'),
                      _buildPopularCategoryChip(context, 'PROTECTORES'),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Botón Ver todos los productos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: InkWell(
            onTap: () => _showAllProducts(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_view, color: Colors.green.shade700),
                  const SizedBox(width: 10),
                  Text(
                    'Ver todos los productos',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Título de sección
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              const Text(
                'Departamentos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Text(
                  '${filteredDepartments.length}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Lista de departamentos
        Expanded(
          child: filteredDepartments.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No se encontraron resultados',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Intenta con otra búsqueda',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Limpiar búsqueda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade50,
                    foregroundColor: Colors.green.shade700,
                    elevation: 0,
                    side: BorderSide(color: Colors.green.shade200),
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            itemCount: filteredDepartments.length,
            itemBuilder: (context, index) {
              final department = filteredDepartments.keys.elementAt(index);
              final subDepartments = filteredDepartments[department]!;
              final isExpanded = _expandedDepartments[department] ?? false;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isExpanded ? Colors.white : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isExpanded ? 0.1 : 0.05),
                      blurRadius: isExpanded ? 5 : 3,
                      spreadRadius: isExpanded ? 1 : 0,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Departamento principal
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _toggleExpanded(department),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(department),
                                color: Colors.green.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  department,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isExpanded ? Colors.green.shade50 : Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                  color: isExpanded ? Colors.green.shade700 : Colors.grey.shade700,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Subdepartamentos (si está expandido)
                    if (isExpanded)
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 200),
                        firstChild: Container(height: 0),
                        secondChild: Column(
                          children: subDepartments.map((subdept) =>
                              Material(
                                color: Colors.grey.shade50,
                                child: InkWell(
                                  onTap: () => _navigateToCategory(context, subdept),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subdept,
                                            style: TextStyle(
                                              color: Colors.grey.shade800,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 14,
                                            color: Colors.grey
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                          ).toList(),
                        ),
                        crossFadeState: isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularCategoryChip(BuildContext context, String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        label: Text(
          category,
          style: TextStyle(
            color: Colors.green.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        side: BorderSide(color: Colors.green.shade200),
        onPressed: () => _navigateToCategory(context, category),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
    );
  }

  IconData _getCategoryIcon(String department) {
    switch (department) {
      case 'AIRES ACONDICIONADOS':
        return Icons.ac_unit;
      case 'EQUIPOS DE ENFRIAMIENTO':
        return Icons.kitchen;
      case 'ACCESORIOS':
        return Icons.cable;
      case 'REPUESTOS':
        return Icons.settings;
      case 'HERRAMIENTAS':
        return Icons.handyman;
      default:
        return Icons.category;
    }
  }
}