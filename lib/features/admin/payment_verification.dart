import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/api_client.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/payment.dart';
import '../../data/services/mock_database.dart';

class PaymentVerification extends StatelessWidget {
  const PaymentVerification({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<MockDatabase>(context);
    final pendingPayments = db.payments.where((p) => p.status == PaymentStatus.pending).toList();
    final approvedPayments = db.payments.where((p) => p.status == PaymentStatus.approved).toList();
    final rejectedPayments = db.payments.where((p) => p.status == PaymentStatus.rejected).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Validación de Pagos (OCR)'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar lista de pagos',
              onPressed: () => db.refreshAllData(),
            ),
          ],
          bottom: TabBar(
            labelColor: AppColors.primaryDark,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            tabs: [
              Tab(text: 'Pendientes (${pendingPayments.length})'),
              Tab(text: 'Aprobados (${approvedPayments.length})'),
              Tab(text: 'Rechazados (${rejectedPayments.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPaymentsList(context, db, pendingPayments, 'No hay comprobantes pendientes por revisar.'),
            _buildPaymentsList(context, db, approvedPayments, 'Aún no hay pagos aprobados.'),
            _buildPaymentsList(context, db, rejectedPayments, 'No hay pagos rechazados.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsList(
    BuildContext context,
    MockDatabase db,
    List<Payment> items,
    String emptyMessage,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final pay = items[index];
        final bool hasComprobante = pay.comprobanteId != null;

        Color statusColor;
        String statusStr;
        switch (pay.status) {
          case PaymentStatus.approved:
            statusColor = AppColors.success;
            statusStr = 'Aprobado / Pagado';
            break;
          case PaymentStatus.rejected:
            statusColor = AppColors.danger;
            statusStr = 'Rechazado';
            break;
          case PaymentStatus.pending:
            statusColor = hasComprobante ? AppColors.warning : AppColors.textMuted;
            statusStr = hasComprobante ? 'Comprobante por Revisar' : 'Esperando Comprobante';
            break;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pay.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        statusStr,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Monto: \$${pay.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                if (pay.representanteNombre != null && pay.representanteNombre!.isNotEmpty)
                  Text('Representante: ${pay.representanteNombre}', style: const TextStyle(fontSize: 12)),
                Text('Referencia: ${pay.referenceNumber ?? "N/A"}', style: const TextStyle(fontSize: 12)),
                Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(pay.date)}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (pay.status == PaymentStatus.pending && hasComprobante)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OcrVerificationScreen(payment: pay, db: db),
                            ),
                          );
                        },
                        icon: const Icon(Icons.document_scanner, size: 16, color: AppColors.accent),
                        label: const Text('Revisar / Aprobar OCR', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.accent,
                          minimumSize: const Size(140, 38),
                        ),
                      )
                    else if (pay.status == PaymentStatus.pending && !hasComprobante)
                      const Text(
                        'El padre aún no ha subido el comprobante',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMuted),
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            pay.status == PaymentStatus.approved ? Icons.verified : Icons.cancel,
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusStr,
                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- Screen for Scanning and OCR Simulation ---
class OcrVerificationScreen extends StatefulWidget {
  final Payment payment;
  final MockDatabase db;

  const OcrVerificationScreen({
    super.key,
    required this.payment,
    required this.db,
  });

  @override
  State<OcrVerificationScreen> createState() => _OcrVerificationScreenState();
}

class _OcrVerificationScreenState extends State<OcrVerificationScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  bool _isScanning = true;
  bool _scanComplete = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Simulate scanning delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _scanComplete = true;
          _scanController.stop();
        });
      }
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  Widget _buildFallbackReceiptInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              (widget.payment.banco ?? 'COMPROBANTE BANCARIO').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            Text(
              'Ref OCR: ${widget.payment.ocrReferencia ?? widget.payment.referenceNumber ?? "N/A"}\n'
              'Monto OCR: \$${widget.payment.ocrMonto ?? widget.payment.amount}\n'
              'Fecha: ${widget.payment.ocrFecha ?? DateFormat('dd/MM/yyyy').format(widget.payment.date)}\n'
              'Confianza OCR: ${widget.payment.ocrConfianza ?? "N/A"}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.black54, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador OCR'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Receipt Image Frame with Scan Line Animation
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: Stack(
                    children: [
                      // Paso 5.2: Ver la imagen subida (http://.../uploads/comprobantes/...) y datos OCR
                      if (widget.payment.receiptImagePath.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(
                            widget.payment.receiptImagePath.startsWith('http')
                                ? widget.payment.receiptImagePath
                                : '${ApiClient.baseUrl}/${widget.payment.receiptImagePath.replaceFirst(RegExp(r'^/'), '')}',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => _buildFallbackReceiptInfo(),
                          ),
                        )
                      else
                        _buildFallbackReceiptInfo(),
                      
                      // Scan overlay animation
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _scanController,
                          builder: (context, child) {
                            return Positioned(
                              top: _scanController.value * 260,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.success.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      
                      // Scanning indicator overlay text
                      if (_isScanning)
                        Container(
                          color: Colors.black38,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: AppColors.accent),
                                SizedBox(height: 12),
                                Text(
                                  'Analizando comprobante...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // OCR Reading Results
            if (_scanComplete) ...[
              Card(
                color: isDark ? Colors.white54.withOpacity(0.05) : Colors.green.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.success, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppColors.success),
                          SizedBox(width: 8),
                          Text(
                            'Lectura OCR Completada',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _OcrMatchRow(
                        label: 'Monto Identificado',
                        ocrValue: '\$${widget.payment.ocrMonto ?? widget.payment.amount}',
                        inputValue: '\$${widget.payment.amount}',
                        isMatch: true,
                      ),
                      const SizedBox(height: 10),
                      _OcrMatchRow(
                        label: 'Número de Referencia',
                        ocrValue: widget.payment.ocrReferencia ?? widget.payment.referenceNumber ?? 'N/A',
                        inputValue: widget.payment.referenceNumber ?? 'N/A',
                        isMatch: true,
                      ),
                      const SizedBox(height: 10),
                      _OcrMatchRow(
                        label: 'Representante / Banco',
                        ocrValue: widget.payment.banco ?? 'No especificado',
                        inputValue: widget.payment.representanteNombre ?? widget.payment.studentName,
                        isMatch: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.db.updatePaymentStatus(widget.payment.id, PaymentStatus.rejected);
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Pago Rechazado en Base de Datos'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              } catch (e) {
                                if (mounted) setState(() => _isProcessing = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Rechazar Pago', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              final navigator = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await widget.db.updatePaymentStatus(widget.payment.id, PaymentStatus.approved);
                                navigator.pop();
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Pago Aprobado en Base de Datos'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } catch (e) {
                                if (mounted) setState(() => _isProcessing = false);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(e.toString().replaceFirst('Exception: ', '')),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Aprobar Pago', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OcrMatchRow extends StatelessWidget {
  final String label;
  final String ocrValue;
  final String inputValue;
  final bool isMatch;

  const _OcrMatchRow({
    required this.label,
    required this.ocrValue,
    required this.inputValue,
    required this.isMatch,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'OCR: $ocrValue  •  Ingresado: $inputValue',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Icon(
              isMatch ? Icons.check : Icons.close,
              color: isMatch ? AppColors.success : AppColors.danger,
              size: 18,
            ),
          ],
        ),
      ],
    );
  }
}
