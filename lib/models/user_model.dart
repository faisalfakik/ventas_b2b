enum UserRole { admin, vendor, client }

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? companyName;
  final String? phoneNumber;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.companyName,
    this.phoneNumber,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: _stringToRole(data['role'] ?? 'client'),
      companyName: data['companyName'],
      phoneNumber: data['phoneNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': _roleToString(role),
      'companyName': companyName,
      'phoneNumber': phoneNumber,
    };
  }

  static UserRole _stringToRole(String role) {
    switch (role) {
      case 'admin':
        return UserRole.admin;
      case 'vendor':
        return UserRole.vendor;
      case 'client':
      default:
        return UserRole.client;
    }
  }

  static String _roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'admin';
      case UserRole.vendor:
        return 'vendor';
      case UserRole.client:
        return 'client';
    }
  }
}