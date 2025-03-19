class Client {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String businessName; // Añadido
  final String? clientType; // Añadido
  final String? priceLevel; // Añadido
  final DateTime? createdAt; // Añadido
  final String? fcmToken; // Añadido para notificaciones

  Client({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.businessName = '', // Valor por defecto
    this.clientType,
    this.priceLevel,
    this.createdAt,
    this.fcmToken,
  });
}