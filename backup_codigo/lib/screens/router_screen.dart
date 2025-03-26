import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'product_catalog_screen.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';
import 'store_seller_screen.dart';

class RouterScreen extends StatefulWidget {
  const RouterScreen({Key? key}) : super(key: key);

  @override
  _RouterScreenState createState() => _RouterScreenState();
}

class _RouterScreenState extends State<RouterScreen> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const ProductCatalogScreen(isAdmin: false),  // Vista de cliente
    const CartScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Método para navegar a la pantalla de vendedor de tienda
  void navigateToStoreSeller(String storeId, String sellerId, String storeName, String sellerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreSellerScreen(
          storeId: storeId,
          sellerId: sellerId,
          storeName: storeName,
          sellerName: sellerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Catálogo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Carrito',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green,
        onTap: _onItemTapped,
      ),
    );
  }
}