import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/student.dart';
import '../../data/services/mock_database.dart';

class ActiveRouteMap extends StatefulWidget {
  final String routeId;

  const ActiveRouteMap({super.key, required this.routeId});

  @override
  State<ActiveRouteMap> createState() => _ActiveRouteMapState();
}

class _ActiveRouteMapState extends State<ActiveRouteMap> {
  final MapController _mapController = MapController();
  bool _followBus = true;
  bool _shareGps = true;
  bool _showOptimizedRoute = false;
  bool _isOptimizing = false;
  List<LatLng>? _backendOptimizedPoints;
  List<dynamic>? _paradasOptimizadas;
  double? _distanciaTotalKm;
  double? _tiempoTotalMin;
  Timer? _realGpsTimer;
  int _manualStepIndex = 0;

  @override
  void initState() {
    super.initState();
    _iniciarEmisionGpsPeriodica();
  }

  void _iniciarEmisionGpsPeriodica() {
    _realGpsTimer?.cancel();
    // Paso 4.1: Timer cada 5 segundos enviando Geolocator.getCurrentPosition() -> POST /api/gps/viajes/{viaje_id}/posicion
    _realGpsTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || !_shareGps) return;
      final db = Provider.of<MockDatabase>(context, listen: false);
      try {
        await db.enviarPosicionRealConductor(widget.routeId);
      } catch (_) {}
    });
  }

  Future<void> _emitirUbicacionManual(
    MockDatabase db,
    List<Student> routeStudents, {
    LatLng? customPoint,
  }) async {
    try {
      double targetLat;
      double targetLng;

      if (customPoint != null) {
        targetLat = customPoint.latitude;
        targetLng = customPoint.longitude;
      } else if (routeStudents.isNotEmpty) {
        final studentTarget = routeStudents[_manualStepIndex % routeStudents.length];
        _manualStepIndex++;
        targetLat = studentTarget.stopLatitude;
        targetLng = studentTarget.stopLongitude;
      } else {
        final rIdx = db.routes.indexWhere((r) => r.id == widget.routeId);
        final pts = rIdx != -1 ? db.routes[rIdx].pathPoints : <LatLng>[];
        if (pts.isNotEmpty) {
          final pt = pts[_manualStepIndex % pts.length];
          _manualStepIndex++;
          targetLat = pt.latitude;
          targetLng = pt.longitude;
        } else {
          targetLat = -0.17612;
          targetLng = -78.48541;
        }
      }

      final data = await db.enviarPosicionRealConductor(
        widget.routeId,
        latOverride: targetLat,
        lngOverride: targetLng,
      );

      _mapController.move(LatLng(targetLat, targetLng), _mapController.camera.zoom);

      if (mounted) {
        final alertasList = data['alertas_disparadas'];
        final int alertasCount = alertasList is List
            ? alertasList.length
            : ((data['alertas_geocerca_generadas'] as num?)?.toInt() ?? 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'GPS enviado (${targetLat.toStringAsFixed(5)}, ${targetLng.toStringAsFixed(5)}) • Geocercas activadas: $alertasCount',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al emitir GPS: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _toggleOptimizedRoute(MockDatabase db) async {
    if (_showOptimizedRoute) {
      setState(() => _showOptimizedRoute = false);
      return;
    }

    setState(() => _isOptimizing = true);
    try {
      final result = await db.optimizarRutaBackend(widget.routeId);
      if (mounted) {
        setState(() {
          _backendOptimizedPoints = result['polilinea'] as List<LatLng>?;
          _paradasOptimizadas = result['paradas'] as List<dynamic>?;
          _distanciaTotalKm = (result['distancia_total_km'] as num?)?.toDouble();
          _tiempoTotalMin = (result['tiempo_total_estimado_min'] as num?)?.toDouble();
          _showOptimizedRoute = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _showOptimizedRoute = true);
      }
    } finally {
      if (mounted) {
        setState(() => _isOptimizing = false);
      }
    }
  }

  @override
  void dispose() {
    _realGpsTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<MockDatabase>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Find the route
    final routeIndex = db.routes.indexWhere((r) => r.id == widget.routeId);
    if (routeIndex == -1) {
      return const Scaffold(body: Center(child: Text('Ruta no encontrada')));
    }
    
    final route = db.routes[routeIndex];
    final routeStudents = db.students.where((s) => route.studentIds.contains(s.id)).toList();
    final busPosition = LatLng(route.currentLatitude, route.currentLongitude);

    // If map is active and followBus is true, move camera to bus
    if (_followBus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(busPosition, _mapController.camera.zoom);
      });
    }

    // Path calculation: standard vs OR-Tools optimized order from backend
    final standardPoints = route.pathPoints;
    final List<LatLng> optimizedPoints =
        (_backendOptimizedPoints != null && _backendOptimizedPoints!.isNotEmpty)
            ? _backendOptimizedPoints!
            : standardPoints;

    // Prepare markers
    List<Marker> markers = [];

    // 1. Bus Marker (Only show if sharing GPS is active)
    if (_shareGps) {
      markers.add(
        Marker(
          point: busPosition,
          width: 50,
          height: 50,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: const Icon(
              Icons.directions_bus_filled,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      );
    }

    // 2. School Marker (last point in path)
    if (route.pathPoints.isNotEmpty) {
      markers.add(
        Marker(
          point: route.pathPoints.last,
          width: 45,
          height: 45,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      );
    }

    // 3. Student Stop Markers (numerados 1, 2, 3... cuando se optimiza con OR-Tools)
    if (_showOptimizedRoute && _paradasOptimizadas != null && _paradasOptimizadas!.isNotEmpty) {
      for (int idx = 0; idx < _paradasOptimizadas!.length; idx++) {
        final p = _paradasOptimizadas![idx];
        if (p is! Map<String, dynamic>) continue;
        final coord = Student.parseCoordinate(p['geom']) ?? Student.parseCoordinate(p);
        if (coord == null) continue;
        final orden = (p['orden'] as num?)?.toInt() ?? (idx + 1);
        markers.add(
          Marker(
            point: LatLng(coord['lat']!, coord['lng']!),
            width: 42,
            height: 42,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: Text(
                '$orden',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        );
      }
    } else {
      for (int idx = 0; idx < routeStudents.length; idx++) {
        final student = routeStudents[idx];
        Color statusColor;
        IconData statusIcon;

        switch (student.status) {
          case StudentStatus.atHome:
            statusColor = AppColors.accent;
            statusIcon = Icons.home_outlined;
            break;
          case StudentStatus.inRoute:
            statusColor = AppColors.warning;
            statusIcon = Icons.directions_bus_outlined;
            break;
          case StudentStatus.atSchool:
            statusColor = AppColors.success;
            statusIcon = Icons.check_circle_outline;
            break;
          case StudentStatus.absent:
            statusColor = AppColors.danger;
            statusIcon = Icons.cancel_outlined;
            break;
        }

        markers.add(
          Marker(
            point: LatLng(student.stopLatitude, student.stopLongitude),
            width: 42,
            height: 42,
            child: GestureDetector(
              onTap: () => _showStudentDialog(context, student, db),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: _showOptimizedRoute
                    ? Text(
                        '${idx + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      )
                    : Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 18,
                      ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(route.name),
        actions: [
          IconButton(
            icon: Icon(
              _followBus ? Icons.gps_fixed : Icons.gps_not_fixed,
              color: _followBus ? AppColors.primary : Colors.grey,
            ),
            tooltip: 'Centrar en Autobús',
            onPressed: () => setState(() => _followBus = !_followBus),
          ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
            tooltip: 'Botón SOS de Alerta',
            onPressed: () => _showSOSDialog(context, db, route.id),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Flutter Map Integration (Paso 3.1 y 3.3)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: busPosition,
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  setState(() => _followBus = false);
                }
              },
              onTap: (tapPos, point) {
                if (_shareGps) {
                  _emitirUbicacionManual(db, routeStudents, customPoint: point);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tesis.transporte_escolar',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _showOptimizedRoute ? optimizedPoints : standardPoints,
                    strokeWidth: 5.5,
                    color: _showOptimizedRoute ? Colors.blueAccent : AppColors.primary.withOpacity(0.7),
                  ),
                ],
              ),
              MarkerLayer(
                markers: markers,
              ),
            ],
          ),

          // Floating GPS Control and OR-Tools Path Optimization Panel
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 6,
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.share_location_rounded,
                                color: _shareGps ? AppColors.success : Colors.grey,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Monitoreo GPS (Cada 5 seg)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _shareGps
                                          ? 'Posición: ${route.currentLatitude.toStringAsFixed(5)}, ${route.currentLongitude.toStringAsFixed(5)} (Toca el mapa o Emitir)'
                                          : 'Transmisión GPS pausada.',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _shareGps ? AppColors.success : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _emitirUbicacionManual(db, routeStudents),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(95, 32),
                          ),
                          icon: const Icon(Icons.send_rounded, size: 15, color: AppColors.accent),
                          label: const Text(
                            'Emitir GPS',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ),
                        Switch(
                          value: _shareGps,
                          activeColor: AppColors.success,
                          onChanged: (val) {
                            setState(() {
                              _shareGps = val;
                            });
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.explore_outlined,
                                color: _showOptimizedRoute ? AppColors.info : AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Optimizar Ruta Hoy (OR-Tools)',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _showOptimizedRoute
                                          ? (_distanciaTotalKm != null
                                              ? 'OR-Tools: ${_distanciaTotalKm!.toStringAsFixed(1)} km (~${_tiempoTotalMin?.toStringAsFixed(0) ?? '-'} min)'
                                              : 'Polilínea optimizada activa')
                                          : 'Trazado estándar de paradas',
                                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isOptimizing ? null : () => _toggleOptimizedRoute(db),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showOptimizedRoute ? AppColors.info : AppColors.primary,
                            foregroundColor: _showOptimizedRoute ? Colors.white : AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: const Size(110, 32),
                          ),
                          icon: _isOptimizing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                                )
                              : Icon(
                                  _showOptimizedRoute ? Icons.check_circle : Icons.auto_fix_high,
                                  size: 15,
                                  color: _showOptimizedRoute ? Colors.white : AppColors.accent,
                                ),
                          label: Text(
                            _showOptimizedRoute ? 'Optimizada' : 'Optimizar Ruta',
                            style: TextStyle(
                              fontSize: 11,
                              color: _showOptimizedRoute ? Colors.white : AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sliding Checklist or Bottom Controller Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomChecklistSheet(
              students: routeStudents,
              routeIsActive: route.isActive,
              db: db,
              onStopRoute: () async {
                final navigator = Navigator.of(context);
                await db.stopRoute(route.id);
                navigator.pop();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentDialog(BuildContext context, Student student, MockDatabase db) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(student.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Representante: ${student.tutorName}'),
              Text('Parada: ${student.stopName}'),
              const SizedBox(height: 16),
              const Text('Modificar Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: StudentStatus.values.map((status) {
                  String label = '';
                  Color color = Colors.grey;
                  switch (status) {
                    case StudentStatus.atHome:
                      label = 'En Casa';
                      color = AppColors.accent;
                      break;
                    case StudentStatus.inRoute:
                      label = 'Abordó';
                      color = AppColors.warning;
                      break;
                    case StudentStatus.atSchool:
                      label = 'En Colegio';
                      color = AppColors.success;
                      break;
                    case StudentStatus.absent:
                      label = 'Ausente';
                      color = AppColors.danger;
                      break;
                  }
                  return ActionChip(
                    label: Text(label),
                    backgroundColor: student.status == status ? color.withOpacity(0.2) : null,
                    side: BorderSide(color: student.status == status ? color : Colors.grey[300]!),
                    onPressed: () {
                      db.updateStudentStatus(student.id, status);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showSOSDialog(BuildContext context, MockDatabase db, String routeId) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.danger),
              SizedBox(width: 8),
              Text('🚨 ALERTA SOS 🚨'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Seleccione o describa la emergencia para notificar inmediatamente a la administración y a los padres:'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Falla Mecánica / Autobús Varado'),
                onTap: () {
                  db.triggerSOS(routeId, 'Falla Mecánica en el autobús.');
                  Navigator.pop(context);
                  _showSOSConfirmation(context);
                },
              ),
              ListTile(
                title: const Text('Tránsito Pesado / Retraso Mayor'),
                onTap: () {
                  db.triggerSOS(routeId, 'Retraso por congestión vehicular pesada.');
                  Navigator.pop(context);
                  _showSOSConfirmation(context);
                },
              ),
              ListTile(
                title: const Text('Problema de Salud'),
                onTap: () {
                  db.triggerSOS(routeId, 'Incidente de salud a bordo.');
                  Navigator.pop(context);
                  _showSOSConfirmation(context);
                },
              ),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Otro motivo (especificar)',
                  hintText: 'Ej. Accidente leve en la vía',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  db.triggerSOS(routeId, textController.text);
                  Navigator.pop(context);
                  _showSOSConfirmation(context);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Enviar SOS'),
            ),
          ],
        );
      },
    );
  }

  void _showSOSConfirmation(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Alerta SOS enviada con éxito.'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _BottomChecklistSheet extends StatefulWidget {
  final List<Student> students;
  final bool routeIsActive;
  final MockDatabase db;
  final VoidCallback onStopRoute;

  const _BottomChecklistSheet({
    required this.students,
    required this.routeIsActive,
    required this.db,
    required this.onStopRoute,
  });

  @override
  State<_BottomChecklistSheet> createState() => _BottomChecklistSheetState();
}

class _BottomChecklistSheetState extends State<_BottomChecklistSheet> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta! < -10 && !_isExpanded) {
          setState(() => _isExpanded = true);
        } else if (details.primaryDelta! > 10 && _isExpanded) {
          setState(() => _isExpanded = false);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: _isExpanded ? 360 : 120,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Sheet Title & Controller Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registro de Abordaje',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.primary : AppColors.textDark,
                        ),
                      ),
                      Text(
                        'Alumnos: ${widget.students.where((s) => s.status == StudentStatus.atSchool || s.status == StudentStatus.inRoute).length}/${widget.students.length}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  if (widget.routeIsActive)
                    ElevatedButton(
                      onPressed: widget.onStopRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size(140, 36),
                      ),
                      child: const Text('Finalizar Recorrido', style: TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                ],
              ),
            ),
            const Divider(),

            // Students Checklist (Paso 4.1: "Subió al Bus" -> RECOGIDO, "No Salió" -> NO_ASISTIO)
            if (_isExpanded)
              Expanded(
                child: ListView.builder(
                  itemCount: widget.students.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final student = widget.students[index];
                    IconData icon;
                    Color color;
                    String statusText;

                    switch (student.status) {
                      case StudentStatus.atHome:
                        icon = Icons.home_outlined;
                        color = AppColors.info;
                        statusText = 'En Espera';
                        break;
                      case StudentStatus.inRoute:
                        icon = Icons.directions_bus;
                        color = AppColors.warning;
                        statusText = 'RECOGIDO';
                        break;
                      case StudentStatus.atSchool:
                        icon = Icons.school;
                        color = AppColors.success;
                        statusText = 'Entregado';
                        break;
                      case StudentStatus.absent:
                        icon = Icons.cancel;
                        color = AppColors.danger;
                        statusText = 'NO_ASISTIO';
                        break;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: color.withOpacity(0.1),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(student.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('${student.stopName} • $statusText', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                widget.db.updateStudentStatus(student.id, StudentStatus.inRoute);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(82, 30),
                              ),
                              child: const Text('Subió al Bus', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton(
                              onPressed: () {
                                widget.db.updateStudentStatus(student.id, StudentStatus.absent);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: const Size(68, 30),
                              ),
                              child: const Text('No Salió', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Deslice hacia arriba para ver el listado de alumnos',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
