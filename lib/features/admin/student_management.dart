import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student.dart';
import '../../data/services/mock_database.dart';

class StudentManagement extends StatefulWidget {
  const StudentManagement({super.key});

  @override
  State<StudentManagement> createState() => _StudentManagementState();
}

class _StudentManagementState extends State<StudentManagement> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<MockDatabase>(context);

    final students = db.students
        .where((s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Padre y Estudiante'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Consultar estudiante por nombre...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: students.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron estudiantes registrados.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : ListView.builder(
                    itemCount: students.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final matchingRoutes = db.routes.where((r) => r.id == student.routeId).toList();
                      final routeName = matchingRoutes.isNotEmpty
                          ? matchingRoutes.first.name
                          : 'Ruta asignada';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.school, color: AppColors.primary),
                          ),
                          title: Text(
                            student.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Text(
                            'Grado: ${student.grade ?? "${student.age} años"} • Representante: ${student.tutorName}\n'
                            '$routeName • Parada: ${student.stopName}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.alt_route_rounded, color: AppColors.primaryDark),
                                tooltip: 'Asignar / Cambiar Ruta',
                                onPressed: () => _showAssignRouteDialog(context, db, student),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppColors.info),
                                tooltip: 'Editar Estudiante',
                                onPressed: () => _showEditStudentDialog(context, db, student),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                tooltip: 'Desactivar Estudiante',
                                onPressed: () => _showDeleteConfirmation(context, db, student.id, student.name),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        onPressed: () => _showRegistrarPadreYEstudianteDialog(context, db),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Registrar Padre y Estudiante', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MockDatabase db, String studentId, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar Desactivación'),
          content: Text('¿Está seguro de que desea desactivar al estudiante "$name"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await db.deleteStudent(studentId);
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Estudiante desactivado en la Base de Datos')),
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

  /// Formulario Todo-en-Uno: POST /api/estudiantes/registrar-padre-y-estudiante
  void _showRegistrarPadreYEstudianteDialog(BuildContext context, MockDatabase db) {
    // Campos del Padre / Representante
    final padreNombreCtrl = TextEditingController();
    final padreApellidoCtrl = TextEditingController();
    final padreCedulaCtrl = TextEditingController();
    final padreEmailCtrl = TextEditingController();
    final padrePasswordCtrl = TextEditingController(text: 'padre123');
    final padreTelefonoCtrl = TextEditingController();

    // Campos del Estudiante + Parada GPS
    final estNombreCtrl = TextEditingController();
    final estApellidoCtrl = TextEditingController();
    final estCedulaCtrl = TextEditingController();
    final estGradoCtrl = TextEditingController(text: '6to EGB');
    final direccionCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: '-0.179500');
    final lngCtrl = TextEditingController(text: '-78.482100');
    final montoCtrl = TextEditingController(text: '55.00');

    bool isSaving = false;
    bool isFetchingGps = false;
    final MapController mapDialogController = MapController();
    String? selectedRouteId = db.routes.isNotEmpty ? db.routes.first.id : null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> capturarGpsActual() async {
              setDialogState(() => isFetchingGps = true);
              try {
                final enabled = await Geolocator.isLocationServiceEnabled();
                if (!enabled) {
                  throw Exception('El servicio de ubicación del sistema está desactivado. Puedes tocar directamente en el mapa para fijar el pin.');
                }
                LocationPermission perm = await Geolocator.checkPermission();
                if (perm == LocationPermission.denied) {
                  perm = await Geolocator.requestPermission();
                }
                if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
                  throw Exception('Permiso de ubicación denegado. Toca directamente en el mapa para fijar la parada.');
                }
                final pos = await Geolocator.getCurrentPosition(
                  desiredAccuracy: LocationAccuracy.high,
                  timeLimit: const Duration(seconds: 5),
                );
                setDialogState(() {
                  latCtrl.text = pos.latitude.toStringAsFixed(6);
                  lngCtrl.text = pos.longitude.toStringAsFixed(6);
                });
                mapDialogController.move(LatLng(pos.latitude, pos.longitude), 16.0);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ubicación GPS capturada: ${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                final currentLat = double.tryParse(latCtrl.text) ?? -0.179500;
                final currentLng = double.tryParse(lngCtrl.text) ?? -78.482100;
                mapDialogController.move(LatLng(currentLat, currentLng), 15.5);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', ''),
                      ),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              } finally {
                setDialogState(() => isFetchingGps = false);
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.family_restroom_rounded,
                      color: AppColors.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Registrar Padre y Estudiante',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '1. DATOS DEL PADRE / REPRESENTANTE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: padreNombreCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombres del Padre *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: padreApellidoCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Apellidos del Padre *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: padreCedulaCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Cédula del Padre (10 dígitos) *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: padreEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Correo del Padre (Usuario Login) *',
                          hintText: 'roberto.vega@correo.ec',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: padrePasswordCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña para el Padre *',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: padreTelefonoCtrl,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono del Padre *',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const Divider(height: 28),
                      const Text(
                        '2. DATOS DEL ESTUDIANTE Y PARADA GPS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: estNombreCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombres del Estudiante *',
                          prefixIcon: Icon(Icons.face_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: estApellidoCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Apellidos del Estudiante *',
                          prefixIcon: Icon(Icons.face_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: estCedulaCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Cédula del Estudiante (10 dígitos) *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: estGradoCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Grado / Curso *',
                          hintText: 'Ej: 6to EGB',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: direccionCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Dirección del Domicilio / Parada *',
                          hintText: 'Av. República del Salvador y Moscú',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Toca en el mapa para fijar el pin de la casa o usa el botón GPS:',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            mapController: mapDialogController,
                            options: MapOptions(
                              initialCenter: LatLng(
                                double.tryParse(latCtrl.text) ?? -0.179500,
                                double.tryParse(lngCtrl.text) ?? -78.482100,
                              ),
                              initialZoom: 14.5,
                              onTap: (tapPos, point) {
                                setDialogState(() {
                                  latCtrl.text = point.latitude.toStringAsFixed(6);
                                  lngCtrl.text = point.longitude.toStringAsFixed(6);
                                });
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.tesis.transporte_escolar',
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(
                                      double.tryParse(latCtrl.text) ?? -0.179500,
                                      double.tryParse(lngCtrl.text) ?? -78.482100,
                                    ),
                                    width: 44,
                                    height: 44,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: AppColors.danger,
                                      size: 40,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: latCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(labelText: 'Latitud GPS *'),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lngCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                              decoration: const InputDecoration(labelText: 'Longitud GPS *'),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              tooltip: 'Capturar ubicación GPS actual (Geolocator)',
                              onPressed: isFetchingGps ? null : capturarGpsActual,
                              icon: isFetchingGps
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                    )
                                  : const Icon(Icons.my_location, color: AppColors.accent),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: montoCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Tarifa Mensual Inicial (\$) *',
                          prefixText: '\$ ',
                          prefixIcon: Icon(Icons.attach_money_rounded),
                        ),
                      ),
                      if (db.routes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedRouteId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Asignar a Ruta Escolar *',
                            prefixIcon: Icon(Icons.alt_route_rounded),
                          ),
                          items: db.routes.map((r) {
                            return DropdownMenuItem<String>(
                              value: r.id,
                              child: Text(
                                '${r.name} (${r.driverName})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedRouteId = val);
                          },
                        ),
                      ],
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
                          if (padreNombreCtrl.text.trim().isEmpty ||
                              padreApellidoCtrl.text.trim().isEmpty ||
                              padreCedulaCtrl.text.trim().length != 10 ||
                              padreEmailCtrl.text.trim().isEmpty ||
                              estNombreCtrl.text.trim().isEmpty ||
                              estApellidoCtrl.text.trim().isEmpty ||
                              estCedulaCtrl.text.trim().length != 10 ||
                              direccionCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Completa todos los campos y verifica que las cédulas tengan 10 dígitos'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          final lat = double.tryParse(latCtrl.text.trim()) ?? -0.1795;
                          final lng = double.tryParse(lngCtrl.text.trim()) ?? -78.4821;
                          final monto = double.tryParse(montoCtrl.text.trim()) ?? 55.0;

                          try {
                            await db.registrarPadreYEstudianteJerarquico(
                              padreEmail: padreEmailCtrl.text,
                              padrePassword: padrePasswordCtrl.text,
                              padreNombre: padreNombreCtrl.text,
                              padreApellido: padreApellidoCtrl.text,
                              padreCedula: padreCedulaCtrl.text,
                              padreTelefono: padreTelefonoCtrl.text,
                              estudianteCedula: estCedulaCtrl.text,
                              estudianteNombre: estNombreCtrl.text,
                              estudianteApellido: estApellidoCtrl.text,
                              estudianteGrado: estGradoCtrl.text,
                              latitudCasa: lat,
                              longitudCasa: lng,
                              direccionCasa: direccionCtrl.text,
                              montoMensual: monto,
                              rutaId: selectedRouteId != null ? int.tryParse(selectedRouteId!) : null,
                            );

                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Padre, estudiante, tarifa y parada GPS creados en la ruta'),
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
                      : const Text('Registrar Todo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAssignRouteDialog(BuildContext context, MockDatabase db, Student student) {
    if (db.routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay rutas registradas. Crea una ruta primero en Gestión de Rutas.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    String selectedRouteId = db.routes.any((r) => r.id == student.routeId)
        ? student.routeId!
        : db.routes.first.id;
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
                    child: const Icon(Icons.alt_route_rounded, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Asignar Ruta al Estudiante', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Estudiante: ${student.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Parada: ${student.stopName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRouteId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Seleccionar Ruta Escolar *',
                        prefixIcon: Icon(Icons.directions_bus_outlined),
                      ),
                      items: db.routes.map((r) {
                        return DropdownMenuItem<String>(
                          value: r.id,
                          child: Text(
                            '${r.name} • Cond: ${r.driverName}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRouteId = val);
                        }
                      },
                    ),
                  ],
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
                          setDialogState(() => isSaving = true);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await db.asignarEstudianteARuta(student.id, selectedRouteId);
                            navigator.pop();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Estudiante asignado a la ruta en PostGIS'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Error al asignar ruta: $e'),
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
                      : const Text('Asignar Ruta'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditStudentDialog(BuildContext context, MockDatabase db, Student student) {
    final nameController = TextEditingController(text: student.name);
    final gradeController = TextEditingController(text: student.grade ?? '${student.age} años');
    final stopNameController = TextEditingController(text: student.stopName);

    showDialog(
      context: context,
      builder: (context) {
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
                child: const Icon(Icons.edit_outlined, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Editar Estudiante', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: gradeController,
                    decoration: const InputDecoration(
                      labelText: 'Grado Escolar *',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stopNameController,
                    decoration: const InputDecoration(
                      labelText: 'Dirección / Parada *',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
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

                try {
                  await db.updateStudent(
                    student.copyWith(
                      name: nameController.text.trim(),
                      grade: gradeController.text.trim(),
                      stopName: stopNameController.text.trim(),
                    ),
                  );
                  navigator.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Estudiante actualizado en BD')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: AppColors.danger),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
