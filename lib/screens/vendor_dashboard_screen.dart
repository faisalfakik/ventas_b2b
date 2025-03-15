import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vendor_models.dart';
import 'customer_detail_screen.dart';
import 'visit_detail_screen.dart';
import 'schedule_visit_screen.dart';

class VendorDashboardScreen extends StatefulWidget {
  final String vendorId;

  const VendorDashboardScreen({
    Key? key,
    required this.vendorId,
  }) : super(key: key);

  @override
  _VendorDashboardScreenState createState() => _VendorDashboardScreenState();
}

class _VendorDashboardScreenState extends State<VendorDashboardScreen> {
  late Vendor? vendor;
  late List<Customer> assignedCustomers;
  late List<Visit> upcomingVisits;
  late SalesGoal? currentGoal;

  @override
  void initState() {
    super.initState();
    _loadVendorData();
  }

  void _loadVendorData() {
    // Obtener información del vendedor
    vendor = VendorService.getVendorById(widget.vendorId);

    if (vendor != null) {
      // Obtener clientes asignados
      assignedCustomers = VendorService.getCustomersByVendorId(widget.vendorId);

      // Obtener visitas programadas
      upcomingVisits = VendorService.getVisitsByVendorId(widget.vendorId)
          .where((visit) => visit.status == 'Programada')
          .toList();

      // Ordenar las visitas por fecha (más próximas primero)
      upcomingVisits.sort((a, b) => a.date.compareTo(b.date));

      // Obtener objetivo actual de ventas
      currentGoal = VendorService.getCurrentSalesGoalForVendor(widget.vendorId);
    } else {
      assignedCustomers = [];
      upcomingVisits = [];
      currentGoal = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (vendor == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard de Vendedor'),
          backgroundColor: Colors.green,
        ),
        body: const Center(
          child: Text('Vendedor no encontrado'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard: ${vendor!.name}', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _loadVendorData();
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadVendorData();
          });
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tarjeta de información del vendedor
                _buildVendorInfoCard(),

                const SizedBox(height: 20),

                // Objetivos de venta
                if (currentGoal != null) _buildSalesGoalCard(),

                const SizedBox(height: 20),

                // Próximas visitas
                _buildUpcomingVisitsSection(),

                const SizedBox(height: 20),

                // Clientes asignados
                _buildAssignedCustomersSection(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navegar a la pantalla para programar una nueva visita
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ScheduleVisitScreen(vendorId: widget.vendorId),
            ),
          ).then((_) {
            // Recargar datos cuando regrese
            setState(() {
              _loadVendorData();
            });
          });
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVendorInfoCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person,
                      size: 36,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor!.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vendor!.phone,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Zonas Asignadas:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vendor!.assignedZones.map((zone) => Chip(
                label: Text(zone),
                backgroundColor: Colors.green.shade100,
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesGoalCard() {
    final percentComplete = currentGoal!.completionPercentage;
    final formattedCurrent = NumberFormat.currency(symbol: '\$', decimalDigits: 2)
        .format(currentGoal!.currentAmount);
    final formattedTarget = NumberFormat.currency(symbol: '\$', decimalDigits: 2)
        .format(currentGoal!.targetAmount);

    Color progressColor;
    if (percentComplete < 30) {
      progressColor = Colors.red;
    } else if (percentComplete < 70) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Objetivo Mensual de Ventas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${DateFormat('MMMM yyyy').format(DateTime(currentGoal!.year, currentGoal!.month))}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentComplete / 100,
                backgroundColor: Colors.grey.shade200,
                color: progressColor,
                minHeight: 16,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$formattedCurrent de $formattedTarget',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${percentComplete.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingVisitsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Próximas Visitas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (upcomingVisits.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Navegar a la pantalla de todas las visitas
                },
                child: const Text('Ver Todas'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        upcomingVisits.isEmpty
            ? Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_busy,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay visitas programadas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Programa tu primera visita',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            : Column(
          children: upcomingVisits
              .take(3)
              .map((visit) => _buildVisitCard(visit))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildVisitCard(Visit visit) {
    final customer = VendorService.getCustomerById(visit.customerId);
    final formattedDate = DateFormat('EEE, MMM d, yyyy - h:mm a').format(visit.date);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navegar a la pantalla de detalles de la visita
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VisitDetailScreen(visitId: visit.id),
            ),
          ).then((_) {
            // Recargar datos cuando regrese
            setState(() {
              _loadVendorData();
            });
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.store,
                        size: 24,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer?.businessName ?? 'Cliente Desconocido',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customer?.name ?? 'Contacto Desconocido',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              if (visit.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        visit.notes,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignedCustomersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Clientes Asignados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (assignedCustomers.isNotEmpty)
              TextButton(
                onPressed: () {
                  // Navegar a la pantalla de todos los clientes
                },
                child: const Text('Ver Todos'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        assignedCustomers.isEmpty
            ? Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay clientes asignados',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            : Column(
          children: assignedCustomers
              .take(5)
              .map((customer) => _buildCustomerCard(customer))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Navegar a la pantalla de detalles del cliente
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerDetailScreen(
                customerId: customer.id,
                vendorId: widget.vendorId,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(
                    Icons.business,
                    size: 24,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.businessName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            customer.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}