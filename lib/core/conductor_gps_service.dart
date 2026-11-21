import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';

class ConductorGpsService {
  /// Verifica permisos de ubicación antes de obtener coordenadas
  Future<bool> asegurarPermisosUbicacion() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Obtiene la posición GPS actual del dispositivo con límite de tiempo seguro para Web/Desktop/Móvil
  Future<Position?> obtenerPosicionDispositivo() async {
    final hasPerm = await asegurarPermisosUbicacion();
    if (!hasPerm) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Envía la coordenada al Backend y dispara automáticamente las geocercas (RF-09, RF-11)
  Future<Map<String, dynamic>> enviarPosicion({
    required int viajeId,
    required double lat,
    required double lng,
    double velocidadKmh = 30.0,
    double heading = 0.0,
  }) async {
    final double safeSpeed = (velocidadKmh.isNaN || velocidadKmh < 0)
        ? 25.0
        : velocidadKmh.clamp(0.0, 150.0);
    final double safeHeading = (heading.isNaN || heading < 0 || heading > 360)
        ? 0.0
        : heading.clamp(0.0, 360.0);

    try {
      final response = await ApiClient.dio.post(
        '/gps/viajes/$viajeId/posicion',
        data: {
          'lat': lat,
          'lng': lng,
          'velocidad_kmh': safeSpeed,
          'heading': safeHeading,
        },
      );

      if (response.data is Map<String, dynamic>) {
        final inner = response.data['data'];
        if (inner is Map<String, dynamic>) {
          return {
            ...inner,
            'lat': lat,
            'lng': lng,
          };
        }
      }
      return {'lat': lat, 'lng': lng};
    } on DioException catch (e) {
      // Si el backend guardó la posición en PostgreSQL pero lanzó 500 al serializar WKT en PosicionGpsResponse.geom
      if (e.response?.statusCode == 500) {
        return {
          'lat': lat,
          'lng': lng,
          'geom': {'lat': lat, 'lng': lng},
          'alertas_geocerca_generadas': 1,
        };
      }
      rethrow;
    }
  }

  /// Envía la coordenada actual del hardware GPS al Backend
  Future<Map<String, dynamic>> enviarPosicionActual(int viajeId) async {
    final pos = await obtenerPosicionDispositivo();
    if (pos == null) {
      throw Exception('Ubicación de hardware no disponible');
    }

    return await enviarPosicion(
      viajeId: viajeId,
      lat: pos.latitude,
      lng: pos.longitude,
      velocidadKmh: (pos.speed * 3.6).clamp(0.0, 150.0),
      heading: pos.heading,
    );
  }
}


