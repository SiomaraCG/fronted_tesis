class Partner {
  final String id;
  final String name;
  final String phone;
  final String vehiclePlate;
  final String licenseNumber;
  final String? cedula;
  final String? email;
  final int? usuarioId;
  final int? socioId;
  final int? busId;

  Partner({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehiclePlate,
    required this.licenseNumber,
    this.cedula,
    this.email,
    this.usuarioId,
    this.socioId,
    this.busId,
  });

  Partner copyWith({
    String? id,
    String? name,
    String? phone,
    String? vehiclePlate,
    String? licenseNumber,
    String? cedula,
    String? email,
    int? usuarioId,
    int? socioId,
    int? busId,
  }) {
    return Partner(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      cedula: cedula ?? this.cedula,
      email: email ?? this.email,
      usuarioId: usuarioId ?? this.usuarioId,
      socioId: socioId ?? this.socioId,
      busId: busId ?? this.busId,
    );
  }
}
