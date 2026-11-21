import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

class ReportesService {
  /// URL Reporte Rutas PDF
  static String get urlReporteRutasPdf =>
      '${ApiClient.baseUrl}/api/reportes/rutas?formato=pdf';

  /// URL Reporte Rutas Excel
  static String get urlReporteRutasExcel =>
      '${ApiClient.baseUrl}/api/reportes/rutas?formato=excel';

  /// URL Reporte Estudiantes PDF
  static String urlReporteEstudiantesPdf({int rutaId = 1}) =>
      '${ApiClient.baseUrl}/api/reportes/estudiantes?ruta_id=$rutaId&formato=pdf';

  /// URL Reporte Estudiantes Excel
  static String urlReporteEstudiantesExcel({int rutaId = 1}) =>
      '${ApiClient.baseUrl}/api/reportes/estudiantes?ruta_id=$rutaId&formato=excel';

  /// URL Reporte Pagos PDF
  static String urlReportePagosPdf({required int mes, required int anio}) =>
      '${ApiClient.baseUrl}/api/reportes/pagos?mes=$mes&anio=$anio&formato=pdf';

  /// URL Reporte Pagos Excel
  static String urlReportePagosExcel({required int mes, required int anio}) =>
      '${ApiClient.baseUrl}/api/reportes/pagos?mes=$mes&anio=$anio&formato=excel';

  /// Descarga los bytes del reporte autenticando con el token Bearer de ADMIN
  Future<List<int>> descargarReporteBytes(String endpointPath, {Map<String, dynamic>? queryParameters}) async {
    final response = await ApiClient.dio.get<List<int>>(
      endpointPath,
      queryParameters: queryParameters,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? <int>[];
  }

  /// Abre la URL del reporte en el navegador externo
  Future<bool> abrirReporteEnNavegador(String url) async {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

