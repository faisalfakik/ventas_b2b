import 'package:flutter/material.dart';
import 'vendor_dashboard/vendor_dashboard_screen.dart';
import 'vendor_tools_screen.dart';
import 'price_management_screen.dart';
import 'quote_screen.dart';
import 'product_catalog_screen.dart';
import 'admin_sales_review_screen.dart'; // Importar la nueva pantalla
import 'serial_batch_upload_screen.dart'; // Importar la pantalla de carga de seriales

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        backgroundColor: Colors.indigo,
      ),
      drawer: _buildAdminDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Administración del Sistema',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Grid de opciones
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildAdminCard(
                  context,
                  title: 'Gestión de Productos',
                  icon: Icons.inventory,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProductCatalogScreen(isAdmin: true)),
                    );
                  },
                ),
                _buildAdminCard(
                  context,
                  title: 'Gestión de Precios',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PriceManagementScreen()),
                    );
                  },
                ),
                _buildAdminCard(
                  context,
                  title: 'Cotizaciones',
                  icon: Icons.description,
                  color: Colors.amber,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QuoteScreen()),
                    );
                  },
                ),
                _buildAdminCard(
                  context,
                  title: 'Panel de Vendedor',
                  icon: Icons.person,
                  color: Colors.deepPurple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VendorDashboardScreen(vendorId: 'V001')),
                    );
                  },
                ),
                _buildAdminCard(
                  context,
                  title: 'Herramientas de Vendedor',
                  icon: Icons.build,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const VendorToolsScreen()),
                    );
                  },
                ),
                _buildAdminCard(
                  context,
                  title: 'Reportes',
                  icon: Icons.bar_chart,
                  color: Colors.teal,
                  onTap: () {
                    // Navegar a una futura pantalla de reportes
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Próximamente: Reportes')),
                    );
                  },
                ),

                // Nuevas tarjetas para la gestión de ventas de tiendas
                _buildAdminCard(
                  context,
                  title: 'Revisión de Ventas',
                  icon: Icons.store,
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminSalesReviewScreen()),
                    );
                  },
                ),
                _buildAdminCard(
                  context,
                  title: 'Cargar Seriales',
                  icon: Icons.qr_code,
                  color: Colors.indigo,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SerialBatchUploadScreen()),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.indigo,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.admin_panel_settings,
                    size: 36,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Panel Administrativo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Gestión de Productos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductCatalogScreen(isAdmin: true)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Gestión de Precios'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PriceManagementScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Cotizaciones'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuoteScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Panel de Vendedor'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VendorDashboardScreen(vendorId: 'V001')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Herramientas de Vendedor'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VendorToolsScreen()),
              );
            },
          ),

          // Nuevas opciones en el drawer
          const Divider(),
          const ListTile(
            title: Text(
              'GESTIÓN DE TIENDAS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Revisión de Ventas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminSalesReviewScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Cargar Seriales'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SerialBatchUploadScreen()),
              );
            },
          ),

          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar Sesión'),
            onTap: () {
              // Volver a la pantalla de login
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
    );
  }
}