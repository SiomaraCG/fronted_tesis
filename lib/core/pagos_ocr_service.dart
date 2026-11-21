import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';

class PagosOcrService {
  final ImagePicker _picker = ImagePicker();

  /// Abre la galería/cámara, sube la imagen al Backend y devuelve los datos extraídos por el OCR
  Future<Map<String, dynamic>?> seleccionarYSubirComprobante(
    int pagoId, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final XFile? imagen = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (imagen == null) return null;

    return subirArchivoComprobante(pagoId, imagen);
  }

  /// Sube un XFile ya seleccionado al Backend y devuelve los datos extraídos por el OCR
  Future<Map<String, dynamic>> subirArchivoComprobante(int pagoId, XFile imagen) async {
    final bytes = await imagen.readAsBytes();
    final formData = FormData.fromMap({
      'archivo': MultipartFile.fromBytes(
        bytes,
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

  /// Paso 5.1: El Padre confirma (o corrige) los datos leídos por el OCR
  Future<void> confirmarDatosOcr({
    required int comprobanteId,
    required String banco,
    required double montoExtraido,
    required String fechaTransferencia,
    required String referenciaExtraida,
  }) async {
    await ApiClient.dio.put(
      '/pagos/comprobantes/$comprobanteId/confirmar-datos',
      data: {
        'banco': banco,
        'monto_extraido': montoExtraido,
        'fecha_transferencia': fechaTransferencia,
        'referencia_extraida': referenciaExtraida,
      },
    );
  }

  /// Paso 5.2: El Administrador aprueba (VALIDADO) o rechaza (RECHAZADO) el comprobante
  Future<void> revisarComprobanteAdmin({
    required int comprobanteId,
    required bool aprobar,
    String? observacion,
  }) async {
    await ApiClient.dio.patch(
      '/pagos/comprobantes/$comprobanteId/revisar',
      data: {
        'estado': aprobar ? 'VALIDADO' : 'RECHAZADO',
        'observacion': observacion,
      },
    );
  }
}

