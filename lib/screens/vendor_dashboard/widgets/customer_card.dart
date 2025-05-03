import 'package:flutter/material.dart';
import '../../../models/customer_model.dart'; // ✅ Import correcto del modelo
import 'package:ventas_b2b/utils/helpers.dart'; // ✅ Para usar launchExternalUrl
import 'quick_action_button.dart'; // ✅ Si usas botones de acción rápida



class CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onAcknowledged;

  const CustomerCard({
    super.key, // Añadir super.key
    required this.customer,
    required this.onTap,
    required this.onAcknowledged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bool isPending = customer.isPendingAcknowledgement; // Usa getter
    final Color cardColor = isPending ? Colors.lightBlue.shade50 : theme.cardColor;
    final Color highlightColor = Colors.blue.shade700;
    final Color normalIconColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isPending ? 3 : 1.5,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isPending ? highlightColor : theme.dividerColor.withOpacity(0.5), width: isPending ? 2 : 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Fila Superior ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon( isPending ? Icons.person_add_alt_1_outlined : Icons.business_center_outlined, size: 32, color: isPending ? highlightColor : normalIconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text( customer.businessName, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text( customer.name, style: textTheme.bodySmall?.copyWith(color: theme.hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (isPending)
                    IconButton(
                      icon: Icon(Icons.mark_chat_read_outlined, color: Colors.green.shade600), iconSize: 28, tooltip: 'Marcar asignación como vista', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onAcknowledged,
                    )
                  else
                    Icon(Icons.chevron_right, color: theme.hintColor),
                ],
              ),
              // --- Dirección y Acciones Rápidas ---
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 44.0), // Indentar para alinear con texto
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text( customer.address?.isNotEmpty ?? false ? customer.address! : 'Dirección no disponible', style: textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Row( // Acciones rápidas
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if(customer.address?.isNotEmpty ?? false)
                          QuickActionButton(icon: Icons.map_outlined, tooltip: 'Ver en Mapa', onPressed: () => launchExternalUrl('https://maps.google.com/?q=${Uri.encodeComponent(customer.address!)}', context)),
                        if(customer.phone?.isNotEmpty ?? false)
                          QuickActionButton(icon: Icons.phone_outlined, tooltip: 'Llamar ${customer.phone ?? 'Teléfono no disponible'}', onPressed: () => launchExternalUrl('tel:${customer.phone}', context)),
                      ],
                    )
                  ],
                ),
              ),

              // --- Nota del Admin ---
              if (customer.adminNote != null && customer.adminNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration( color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.amber.shade200, width: 0.8)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column( crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Nota de Administración:", style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                            const SizedBox(height: 2),
                            Text(customer.adminNote!, style: textTheme.bodySmall?.copyWith(color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}