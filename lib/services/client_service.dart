import '../models/client_model.dart';

class ClientService {
  // Método de ejemplo que devuelve una lista de clientes
  Future<List<Client>> getClients() async {
    // Simulación de carga de datos (en un entorno real, se conectaría a una API o base de datos)
    await Future.delayed(const Duration(milliseconds: 500));

    // Datos de ejemplo
    return [
      Client(
        id: 'C001',
        name: 'Refrigeración Industrial S.A.',
        email: 'info@refrigeracionindustrial.com',
        phone: '555-123-4567',
        address: 'Av. Principal 1234, Ciudad Industrial',
      ),
      Client(
        id: 'C002',
        name: 'Hoteles Premium',
        email: 'compras@hotelespremium.com',
        phone: '555-987-6543',
        address: 'Calle Comercial 567, Zona Hotelera',
      ),
      Client(
        id: 'C003',
        name: 'Distribuidora del Norte',
        email: 'ventas@distnorte.com',
        phone: '555-456-7890',
        address: 'Blvd. Norte 890, Parque Industrial',
      ),
    ];
  }
}