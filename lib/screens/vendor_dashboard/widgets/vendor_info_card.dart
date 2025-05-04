import 'package:flutter/material.dart';
// Ajusta la ruta a tu modelo
import 'package:ventas_b2b/models/vendor_model.dart';

class VendorInfoCard extends StatelessWidget {
  final Vendor vendor;
  const VendorInfoCard({super.key, required this.vendor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Card(
      elevation: 1.5, // Elevación sutil
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Alinear verticalmente
              children: [
                // Avatar con iniciales o podrías poner el logo aquí
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.primaryColorLight, // Color del tema
                  child: Text(
                    // Maneja caso de nombre vacío
                    vendor.name.isNotEmpty ? vendor.name.substring(0, 1).toUpperCase() : 'V',
                    style: textTheme.headlineSmall?.copyWith(color: theme.primaryColorDark), // Color del tema
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vendor.name.isNotEmpty ? vendor.name : 'Nombre no disponible',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      // Mostrar email y teléfono si existen
                      if (vendor.email?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        SelectableText(vendor.email, style: textTheme.bodyMedium), // Permite copiar
                      ],
                      if (vendor.phone?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        SelectableText(vendor.phone ?? '', style: textTheme.bodyMedium), // Permite copiar
                      ],
                    ],
                  ),
                ),
              ],
            ),
            // Mostrar zonas asignadas si existen
            if (vendor.assignedZones.isNotEmpty) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.dividerColor.withOpacity(0.5)), // Separador
              const SizedBox(height: 12),
              Text('Zonas Asignadas:', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap( // Para que los chips se ajusten si son muchos
                spacing: 8, // Espacio horizontal
                runSpacing: 4, // Espacio vertical
                children: vendor.assignedZones.map((zone) => Chip(
                  label: Text(zone),
                  labelStyle: textTheme.bodySmall?.copyWith(color: theme.primaryColorDark),
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  side: BorderSide.none, // Sin borde
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact, // Más compacto
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}