import 'package:latlong2/latlong.dart';
import 'api_client.dart';

class RutaOptimizacionService {
  /// Llama a POST /api/rutas/{rutaId}/optimizar y devuelve la polilínea para FlutterMap
  Future<Map<String, dynamic>> optimizarRutaConOrTools(int rutaId, {int? viajeId}) async {
    final response = await ApiClient.dio.post(
      '/rutas/$rutaId/optimizar',
      data: {
        'viaje_id': viajeId,
        'velocidad_promedio_kmh': 25.0,
      },
    );

    final data = response.data['data'] as Map<String, dynamic>;

    // Convertir polilinea_coordenadas en List<LatLng> lista para PolylineLayer de flutter_map
    final List<LatLng> puntosPolilinea = (data['polilinea_coordenadas'] as List)
        .map((pt) => LatLng((pt['lat'] as num).toDouble(), (pt['lng'] as num).toDouble()))
        .toList();

    return {
      'distancia_total_km': data['distancia_total_km'],
      'tiempo_total_estimado_min': data['tiempo_total_estimado_min'],
      'paradas': data['paradas_activas_optimizadas'],
      'paradas_optimizadas': data['paradas_activas_optimizadas'],
      'polilinea': puntosPolilinea,
    };
  }
}

