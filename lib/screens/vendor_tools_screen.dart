import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'quote_screen.dart';
import 'price_management_screen.dart';
import 'catalog_screen.dart';  // Añadido para catálogo
import 'quote_history_screen.dart';  // Añadido para historial de cotizaciones
import 'payment_register_screen.dart';  // Añadido para registro de abonos
import 'payment_history_screen.dart';  // Añadido para historial de abonos
// import 'sales_report_screen.dart';  // Se implementará en el futuro

class VendorToolsScreen extends StatefulWidget {
  final String? vendorId;

  const VendorToolsScreen({Key? key, this.vendorId}) : super(key: key);

  @override
  _VendorToolsScreenState createState() => _VendorToolsScreenState();
}

class _VendorToolsScreenState extends State<VendorToolsScreen> {
  String? _effectiveVendorId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeVendorId();
  }

  Future<void> _initializeVendorId() async {
    // Si ya tenemos un ID, úsalo
    if (widget.vendorId != null && widget.vendorId!.isNotEmpty) {
      setState(() {
        _effectiveVendorId = widget.vendorId;
        _isLoading = false;
      });
      return;
    }

    try {
      // Intentar obtener el ID del vendedor de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final storedVendorId = prefs.getString('current_vendor_id');

      setState(() {
        _effectiveVendorId = storedVendorId;
        _isLoading = false;
      });

      // Si obtuvimos un ID, guardarlo para referencia futura
      if (_effectiveVendorId != null && _effectiveVendorId!.isNotEmpty) {
        print("DEBUG: Usando vendorId desde SharedPreferences: $_effectiveVendorId");
      } else {
        print("DEBUG: No se encontró vendorId en SharedPreferences");

        // Solo para desarrollo: asignar un ID de prueba
        // En producción, comenta esta línea
        _effectiveVendorId = "vendor_test_id";
      }
    } catch (e) {
      print("DEBUG: Error obteniendo vendorId: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Herramientas de Vendedor'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herramientas de Vendedor'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Herramientas de Ventas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Tarjeta para Cotizaciones
            _buildFeatureCard(
              context,
              title: 'Generar Cotización',
              description: 'Crea y envía cotizaciones personalizadas a los clientes',
              icon: Icons.description,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QuoteScreen()),
                );
              },
            ),

            // NUEVA TARJETA: Historial de Cotizaciones
            _buildFeatureCard(
              context,
              title: 'Historial de Cotizaciones',
              description: 'Visualiza todas tus cotizaciones anteriores',
              icon: Icons.history,
              color: Colors.amber,
              onTap: () {
                if (_effectiveVendorId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuoteHistoryScreen(vendorId: _effectiveVendorId),
                    ),
                  );
                } else {
                  _showVendorIdError(context);
                }
              },
            ),

            // NUEVA TARJETA: Catálogo de Productos
            _buildFeatureCard(
              context,
              title: 'Catálogo de Productos',
              description: 'Explora todos los productos disponibles',
              icon: Icons.menu_book,
              color: Colors.green.shade700,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CatalogScreen()),
                );
              },
            ),

            // Tarjeta para Gestión de Precios
            _buildFeatureCard(
              context,
              title: 'Gestión de Precios',
              description: 'Configura precios especiales y descuentos',
              icon: Icons.attach_money,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PriceManagementScreen()),
                );
              },
            ),

            // NUEVA SECCIÓN: Abonos y Pagos
            const SizedBox(height: 20),
            const Text(
              'Abonos y Pagos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // NUEVA TARJETA: Registrar Abono
            _buildFeatureCard(
              context,
              title: 'Registrar Abono',
              description: 'Registra pagos y abonos de tus clientes',
              icon: Icons.payments_outlined,
              color: Colors.purple,
              onTap: () {
                if (_effectiveVendorId != null) {
                  print("DEBUG: Navegando a pantalla de registro de abonos con vendorId: $_effectiveVendorId");
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentRegisterScreen(vendorId: _effectiveVendorId!),
                    ),
                  );
                } else {
                  _showVendorIdError(context);
                }
              },
            ),

            // NUEVA TARJETA: Historial de Abonos
            _buildFeatureCard(
              context,
              title: 'Historial de Abonos',
              description: 'Visualiza todos los abonos registrados',
              icon: Icons.receipt_long,
              color: Colors.indigo,
              onTap: () {
                if (_effectiveVendorId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentHistoryScreen(vendorId: _effectiveVendorId!),
                    ),
                  );
                } else {
                  _showVendorIdError(context);
                }
              },
            ),

            const SizedBox(height: 20),
            const Text(
              'Próximamente',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Funcionalidades futuras
            _buildFeatureCard(
              context,
              title: 'Gestión de Rutas',
              description: 'Planifica y organiza las rutas de visitas a clientes',
              icon: Icons.map,
              color: Colors.orange,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente disponible')),
                );
              },
              isComingSoon: true,
            ),

            // Reportes de Ventas - Marcado como próximamente
            _buildFeatureCard(
              context,
              title: 'Reportes de Ventas',
              description: 'Visualiza informes y estadísticas de ventas',
              icon: Icons.bar_chart,
              color: Colors.purple,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Próximamente disponible')),
                );
              },
              isComingSoon: true,  // Marcado como próximamente
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
      BuildContext context, {
        required String title,
        required String description,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
        bool isComingSoon = false,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isComingSoon) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Próximamente',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NUEVO MÉTODO: Para mostrar error cuando no se dispone del vendorId
  void _showVendorIdError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error: ID de vendedor no disponible'),
        backgroundColor: Colors.red,
      ),
    );
  }
}