import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../models/customer_model.dart';
import '../services/payment_service.dart';
import '../services/customer_service.dart';
import 'payment_register_screen.dart';
import 'dart:io';
import 'dart:math' as Math;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:cross_file/cross_file.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, FieldValue, Timestamp, DocumentSnapshot;

class PaymentHistoryScreen extends StatefulWidget {
  final String vendorId;
  final String? clientId; // Si se proporciona, solo muestra abonos para este cliente

  const PaymentHistoryScreen({
    Key? key,
    required this.vendorId,
    this.clientId,
  }) : super(key: key);

  @override
  _PaymentHistoryScreenState createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  final CustomerService _CustomerService = CustomerService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Payment> _payments = [];
  Map<String, Customer> _clientsMap = {};
  bool _isLoading = true;
  bool _onlyPending = false;

  // Para la pestaña de resumen
  double _totalCollected = 0;
  double _totalPending = 0;

  // Lista de IDs de pagos actualizados para referencia
  List<String> updatedPaymentIds = [];

  // Añade esta nueva variable:
  Map<String, double> _partialDeliveries = {}; // Mapeo de paymentId -> monto entregado

  // Controlador para TabBar
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    updateExistingTransactions(); // Añadir esta línea
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    print("DEBUG: Iniciando carga de pagos en PaymentHistoryScreen");
    print("DEBUG: vendorId = '${widget.vendorId}'");

    // NUEVO: Si forceRefresh es true, limpiamos todos los datos antes de recargar
    if (forceRefresh) {
      print("DEBUG: Forzando recarga completa - limpiando datos en caché");
      setState(() {
        _payments = [];
        _clientsMap = {};
        _totalCollected = 0;
        _totalPending = 0;
        _partialDeliveries = {}; // Añadir esta línea para limpiar entregas parciales
        updatedPaymentIds = []; // Limpiar IDs de pagos actualizados
      });
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar abonos
      List<Payment> payments;
      if (widget.clientId != null) {
        print("DEBUG: Cargando pagos para cliente: ${widget.clientId}");
        payments = await _paymentService.getPaymentsByCustomer(widget.clientId!);
      } else {
        print("DEBUG: Cargando pagos para vendedor: ${widget.vendorId}");
        payments = await _paymentService.getPaymentsByVendor(widget.vendorId);
      }

// Ordenar los pagos por fecha (más recientes primero)
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

// Imprimir información de los pagos para depuración
      print("DEBUG: Se cargaron ${payments.length} pagos");
      for (var payment in payments) {
        print("DEBUG: Pago ID: ${payment.id}, Cliente: ${payment.clientId}, Monto: ${payment.amount}, Método: ${payment.method}, Estado: ${payment.status}, RemainingAmount: ${payment.remainingAmount}");
      }

// Cargar información de todos los clientes para mostrar nombres
      final clients = await _CustomerService.getAllClients();
      final clientsMap = {for (var Customer in clients) Customer.id: Customer};

// Cargar transacciones de entrega para ajustar los montos pendientes
      final deliveriesSnapshot = await _firestore
          .collection('delivery_transactions')
          .where('vendorId', isEqualTo: widget.vendorId)
          .where('status', isEqualTo: 'active') // Añadir este filtro
          .get();

// Mapear las entregas parciales por paymentId
      Map<String, double> partialDeliveries = {};
      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        if (data['isPartial'] == true) {
          String paymentId = data['paymentId'];
          double amount = (data['amount'] is int)
              ? (data['amount'] as int).toDouble()
              : (data['amount'] ?? 0.0);

          partialDeliveries[paymentId] = (partialDeliveries[paymentId] ?? 0.0) + amount;

          // VERIFICAR: Imprimir entrega parcial para depuración
          print("DEBUG: Entrega parcial para pago $paymentId - Monto: $amount");
        }
      }
      // Calcular totales basados en remainingAmount en lugar de status
      double totalCollected = 0;
      double totalPending = 0;

      for (var payment in payments) {
        // Verificar si el pago está efectivamente completado (remainingAmount <= 0)
        if (payment.remainingAmount <= 0) {
          totalCollected += payment.amount;
        } else {
          // Para pagos con monto pendiente, calcular cuánto se ha entregado y cuánto queda
          double pendingAmount = payment.remainingAmount;
          double deliveredAmount = payment.amount - pendingAmount;

          // Añadir la parte entregada al total cobrado
          totalCollected += deliveredAmount;

          // Añadir la parte pendiente al total pendiente
          totalPending += pendingAmount;
        }
      }

      // Verificación con el método centralizado
      try {
        double newPendingBalance = await _paymentService.getPendingBalance(widget.vendorId);

        // Solo usar el nuevo cálculo si hay una diferencia significativa
        if ((totalPending - newPendingBalance).abs() > 1.0) {
          print("DEBUG: Diferencia detectada entre el cálculo local ($totalPending) y el centralizado ($newPendingBalance). Usando el valor centralizado.");
          totalPending = newPendingBalance;
        }
      } catch (errorPending) {
        print("ERROR: Error al verificar el saldo pendiente centralizado: $errorPending");
        // Mantener el cálculo original en caso de error
      }

      setState(() {
        _payments = payments;
        _clientsMap = clientsMap;
        _totalCollected = totalCollected;
        _totalPending = totalPending;
        _partialDeliveries = partialDeliveries;
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR: Error al cargar datos: $e');
      print('ERROR: Stack trace: ${StackTrace.current}');
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    }
  }

  // Método para verificar directamente en Firebase
  Future<void> _verifyPaymentInFirebase(String paymentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('payments')
          .doc(paymentId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        print("VERIFICACIÓN DIRECTA: ID $paymentId");
        print("VERIFICACIÓN DIRECTA: Status: ${data!['status']}");
        print("VERIFICACIÓN DIRECTA: RemainingAmount: ${data['remainingAmount']}");
        print("VERIFICACIÓN DIRECTA: DeliveredAmount: ${data['deliveredAmount']}");
      } else {
        print("VERIFICACIÓN DIRECTA: Documento no encontrado para ID $paymentId");
      }
    } catch (e) {
      print("VERIFICACIÓN DIRECTA: Error al verificar $paymentId - $e");
    }
  }

  // Obtener los pagos filtrados
  List<Payment> get _filteredPayments {
    List<Payment> result;

    if (!_onlyPending) {
      result = List.from(_payments);
    } else {
      // CAMBIO: Mostrar solo pagos con monto pendiente real, independiente del status
      result = _payments.where((payment) => payment.remainingAmount > 0).toList();
    }

    // Ordenar por fecha (más recientes primero)
    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return result;
  }

// Método para obtener el nombre del cliente a partir de su ID
  String _getClientName(String clientId) {
    if (_clientsMap.containsKey(clientId)) {
      return _clientsMap[clientId]!.name;
    }
    return 'Cliente ID: $clientId';
  }
  /// Método para construir la tarjeta de cada pago
  Widget _buildPaymentCard(Payment payment) {
    final Customer = _clientsMap[payment.clientId];
    final clientName = Customer?.name ?? 'Cliente desconocido';

    // Color según el estado
    Color statusColor;
    IconData statusIcon;
    String statusText;

    // CAMBIO CLAVE: Considerar pagos con remainingAmount = 0 como completados visualmente
    bool isEffectivelyCompleted = payment.status == PaymentStatus.completed || payment.remainingAmount <= 0;

    // Verificar si hay entrega parcial para este pago
    bool hasPartialDelivery = payment.deliveredAmount > 0 && payment.remainingAmount > 0;
    double remainingAmount = payment.remainingAmount;

    if (isEffectivelyCompleted) {
      // Mostrar como completado si remainingAmount es 0, sin importar el status real
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completado';
    } else if (hasPartialDelivery) {
      // Estado especial para pagos con entrega parcial
      statusColor = Colors.deepOrange;
      statusIcon = Icons.sync_alt;
      statusText = 'Entrega Parcial';
    } else {
      // Pendiente normal
      statusColor = Colors.orange;
      statusIcon = Icons.pending_actions;
      statusText = 'Pendiente';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con nombre del cliente y fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    clientName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Monto y tipo de abono (efectivo o depósito)
            Row(
              children: [
                Icon(
                  payment.method == PaymentMethod.transfer || payment.method == PaymentMethod.check
                      ? Icons.account_balance
                      : Icons.attach_money,
                  size: 20,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  payment.method == PaymentMethod.cash ? 'Efectivo' :
                  payment.method == PaymentMethod.transfer ? 'Depósito bancario' :
                  payment.method == PaymentMethod.check ? 'Cheque' :
                  payment.method == PaymentMethod.card ? 'Tarjeta' : 'Otro',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  hasPartialDelivery
                      ? '\$${remainingAmount.toStringAsFixed(2)} / \$${payment.amount.toStringAsFixed(2)}'
                      : '\$${payment.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: hasPartialDelivery ? Colors.deepOrange : null,
                  ),
                ),
              ],
            ),

            // Mostrar información de entrega parcial si existe
            if (hasPartialDelivery) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Entregado: \$${payment.deliveredAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.deepOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Estado y ubicación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: (0.1 * 255).toDouble()),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón para ver detalles (ubicación o comprobante)
                payment.method == PaymentMethod.transfer || payment.method == PaymentMethod.check
                    ? TextButton.icon(
                  icon: const Icon(Icons.image, size: 16),
                  label: const Text('Ver comprobante'),
                  onPressed: () {
                    _showDepositReceipt(payment);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                )
                    : TextButton.icon(
                  icon: const Icon(Icons.location_on, size: 16),
                  label: const Text('Ver ubicación'),
                  onPressed: () {
                    _showLocationMap(payment);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ],
            ),

            // Notas (si hay)
            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Descripción:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ), // Cierre de Text
              const SizedBox(height: 4),
              Text(
                payment.notes!,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ), // Cierre de Text
            ], // Cierre del spread operator ...[]
          ],
        ),
      ),
    );
  }

// Método para mostrar un mensaje cuando no hay abonos
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payments_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _onlyPending
                ? 'No hay abonos pendientes'
                : 'No hay abonos registentes',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Los abonos registrados aparecerán aquí',
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Registrar Nuevo Abono'),
            onPressed: () {
              // Navegar a la pantalla de registro de abonos
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaymentRegisterScreen(
                    vendorId: widget.vendorId,
                    clientId: widget.clientId,
                  ),
                ),
              ).then((_) => _loadData()); // Recargar al volver
            },
          ),
        ],
      ),
    );
  }

  // Método para construir cada ítem del resumen financiero
  Widget _buildSummaryItem({
    required IconData icon,
    required String title,
    required double amount,
    required Color color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Método para generar estadísticas por tipo de abono
  List<Widget> _generatePaymentMethodStats() {
    // Agrupar pagos por método de pago (efectivo o depósito)
    double totalCash = 0.0;
    double totalDeposit = 0.0;

    for (var payment in _payments) {
      if (payment.method == PaymentMethod.transfer || payment.method == PaymentMethod.check) {
        totalDeposit += payment.amount;
      } else {
        totalCash += payment.amount;
      }
    }

    return [
      // Efectivo
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.attach_money,
              color: Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text('Efectivo'),
            const Spacer(),
            Text(
              '\$${totalCash.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      const Divider(),

      // Depósitos
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.account_balance,
              color: Colors.grey.shade700,
              size: 20,
            ),
            const SizedBox(width: 12),
            const Text('Depósito bancario'),
            const Spacer(),
            Text(
              '\$${totalDeposit.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // Método para generar el resumen por cliente
  Map<String, List<Payment>> _getPaymentsByCustomer() {
    Map<String, List<Payment>> result = {};

    // Fecha límite (3 meses atrás)
    final DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

    // Filtrar pagos para mostrar solo los últimos 3 meses
    final recentPayments = _payments
        .where((payment) => payment.createdAt.isAfter(threeMonthsAgo))
        .toList();

    // Ordenar por fecha más reciente primero
    recentPayments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (var payment in recentPayments) {
      if (!result.containsKey(payment.clientId)) {
        result[payment.clientId] = [];
      }
      result[payment.clientId]!.add(payment);
    }

    // También ordenar cada lista de pagos por cliente
    result.forEach((clientId, payments) {
      payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });

    return result;
  }

// Método para construir el widget de resumen por cliente
  Widget _buildClientSummary() {
    final paymentsByClient = _getPaymentsByCustomer();

    if (paymentsByClient.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No hay pagos registrados en los últimos 3 meses',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Resumen por Cliente',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Últimos 3 meses',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...paymentsByClient.entries.map((entry) {
              final clientId = entry.key;
              final payments = entry.value;
              final clientName = _getClientName(clientId);
              final totalAmount = payments.fold<double>(
                  0, (sum, payment) => sum + payment.amount);

              return ExpansionTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        clientName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: payments.length,
                    itemBuilder: (context, index) {
                      final payment = payments[index];
                      // CAMBIO: Añadir esta línea para determinar si está efectivamente completado
                      bool isEffectivelyCompleted = payment.status == PaymentStatus.completed || payment.remainingAmount <= 0;

                      return ListTile(
                        dense: true,
                        title: Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt),
                        ),
                        trailing: Text(
                          '\$${payment.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: isEffectivelyCompleted
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        subtitle: Text(
                          isEffectivelyCompleted
                              ? 'Entregado'
                              : 'Pendiente por entregar',
                          style: TextStyle(
                            fontSize: 12,
                            color: isEffectivelyCompleted
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  // Método para mostrar el comprobante de depósito
  void _showDepositReceipt(Payment payment) {
    if (payment.receiptImageUrl == null || payment.receiptImageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay comprobante disponible para este depósito')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Comprobante de Depósito'),
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
                  Text(
                    'Cliente: ${_getClientName(payment.clientId)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt)}'),
                  Text('Monto: \$${payment.amount.toStringAsFixed(2)}'),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      payment.receiptImageUrl!,
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
                            child: Icon(Icons.error, size: 50, color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para mostrar el diálogo de confirmación de entrega
  void _showDeliveryConfirmation() {
    final TextEditingController locationController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    // Inicializar con el monto total pendiente como sugerencia
    amountController.text = _totalPending.toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Entrega de Dinero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mostrar el monto total pendiente
            Text(
              'Total pendiente por entregar: \$${_totalPending.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Campo para ingresar el monto a entregar
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Monto a entregar',
                hintText: 'Ingrese el monto que entregará',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 16),

            // Campo para ingresar el lugar de entrega
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'Lugar de entrega',
                hintText: 'Ej: Oficina Central, Sucursal Norte, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),

            const SizedBox(height: 16),

            // Nota informativa
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                'Puede entregar un monto parcial. El sistema seleccionará los abonos más antiguos para completar el monto indicado.',
                style: TextStyle(fontSize: 13),
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
              // Validar que el monto no sea mayor que el pendiente
              double amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor ingrese un monto válido mayor a cero')),
                );
                return;
              }

              if (amount > _totalPending) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('El monto a entregar no puede ser mayor que el pendiente')),
                );
                return;
              }

              // Verificar que se haya ingresado una ubicación
              if (locationController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor ingrese el lugar de entrega')),
                );
                return;
              }

              // Implementar entrega de dinero con ubicación y monto específico
              _deliverPaymentsPartial(locationController.text, amount);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Entrega'),
          ),
        ],
      ),
    );
  }

  Future<void> _deliverPayments(String deliveryLocation) async {
    try {
      setState(() => _isLoading = true);

      // Obtener todos los pagos pendientes
      final pendingPayments = _payments.where((payment) =>
      payment.status == PaymentStatus.pending).toList();

      // Marcar cada pago como entregado
      for (var payment in pendingPayments) {
        await _paymentService.updatePaymentStatus(
          paymentId: payment.id,
          status: PaymentStatus.completed,
          deliveryDate: DateTime.now(),
          deliveryLocation: deliveryLocation, // Añadir la ubicación
        );
      }

      // Recargar datos
      await _loadData(forceRefresh: true);

      // AÑADIR ESTO: Forzar actualización manual de los pagos en la interfaz
      for (String paymentId in updatedPaymentIds) {
        if (!paymentId.startsWith("parcial_")) {
          // Buscar el índice de este pago en la lista actual
          int index = _payments.indexWhere((p) => p.id == paymentId);
          if (index >= 0) {
            try {
              // Obtener los datos actualizados directamente de Firebase
              DocumentSnapshot doc = await _firestore.collection('payments').doc(paymentId).get();
              if (doc.exists) {
                // Reemplazar el pago en la lista local con uno nuevo construido desde Firebase
                setState(() {
                  _payments[index] = Payment.fromFirestore(doc);
                  print("DEBUG: Actualización manual con datos de Firebase para pago ID: $paymentId");
                });
              } else {
                print("DEBUG: No se encontró el documento en Firebase para ID: $paymentId");
                // Caer en la actualización manual original como respaldo
                setState(() {
                  _payments[index] = _payments[index].copyWith(
                    status: PaymentStatus.completed,
                    remainingAmount: 0.0,
                    deliveredAmount: _payments[index].amount,
                  );
                });
              }
            } catch (e) {
              print("ERROR al actualizar desde Firebase: $e");
              // Caer en la actualización manual como respaldo en caso de error
              setState(() {
                _payments[index] = _payments[index].copyWith(
                  status: PaymentStatus.completed,
                  remainingAmount: 0.0,
                  deliveredAmount: _payments[index].amount,
                );
              });
            }
          }
        }
      }

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrega registrada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al entregar pagos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar la entrega: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método para entregar pagos parcialmente
  Future<void> _deliverPaymentsPartial(String deliveryLocation, double deliveryAmount) async {
    try {
      setState(() => _isLoading = true);

      print("DEBUG: Iniciando entrega parcial con monto: $deliveryAmount, ubicación: $deliveryLocation");

      // Obtener todos los pagos pendientes ordenados por fecha (más antiguos primero)
      final pendingPayments = _payments
          .where((p) => p.status == PaymentStatus.pending)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      if (pendingPayments.isEmpty) {
        throw 'No hay pagos pendientes para entregar';
      }

      print("DEBUG: Total pagos pendientes: ${pendingPayments.length}");
      print("DEBUG: Montos pendientes: ${pendingPayments.map((p) => p.amount).toList()}");

      double remainingAmount = deliveryAmount;
      // Usar la variable de clase para almacenar IDs de pagos actualizados
      updatedPaymentIds = [];
      bool processingPartial = false;

      // Procesar pagos hasta completar el monto a entregar
      for (var payment in pendingPayments) {
        print("DEBUG: Evaluando pago ID: ${payment.id}, Monto: ${payment.amount}, Restante: $remainingAmount");

        if (remainingAmount <= 0) {
          print("DEBUG: Monto restante agotado, saliendo del bucle");
          break;
        }

        // Caso 1: El pago se puede completar totalmente
        if (remainingAmount >= payment.amount) {
          final bool updated = await _paymentService.updatePaymentStatus(
            paymentId: payment.id,
            status: PaymentStatus.completed, // CAMBIO IMPORTANTE: Marcar como completado
            deliveryDate: DateTime.now(),
            deliveryLocation: deliveryLocation,
            deliveredAmount: payment.amount, // Añadir esta línea para forzar la actualización
          );

          if (updated) {
            remainingAmount -= payment.amount;
            updatedPaymentIds.add(payment.id);

            // Verificar inmediatamente que se actualizó correctamente
            await Future.delayed(const Duration(milliseconds: 500)); // Pequeña espera
            await _verifyPaymentInFirebase(payment.id);

            print("DEBUG: Pago completado. Nuevo restante: $remainingAmount");

            // Registrar la entrega como una transacción
            await _registerDeliveryTransaction(
              paymentId: payment.id,
              clientId: payment.clientId,
              amount: payment.amount,
              location: deliveryLocation,
              isPartial: false, // Marcamos explícitamente como no parcial
            );
          } else {
            print("DEBUG: No se pudo actualizar el estado del pago");
          }
        }
        // Caso 2: Permitir completar parcialmente el último pago si es necesario
        else if (!processingPartial && remainingAmount > 0) {
          print("DEBUG: Procesando pago parcial para ID: ${payment.id}");
          processingPartial = true; // Procesar solo un pago parcial

          // AÑADIR ESTA LÍNEA: Actualizar el pago en Firebase aunque sea parcial
          final bool updated = await _paymentService.updatePaymentStatus(
            paymentId: payment.id,
            status: PaymentStatus.pending, // Mantener como pendiente
            deliveryDate: DateTime.now(),
            deliveryLocation: deliveryLocation,
            deliveredAmount: remainingAmount, // Actualizar monto entregado
          );

          // Registrar la entrega parcial como una transacción separada
          await _registerDeliveryTransaction(
            paymentId: payment.id,
            clientId: payment.clientId,
            amount: remainingAmount, // Solo la cantidad restante
            location: deliveryLocation,
            isPartial: true,
          );

          updatedPaymentIds.add("parcial_" + payment.id);
          remainingAmount = 0;
          print("DEBUG: Pago parcial registrado");
        }
      }

      if (updatedPaymentIds.isEmpty) {
        throw 'No se pudo procesar ningún pago. Intente con un monto diferente.';
      }

      // Forzar una recarga completa de datos para asegurar que todo esté actualizado
      await _loadData(forceRefresh: true);

      // Mostrar mensaje de éxito
      if (mounted) {
        int completedPayments = updatedPaymentIds.where((id) => !id.startsWith("parcial_")).length;
        int partialPayments = updatedPaymentIds.where((id) => id.startsWith("parcial_")).length;

        String successMessage = 'Entrega de \$${deliveryAmount.toStringAsFixed(2)} registrada correctamente';
        if (completedPayments > 0) {
          successMessage += ' (${completedPayments} ${completedPayments == 1 ? 'abono completado' : 'abonos completados'}';
          if (partialPayments > 0) {
            successMessage += ', 1 abono parcial';
          }
          successMessage += ')';
        } else if (partialPayments > 0) {
          successMessage += ' (pago parcial registrado)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error al entregar pagos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la entrega: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _registerDeliveryTransaction({
    required String paymentId,
    required String clientId,
    required double amount,
    required String location,
    bool isPartial = false,
  }) async {
    try {
      await _firestore.collection('delivery_transactions').add({
        'paymentId': paymentId,
        'clientId': clientId,
        'vendorId': widget.vendorId,
        'amount': amount,
        'location': location,
        'isPartial': isPartial,
        'status': 'active', // Añadir este campo
        'timestamp': FieldValue.serverTimestamp(),
        'date': DateTime.now(),
      });

      print("DEBUG: Transacción de entrega registrada para pago ID: $paymentId, Monto: $amount, Parcial: $isPartial");
    } catch (e) {
      print('Error al registrar transacción de entrega: $e');
      // No lanzamos excepción para no interrumpir el flujo principal
    }
  }

  Future<void> updateExistingTransactions() async {
    try {
      final transactionsSnapshot = await _firestore
          .collection('delivery_transactions')
          .where('vendorId', isEqualTo: widget.vendorId)
          .get();

      final batch = _firestore.batch();
      int updatedCount = 0;

      for (var doc in transactionsSnapshot.docs) {
        final data = doc.data();
        // Si el documento no tiene campo 'status', añadirlo como 'active'
        if (!(data.containsKey('status'))) {
          batch.update(doc.reference, {'status': 'active'});
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('Transacciones existentes actualizadas: $updatedCount');
      } else {
        print('No se encontraron transacciones para actualizar');
      }
    } catch (e) {
      print('Error al actualizar transacciones existentes: $e');
    }
  }

  Future<void> markTransactionAsDeleted(String transactionId) async {
    try {
      await _firestore
          .collection('delivery_transactions')
          .doc(transactionId)
          .update({'status': 'deleted'});

      // Recargar datos después de marcar como eliminada
      await _loadData(forceRefresh: true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transacción marcada como eliminada'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error al marcar transacción como eliminada: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAllTransactions() async {
    setState(() => _isLoading = true);

    try {
      final transactionsSnapshot = await _firestore
          .collection('delivery_transactions')
          .where('vendorId', isEqualTo: widget.vendorId)
          .orderBy('date', descending: true)
          .get();

      setState(() => _isLoading = false);

      if (mounted) {
        // Obtener información de clientes para mostrar nombres
        final Map<String, String> clientNames = {};
        for (var doc in transactionsSnapshot.docs) {
          final data = doc.data();
          final clientId = data['clientId'] as String? ?? '';
          if (clientId.isNotEmpty && !clientNames.containsKey(clientId)) {
            try {
              final Customer = await _CustomerService.getClientById(clientId);
              if (Customer != null) {
                clientNames[clientId] = Customer.name;
              }
            } catch (e) {
              print('Error al obtener cliente: $e');
            }
          }
        }

        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('Historial de Transacciones'),
                    centerTitle: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Expanded(
                    child: transactionsSnapshot.docs.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('No hay transacciones registradas',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                        : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactionsSnapshot.docs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final doc = transactionsSnapshot.docs[index];
                        final data = doc.data();
                        final date = data['date'] is Timestamp
                            ? (data['date'] as Timestamp).toDate()
                            : DateTime.now();
                        final amount = (data['amount'] ?? 0.0).toDouble();
                        final isPartial = data['isPartial'] ?? false;
                        final status = data['status'] ?? 'active';
                        final location = data['location'] as String? ?? 'No especificado';
                        final clientId = data['clientId'] as String? ?? '';
                        final paymentId = data['paymentId'] as String? ?? '';
                        final clientName = clientNames[clientId] ?? 'Cliente ID: $clientId';

                        // Determinar qué ícono mostrar según los datos
                        IconData transactionIcon;
                        Color iconColor;
                        String transactionType;

                        if (isPartial) {
                          transactionIcon = Icons.sync_alt;
                          iconColor = Colors.orange;
                          transactionType = "Entrega Parcial";
                        } else {
                          transactionIcon = Icons.check_circle;
                          iconColor = Colors.green;
                          transactionType = "Entrega Completa";
                        }

                        if (status != 'active') {
                          iconColor = Colors.grey;
                        }

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: status == 'active' ? Colors.transparent : Colors.red.shade100,
                              width: status == 'active' ? 0 : 1,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: iconColor.withOpacity(0.1),
                                      child: Icon(transactionIcon, color: iconColor),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                transactionType,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                '\$${amount.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: status == 'active' ? Colors.green : Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cliente: $clientName',
                                            style: const TextStyle(fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Divider(color: Colors.grey.shade200),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd/MM/yyyy HH:mm').format(date),
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Lugar: $location',
                                        style: TextStyle(color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (paymentId.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.receipt, size: 14, color: Colors.grey.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ref: ${paymentId.substring(0, Math.min(8, paymentId.length))}...',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                if (status != 'active')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ANULADA',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(
                                        status == 'active' ? Icons.delete : Icons.restore,
                                        size: 18,
                                        color: status == 'active' ? Colors.red : Colors.green,
                                      ),
                                      label: Text(
                                        status == 'active' ? 'Anular' : 'Restaurar',
                                        style: TextStyle(
                                          color: status == 'active' ? Colors.red : Colors.green,
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        if (status == 'active') {
                                          _confirmTransactionDeletion(doc.id);
                                        } else {
                                          _firestore
                                              .collection('delivery_transactions')
                                              .doc(doc.id)
                                              .update({'status': 'active'});
                                          _loadData();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error al cargar transacciones: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar transacciones: $e')),
        );
      }
    }
  }

// Función para confirmar la anulación de una transacción
  void _confirmTransactionDeletion(String transactionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular Transacción'),
        content: const Text(
            '¿Estás seguro de que deseas anular esta transacción? Esta acción no se puede deshacer.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              markTransactionAsDeleted(transactionId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
  }

  // Método para mostrar el mapa con la ubicación
  void _showLocationMap(Payment payment) {
    // Verificar si hay coordenadas
    if (payment.latitude == null || payment.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay coordenadas disponibles para este abono')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubicación del Abono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latitud: ${payment.latitude}'),
            Text('Longitud: ${payment.longitude}'),
            const SizedBox(height: 16),
            // Aquí se podría mostrar un mapa con la ubicación
            Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey.shade200,
              child: const Center(
                child: Text('Mapa de ubicación'),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.clientId != null
              ? 'Abonos de ${_getClientName(widget.clientId!)}'
              : 'Control de Abonos',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Historial'),
            Tab(text: 'Resumen'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Historial de abonos
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
            children: [
              // Filtro para mostrar solo pendientes
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Checkbox(
                      value: _onlyPending,
                      onChanged: (value) {
                        setState(() {
                          _onlyPending = value ?? false;
                        });
                      },
                    ),
                    const Text('Mostrar solo abonos pendientes'),
                    const Spacer(),
                    Text(
                      'Total: ${_filteredPayments.length} abonos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de abonos
              Expanded(
                child: _filteredPayments.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredPayments.length,
                  itemBuilder: (context, index) => _buildPaymentCard(_filteredPayments[index]),
                ),
              ),
            ],
          ),

          // Tab 2: Resumen financiero
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nuevo componente de resumen por cliente
                _buildClientSummary(),

                const SizedBox(height: 24),

                // Card de resumen
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen Financiero',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Total cobrado
                        _buildSummaryItem(
                          icon: Icons.payments,
                          title: 'Total Cobrado',
                          amount: _totalCollected,
                          color: Colors.green,
                        ),

                        const Divider(),

                        // Total pendiente (resaltado)
                        _totalPending > 0
                            ? Container(
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange.shade700,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pendiente por Entregar',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Se requiere entregar en administración',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '\$${_totalPending.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                        )
                            : _buildSummaryItem(
                          icon: Icons.pending_actions,
                          title: 'Pendiente por Entregar',
                          amount: _totalPending,
                          color: Colors.orange,
                        ),

                        const Divider(),

                        // Total general
                        _buildSummaryItem(
                          icon: Icons.account_balance_wallet,
                          title: 'Total General',
                          amount: _totalCollected + _totalPending,
                          color: Colors.blue,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Estadísticas por método de pago
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Desglose por Tipo de Abono',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Generar estadísticas por método de pago
                        ..._generatePaymentMethodStats(),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Instrucciones para entregar efectivo
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Procedimiento de Entrega',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Recuerda que debes entregar el dinero recaudado a la administración. '
                              'Una vez entregado, el administrador actualizará el estado de los abonos a "Completado".',
                          style: TextStyle(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Notificar Entrega de Dinero'),
                            onPressed: _totalPending > 0 ? _showDeliveryConfirmation : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Nuevo Card para generar reporte
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reportes y Estado de Cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Generar Estado de Cuenta PDF'),
                            onPressed: () => _generateAccountStatement(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Ver todas las transacciones'),
                            onPressed: _showAllTransactions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegar a la pantalla de registro de abonos
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentRegisterScreen(
                vendorId: widget.vendorId,
                clientId: widget.clientId,
              ),
            ),
          ).then((_) => _loadData()); // Recargar al volver
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  // Metodo para generar el estado de cuenta PDF
  Future<void> _generateAccountStatement() async {
    try {
      setState(() => _isLoading = true);

      // Obtener el nombre del vendedor (esto deberías obtenerlo de tu servicio)
      final vendorName = "Vendedor"; // Reemplaza con el nombre real

      // Obtener todas las transacciones de entrega de este vendedor
      final deliveriesSnapshot = await _firestore
          .collection('delivery_transactions')
          .where('vendorId', isEqualTo: widget.vendorId)
          .orderBy('date')
          .get();

      // Convertir las transacciones de entrega a un formato compatible con el reporte
      final List<Map<String, dynamic>> deliveryTransactions = deliveriesSnapshot.docs
          .map((doc) {
        final data = doc.data();
        return {
          'date': data['date'] is Timestamp
              ? (data['date'] as Timestamp).toDate()
              : DateTime.now(),
          'type': 'delivery',
          'amount': data['amount'] ?? 0.0,
          'location': data['location'] ?? 'No especificado',
          'clientId': data['clientId'] ?? '',
          'paymentId': data['paymentId'] ?? '',
        };
      })
          .toList();

      // Llamar al servicio para generar el PDF con el nuevo formato incluyendo las entregas
      final pdfPath = await _paymentService.generateAccountStatementPDF(
        vendorId: widget.vendorId,
        vendorName: vendorName,
        payments: _payments,
        deliveryTransactions: deliveryTransactions, // Pasar las transacciones de entrega
      );

      setState(() => _isLoading = false);

      if (pdfPath != null) {
        // Mostrar diálogo de éxito con opción de compartir o ver el PDF
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Estado de Cuenta Generado'),
            content: const Text('El estado de cuenta se ha generado correctamente. ¿Qué deseas hacer?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.share),
                label: const Text('Compartir'),
                onPressed: () {
                  Navigator.pop(context);
                  // Código para compartir el PDF
                  Share.shareXFiles([XFile(pdfPath)], text: 'Estado de Cuenta del Vendedor');
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.visibility),
                label: const Text('Ver'),
                onPressed: () {
                  Navigator.pop(context);
                  // Código para abrir el PDF
                  Printing.sharePdf(bytes: File(pdfPath).readAsBytesSync(), filename: 'estado_cuenta.pdf');
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al generar el estado de cuenta')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error al generar estado de cuenta: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al generar estado de cuenta: $e')),
      );
    }
  }
}