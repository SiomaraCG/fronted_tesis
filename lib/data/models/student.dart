enum StudentStatus { atHome, inRoute, atSchool, absent }

class Student {
  final String id;
  final String name;
  final int age;
  final String tutorId;
  final String tutorName;
  final String? routeId;
  final String? routeName;
  final String stopName;
  final double stopLatitude;
  final double stopLongitude;
  final StudentStatus status;
  final String? cedula;
  final String? grade;
  final int? stopId;
  final double? monthlyFee;

  Student({
    required this.id,
    required this.name,
    required this.age,
    required this.tutorId,
    required this.tutorName,
    this.routeId,
    this.routeName,
    required this.stopName,
    required this.stopLatitude,
    required this.stopLongitude,
    required this.status,
    this.cedula,
    this.grade,
    this.stopId,
    this.monthlyFee,
  });

  Student copyWith({
    String? id,
    String? name,
    int? age,
    String? tutorId,
    String? tutorName,
    String? routeId,
    String? routeName,
    String? stopName,
    double? stopLatitude,
    double? stopLongitude,
    StudentStatus? status,
    String? cedula,
    String? grade,
    int? stopId,
    double? monthlyFee,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      tutorId: tutorId ?? this.tutorId,
      tutorName: tutorName ?? this.tutorName,
      routeId: routeId ?? this.routeId,
      routeName: routeName ?? this.routeName,
      stopName: stopName ?? this.stopName,
      stopLatitude: stopLatitude ?? this.stopLatitude,
      stopLongitude: stopLongitude ?? this.stopLongitude,
      status: status ?? this.status,
      cedula: cedula ?? this.cedula,
      grade: grade ?? this.grade,
      stopId: stopId ?? this.stopId,
      monthlyFee: monthlyFee ?? this.monthlyFee,
    );
  }

  /// Parsea coordenadas tanto en formato dict `{"lat": ..., "lng": ...}` como WKT `"POINT(lng lat)"`
  static Map<String, double>? parseCoordinate(dynamic raw) {
    if (raw is Map) {
      final lat = (raw['lat'] as num?)?.toDouble() ?? double.tryParse(raw['lat']?.toString() ?? '');
      final lng = (raw['lng'] as num?)?.toDouble() ?? double.tryParse(raw['lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        return {'lat': lat, 'lng': lng};
      }
    } else if (raw is String && raw.toUpperCase().contains('POINT')) {
      final match = RegExp(r'POINT\s*\(\s*([-\d\.]+)\s+([-\d\.]+)\s*\)', caseSensitive: false).firstMatch(raw);
      if (match != null) {
        final lng = double.tryParse(match.group(1)!);
        final lat = double.tryParse(match.group(2)!);
        if (lat != null && lng != null) {
          return {'lat': lat, 'lng': lng};
        }
      }
    }
    return null;
  }

  factory Student.fromBackendJson(Map<String, dynamic> json, {StudentStatus? overrideStatus}) {
    final nombre = (json['nombre'] ?? '').toString().trim();
    final apellido = (json['apellido'] ?? '').toString().trim();
    final fullName = '$nombre $apellido'.trim();

    final asignaciones = (json['asignaciones_activas'] as List<dynamic>?) ?? [];
    Map<String, dynamic>? primeraAsignacion;
    if (asignaciones.isNotEmpty && asignaciones.first is Map<String, dynamic>) {
      primeraAsignacion = asignaciones.first as Map<String, dynamic>;
    }

    final coord = parseCoordinate(primeraAsignacion?['parada_geom']) ??
        parseCoordinate(json['parada_geom']) ??
        parseCoordinate(json['domicilio_geom']);

    final lat = coord?['lat'] ?? -0.1800;
    final lng = coord?['lng'] ?? -78.4800;

    final gradoStr = (json['grado'] ?? '').toString();
    final ageMatch = RegExp(r'\d+').firstMatch(gradoStr);
    final parsedAge = ageMatch != null ? (int.tryParse(ageMatch.group(0)!) ?? 8) : 8;

    return Student(
      id: (json['id'] ?? json['estudiante_id'] ?? '').toString(),
      name: fullName.isNotEmpty
          ? fullName
          : (json['estudiante_nombre_completo'] ?? json['estudiante'] ?? json['name'] ?? 'Estudiante').toString(),
      age: parsedAge,
      tutorId: (json['representante_usuario_id'] ?? '').toString(),
      tutorName: (json['representante_nombre'] ?? json['representante'] ?? 'Representante').toString(),
      routeId: primeraAsignacion?['ruta_id']?.toString() ?? json['ruta_id']?.toString(),
      routeName: (primeraAsignacion?['ruta_nombre'] ?? json['ruta'])?.toString(),
      stopName: (primeraAsignacion?['parada_nombre'] ??
              json['parada_nombre'] ??
              json['parada'] ??
              json['domicilio_direccion'] ??
              'Parada Principal')
          .toString(),
      stopLatitude: lat,
      stopLongitude: lng,
      status: overrideStatus ?? _mapEstadoHoy(json['estado_hoy']?.toString()),
      cedula: json['cedula']?.toString(),
      grade: json['grado']?.toString(),
      stopId: ((primeraAsignacion?['parada_id'] ?? json['parada_id']) as num?)?.toInt(),
      monthlyFee: double.tryParse((json['tarifa_actual'] ?? json['tarifa_mensual'] ?? '').toString()),
    );
  }

  static StudentStatus _mapEstadoHoy(String? estadoHoy) {
    switch (estadoHoy?.toUpperCase()) {
      case 'RECOGIDO':
        return StudentStatus.inRoute;
      case 'ENTREGADO':
        return StudentStatus.atSchool;
      case 'AUSENCIA_PREVIA':
      case 'NO_ASISTIO':
        return StudentStatus.absent;
      default:
        return StudentStatus.atHome;
    }
  }
}
