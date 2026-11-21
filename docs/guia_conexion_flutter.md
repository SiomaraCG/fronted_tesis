# Guía Completa: Cómo Conectar tu App de Flutter al Backend (FastAPI + PostGIS)

Este documento contiene la configuración exacta y el código en **Dart / Flutter** listo para copiar y pegar en tu aplicación para consumir todos los módulos de tu Backend (Login JWT con menú por rol, respuesta estándar `cod_ok`, Google OR-Tools, GPS en tiempo real con WebSockets y subida de comprobantes con OCR).

---

## 1. Paso Crítico: Cómo Levantar el Backend para que Flutter lo Vea

Cuando pruebas desde un **Emulador Android** o desde un **celular físico**, debes levantar FastAPI escuchando en `0.0.0.0`:

```powershell
cd backend
.\venv\Scripts\uvicorn.exe app.main:app --reload --host 0.0.0.0 --port 8000
```

### ¿Qué `baseUrl` poner en Flutter según el dispositivo?

| Dispositivo donde corre tu App Flutter | `baseUrl` HTTP | `wsUrl` WebSocket |
| :--- | :--- | :--- |
| **Emulador Android (Android Studio)** | `http://10.0.2.2:8000` | `ws://10.0.2.2:8000` |
| **Flutter Web / Windows Desktop** | `http://127.0.0.1:8000` | `ws://127.0.0.1:8000` |
| **Celular Físico (en el mismo Wi-Fi)** | `http://TU_IP_PC:8000` *(ej. `http://192.168.1.25:8000`)* | `ws://TU_IP_PC:8000` |

> **Permiso en Android (`android/app/src/main/AndroidManifest.xml`):**
> Agrega `android:usesCleartextTraffic="true"` dentro de `<application ...>` y los permisos de Internet y GPS:
> ```xml
> <uses-permission android:name="android.permission.INTERNET"/>
> <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
> <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
> ```

---

## 2. Dependencias Recomendadas en tu `pubspec.yaml`

Ejecuta en la carpeta de tu proyecto Flutter:

```bash
flutter pub add dio shared_preferences flutter_map latlong2 geolocator web_socket_channel image_picker url_launcher
```

---

## 3. Cliente HTTP Centralizado en Dart (`lib/core/api_client.dart`)

Este cliente lee automáticamente tu estructura estandarizada `{ "COD": "COD_OK", "codigo": 200, "mensaje": "...", "data": ... }` e inyecta automáticamente el **Token Bearer JWT** en todas las peticiones protegidas:

```dart
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiResponse<T> {
  final String cod;
  final int codigo;
  final String mensaje;
  final T? data;

  bool get isOk => cod == 'COD_OK';

  ApiResponse({
    required this.cod,
    required this.codigo,
    required this.mensaje,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic rawData)? fromData,
  ) {
    return ApiResponse<T>(
      cod: json['COD'] ?? 'COD_ERROR',
      codigo: json['codigo'] ?? 500,
      mensaje: json['mensaje'] ?? '',
      data: (json['data'] != null && fromData != null)
          ? fromData(json['data'])
          : json['data'] as T?,
    );
  }
}

class ApiClient {
  // Cambia a 'http://10.0.2.2:8000' en Emulador Android o 'http://127.0.0.1:8000' en Web/Desktop
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String wsBaseUrl = 'ws://10.0.2.2:8000';

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
}
```

---

## 4. Servicio de Login y Menú por Rol (`RF-01`, `RF-15`)

```dart
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
      final msg = e.response?.data?['mensaje'] ?? 'Error de conexión con el servidor';
      throw Exception(msg);
    }
  }

  /// Registra un nuevo usuario (PADRE, CONDUCTOR, ADMIN o SOCIO) y guarda el token automáticamente
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String cedula,
    String? telefono,
    String rol = 'PADRE',
    String? licencia,
  }) async {
    try {
      final response = await ApiClient.dio.post(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'nombre': nombre.trim(),
          'apellido': apellido.trim(),
          'cedula': cedula.trim(),
          'telefono': telefono?.trim(),
          'rol': rol.toUpperCase(),
          'cooperativa_id': 1,
          if (licencia != null) 'licencia': licencia.trim(),
        },
      );

      final body = response.data as Map<String, dynamic>;
      if (body['COD'] != 'COD_OK') {
        throw Exception(body['mensaje'] ?? 'Error al registrar usuario');
      }

      final data = body['data'] as Map<String, dynamic>;
      final String token = data['access_token'];
      final Map<String, dynamic> usuario = data['usuario'];
      final List<dynamic> roles = usuario['roles'] ?? [];
      final List<dynamic> menu = data['menu'] ?? [];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      await prefs.setString('rol_principal', roles.isNotEmpty ? roles.first.toString() : '');

      return {
        'usuario': usuario,
        'roles': roles,
        'menu': menu,
      };
    } on DioException catch (e) {
      final msg = e.response?.data?['mensaje'] ?? 'Error al registrar el usuario';
      throw Exception(msg);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('rol_principal');
  }
}
```

---

## 5. Cómo Consumir la Optimización de Rutas con Google OR-Tools (`RF-08`) en un Mapa Flutter

```dart
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
      'paradas_optimizadas': data['paradas_activas_optimizadas'],
      'polilinea': puntosPolilinea,
    };
  }
}
```

---

## 6. Emisión GPS del Conductor y Monitoreo en Tiempo Real del Padre (`RF-09`, `RF-10`, `RF-11`)

### A) En la pantalla del Conductor (Enviar ubicación GPS real del teléfono):
```dart
import 'package:geolocator/geolocator.dart';
import 'api_client.dart';

class ConductorGpsService {
  /// Envía la coordenada actual al Backend y dispara automáticamente las geocercas (RF-09, RF-11)
  Future<Map<String, dynamic>> enviarPosicionActual(int viajeId) async {
    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final response = await ApiClient.dio.post(
      '/gps/viajes/$viajeId/posicion',
      data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'velocidad_kmh': (pos.speed * 3.6).clamp(0, 150), // m/s a km/h
        'heading': pos.heading,
      },
    );

    return response.data['data'] as Map<String, dynamic>;
  }
}
```

### B) En la pantalla del Padre (Recibir el bus en vivo por WebSocket):
```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class PadreLiveTrackingService {
  WebSocketChannel? _channel;

  Future<Stream<Map<String, dynamic>>> conectarWebSocketRuta(int rutaId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    final uri = Uri.parse('${ApiClient.wsBaseUrl}/api/gps/ws/rutas/$rutaId?token=$token');
    _channel = WebSocketChannel.connect(uri);

    return _channel!.stream.map((mensajeTexto) {
      return jsonDecode(mensajeTexto as String) as Map<String, dynamic>;
    });
  }

  void desconectar() {
    _channel?.sink.close();
  }
}
```

---

## 7. Subida de Comprobante de Pago con Imagen y Lectura del OCR (`RF-12`, `RF-13`)

```dart
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class PagosOcrService {
  final ImagePicker _picker = ImagePicker();

  /// Abre la galería/cámara, sube la imagen al Backend y devuelve los datos extraídos por el OCR
  Future<Map<String, dynamic>?> seleccionarYSubirComprobante(int pagoId) async {
    final XFile? imagen = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (imagen == null) return null;

    final formData = FormData.fromMap({
      'archivo': await MultipartFile.fromFile(
        imagen.path,
        filename: imagen.name,
      ),
      'canal': 'APP_MOVIL',
    });

    final response = await ApiClient.dio.post(
      '/pagos/$pagoId/comprobante',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    // Devuelve: banco, monto_extraido, fecha_transferencia, referencia_extraida, ocr_confianza
    return response.data['data'] as Map<String, dynamic>;
  }
}
```

---

## 8. Descarga de Reportes en PDF y Excel (`RF-06`)

Para abrir o descargar directamente un reporte PDF o Excel desde Flutter:
- **URL Reporte Rutas PDF:** `${ApiClient.baseUrl}/api/reportes/rutas?formato=pdf`
- **URL Reporte Estudiantes Excel:** `${ApiClient.baseUrl}/api/reportes/estudiantes?ruta_id=1&formato=excel`
- **URL Reporte Pagos PDF:** `${ApiClient.baseUrl}/api/reportes/pagos?mes=11&anio=2026&formato=pdf`
*(Descargándolo con `ApiClient.dio.get(..., options: Options(responseType: ResponseType.bytes))` para que envíe automáticamente el token Bearer de `ADMIN`).*

