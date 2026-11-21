import 'package:dio/dio.dart';
import 'api_client.dart';

class RegistroJerarquicoService {
  /// 1. EXCLUSIVO ADMIN: Registrar un nuevo Conductor
  Future<Map<String, dynamic>> registrarConductorPorAdmin({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String cedula,
    required String telefono,
    required String licencia,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/flota/conductores',
        data: {
          'email': email.trim(),
          'password': password,
          'nombre': nombre.trim(),
          'apellido': apellido.trim(),
          'cedula': cedula.trim(),
          'telefono': telefono.trim(),
          'licencia': licencia.trim(),
        },
      );

      final body = response.data as Map<String, dynamic>;
      if (body['COD'] != 'COD_OK') {
        throw Exception(body['mensaje'] ?? 'Error al registrar al conductor');
      }
      return body['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['mensaje'] != null)
          ? data['mensaje'].toString()
          : 'Error al registrar conductor';
      throw Exception(msg);
    }
  }

  /// 2. CONDUCTOR (o ADMIN): Registrar al Padre de Familia + Estudiante + Parada GPS en su ruta
  Future<Map<String, dynamic>> registrarPadreYEstudiantePorConductor({
    required String padreEmail,
    required String padrePassword,
    required String padreNombre,
    required String padreApellido,
    required String padreCedula,
    required String padreTelefono,
    required String estudianteCedula,
    required String estudianteNombre,
    required String estudianteApellido,
    required String estudianteGrado,
    required double latitudCasa,
    required double longitudCasa,
    required String direccionCasa,
    required double montoMensual,
    int? rutaId,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/estudiantes/registrar-padre-y-estudiante',
        data: {
          'padre': {
            'email': padreEmail.trim(),
            'password': padrePassword,
            'nombre': padreNombre.trim(),
            'apellido': padreApellido.trim(),
            'cedula': padreCedula.trim(),
            'telefono': padreTelefono.trim(),
          },
          'estudiante': {
            'cedula': estudianteCedula.trim(),
            'nombre': estudianteNombre.trim(),
            'apellido': estudianteApellido.trim(),
            'grado': estudianteGrado.trim(),
            'domicilio_geom': {
              'lat': latitudCasa,
              'lng': longitudCasa,
            },
            'domicilio_direccion': direccionCasa.trim(),
            'monto_mensual_inicial': montoMensual,
          },
          if (rutaId != null) 'ruta_id': rutaId,
        },
      );

      final body = response.data as Map<String, dynamic>;
      if (body['COD'] != 'COD_OK') {
        throw Exception(body['mensaje'] ?? 'Error al registrar padre y estudiante');
      }
      return body['data'] as Map<String, dynamic>;
    } on DioException catch (e) {
      // Si el backend hizo commit en PostgreSQL pero falló al serializar EstudianteResponse por WKT 'POINT(...)' (HTTP 500),
      // verificamos en /estudiantes/padres si el padre ya quedó guardado en la BD.
      if (e.response?.statusCode == 500) {
        try {
          final checkRes = await ApiClient.dio.get('/estudiantes/padres');
          final rawData = checkRes.data;
          final List<dynamic> padresList = (rawData is Map && rawData['data'] is List)
              ? rawData['data'] as List<dynamic>
              : [];
          final existePadre = padresList.any(
            (p) =>
                p is Map &&
                (p['cedula']?.toString() == padreCedula.trim() ||
                    p['email']?.toString().toLowerCase() == padreEmail.trim().toLowerCase()),
          );
          if (existePadre) {
            return {
              'padre_cedula': padreCedula.trim(),
              'estudiante_cedula': estudianteCedula.trim(),
            };
          }
        } catch (_) {}
      }

      final data = e.response?.data;
      final msg = (data is Map && data['mensaje'] != null)
          ? data['mensaje'].toString()
          : 'Error al registrar padre y estudiante';
      throw Exception(msg);
    }
  }
}

