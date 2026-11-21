import 'package:latlong2/latlong.dart';
import 'student.dart';

class SchoolRoute {
  final String id;
  final String name;
  final String driverId;
  final String driverName;
  final List<String> studentIds;
  final List<LatLng> pathPoints;
  final bool isActive;
  final double currentLatitude;
  final double currentLongitude;
  final int? activeTripId;
  final int? busId;
  final String? busPlate;
  final int? institucionId;
  final String? institucionName;
  final String? sector;
  final String? turno;

  SchoolRoute({
    required this.id,
    required this.name,
    required this.driverId,
    required this.driverName,
    required this.studentIds,
    required this.pathPoints,
    required this.isActive,
    required this.currentLatitude,
    required this.currentLongitude,
    this.activeTripId,
    this.busId,
    this.busPlate,
    this.institucionId,
    this.institucionName,
    this.sector,
    this.turno,
  });

  SchoolRoute copyWith({
    String? id,
    String? name,
    String? driverId,
    String? driverName,
    List<String>? studentIds,
    List<LatLng>? pathPoints,
    bool? isActive,
    double? currentLatitude,
    double? currentLongitude,
    int? activeTripId,
    int? busId,
    String? busPlate,
    int? institucionId,
    String? institucionName,
    String? sector,
    String? turno,
  }) {
    return SchoolRoute(
      id: id ?? this.id,
      name: name ?? this.name,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      studentIds: studentIds ?? this.studentIds,
      pathPoints: pathPoints ?? this.pathPoints,
      isActive: isActive ?? this.isActive,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      activeTripId: activeTripId ?? this.activeTripId,
      busId: busId ?? this.busId,
      busPlate: busPlate ?? this.busPlate,
      institucionId: institucionId ?? this.institucionId,
      institucionName: institucionName ?? this.institucionName,
      sector: sector ?? this.sector,
      turno: turno ?? this.turno,
    );
  }

  factory SchoolRoute.fromBackendJson(
    Map<String, dynamic> json, {
    List<String> assignedStudentIds = const [],
    bool isActive = false,
    int? activeTripId,
    LatLng? livePosition,
  }) {
    final paradasJson = (json['paradas'] as List<dynamic>?) ?? [];
    final List<LatLng> points = [];
    for (final p in paradasJson) {
      if (p is Map<String, dynamic>) {
        final coord = Student.parseCoordinate(p['geom']);
        if (coord != null) {
          points.add(LatLng(coord['lat']!, coord['lng']!));
        }
      }
    }

    final initialLat = livePosition?.latitude ??
        (points.isNotEmpty ? points.first.latitude : -0.17612);
    final initialLng = livePosition?.longitude ??
        (points.isNotEmpty ? points.first.longitude : -78.48541);

    return SchoolRoute(
      id: (json['id'] ?? '').toString(),
      name: (json['nombre'] ?? 'Ruta').toString(),
      driverId: (json['conductor_id'] ?? '').toString(),
      driverName: (json['conductor_nombre'] ?? json['conductor'] ?? 'Conductor').toString(),
      studentIds: assignedStudentIds,
      pathPoints: points,
      isActive: isActive,
      currentLatitude: initialLat,
      currentLongitude: initialLng,
      activeTripId: activeTripId,
      busId: (json['bus_id'] as num?)?.toInt(),
      busPlate: json['bus_placa']?.toString(),
      institucionId: (json['institucion_id'] as num?)?.toInt(),
      institucionName: (json['institucion_nombre'] ?? json['institucion'])?.toString(),
      sector: json['sector']?.toString(),
      turno: json['turno']?.toString(),
    );
  }
}
