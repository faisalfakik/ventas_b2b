import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/serial_validation_service.dart';
import '../models/product_model.dart';

class SerialBatchUploadScreen extends StatefulWidget {
  const SerialBatchUploadScreen({Key? key}) : super(key: key);

  @override
  State<SerialBatchUploadScreen> createState() => _SerialBatchUploadScreenState();
}

class _SerialBatchUploadScreenState extends State<SerialBatchUploadScreen> {
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _productIdController = TextEditingController();
  final SerialValidationService _serialService = SerialValidationService();
  bool _isLoading = false;
  String _status = '';
  List<Map<String, dynamic>> _pendingSerials = [];
  Product? _selectedProduct; // Añadida definición de _selectedProduct

  @override
  void initState() {
    super.initState();
    _loadProducts(); // Cargar productos al iniciar
  }

  // Método para cargar los productos disponibles
  Future<void> _loadProducts() async {
    try {
      setState(() => _isLoading = true);

      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();

      setState(() => _isLoading = false);

      if (snapshot.docs.isEmpty) {
        setState(() {
          _status = 'No hay productos disponibles';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error al cargar productos: $e';
      });
    }
  }

  // Método para seleccionar un producto
  Future<void> _selectProduct() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        builder: (context) => snapshot.docs.isEmpty
            ? Center(child: Text('No hay productos disponibles'))
            : ListView.builder(
          itemCount: snapshot.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.docs[index];
            final data = doc.data();

            return ListTile(
              title: Text(data['name'] ?? 'Producto sin nombre'),
              subtitle: Text(data['description'] ?? ''),
              onTap: () {
                setState(() {
                  _selectedProduct = Product.fromMap(data);
                  _productIdController.text = doc.id;
                });
                Navigator.pop(context);
              },
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar productos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addSerial() {
    final serial = _serialController.text.trim();
    final productId = _productIdController.text.trim();

    if (serial.isEmpty || productId.isEmpty) {
      setState(() {
        _status = 'Por favor complete ambos campos';
      });
      return;
    }

    setState(() {
      _pendingSerials.add({
        'serial': serial,
        'productId': productId,
      });
      _serialController.clear();
      _status = 'Serial añadido a la lista';
    });
  }

  Future<void> _uploadSerials() async {
    if (_pendingSerials.isEmpty) {
      setState(() {
        _status = 'No hay seriales para cargar';
      });
      return;
    }

    // Verificar si tenemos un producto seleccionado
    if (_selectedProduct == null) {
      final productId = _productIdController.text.trim();
      if (productId.isEmpty) {
        setState(() {
          _status = 'Por favor seleccione un producto';
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _status = 'Cargando ${_pendingSerials.length} seriales...';
    });

    try {
      // Uso del productId desde el controlador si no hay producto seleccionado
      final productId = _selectedProduct?.id ?? _productIdController.text.trim();

      final result = await _serialService.uploadSerialsBatch(_pendingSerials, productId);

      setState(() {
        _isLoading = false;
        _status = result['success']
            ? '¡Seriales cargados correctamente! Añadidos: ${result['added']}, Duplicados: ${result['duplicates']}'
            : 'Error: ${result['errors']}';

        if (result['success']) {
          _pendingSerials = [];
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }

  void _addBulkSerials() {
    // Mostrar un diálogo para ingresar seriales en bloque
    final bulkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir seriales en bloque'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ingrese seriales en formato: serial,productId (uno por línea)'),
            const SizedBox(height: 16),
            TextField(
              controller: bulkController,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'A123,PROD001\nB456,PROD002\nC789,PROD003',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final lines = bulkController.text.split('\n');
              int addedCount = 0;

              for (var line in lines) {
                final parts = line.split(',');
                if (parts.length >= 2) {
                  _pendingSerials.add({
                    'serial': parts[0].trim(),
                    'productId': parts[1].trim(),
                  });
                  addedCount++;
                }
              }

              Navigator.pop(context);
              setState(() {
                _status = 'Se añadieron $addedCount seriales a la lista';
              });
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de Seriales'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Añadir seriales válidos al sistema',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Formulario para añadir serial
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _serialController,
                      decoration: const InputDecoration(
                        labelText: 'Número de Serial',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _selectProduct,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: _productIdController,
                          decoration: InputDecoration(
                            labelText: 'ID de Producto',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: _selectProduct,
                              tooltip: 'Buscar producto',
                            ),
                            hintText: _selectedProduct != null
                                ? _selectedProduct!.name
                                : 'Seleccione un producto',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Añadir Serial'),
                            onPressed: _addSerial,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.list),
                            label: const Text('Añadir en Bloque'),
                            onPressed: _addBulkSerials,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Lista de seriales pendientes
            const Text(
              'Seriales pendientes de carga',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _pendingSerials.isEmpty
                  ? const Center(
                child: Text('No hay seriales en la lista'),
              )
                  : ListView.builder(
                itemCount: _pendingSerials.length,
                itemBuilder: (context, index) {
                  final serial = _pendingSerials[index];
                  return ListTile(
                    leading: const Icon(Icons.qr_code),
                    title: Text(serial['serial']),
                    subtitle: Text('Producto ID: ${serial['productId']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _pendingSerials.removeAt(index);
                          _status = 'Serial eliminado de la lista';
                        });
                      },
                    ),
                  );
                },
              ),
            ),

            // Botón de carga y estado
            if (_pendingSerials.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.cloud_upload),
                    label: Text('Cargar ${_pendingSerials.length} seriales'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _uploadSerials,
                  ),
                ),
              ),

            if (_isLoading)
              const Center(child: CircularProgressIndicator()),

            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _status.contains('Error')
                      ? Colors.red.shade50
                      : _status.contains('correctamente')
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_status),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _serialController.dispose();
    _productIdController.dispose();
    super.dispose();
  }
}