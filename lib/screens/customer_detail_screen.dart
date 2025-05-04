import 'package:flutter/material.dart';
import '../models/vendor_model.dart';
import '../services/customer_service.dart';
import '../services/vendor_service.dart';
import '../models/customer_model.dart' as cust;

class CustomerDetailScreen extends StatefulWidget {
  final String customerId;
  final String vendorId;

  const CustomerDetailScreen({
    Key? key,
    required this.customerId,
    required this.vendorId,
  }) : super(key: key);

  @override
  _CustomerDetailScreenState createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late String customerId;
  late String vendorId;
  cust.Customer? _customer;
  final CustomerService _customerService = CustomerService();
  final VendorService _vendorService = VendorService();

  @override
  void initState() {
    super.initState();
    customerId = widget.customerId;
    vendorId = widget.vendorId;
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    try {
      final customer = await _customerService.getClientById(customerId);
      if (customer != null) {
        setState(() {
          _customer = customer;
        });
      }
    } catch (e) {
      print('Error loading customer: $e');
    }
  }

  void _onVisitTap(String visitId) {
    // TODO: implementar
  }

  void _onCustomerTap(String customerId) {
    // TODO: implementar
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.businessName ?? 'Cliente', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Text('Detalles del cliente ${_customer?.name ?? ""}'),
      ),
    );
  }
}