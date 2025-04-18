import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/store_sale_model.dart';

class AdminSalesReviewScreen extends StatefulWidget {
  const AdminSalesReviewScreen({Key? key}) : super(key: key);

  @override
  State<AdminSalesReviewScreen> createState() => _AdminSalesReviewScreenState();
}

class _AdminSalesReviewScreenState extends State<AdminSalesReviewScreen> {
  List<StoreSale> _pendingSales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingSales();
  }

  Future<void> _loadPendingSales() async {
    setState(() => _isLoading = true);

    try {
      // Solo cargar ventas pendientes de revisión
      final pendingSnapshot = await FirebaseFirestore.instance
          .collection('store_sales')
          .where('status', isEqualTo: 'pending_review')
          .orderBy('saleDate', descending: true)
          .get();

      setState(() {
        _pendingSales = pendingSnapshot.docs
            .map((doc) => StoreSale.fromMap(doc.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading pending sales: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar ventas pendientes: $e')),
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
        'approvedAt': DateTime.now().toIso8601String(),
        'reviewNotes': 'Aprobado manualmente',
      });

      // Marcar el serial como usado
      await FirebaseFirestore.instance
          .collection('valid_serials')
          .add({
        'serial': sale.productSerial,
        'productId': sale.productId,
        'used': true,
        'saleId': sale.id,
        'usedDate': FieldValue.serverTimestamp(),
        'addedManually': true,
      });

      await _loadPendingSales();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Venta aprobada exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aprobar venta: $e')),
      );
    }
  }

  Future<void> _rejectSale(StoreSale sale, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('store_sales')
          .doc(sale.id)
          .update({
        'status': 'rejected',
        'rejectedAt': DateTime.now().toIso8601String(),
        'reviewNotes': reason,
      });

      await _loadPendingSales();

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
        title: const Text('Revisión de Ventas Pendientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingSales,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingSales.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No hay ventas pendientes de revisión',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Todas las ventas han sido procesadas',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: _pendingSales.length,
        itemBuilder: (context, index) {
          final sale = _pendingSales[index];
          return _buildSaleCard(sale);
        },
      ),
    );
  }

  Widget _buildSaleCard(StoreSale sale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.pending, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.productDetails['name'] ?? 'Producto',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Serial: ${sale.productSerial}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(sale.saleDate),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Tienda: ${sale.storeId}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Precio: \$${sale.salePrice.toStringAsFixed(2)}'),
                const Spacer(),
                Text(
                  'Comisión: \$${sale.commissionAmount.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver Fotos'),
                    onPressed: () => _showSaleImages(sale),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                    onPressed: () => _showRejectDialog(sale),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Aprobar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _approveSale(sale),
                  ),
                ),
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
                      fit: BoxFit.cover,
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
                        fit: BoxFit.cover,
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

  void _showRejectDialog(StoreSale sale) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Venta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Por favor, proporcione una razón para rechazar esta venta:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo del rechazo',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Confirmar Rechazo'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Por favor ingrese un motivo para el rechazo'),
                  ),
                );
                return;
              }

              Navigator.pop(context);
              _rejectSale(sale, reason);
            },
          ),
        ],
      ),
    );
  }
}