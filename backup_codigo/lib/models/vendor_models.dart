import 'package:flutter/material.dart';

// Modelo para representar un Cliente B2B
class Customer {
  final String id;
  final String name;
  final String businessName;
  final String email;
  final String phone;
  final String address;
  final double creditLimit;
  final int paymentTermDays;
  final List<String> assignedVendorIds;

  Customer({
    required this.id,
    required this.name,
    required this.businessName,
    required this.email,
    required this.phone,
    required this.address,
    this.creditLimit = 0.0,
    this.paymentTermDays = 30,
    this.assignedVendorIds = const [],
  });
}

// Modelo para representar un Vendedor
class Vendor {
  final String id;
  final String name;
  final String email;
  final String phone;
  final List<String> assignedZones;
  final List<String> assignedCustomerIds;

  Vendor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.assignedZones = const [],
    this.assignedCustomerIds = const [],
  });
}

// Modelo para una visita de vendedor a cliente
class Visit {
  final String id;
  final String vendorId;
  final String customerId;
  final DateTime date;
  final String status; // Programada, Completada, Cancelada
  final String notes;
  final List<String> orderIds;

  Visit({
    required this.id,
    required this.vendorId,
    required this.customerId,
    required this.date,
    this.status = 'Programada',
    this.notes = '',
    this.orderIds = const [],
  });
}

// Modelo para objetivos de venta
class SalesGoal {
  final String id;
  final String vendorId;
  final int year;
  final int month;
  final double targetAmount;
  final double currentAmount;

  SalesGoal({
    required this.id,
    required this.vendorId,
    required this.year,
    required this.month,
    required this.targetAmount,
    this.currentAmount = 0.0,
  });

  double get completionPercentage =>
      targetAmount > 0 ? (currentAmount / targetAmount * 100) : 0;
}

// Servicio para gestionar datos de vendedores y clientes
class VendorService {
  // Lista de clientes ejemplo
  static final List<Customer> customers = [
    Customer(
      id: 'C001',
      name: 'Carlos Mendoza',
      businessName: 'Electrodomésticos El Económico',
      email: 'cmendoza@eleconomico.com',
      phone: '+58 412-555-1234',
      address: 'Av. Principal, C.C. El Centro, Local 15, Caracas',
      creditLimit: 5000.00,
      paymentTermDays: 30,
      assignedVendorIds: ['V001'],
    ),
    Customer(
      id: 'C002',
      name: 'María Rodríguez',
      businessName: 'Tiendas TecnoHogar',
      email: 'mrodriguez@tecnohogar.com',
      phone: '+58 414-555-5678',
      address: 'Calle 5, C.C. Las Mercedes, Local 22, Maracaibo',
      creditLimit: 8000.00,
      paymentTermDays: 45,
      assignedVendorIds: ['V001', 'V002'],
    ),
    Customer(
      id: 'C003',
      name: 'José Blanco',
      businessName: 'Distribuidora Aires Frescos',
      email: 'jblanco@airesfrescos.com',
      phone: '+58 416-555-9012',
      address: 'Av. Libertador, Edificio Plaza, Piso 2, Valencia',
      creditLimit: 12000.00,
      paymentTermDays: 60,
      assignedVendorIds: ['V002'],
    ),
    Customer(
      id: 'C004',
      name: 'Luisa Martínez',
      businessName: 'Electronica Moderna',
      email: 'lmartinez@electronicamoderna.com',
      phone: '+58 424-555-3456',
      address: 'Calle Principal, C.C. El Sambil, Local 45, Barquisimeto',
      creditLimit: 6000.00,
      paymentTermDays: 30,
      assignedVendorIds: ['V003'],
    ),
    Customer(
      id: 'C005',
      name: 'Antonio Pérez',
      businessName: 'Climatización Pérez & Asociados',
      email: 'aperez@climatizacionperez.com',
      phone: '+58 426-555-7890',
      address: 'Av. Las Américas, C.C. Gran Bazar, Nivel 1, Local 12, Maracay',
      creditLimit: 15000.00,
      paymentTermDays: 45,
      assignedVendorIds: ['V001', 'V003'],
    ),
  ];

  // Lista de vendedores ejemplo
  static final List<Vendor> vendors = [
    Vendor(
      id: 'V001',
      name: 'Pedro Gómez',
      email: 'pgomez@gtronic.com',
      phone: '+58 412-555-2468',
      assignedZones: ['Caracas', 'Maracay'],
      assignedCustomerIds: ['C001', 'C002', 'C005'],
    ),
    Vendor(
      id: 'V002',
      name: 'Laura Fernández',
      email: 'lfernandez@gtronic.com',
      phone: '+58 414-555-1357',
      assignedZones: ['Maracaibo', 'Valencia'],
      assignedCustomerIds: ['C002', 'C003'],
    ),
    Vendor(
      id: 'V003',
      name: 'Miguel Torres',
      email: 'mtorres@gtronic.com',
      phone: '+58 416-555-8642',
      assignedZones: ['Barquisimeto', 'Maracay'],
      assignedCustomerIds: ['C004', 'C005'],
    ),
  ];

  // Lista de visitas ejemplo
  static final List<Visit> visits = [
    Visit(
      id: 'VS001',
      vendorId: 'V001',
      customerId: 'C001',
      date: DateTime.now().add(const Duration(days: 2)),
      status: 'Programada',
      notes: 'Presentar nuevos productos de ventiladores',
    ),
    Visit(
      id: 'VS002',
      vendorId: 'V001',
      customerId: 'C002',
      date: DateTime.now().subtract(const Duration(days: 3)),
      status: 'Completada',
      notes: 'Cliente interesado en aires acondicionados split',
      orderIds: ['ORD12345'],
    ),
    Visit(
      id: 'VS003',
      vendorId: 'V002',
      customerId: 'C003',
      date: DateTime.now().add(const Duration(days: 5)),
      status: 'Programada',
      notes: 'Revisar inventario y necesidades de reposición',
    ),
    Visit(
      id: 'VS004',
      vendorId: 'V003',
      customerId: 'C004',
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Completada',
      notes: 'Presentación de ofertas especiales en electrodomésticos',
      orderIds: ['ORD12346'],
    ),
    Visit(
      id: 'VS005',
      vendorId: 'V001',
      customerId: 'C005',
      date: DateTime.now().add(const Duration(days: 7)),
      status: 'Programada',
      notes: 'Seguimiento de pedido anterior',
    ),
  ];

  // Lista de objetivos de venta ejemplo
  static final List<SalesGoal> salesGoals = [
    SalesGoal(
      id: 'SG001',
      vendorId: 'V001',
      year: DateTime.now().year,
      month: DateTime.now().month,
      targetAmount: 15000.00,
      currentAmount: 8500.00,
    ),
    SalesGoal(
      id: 'SG002',
      vendorId: 'V002',
      year: DateTime.now().year,
      month: DateTime.now().month,
      targetAmount: 12000.00,
      currentAmount: 9800.00,
    ),
    SalesGoal(
      id: 'SG003',
      vendorId: 'V003',
      year: DateTime.now().year,
      month: DateTime.now().month,
      targetAmount: 10000.00,
      currentAmount: 4200.00,
    ),
  ];

  // Métodos para obtener información

  // Obtener todos los clientes
  static List<Customer> getAllCustomers() {
    return customers;
  }

  // Obtener clientes por vendedor
  static List<Customer> getCustomersByVendorId(String vendorId) {
    return customers.where((customer) =>
        customer.assignedVendorIds.contains(vendorId)).toList();
  }

  // Obtener un cliente específico
  static Customer? getCustomerById(String customerId) {
    try {
      return customers.firstWhere((customer) => customer.id == customerId);
    } catch (e) {
      return null;
    }
  }

  // Obtener todos los vendedores
  static List<Vendor> getAllVendors() {
    return vendors;
  }

  // Obtener un vendedor específico
  static Vendor? getVendorById(String vendorId) {
    try {
      return vendors.firstWhere((vendor) => vendor.id == vendorId);
    } catch (e) {
      return null;
    }
  }

  // Obtener visitas por vendedor
  static List<Visit> getVisitsByVendorId(String vendorId) {
    return visits.where((visit) => visit.vendorId == vendorId).toList();
  }

  // Obtener visitas por cliente
  static List<Visit> getVisitsByCustomerId(String customerId) {
    return visits.where((visit) => visit.customerId == customerId).toList();
  }

  // Obtener visitas programadas (futuras)
  static List<Visit> getScheduledVisits() {
    final now = DateTime.now();
    return visits.where((visit) =>
    visit.status == 'Programada' &&
        visit.date.isAfter(now)).toList();
  }

  // Obtener objetivo de ventas de un vendedor para el mes actual
  static SalesGoal? getCurrentSalesGoalForVendor(String vendorId) {
    final now = DateTime.now();
    try {
      return salesGoals.firstWhere((goal) =>
      goal.vendorId == vendorId &&
          goal.year == now.year &&
          goal.month == now.month);
    } catch (e) {
      return null;
    }
  }

  // Obtener el nombre completo del cliente a partir de su ID
  static String getCustomerFullName(String customerId) {
    final customer = getCustomerById(customerId);
    if (customer != null) {
      return '${customer.name} (${customer.businessName})';
    }
    return 'Cliente Desconocido';
  }
}