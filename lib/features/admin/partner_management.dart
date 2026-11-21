import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/partner.dart';
import '../../data/services/mock_database.dart';

class PartnerManagement extends StatefulWidget {
  const PartnerManagement({super.key});

  @override
  State<PartnerManagement> createState() => _PartnerManagementState();
}

class _PartnerManagementState extends State<PartnerManagement> {
  @override
  Widget build(BuildContext context) {
    final db = Provider.of<MockDatabase>(context);
    final partners = db.partners;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar y Gestionar Conductores'),
      ),
      body: partners.isEmpty
          ? const Center(
              child: Text(
                'No se encontraron conductores registrados.',
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          : ListView.builder(
              itemCount: partners.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final partner = partners[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.person, color: AppColors.textDark, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                partner.name.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white12
                                      : Colors.black12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Placa: ${partner.vehiclePlate} • Cédula: ${partner.cedula ?? "N/A"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Licencia: ${partner.licenseNumber} • Tel: ${partner.phone}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (partner.email != null && partner.email!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Correo: ${partner.email}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.info),
                              onPressed: () => _showPartnerFormDialog(context, db, partner),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                              onPressed: () => _showDeleteConfirmation(context, db, partner.id, partner.name),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        onPressed: () => _showPartnerFormDialog(context, db, null),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Registrar Conductor', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MockDatabase db, String partnerId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Desactivación'),
          content: Text('¿Está seguro de que desea desactivar al conductor "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await db.deletePartner(partnerId);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Conductor desactivado en Base de Datos')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Desactivar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showPartnerFormDialog(BuildContext context, MockDatabase db, Partner? partner) {
    final isEdit = partner != null;
    final nameParts = (partner?.name ?? '').trim().split(RegExp(r'\s+'));
    final initialNombre = isEdit && nameParts.isNotEmpty ? nameParts.first : '';
    final initialApellido = isEdit && nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final nombreController = TextEditingController(text: initialNombre);
    final apellidoController = TextEditingController(text: initialApellido);
    final cedulaController = TextEditingController(text: partner?.cedula ?? '');
    final emailController = TextEditingController(text: partner?.email ?? '');
    final passwordController = TextEditingController(text: 'conductor123');
    final phoneController = TextEditingController(text: partner?.phone ?? '');
    final licenseController = TextEditingController(text: partner?.licenseNumber ?? '');
    final plateController = TextEditingController(text: partner?.vehiclePlate ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Editar Conductor' : 'Nuevo Conductor',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'INFORMACIÓN PERSONAL Y ACCESO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nombreController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombres *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: apellidoController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Apellidos *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isEdit) ...[
                        TextField(
                          controller: cedulaController,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Cédula (10 dígitos) *',
                            prefixIcon: Icon(Icons.badge_outlined),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico *',
                          hintText: 'conductor.nuevo@cooperativa.ec',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isEdit) ...[
                        TextField(
                          controller: passwordController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña Inicial *',
                            helperText: 'Credencial para que el conductor inicie sesión',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      const Divider(height: 24),
                      const Text(
                        'LICENCIA Y UNIDAD ASIGNADA',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono *',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: licenseController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Licencia Profesional *',
                          hintText: 'Ej: TIPO-E-1712345678',
                          prefixIcon: Icon(Icons.card_membership_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: plateController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Placa del Vehículo (Opcional)',
                          hintText: 'Ej: PAB-1234',
                          prefixIcon: Icon(Icons.directions_bus_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (nombreController.text.trim().isEmpty ||
                              apellidoController.text.trim().isEmpty ||
                              licenseController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Completa los campos obligatorios (*)'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            if (isEdit) {
                              await db.updatePartner(
                                partner.copyWith(
                                  name: '${nombreController.text.trim()} ${apellidoController.text.trim()}'.trim(),
                                  phone: phoneController.text.trim(),
                                  vehiclePlate: plateController.text.trim(),
                                  licenseNumber: licenseController.text.trim(),
                                  email: emailController.text.trim(),
                                ),
                              );
                            } else {
                              await db.registrarConductorJerarquico(
                                email: emailController.text,
                                password: passwordController.text,
                                nombre: nombreController.text,
                                apellido: apellidoController.text,
                                cedula: cedulaController.text,
                                telefono: phoneController.text,
                                licencia: licenseController.text,
                                placaVehiculo: plateController.text,
                              );
                            }

                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isEdit
                                      ? 'Conductor actualizado exitosamente'
                                      : 'Conductor y usuario creados exitosamente',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(e.toString().replaceFirst('Exception: ', '')),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
