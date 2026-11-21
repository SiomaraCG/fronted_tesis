import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/navigation/routes.dart';
import '../../data/models/app_user.dart';
import '../../data/models/student.dart';
import '../../data/models/payment.dart';
import '../../data/services/mock_database.dart';
import 'live_tracking_map.dart';

class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<MockDatabase>(context);
    final parent = db.currentUser;
    
    // Estudiantes pertenecientes a este representante (cargados desde el backend con aislamiento por rol RF-15)
    final children = db.students
        .where((s) => s.tutorId == parent?.id || parent?.role == UserRole.parent)
        .toList();

    final List<Widget> tabs = [
      _MonitoringTab(children: children, db: db),
      _PaymentsTab(children: children, db: db),
      _NotificationsTab(db: db),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Padre de Familia - Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Notificaciones (/api/gps/notificaciones)',
            onPressed: () {
              db.refrescarNotificaciones();
              setState(() => _currentIndex = 2);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              db.logout();
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
          ),
        ],
      ),
      extendBody: true,
      body: Stack(
        children: [
          // Yellow background pattern - bottom left
          Positioned(
            bottom: -150,
            left: -100,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(60),
                ),
              ),
            ),
          ),
          // Yellow background pattern - bottom right
          Positioned(
            bottom: -50,
            right: -100,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutQuart,
              switchOutCurve: Curves.easeInQuart,
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.95,
                      end: 1.0,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: Container(
                key: ValueKey<int>(_currentIndex),
                child: tabs[_currentIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.black12,
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              if (Theme.of(context).brightness == Brightness.dark)
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
            ],
            border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: Colors.white24, width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.map_outlined, Icons.map, 'Monitoreo'),
              _buildNavItem(1, Icons.payment_outlined, Icons.payment, 'Pagos'),
              _buildNavItem(2, Icons.notifications_outlined, Icons.notifications, 'Avisos'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: isSelected ? 16 : 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(isDark ? 0.2 : 0.15) 
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected 
                  ? (isDark ? AppColors.primary : AppColors.accent)
                  : (isDark ? Colors.white70 : Colors.grey),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? AppColors.primary : AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// --- Tab 1: Monitoreo ---
class _MonitoringTab extends StatelessWidget {
  final List<Student> children;
  final MockDatabase db;

  const _MonitoringTab({required this.children, required this.db});

  @override
  Widget build(BuildContext context) {
    // children and db are fields of the StatelessWidget, no need for widget. prefix
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado de mis Hijos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            const Center(child: Text('No tienes estudiantes registrados.'))
          else
            ...children.map((child) {
              // Obtener ruta asignada al estudiante desde la BD
              final matchingRoutes = db.routes.where((r) => r.id == child.routeId).toList();
              final route = matchingRoutes.isNotEmpty
                  ? matchingRoutes.first
                  : (db.routes.isNotEmpty ? db.routes.first : null);
              final bool hasRoute = route != null;
              final bool routeActive = route?.isActive ?? false;

              Color statusColor;
              String statusText;
              IconData statusIcon;

              switch (child.status) {
                case StudentStatus.atHome:
                  statusColor = AppColors.info;
                  statusText = 'En Casa / Espera';
                  statusIcon = Icons.home_outlined;
                  break;
                case StudentStatus.inRoute:
                  statusColor = AppColors.warning;
                  statusText = 'En Ruta / En Autobús';
                  statusIcon = Icons.directions_bus;
                  break;
                case StudentStatus.atSchool:
                  statusColor = AppColors.success;
                  statusText = 'Entregado en Colegio';
                  statusIcon = Icons.school_outlined;
                  break;
                case StudentStatus.absent:
                  statusColor = AppColors.danger;
                  statusText = 'Ausente hoy';
                  statusIcon = Icons.cancel_outlined;
                  break;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.person, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  child.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Edad: ${child.age} años | Grado escolar',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 20),
                          const SizedBox(width: 8),
                          const Text('Estado actual: ', style: TextStyle(fontSize: 14)),
                          Text(
                            statusText,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Parada: ${child.stopName}',
                              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: hasRoute
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LiveTrackingMap(
                                      routeId: route.id,
                                      studentId: child.id,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasRoute ? AppColors.primary : Colors.grey[300],
                          foregroundColor: hasRoute ? AppColors.accent : Colors.grey[600],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.map),
                            const SizedBox(width: 8),
                            Text(
                              !hasRoute
                                  ? 'Sin Ruta Asignada'
                                  : (routeActive
                                      ? 'Monitorear Autobús en Vivo'
                                      : 'Ver Mapa de Ruta'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Paso 4.2: Botón "Mi hijo no asistirá hoy" -> POST /api/viajes/{viaje_id}/ausencias
                      OutlinedButton.icon(
                        onPressed: child.status == StudentStatus.absent
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                try {
                                  await db.reportarAusenciaHijo(child.id);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Ausencia de ${child.name} reportada al conductor'),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                } catch (e) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Error al reportar ausencia: $e'),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          minimumSize: const Size(double.infinity, 42),
                        ),
                        icon: const Icon(Icons.event_busy_outlined, size: 18),
                        label: Text(
                          child.status == StudentStatus.absent
                              ? 'Ausencia ya reportada hoy'
                              : 'Mi hijo no asistirá hoy',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// --- Tab 2: Pagos ---
class _PaymentsTab extends StatefulWidget {
  final List<Student> children;
  final MockDatabase db;

  const _PaymentsTab({required this.children, required this.db});

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  Student? _selectedStudent;
  XFile? _selectedImage;
  bool _isUploadingOcr = false;

  @override
  void initState() {
    super.initState();
    if (widget.children.isNotEmpty) {
      _selectedStudent = widget.children.first;
    }
  }

  Future<void> _pickReceiptImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => _selectedImage = picked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comprobante seleccionado: ${picked.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir la galería: $e')),
        );
      }
    }
  }

  Future<void> _submitReceipt() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un estudiante')),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor adjunta la imagen del comprobante para procesarlo con OCR')),
      );
      return;
    }

    setState(() => _isUploadingOcr = true);
    try {
      final ocrData = await widget.db.subirComprobantePagoReal(
        studentId: _selectedStudent!.id,
        imagen: _selectedImage!,
      );

      _amountController.clear();
      _referenceController.clear();
      setState(() => _selectedImage = null);

      if (!mounted) return;
      final bancoCtrl = TextEditingController(
        text: (ocrData?['banco'] ?? 'Banco Pichincha').toString(),
      );
      final montoCtrl = TextEditingController(
        text: (ocrData?['monto_extraido'] ?? '55.00').toString(),
      );
      final fechaCtrl = TextEditingController(
        text: (ocrData?['fecha_transferencia'] ?? DateTime.now().toIso8601String().split('T').first).toString(),
      );
      final refCtrl = TextEditingController(
        text: (ocrData?['referencia_extraida'] ?? 'REF-001').toString(),
      );
      final int? comprobanteId = (ocrData?['id'] as num?)?.toInt();
      final confianza = ocrData?['ocr_confianza'] ?? '-';

      showDialog(
        context: context,
        builder: (dialogContext) {
          bool isConfirming = false;
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.document_scanner, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(child: Text('Datos Leídos por OCR')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Confianza OCR: $confianza',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bancoCtrl,
                        decoration: const InputDecoration(labelText: 'Banco detectado'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Monto extraído (\$)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fechaCtrl,
                        decoration: const InputDecoration(labelText: 'Fecha transferencia (YYYY-MM-DD)'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: refCtrl,
                        decoration: const InputDecoration(labelText: 'Referencia extraída'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isConfirming ? null : () => Navigator.pop(dialogContext),
                    child: const Text('Cerrar'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isConfirming
                        ? null
                        : () async {
                            if (comprobanteId == null) {
                              Navigator.pop(dialogContext);
                              return;
                            }
                            setDialogState(() => isConfirming = true);
                            final navigator = Navigator.of(dialogContext);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await widget.db.confirmarDatosComprobanteOcr(
                                comprobanteId: comprobanteId,
                                banco: bancoCtrl.text.trim(),
                                montoExtraido: double.tryParse(montoCtrl.text.trim()) ?? 55.0,
                                fechaTransferencia: fechaCtrl.text.trim(),
                                referenciaExtraida: refCtrl.text.trim(),
                              );
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Datos del comprobante confirmados (EN_REVISION)'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              setDialogState(() => isConfirming = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al confirmar datos OCR: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Confirmar Datos'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingOcr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = widget.db.payments.where((p) => widget.children.any((s) => s.id == p.studentId)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subir Comprobante de Pago',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<Student>(
                    value: _selectedStudent,
                    decoration: const InputDecoration(labelText: 'Seleccionar Estudiante'),
                    items: widget.children.map((student) {
                      return DropdownMenuItem<Student>(
                        value: student,
                        child: Text(student.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedStudent = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monto Cancelado (\$)',
                      prefixText: '\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Número de Referencia de Transferencia',
                      hintText: 'Ej: REF-123456',
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Photo selector connected to ImagePicker + OCR Backend
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.accentLight : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedImage != null ? AppColors.success : AppColors.primary,
                        width: 1.8,
                      ),
                    ),
                    child: InkWell(
                      onTap: _pickReceiptImage,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedImage != null ? Icons.check_circle : Icons.camera_alt_outlined,
                            color: _selectedImage != null
                                ? AppColors.success
                                : (isDark ? AppColors.primary : AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedImage != null
                                ? 'Imagen lista: ${_selectedImage!.name}'
                                : 'Adjuntar foto del comprobante (OCR)',
                            style: TextStyle(
                              fontSize: 12,
                              color: _selectedImage != null
                                  ? AppColors.success
                                  : (isDark ? AppColors.textLight : AppColors.textDark),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isUploadingOcr ? null : _submitReceipt,
                    child: _isUploadingOcr
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enviar para Verificación (OCR)'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Historial de Pagos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            const Center(child: Text('No hay historial de pagos registrados.'))
          else
            ...payments.reversed.map((pay) {
              Color statusColor = Colors.grey;
              String statusText = '';
              IconData statusIcon = Icons.help;

              switch (pay.status) {
                case PaymentStatus.pending:
                  statusColor = AppColors.warning;
                  statusText = 'Pendiente Validación';
                  statusIcon = Icons.hourglass_empty;
                  break;
                case PaymentStatus.approved:
                  statusColor = AppColors.success;
                  statusText = 'Aprobado';
                  statusIcon = Icons.check_circle;
                  break;
                case PaymentStatus.rejected:
                  statusColor = AppColors.danger;
                  statusText = 'Rechazado';
                  statusIcon = Icons.cancel;
                  break;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(statusIcon, color: statusColor),
                  ),
                  title: Text(
                    '${pay.studentName} - \$${pay.amount}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(pay.date)}\nRef: ${pay.referenceNumber ?? "N/A"}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// --- Tab 3: Avisos/Notificaciones ---
class _NotificationsTab extends StatelessWidget {
  final MockDatabase db;

  const _NotificationsTab({required this.db});

  @override
  Widget build(BuildContext context) {
    final notifications = db.notifications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'Notificaciones del Sistema',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: notifications.isEmpty
              ? const Center(child: Text('No hay avisos recientes.'))
              : ListView.builder(
                  itemCount: notifications.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final not = notifications[index];
                    IconData icon = Icons.info_outline;
                    Color color = AppColors.info;

                    if (not['type'] == 'route') {
                      icon = Icons.directions_bus_outlined;
                      color = AppColors.accent;
                    } else if (not['type'] == 'payment') {
                      icon = Icons.payment_outlined;
                      color = AppColors.success;
                    } else if (not['type'] == 'alert') {
                      icon = Icons.warning_rounded;
                      color = AppColors.danger;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withOpacity(0.1),
                          child: Icon(icon, color: color),
                        ),
                        title: Text(
                          not['title'] as String? ?? 'Aviso',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(not['body'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(not['time'] as DateTime),
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
