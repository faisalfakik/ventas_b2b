import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Necesario si lees el viewmodel aquí, aunque se pasa por constructor

// Ajusta rutas según sea necesario
import '../viewmodels/vendor_dashboard_viewmodel.dart';
import 'package:ventas_b2b/utils/helpers.dart'; // Para formatCurrency
import 'stat_card.dart'; // Importa el widget StatCard

class StatsPanel extends StatelessWidget {
  final VendorDashboardViewModel viewModel;
  const StatsPanel({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Obtener tema aquí si es necesario para StatCard
    return Padding(
      // Puedes ajustar el padding aquí o en el lugar donde se usa StatsPanel
      padding: const EdgeInsets.symmetric(vertical: 0.0),
      child: Row(
        children: [
          // Usar Expanded para que las tarjetas ocupen espacio equitativo
          Expanded(
              child: StatCard(
                  label: 'Visitas Hoy',
                  value: viewModel.visitsTodayCount.toString(),
                  icon: Icons.today_outlined)),
          const SizedBox(width: 8), // Espacio entre tarjetas
          Expanded(
              child: StatCard(
                  label: 'Nuevos Clientes',
                  value: viewModel.newCustomersCount.toString(),
                  icon: Icons.person_add_alt_1_outlined)),
          const SizedBox(width: 8),
          Expanded(
              child: StatCard(
                  label: 'Ventas Hoy',
                  // Usar helper para formatear
                  value: formatCurrency(viewModel.salesToday),
                  icon: Icons.monetization_on_outlined)),
        ],
      ),
    );
  }
}