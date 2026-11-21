enum PaymentStatus { pending, approved, rejected }

class Payment {
  final String id;
  final String studentId;
  final String studentName;
  final double amount;
  final DateTime date;
  final PaymentStatus status;
  final String receiptImagePath;
  String? get receiptImageUrl => receiptImagePath.isNotEmpty ? receiptImagePath : null;
  final String? referenceNumber;
  final int? comprobanteId;
  final String? banco;
  final String? ocrMonto;
  final String? ocrReferencia;
  final String? ocrFecha;
  final String? ocrConfianza;
  final String? representanteNombre;
  final int? mes;
  final int? anio;

  Payment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.date,
    required this.status,
    required this.receiptImagePath,
    this.referenceNumber,
    this.comprobanteId,
    this.banco,
    this.ocrMonto,
    this.ocrReferencia,
    this.ocrFecha,
    this.ocrConfianza,
    this.representanteNombre,
    this.mes,
    this.anio,
  });

  Payment copyWith({
    String? id,
    String? studentId,
    String? studentName,
    double? amount,
    DateTime? date,
    PaymentStatus? status,
    String? receiptImagePath,
    String? referenceNumber,
    int? comprobanteId,
    String? banco,
    String? ocrMonto,
    String? ocrReferencia,
    String? ocrFecha,
    String? ocrConfianza,
    String? representanteNombre,
    int? mes,
    int? anio,
  }) {
    return Payment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      status: status ?? this.status,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      comprobanteId: comprobanteId ?? this.comprobanteId,
      banco: banco ?? this.banco,
      ocrMonto: ocrMonto ?? this.ocrMonto,
      ocrReferencia: ocrReferencia ?? this.ocrReferencia,
      ocrFecha: ocrFecha ?? this.ocrFecha,
      ocrConfianza: ocrConfianza ?? this.ocrConfianza,
      representanteNombre: representanteNombre ?? this.representanteNombre,
      mes: mes ?? this.mes,
      anio: anio ?? this.anio,
    );
  }

  factory Payment.fromBackendJson(Map<String, dynamic> json) {
    final comprobantes = (json['comprobantes'] as List<dynamic>?) ?? [];
    Map<String, dynamic>? ultimoComprobante;
    if (comprobantes.isNotEmpty && comprobantes.last is Map<String, dynamic>) {
      ultimoComprobante = comprobantes.last as Map<String, dynamic>;
    }

    final estadoStr = (json['estado'] ?? '').toString().toUpperCase();
    final compEstadoStr = (ultimoComprobante?['estado'] ?? '').toString().toUpperCase();
    PaymentStatus parsedStatus;
    if (estadoStr == 'PAGADO' ||
        estadoStr == 'VALIDADO' ||
        estadoStr == 'APROBADO' ||
        compEstadoStr == 'VALIDADO' ||
        compEstadoStr == 'APROBADO') {
      parsedStatus = PaymentStatus.approved;
    } else if (estadoStr == 'RECHAZADO' || compEstadoStr == 'RECHAZADO') {
      parsedStatus = PaymentStatus.rejected;
    } else {
      parsedStatus = PaymentStatus.pending;
    }

    final createdAtStr = (ultimoComprobante?['created_at'] ?? json['updated_at'] ?? json['created_at'])?.toString();
    final parsedDate = createdAtStr != null ? (DateTime.tryParse(createdAtStr) ?? DateTime.now()) : DateTime.now();

    return Payment(
      id: json['id'].toString(),
      studentId: (json['estudiante_id'] ?? '').toString(),
      studentName: (json['estudiante_nombre'] ?? 'Estudiante').toString(),
      amount: double.tryParse((json['monto'] ?? '0').toString()) ?? 0.0,
      date: parsedDate,
      status: parsedStatus,
      receiptImagePath: (ultimoComprobante?['archivo_url'] ?? '').toString(),
      referenceNumber: ultimoComprobante?['referencia_extraida']?.toString(),
      comprobanteId: (ultimoComprobante?['id'] as num?)?.toInt(),
      banco: ultimoComprobante?['banco']?.toString(),
      ocrMonto: ultimoComprobante?['monto_extraido']?.toString(),
      ocrReferencia: ultimoComprobante?['referencia_extraida']?.toString(),
      ocrFecha: ultimoComprobante?['fecha_transferencia']?.toString(),
      ocrConfianza: ultimoComprobante?['ocr_confianza']?.toString(),
      representanteNombre: json['representante_nombre']?.toString(),
      mes: (json['mes'] as num?)?.toInt(),
      anio: (json['anio'] as num?)?.toInt(),
    );
  }
}
