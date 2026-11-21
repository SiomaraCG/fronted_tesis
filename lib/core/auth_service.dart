import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthService {
  /// Inicia sesión con email o cédula y guarda el token JWT + rol + menú
  Future<Map<String, dynamic>> login(String identificador, String password) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/login',
        data: {
          'identificador': identificador.trim(),
          'password': password,
        },
      );

      final body = response.data as Map<String, dynamic>;
      if (body['COD'] != 'COD_OK') {
        throw Exception(body['mensaje'] ?? 'Error al iniciar sesión');
      }

      final data = body['data'] as Map<String, dynamic>;
      final String token = data['access_token'];
      final Map<String, dynamic> usuario = data['usuario'];
      final List<dynamic> roles = usuario['roles'] ?? [];
      final List<dynamic> menu = data['menu'] ?? [];

      // Guardar token en el dispositivo para que el interceptor lo envíe en cada ruta
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('rol_principal', roles.isNotEmpty ? roles.first.toString() : '');

      return {
        'usuario': usuario,
        'roles': roles,
        'menu': menu, // Lista de pantallas permitidas según el rol (ADMIN, CONDUCTOR, PADRE)
      };
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = (data is Map && data['mensaje'] != null)
          ? data['mensaje'].toString()
          : 'Error de conexión con el servidor (${ApiClient.baseUrl})';
      throw Exception(msg);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('rol_principal');
  }
}

