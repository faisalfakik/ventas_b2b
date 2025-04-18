import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/store_seller_registration_screen.dart';
import 'package:intl/intl.dart';
import '../models/store_sale_model.dart';

class AdminStoreSalesScreen extends StatefulWidget {
  const AdminStoreSalesScreen({Key? key}) : super(key: key);

  @override
  State<AdminStoreSalesScreen> createState() => _AdminStoreSalesScreenState();
}

class _AdminStoreSalesScreenState extends State<AdminStoreSalesScreen> {
  List<StoreSale> _pendingSales = [];
  List<StoreSale> _approvedSales = [];
  bool _isLoading = true;
  bool _showPendingOnly = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);

    try {
      // Cargar ventas pendientes
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('store_sales')
          .where('status', isEqualTo: 'pending')
          .orderBy('saleDate', descending: true)
          .get();

      // Cargar ventas aprobadas
      final approvedSnapshot = await FirebaseFirestore.instance
          .collection('store_sales')
          .where('status', isEqualTo: 'approved')
          .orderBy('saleDate', descending: true)
          .get();

      setState(() {
        _pendingSales = pendingSnapshot.docs
            .map((doc) => StoreSale.fromMap(doc.data()))
            .toList();

        _approvedSales = approvedSnapshot.docs
            .map((doc) => StoreSale.fromMap(doc.data()))
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sales: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar ventas: $e')),
      );
    }
  }

  Future<void> _approveSale(StoreSale sale) async {
    try {
      await FirebaseFirestore.instance
          .collection('store_sales')
          .doc(sale.id)
          .update({
        'status': 'approved',
        'approvedAt': DateTime.now(),
      });

      await _loadSales();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta aprobada exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar venta: $e')),
      );
    }
  }

  Future<void> _rejectSale(StoreSale sale) async {
    try {
      await FirebaseFirestore.instance
          .collection('store_sales')
          .doc(sale.id)
          .update({
        'status': 'rejected',
        'rejectedAt': DateTime.now(),
      });

      await _loadSales();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta rechazada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al rechazar venta: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas de Tiendas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Ver solo pendientes: '),
                Switch(
                  value: _showPendingOnly,
                  onChanged: (value) {
                    setState(() {
                      _showPendingOnly = value;
                    });
                  },
                ),
                const Spacer(),
                Text(
                  _showPendingOnly
                      ? 'Pendientes: ${_pendingSales.length}'
                      : 'Aprobadas: ${_approvedSales.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: _showPendingOnly
                ? _buildPendingSalesList()
                : _buildApprovedSalesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSalesList() {
    if (_pendingSales.isEmpty) {
      return const Center(
        child: Text('No hay ventas pendientes de aprobación'),
      );
    }

    return ListView.builder(
      itemCount: _pendingSales.length,
      itemBuilder: (context, index) {
        final sale = _pendingSales[index];
        return _buildSaleCard(sale, isPending: true);
      },
    );
  }

  Widget _buildApprovedSalesList() {
    if (_approvedSales.isEmpty) {
      return const Center(
        child: Text('No hay ventas aprobadas'),
      );
    }

    return ListView.builder(
      itemCount: _approvedSales.length,
      itemBuilder: (context, index) {
        final sale = _approvedSales[index];
        return _buildSaleCard(sale, isPending: false);
      },
    );
  }

  Widget _buildSaleCard(StoreSale sale, {required bool isPending}) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sale.productDetails['name'] ?? 'Producto',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(sale.saleDate),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Serial: ${sale.productSerial}'),
            Text('Precio: \$${sale.salePrice.toStringAsFixed(2)}'),
            Text('Comisión: \$${sale.commissionAmount.toStringAsFixed(2)} (${sale.commissionRate}%)'),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.visibility),
                  label: const Text('Ver Fotos'),
                  onPressed: () => _showSaleImages(sale),
                ),
                const Spacer(),
                if (isPending) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                    onPressed: () => _rejectSale(sale),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar'),
                    onPressed: () => _approveSale(sale),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSaleImages(StoreSale sale) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: const Text('Imágenes de venta'),
                automaticallyImplyLeading: false,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Imagen del Serial',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Image.network(
                      sale.serialImageUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.error),
                          ),
                        );
                      },
                    ),
                    if (sale.invoiceImageUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Imagen de la Factura',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Image.network(
                        sale.invoiceImageUrl,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.error),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}