import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/partner.dart';
import '../../data/models/route.dart';
import '../../data/services/mock_database.dart';
import '../driver/active_route_map.dart';

class RouteManagement extends StatelessWidget {
  const RouteManagement({super.key});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<MockDatabase>(context);
    final routes = db.routes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Rutas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar rutas y conductores',
            onPressed: () => db.refreshAllData(),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: routes.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final route = routes[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.25),
                child: const Icon(Icons.alt_route, color: AppColors.accent),
              ),
              title: Text(
                route.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                'Conductor asignado: ${route.driverName}\nTurno: ${route.turno ?? "AM"} • Sector: ${route.sector ?? "Quito"}\nAlumnos asignados: ${route.studentIds.length} • Paradas: ${route.pathPoints.length}',
                style: const TextStyle(fontSize: 11),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.map_outlined, color: AppColors.primaryDark),
                    tooltip: 'Ver Mapa y Optimizar Ruta (OR-Tools)',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveRouteMap(routeId: route.id),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.info),
                    tooltip: 'Editar Ruta / Cambiar Conductor',
                    onPressed: () => _showRouteFormDialog(context, db, route),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                    tooltip: 'Desactivar Ruta',
                    onPressed: () {
                      _showDeleteConfirmation(context, db, route.id, route.name);
                    },
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
        onPressed: () => _showRouteFormDialog(context, db, null),
        icon: const Icon(Icons.add_road_rounded),
        label: const Text(
          'Nueva Ruta',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MockDatabase db, String routeId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Está seguro de que desea eliminar la ruta "$name"? Los estudiantes asignados quedarán sin ruta.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await db.deleteRoute(routeId);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Ruta desactivada en Base de Datos')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showRouteFormDialog(BuildContext context, MockDatabase db, SchoolRoute? route) {
    final isEdit = route != null;
    final nameController = TextEditingController(text: route?.name ?? '');
    final sectorController = TextEditingController(text: route?.sector ?? 'Norte - Quito');
    String selectedTurno = (route?.turno == 'PM') ? 'PM' : 'AM';

    final List<Partner> availableDrivers = List<Partner>.from(db.partners);
    String? selectedDriverId;

    if (availableDrivers.isNotEmpty) {
      final matchById = availableDrivers.where((p) => p.id == route?.driverId).toList();
      final matchByName = availableDrivers
          .where((p) => p.name.toLowerCase().trim() == (route?.driverName ?? '').toLowerCase().trim())
          .toList();
      if (matchById.isNotEmpty) {
        selectedDriverId = matchById.first.id;
      } else if (matchByName.isNotEmpty) {
        selectedDriverId = matchByName.first.id;
      } else {
        selectedDriverId = availableDrivers.first.id;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Partner? selectedPartner;
            if (selectedDriverId != null) {
              for (final p in availableDrivers) {
                if (p.id == selectedDriverId) {
                  selectedPartner = p;
                  break;
                }
              }
            }

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
                    child: const Icon(
                      Icons.alt_route_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEdit ? 'Editar Ruta y Conductor' : 'Nueva Ruta Escolar',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de la Ruta *',
                          hintText: 'Ej: Ruta Norte - La Carolina',
                          prefixIcon: Icon(Icons.alt_route_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (availableDrivers.isNotEmpty)
                        DropdownButtonFormField<String>(
                          value: selectedDriverId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Seleccionar Conductor Asignado *',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: availableDrivers.map((partner) {
                            return DropdownMenuItem<String>(
                              value: partner.id,
                              child: Text(
                                '${partner.name} (${partner.vehiclePlate})',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedDriverId = val;
                              });
                            }
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: const Text(
                            'No hay conductores registrados aún. Registra primero un conductor en Gestión de Conductores.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (selectedPartner != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primaryDark.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_bus_filled, size: 18, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Unidad: ${selectedPartner.vehiclePlate} • Lic: ${selectedPartner.licenseNumber} • Tel: ${selectedPartner.phone}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: sectorController,
                        decoration: const InputDecoration(
                          labelText: 'Sector de Cobertura',
                          hintText: 'Ej: Norte - La Carolina',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTurno,
                        decoration: const InputDecoration(
                          labelText: 'Turno de Recorrido',
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'AM', child: Text('Matutino (AM - Recogida)')),
                          DropdownMenuItem(value: 'PM', child: Text('Vespertino (PM - Retorno)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTurno = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'El conductor seleccionado quedará asignado a esta ruta en PostgreSQL + PostGIS.',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);

                    final assignedDriverId = selectedPartner?.id ?? (route?.driverId ?? '1');
                    final assignedDriverName = selectedPartner?.name ?? (route?.driverName ?? 'Conductor Asignado');
                    final assignedBusId = selectedPartner?.busId ?? route?.busId;

                    try {
                      if (isEdit) {
                        await db.updateRoute(route.copyWith(
                          name: nameController.text.trim(),
                          driverId: assignedDriverId,
                          driverName: assignedDriverName,
                          busId: assignedBusId,
                          sector: sectorController.text.trim(),
                          turno: selectedTurno,
                        ));
                      } else {
                        await db.addRoute(SchoolRoute(
                          id: '0',
                          name: nameController.text.trim(),
                          driverId: assignedDriverId,
                          driverName: assignedDriverName,
                          busId: assignedBusId,
                          sector: sectorController.text.trim(),
                          turno: selectedTurno,
                          studentIds: const [],
                          pathPoints: const [],
                          isActive: false,
                          currentLatitude: -0.1800,
                          currentLongitude: -78.4800,
                        ));
                      }
                      navigator.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            isEdit
                                ? 'Ruta actualizada con conductor $assignedDriverName'
                                : 'Ruta creada y asignada a $assignedDriverName',
                          ),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error al guardar ruta: $e'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar y Asignar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
