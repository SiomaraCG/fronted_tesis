import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
  // Lista de IPs candidatas:
  // - 192.168.137.1:8000 -> Zona con cobertura inalámbrica (Hotspot de Windows)
  // - 172.16.77.50:8000  -> IP Wi-Fi actual de la PC
  // - 127.0.0.1:8000     -> Web / Desktop / Celular por USB con "adb reverse tcp:8000 tcp:8000"
  // - 10.0.2.2:8000      -> Emulador de Android Studio
  static String? _customHost;

  static List<String> get _candidateHosts {
    if (kIsWeb) {
      return ['127.0.0.1:8000', 'localhost:8000'];
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return [
        if (_customHost != null && _customHost!.isNotEmpty) _customHost!,
        '192.168.137.1:8000',
        '172.16.77.50:8000',
        '127.0.0.1:8000',
        '10.0.2.2:8000',
      ];
    }
    return [
      if (_customHost != null && _customHost!.isNotEmpty) _customHost!,
      '127.0.0.1:8000',
      '192.168.137.1:8000',
      '172.16.77.50:8000',
    ];
  }

  static String get _host {
    if (_customHost != null && _customHost!.isNotEmpty) {
      return _customHost!;
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '192.168.137.1:8000';
    }
    return '127.0.0.1:8000';
  }

  static String get currentHost => _host;
  static String get baseUrl => 'http://$_host';
  static String get serverRootUrl => baseUrl;
  static String get wsBaseUrl => 'ws://$_host';

  static Future<void> setCustomHost(String host) async {
    final cleaned = host
        .trim()
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/.*$'), '');
    _customHost = cleaned.isEmpty ? null : cleaned;
    dio.options.baseUrl = '$baseUrl/api';
    final prefs = await SharedPreferences.getInstance();
    if (_customHost != null) {
      await prefs.setString('custom_api_host', _customHost!);
    } else {
      await prefs.remove('custom_api_host');
    }
  }

  static Future<void> loadSavedHost() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('custom_api_host');
    if (saved != null && saved.isNotEmpty) {
      _customHost = saved;
      dio.options.baseUrl = '$baseUrl/api';
    }
  }

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: '$baseUrl/api',
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final savedHost = prefs.getString('custom_api_host');
          if (savedHost != null && savedHost.isNotEmpty && _customHost == null) {
            _customHost = savedHost;
            dio.options.baseUrl = '$baseUrl/api';
          }
          options.baseUrl = '$baseUrl/api';

          final token = prefs.getString('jwt_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          final isConnectionIssue = e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              (e.type == DioExceptionType.unknown && e.response == null);

          final alreadyRetried = e.requestOptions.extra['retried_hosts'] == true;

          if (isConnectionIssue && !alreadyRetried) {
            for (final candidate in _candidateHosts) {
              if (candidate == _host) continue;
              try {
                final probeDio = Dio(
                  BaseOptions(
                    baseUrl: 'http://$candidate/api',
                    connectTimeout: const Duration(milliseconds: 2500),
                    receiveTimeout: const Duration(milliseconds: 4000),
                    headers: e.requestOptions.headers,
                    validateStatus: (status) => status != null && status < 500,
                  ),
                );

                final retryOptions = e.requestOptions.copyWith(
                  baseUrl: 'http://$candidate/api',
                  extra: {...e.requestOptions.extra, 'retried_hosts': true},
                );

                final response = await probeDio.fetch(retryOptions);
                await setCustomHost(candidate);
                return handler.resolve(response);
              } catch (_) {
                // Siguiente IP candidata
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
}

