import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_model.dart';
import '../models/client_model.dart';
import '../services/payment_service.dart';
import '../services/client_service.dart';
import 'payment_register_screen.dart';

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
  final ClientService _clientService = ClientService();

  List<Payment> _payments = [];
  Map<String, Client> _clientsMap = {};
  bool _isLoading = true;
  bool _onlyPending = false;

  // Para la pestaña de resumen
  double _totalCollected = 0;
  double _totalPending = 0;

  // Controlador para TabBar
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Cargar abonos
      List<Payment> payments;
      if (widget.clientId != null) {
        // Si hay un clientId, filtrar por ese cliente
        payments = await _paymentService.getPaymentsByClient(widget.clientId!);
      } else {
        // Cargar todos los abonos del vendedor
        payments = await _paymentService.getPaymentsByVendor(widget.vendorId);
      }

      // Cargar información de todos los clientes para mostrar nombres
      final clients = await _clientService.getAllClients();
      final clientsMap = {for (var client in clients) client.id: client};

      // Calcular totales
      double totalCollected = 0;
      double totalPending = 0;

      for (var payment in payments) {
        if (payment.status == PaymentStatus.completed) {
          totalCollected += payment.amount;
        } else if (payment.status == PaymentStatus.pending) {
          totalPending += payment.amount;
        }
      }

      setState(() {
        _payments = payments;
        _clientsMap = clientsMap;
        _totalCollected = totalCollected;
        _totalPending = totalPending;
        _isLoading = false;
      });
    } catch (e) {
      print('Error al cargar datos: $e');
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    }
  }

  // Obtener los pagos filtrados
  List<Payment> get _filteredPayments {
    if (!_onlyPending) return _payments;
    return _payments.where((payment) => payment.status == PaymentStatus.pending).toList();
  }

  // Método para obtener el nombre del cliente a partir de su ID
  String _getClientName(String clientId) {
    if (_clientsMap.containsKey(clientId)) {
      return _clientsMap[clientId]!.name;
    }
    return 'Cliente ID: $clientId';
  }

  // Método para construir la tarjeta de cada pago
  Widget _buildPaymentCard(Payment payment) {
    final client = _clientsMap[payment.clientId];
    final clientName = client?.name ?? 'Cliente desconocido';

    // Color según el estado
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (payment.status) {
      case PaymentStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_actions;
        statusText = 'Pendiente';
        break;
      case PaymentStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Completado';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
        statusText = 'Desconocido';
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
                  DateFormat('dd/MM/yyyy HH:mm').format(payment.date),
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
                  payment.paymentMethod == 'deposit' ? Icons.account_balance : Icons.attach_money,
                  size: 20,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  payment.paymentMethod == 'deposit' ? 'Depósito bancario' : 'Efectivo',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${payment.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
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
                payment.paymentMethod == 'deposit'
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
                : 'No hay abonos registrados',
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
      if (payment.paymentMethod == 'deposit') {
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
                  Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.date)}'),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Entrega de Dinero'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Estás a punto de confirmar la entrega de \$${_totalPending.toStringAsFixed(2)} a administración.'),
            const SizedBox(height: 16),
            const Text(
              'Esta acción generará una notificación a administración y actualizará el estado de los abonos pendientes.',
              style: TextStyle(fontSize: 14),
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
              // Implementar entrega de dinero
              _deliverPayments();
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

  // Método para entregar los pagos pendientes
  Future<void> _deliverPayments() async {
    try {
      setState(() => _isLoading = true);

      // Obtener todos los pagos pendientes
      final pendingPayments = _payments.where((p) => p.status == PaymentStatus.pending).toList();

      // Marcar cada pago como entregado
      for (var payment in pendingPayments) {
        await _paymentService.updatePaymentStatus(
          paymentId: payment.id,
          status: PaymentStatus.completed,  // Cambiado a "status" y usando un valor existente del enum
          deliveryDate: DateTime.now(),
        );
      }

      // Recargar datos
      await _loadData();

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

                        // Total pendiente
                        _buildSummaryItem(
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

                const SizedBox(height: 24),

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
}