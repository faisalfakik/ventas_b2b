import 'package:flutter/material.dart';
import '../models/vendor_models.dart';

class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  final String vendorId;

  const CustomerDetailScreen({
    Key? key,
    required this.customerId,
    required this.vendorId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final customer = VendorService.getCustomerById(customerId);

    return Scaffold(
      appBar: AppBar(
        title: Text(customer?.businessName ?? 'Cliente', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Text('Detalles del cliente ${customer?.name ?? ""}'),
      ),
    );
  }
}