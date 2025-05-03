import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Para leer el ViewModel y obtener datos

// Ajusta rutas
import '../viewmodels/vendor_dashboard_viewmodel.dart';
import 'package:ventas_b2b/models/visit_model.dart';
import 'visit_card.dart'; // El widget de tarjeta individual
import 'empty_state_card.dart';
import 'loading_widgets.dart'; // Contiene LoadingIndicator y LoadMoreButton
import 'package:ventas_b2b/models/customer_model.dart' as cust;
import 'package:ventas_b2b/utils/helpers.dart';

// Define un tipo de función para el callback de tap en un item
typedef ItemTapCallback = void Function(Visit visit);

class VisitList extends StatelessWidget {
  final ItemTapCallback onVisitTap; // Callback para cuando se toca una visita
  final VoidCallback onLoadMore; // Callback para cargar más

  const VisitList({
    super.key,
    required this.onVisitTap,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    // Escucha el ViewModel para obtener los datos y el estado
    final viewModel = context.watch<VendorDashboardViewModel>();
    final visits = viewModel.displayVisits;
    final bool showLoadingIndicator = viewModel.isFetchingMoreVisits;
    final bool showLoadMoreButton = viewModel.hasMoreVisits && !viewModel.isFetchingMoreVisits;

    // Muestra estado vacío si corresponde (solo si no está en carga inicial)
    if (visits.isEmpty && !viewModel.isLoading) {
      return const SliverToBoxAdapter(
        child: EmptyStateCard( // Usa el widget separado
          icon: Icons.event_busy_outlined,
          title: 'No hay visitas para el filtro actual',
          subtitle: 'Intenta con otro filtro o agenda nuevas visitas.',
        ),
      );
    }

    // Construye la lista usando SliverList
    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          // Último item: posible indicador o botón "cargar más"
          if (index == visits.length) {
            if (showLoadingIndicator) {
              return const LoadingIndicator(); // Usa el widget separado
            }
            if (showLoadMoreButton) {
              // Llama al callback onLoadMore proporcionado
              return LoadMoreButton(onPressed: onLoadMore, label: 'Cargar más visitas'); // Usa el widget separado
            }
            return null; // No mostrar nada si no hay más y no está cargando
          }

          // Item normal: la tarjeta de visita
          if (index < visits.length) {
            final visit = visits[index];
            // Obtener cliente de la caché del ViewModel
            final cachedCustomer = viewModel.getCachedCustomer(visit.customerId);
            return VisitCard( // Usa el widget de tarjeta pública
              visit: visit,
              customer: cachedCustomer, // Pasar cliente cacheado
              // Llama al callback onVisitTap proporcionado
              onTap: () => onVisitTap(visit),
              // Llama al método del ViewModel directamente para esta acción interna
              onAlertAcknowledged: () => viewModel.deactivateVisitAlert(visit.id),
            );
          }
          return null; // Seguridad, no debería llegar aquí
        },
        // El número de items es la lista + 1 si se muestra el indicador/botón
        childCount: visits.length + (showLoadingIndicator || showLoadMoreButton ? 1 : 0),
      ),
    );
  }
}