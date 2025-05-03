import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Necesario para llamar al ViewModel

// Ajusta la ruta a tu ViewModel
import '../viewmodels/vendor_dashboard_viewmodel.dart';

// --- Widget para los Chips de Filtro de Visitas ---
class VisitFilterChips extends StatelessWidget {
  final VendorDashboardViewModel viewModel;
  const VisitFilterChips({super.key, required this.viewModel});

  // Helper para obtener el texto del label del filtro
  String _visitFilterLabel(VisitFilterType filter) {
    switch (filter) {
      case VisitFilterType.upcoming: return 'Próximas';
      case VisitFilterType.today: return 'Hoy';
      case VisitFilterType.thisWeek: return 'Semana';
      case VisitFilterType.alerts: return 'Alertas';
    // Asegúrate de cubrir todos los valores del enum
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40, // Altura consistente para la fila de chips
      child: ListView.separated( // Usar separated para añadir espacio automáticamente
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0), // Padding horizontal
        itemCount: VisitFilterType.values.length,
        itemBuilder: (context, index) {
          final filter = VisitFilterType.values[index];
          final isSelected = viewModel.selectedVisitFilter == filter;
          return FilterChip(
            label: Text(_visitFilterLabel(filter)),
            selected: isSelected,
            onSelected: (selected) {
              if (selected) {
                // Usa 'read' aquí si la acción no necesita reconstruir este widget inmediatamente
                context.read<VendorDashboardViewModel>().applyVisitFilter(filter);
              }
            },
            // Estilos consistentes usando el tema
            labelStyle: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant),
            backgroundColor: theme.colorScheme.surfaceContainerLowest,
            selectedColor: theme.colorScheme.primary,
            checkmarkColor: theme.colorScheme.onPrimary,
            side: isSelected
                ? BorderSide.none
                : BorderSide(color: theme.dividerColor.withOpacity(0.5)), // Borde más sutil
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12), // Padding interno
            showCheckmark: false, // Opcional: quitar el checkmark si se prefiere
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8), // Espacio entre chips
      ),
    );
  }
}

// --- Widget para los Chips de Filtro de Clientes (Placeholder) ---
class CustomerFilterChips extends StatelessWidget {
  final VendorDashboardViewModel viewModel;
  const CustomerFilterChips({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    // TODO: Implementar la lógica y UI de los filtros de cliente aquí
    // Puedes seguir un patrón similar a VisitFilterChips cuando tengas los filtros definidos
    return Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        alignment: Alignment.centerLeft,
        child: Text(
            'Filtros Cliente (Próximamente)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor)
        ));
  }
}