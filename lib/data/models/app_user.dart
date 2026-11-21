enum UserRole { admin, driver, parent }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? cedula;
  final String? phone;
  final int? conductorId;
  final int? socioId;
  final int? cooperativaId;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.cedula,
    this.phone,
    this.conductorId,
    this.socioId,
    this.cooperativaId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final roles = (json['roles'] as List<dynamic>?)?.map((e) => e.toString().toUpperCase()).toList() ?? [];
    UserRole parsedRole = UserRole.parent;
    if (roles.any((r) => r.contains('ADMIN')) || json['role'] == 'admin') {
      parsedRole = UserRole.admin;
    } else if (roles.any((r) => r.contains('CONDUCTOR') || r.contains('SOCIO')) || json['role'] == 'driver') {
      parsedRole = UserRole.driver;
    }

    final nombre = (json['nombre'] ?? '').toString().trim();
    final apellido = (json['apellido'] ?? '').toString().trim();
    final fullName = '$nombre $apellido'.trim();

    return AppUser(
      id: (json['id'] ?? '').toString(),
      name: fullName.isNotEmpty ? fullName : (json['name'] ?? json['email'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: parsedRole,
      cedula: json['cedula']?.toString(),
      phone: json['telefono']?.toString(),
      conductorId: json['conductor_id'] as int?,
      socioId: json['socio_id'] as int?,
      cooperativaId: json['cooperativa_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'cedula': cedula,
      'telefono': phone,
      'conductor_id': conductorId,
      'socio_id': socioId,
      'cooperativa_id': cooperativaId,
    };
  }
}
