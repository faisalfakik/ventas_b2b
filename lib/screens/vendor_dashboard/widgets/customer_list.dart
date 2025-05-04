import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/vendor_dashboard_viewmodel.dart';
import 'package:ventas_b2b/models/customer_model.dart' as cust;

import 'customer_card.dart';
import 'empty_state_card.dart';
import 'loading_widgets.dart';


// Reutiliza el tipo de callback o define uno específico si prefieres
typedef ItemTapCallback = void Function(String id);

class CustomerList extends StatelessWidget {
  final ItemTapCallback onCustomerTap; // Callback para tap en cliente
  final ItemTapCallback onAcknowledgeTap; // Callback para marcar como visto
  final VoidCallback onLoadMore; // Callback para cargar más

  const CustomerList({
    super.key,
    required this.onCustomerTap,
    required this.onAcknowledgeTap,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    // Escucha el ViewModel para obtener los datos y el estado
    final viewModel = context.watch<VendorDashboardViewModel>();
    final customers = viewModel.displayCustomers;
    final bool showLoadingIndicator = viewModel.isFetchingMoreCustomers;
    final bool showLoadMoreButton = viewModel.hasMoreCustomers && !viewModel.isFetchingMoreCustomers;

    // Muestra estado vacío si corresponde
    if (customers.isEmpty && !viewModel.isLoading) {
      return const SliverToBoxAdapter(
        child: EmptyStateCard( // Usa el widget separado
          icon: Icons.people_alt_outlined,
          title: 'No hay clientes para el filtro actual',
          subtitle: 'Contacta a administración si falta alguno.',
        ),
      );
    }

    // Construye la lista usando SliverList
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          // Último item: posible indicador o botón "cargar más"
          if (index == customers.length) {
            if (showLoadingIndicator) {
              return const LoadingIndicator(); // Usa el widget separado
            }
            if (showLoadMoreButton) {
              // Llama al callback onLoadMore proporcionado
              return LoadMoreButton(onPressed: onLoadMore, label: 'Cargar más clientes'); // Usa el widget separado
            }
            return null;
          }

          // Item normal: la tarjeta de cliente
          if (index < customers.length) {
            final customer = customers[index];
            return CustomerCard( // Usa el widget de tarjeta pública
              customer: customer,
              // Llama a los callbacks proporcionados
              onTap: () => onCustomerTap(customer.id),
              onAcknowledged: () => onAcknowledgeTap(customer.id),
            );
          }
          return null;
        },
        childCount: customers.length + (showLoadingIndicator || showLoadMoreButton ? 1 : 0),
      ),
    );
  }
}