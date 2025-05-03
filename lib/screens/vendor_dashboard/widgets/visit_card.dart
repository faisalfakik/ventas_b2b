import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ventas_b2b/services/customer_service.dart';
import 'package:ventas_b2b/utils/helpers.dart';

import '../../../models/visit_model.dart';
import '../../../models/customer_model.dart';
import 'quick_action_button.dart';


class VisitCard extends StatelessWidget {
  final Visit visit;
  final Customer? customer; // RECIBE el cliente (cacheado/precargado)
  final VoidCallback onTap;
  final VoidCallback onAlertAcknowledged;

  const VisitCard({
    super.key, // Añadir super.key
    required this.visit,
    this.customer, // Nullable si no se pudo precargar
    required this.onTap,
    required this.onAlertAcknowledged,
  });

  // TODO: ¡IMPORTANTE! Evitar llamadas directas a servicios aquí si es posible.
  // Pasar el Customer ya cargado es mucho más eficiente.
  // Este FutureBuilder es un fallback si 'customer' es null.
  Future<Customer?> _getCustomerFallback(BuildContext context, String customerId) async {
    // Solo intentar cargar si no se recibió el cliente
    if (customer != null) return customer;
    print("WARN: VisitCard fetching customer $customerId - inefficient");
    try {
      // Asume que CustomerService está disponible (quizás vía Provider.of o instancia directa si no hay otra)
      return await CustomerService().getClientById(customerId);
    } catch (e) {
      print("Error cargando cliente para tarjeta visita: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    // Usa el helper si lo tienes, si no, formatea aquí
    final formattedDate = DateFormat.MMMEd('es').add_jm().format(visit.date);
    // Usa la extensión para claridad
    final bool isAlert = visit.isAlertActiveReal;
    final Color cardColor = isAlert ? Colors.orange.shade50 : theme.cardColor;
    final Color highlightColor = Colors.orange.shade700;
    final Color normalIconColor = theme.colorScheme.primary;

    // Obtener datos del cliente (desde el parámetro o mostrar fallback)
    // Nota: Usamos FutureBuilder solo como fallback si customer es null
    final String initialBusinessName = customer?.businessName ?? 'Cargando...';
    final String initialContactName = customer?.name ?? '';
    final String initialCustomerPhone = customer?.phone ?? '';
    final String initialCustomerAddress = customer?.address ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isAlert ? 3 : 1.5,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isAlert ? highlightColor : theme.dividerColor.withOpacity(0.5), width: isAlert ? 2 : 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Fila Superior ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon( isAlert ? Icons.warning_amber_rounded : Icons.event_note_outlined, size: 32, color: isAlert ? highlightColor : normalIconColor),
                  const SizedBox(width: 12),
                  Expanded(
                    // Usar FutureBuilder solo si customer no fue provisto
                    child: customer == null
                        ? FutureBuilder<Customer?>(
                      future: _getCustomerFallback(context, visit.customerId),
                      builder: (context, snapshot) {
                        String nameToShow = initialBusinessName;
                        String contactToShow = initialContactName;
                        if (snapshot.connectionState == ConnectionState.done) {
                          if (snapshot.hasData && snapshot.data != null) {
                            nameToShow = snapshot.data!.businessName;
                            contactToShow = snapshot.data!.name;
                          } else {
                            nameToShow = 'Cliente no encontrado';
                          }
                        }
                        return _buildCustomerNameSection(context, nameToShow, contactToShow, textTheme, theme);
                      },
                    )
                        : _buildCustomerNameSection(context, initialBusinessName, initialContactName, textTheme, theme),
                  ),
                  if (isAlert)
                    IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Colors.green.shade600),
                      iconSize: 28, tooltip: 'Marcar alerta como gestionada', padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onAlertAcknowledged,
                    )
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 0.5, color: theme.dividerColor.withOpacity(0.8)),
              const SizedBox(height: 12),
              // --- Detalles: Fecha, Notas ---
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 14, color: theme.hintColor),
                  const SizedBox(width: 6),
                  Expanded(child: Text(formattedDate, style: textTheme.bodySmall)),
                ],
              ),
              if (visit.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sticky_note_2_outlined, size: 14, color: theme.hintColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        visit.notes,
                        style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              // --- Etiqueta de Alerta ---
              if (isAlert) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration( color: highlightColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text( 'VISITA SUGERIDA POR ADMIN', style: textTheme.labelSmall?.copyWith(color: highlightColor, fontWeight: FontWeight.bold)),
                ),
              ],
              // --- Acciones Rápidas ---
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón Mapa (si el cliente tiene dirección)
                  if (initialCustomerAddress.isNotEmpty) // Usa dato inicial o del customer precargado
                    QuickActionButton( // Usa el widget separado
                      icon: Icons.location_on_outlined,
                      tooltip: 'Ver Ubicación',
                      onPressed: () => launchExternalUrl('https://maps.google.com/?q=${Uri.encodeComponent(initialCustomerAddress)}', context), // Usa helper
                    ),
                  // Botón Llamar (si el cliente tiene teléfono)
                  if (initialCustomerPhone.isNotEmpty) // Usa dato inicial o del customer precargado
                    QuickActionButton( // Usa el widget separado
                      icon: Icons.phone_outlined,
                      tooltip: 'Llamar $initialCustomerPhone',
                      onPressed: () => launchExternalUrl('tel:$initialCustomerPhone', context), // Usa helper
                    ),
                  // Botón WhatsApp (ejemplo)
                  // if (initialCustomerPhone.isNotEmpty)
                  //    QuickActionButton(
                  //      icon: Icons.message_outlined, // O un icono de WhatsApp
                  //      tooltip: 'WhatsApp',
                  //      onPressed: () => launchExternalUrl('https://wa.me/${formato_telefono_internacional}?text=Hola ${contactName ?? ''}', context),
                  //      color: Colors.green,
                  //   ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Helper interno para construir la sección del nombre del cliente
  Widget _buildCustomerNameSection(BuildContext context, String businessName, String contactName, TextTheme textTheme, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text( businessName, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (contactName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text( contactName, style: textTheme.bodySmall?.copyWith(color: theme.hintColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]
      ],
    );
  }
}