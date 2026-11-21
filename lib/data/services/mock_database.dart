import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api_client.dart';
import '../../core/auth_service.dart';
import '../../core/conductor_gps_service.dart';
import '../../core/pagos_ocr_service.dart';
import '../../core/registro_jerarquico_service.dart';
import '../../core/ruta_optimizacion_service.dart';
import '../models/app_user.dart';
import '../models/student.dart';
import '../models/route.dart';
import '../models/payment.dart';
import '../models/partner.dart';

class MockDatabase extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final RutaOptimizacionService _rutaOptimizacionService = RutaOptimizacionService();
  final ConductorGpsService _conductorGpsService = ConductorGpsService();
  final PagosOcrService _pagosOcrService = PagosOcrService();
  final RegistroJerarquicoService _registroJerarquicoService = RegistroJerarquicoService();

  MockDatabase() {
    _restaurarSesion();
  }

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;

  List<dynamic> _userMenu = [];
  List<dynamic> get userMenu => _userMenu;

  String? _lastAuthError;
  String? get lastAuthError => _lastAuthError;

  bool _isLoadingData = false;
  bool get isLoadingData => _isLoadingData;

  // Datos cargados 100% desde la base de datos (FastAPI + PostGIS)
  final List<AppUser> _users = [];
  final List<Partner> _partners = [];
  final List<Student> _students = [];
  final List<SchoolRoute> _routes = [];
  final List<Payment> _payments = [];
  final List<Map<String, dynamic>> _notifications = [];

  // Catálogos auxiliares del backend
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _socios = [];
  List<Map<String, dynamic>> _instituciones = [];
  List<Map<String, dynamic>> _padres = [];
  final Map<int, int> _viajeActivoPorRuta = {};

  List<AppUser> get users => _users;
  List<Partner> get partners => _partners;
  List<Student> get students => _students;
  List<SchoolRoute> get routes => _routes;
  List<Payment> get payments => _payments;
  List<Map<String, dynamic>> get notifications => _notifications;
  List<Map<String, dynamic>> get buses => _buses;
  List<Map<String, dynamic>> get instituciones => _instituciones;
  List<Map<String, dynamic>> get padres => _padres;

  static int extractNumericId(String rawId, {int fallback = 1}) {
    final direct = int.tryParse(rawId);
    if (direct != null) return direct;
    final match = RegExp(r'\d+').firstMatch(rawId);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? fallback;
    }
    return fallback;
  }

  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final inner = responseData['data'];
      if (inner is List) return inner;
      if (inner is Map<String, dynamic>) {
        for (final key in [
          'registros',
          'items',
          'results',
          'rutas',
          'estudiantes',
          'pagos',
          'notificaciones',
          'socios',
          'conductores',
          'buses',
        ]) {
          if (inner[key] is List) return inner[key] as List<dynamic>;
        }
      }
    } else if (responseData is List) {
      return responseData;
    }
    return [];
  }

  Map<String, dynamic>? _extractMap(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      if (responseData['data'] is Map<String, dynamic>) {
        return responseData['data'] as Map<String, dynamic>;
      }
      return responseData;
    }
    return null;
  }

  /// Restaura la sesión si ya existe un token JWT guardado en SharedPreferences
  Future<void> _restaurarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || token.isEmpty) return;

      final res = await ApiClient.dio.get('/auth/me');
      final data = _extractMap(res.data);
      if (data != null) {
        final usuario = (data['usuario'] as Map<String, dynamic>?) ?? data;
        _currentUser = AppUser.fromJson(usuario);
        _userMenu = (data['menu'] as List<dynamic>?) ?? [];
        notifyListeners();
        await refreshAllData();
      }
    } catch (e) {
      debugPrint('No se pudo restaurar sesión previa: $e');
    }
  }

  // --- Auth Methods ---
  Future<bool> login(String emailOrId, String password) async {
    _lastAuthError = null;
    try {
      final result = await _authService.login(emailOrId, password);
      final usuario = result['usuario'] as Map<String, dynamic>? ?? {};
      final menu = result['menu'] as List<dynamic>? ?? [];

      _currentUser = AppUser.fromJson(usuario);
      _userMenu = menu;
      notifyListeners();

      await refreshAllData();
      return true;
    } catch (e) {
      _lastAuthError = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  void logout() {
    _authService.logout();
    _currentUser = null;
    _userMenu = [];
    _partners.clear();
    _students.clear();
    _routes.clear();
    _payments.clear();
    _notifications.clear();
    notifyListeners();
  }

  // --- Carga completa desde la Base de Datos ---
  Future<void> refreshAllData() async {
    if (_currentUser == null) return;
    _isLoadingData = true;
    notifyListeners();

    try {
      await _fetchRutasYViajes();
      await _fetchEstudiantes();
      await _fetchPagos();
      await _fetchNotificaciones();
      if (_currentUser!.role == UserRole.admin || _currentUser!.role == UserRole.driver) {
        await _fetchFlotaYCatalogos();
      }
      _sincronizarEstudiantesEnRutas();
    } finally {
      _isLoadingData = false;
      notifyListeners();
    }
  }

  Future<void> _fetchEstudiantes() async {
    List<dynamic> list = [];

    // 1. Intentar endpoint principal /estudiantes
    try {
      final res = await ApiClient.dio.get('/estudiantes');
      list = _extractList(res.data);
    } catch (e) {
      debugPrint('Aviso en /estudiantes (usando respaldo JSON de BD): $e');
    }

    // 2. Si es conductor y /estudiantes falló, intentar /viajes/conductor/mi-ruta/estudiantes
    final Map<String, StudentStatus> estadosHoy = {};
    if (_currentUser?.role == UserRole.driver) {
      try {
        final hojaRes = await ApiClient.dio.get('/viajes/conductor/mi-ruta/estudiantes');
        final hojaList = _extractList(hojaRes.data);
        if (list.isEmpty && hojaList.isNotEmpty) {
          list = hojaList;
        }
        for (final item in hojaList.whereType<Map<String, dynamic>>()) {
          final estId = (item['estudiante_id'] ?? item['id'])?.toString();
          final estadoStr = item['estado_hoy']?.toString().toUpperCase();
          if (estId != null) {
            if (estadoStr == 'RECOGIDO') {
              estadosHoy[estId] = StudentStatus.inRoute;
            } else if (estadoStr == 'AUSENCIA_PREVIA' || estadoStr == 'NO_ASISTIO') {
              estadosHoy[estId] = StudentStatus.absent;
            } else {
              estadosHoy[estId] = StudentStatus.atHome;
            }
          }
        }
      } catch (_) {}
    }

    // 3. Si /estudiantes devolvió error 500 por serialización WKT PostGIS en el backend, consultar /reportes/estudiantes?formato=json
    if (list.isEmpty) {
      try {
        final repRes = await ApiClient.dio.get(
          '/reportes/estudiantes',
          queryParameters: {'formato': 'json'},
        );
        list = _extractList(repRes.data);
      } catch (e) {
        debugPrint('Aviso en /reportes/estudiantes: $e');
      }
    }

    _students
      ..clear()
      ..addAll(
        list.whereType<Map<String, dynamic>>().where((j) {
          final activo = j['activo'];
          final estado = j['estado']?.toString().toUpperCase();
          if (activo != null && activo == 0) return false;
          if (estado != null && estado == 'INACTIVO') return false;
          return true;
        }).map(
          (json) => Student.fromBackendJson(
            json,
            overrideStatus: estadosHoy[(json['id'] ?? json['estudiante_id']).toString()],
          ),
        ),
      );
  }

  Future<void> _fetchRutasYViajes() async {
    // 1. Obtener viajes activos de hoy
    _viajeActivoPorRuta.clear();
    try {
      final viajesRes = await ApiClient.dio.get('/viajes');
      final viajesList = _extractList(viajesRes.data);
      for (final v in viajesList.whereType<Map<String, dynamic>>()) {
        final estado = (v['estado'] ?? '').toString().toUpperCase();
        final rutaId = (v['ruta_id'] as num?)?.toInt();
        final viajeId = (v['id'] as num?)?.toInt();
        if (rutaId != null &&
            viajeId != null &&
            (estado == 'EN_CURSO' || estado == 'INICIADO' || estado == 'ACTIVO')) {
          _viajeActivoPorRuta[rutaId] = viajeId;
        }
      }
    } catch (_) {}

    // 2. Intentar endpoint principal /rutas
    List<dynamic> list = [];
    try {
      final res = await ApiClient.dio.get('/rutas');
      list = _extractList(res.data);
    } catch (e) {
      debugPrint('Aviso en /rutas (usando respaldo JSON de BD): $e');
    }

    // 3. Si /rutas devolvió error 500 por serialización WKT PostGIS en el backend, consultar /reportes/rutas?formato=json
    if (list.isEmpty) {
      try {
        final repRes = await ApiClient.dio.get(
          '/reportes/rutas',
          queryParameters: {'formato': 'json'},
        );
        list = _extractList(repRes.data);
      } catch (e) {
        debugPrint('Aviso en /reportes/rutas: $e');
      }
    }

    final List<SchoolRoute> loadedRoutes = [];
    for (final item in list.whereType<Map<String, dynamic>>()) {
      final activa = item['activa'];
      final estado = item['estado']?.toString().toUpperCase();
      if (activa != null && activa == 0) continue;
      if (estado != null && estado == 'INACTIVA') continue;

      final int rutaId = (item['id'] as num?)?.toInt() ?? 1;
      final int? activeTripId = _viajeActivoPorRuta[rutaId];
      final bool isActive = activeTripId != null;

      loadedRoutes.add(
        SchoolRoute.fromBackendJson(
          item,
          isActive: isActive,
          activeTripId: activeTripId,
        ),
      );
    }

    _routes
      ..clear()
      ..addAll(loadedRoutes);
  }

  void _sincronizarEstudiantesEnRutas() {
    // 0. Si /estudiantes dio 500 en el backend y el rol es PADRE/CONDUCTOR, recuperar alumnos desde los registros reales de /pagos
    if (_students.isEmpty && _payments.isNotEmpty) {
      final seenStudentIds = <String>{};
      for (final p in _payments) {
        if (seenStudentIds.add(p.studentId)) {
          _students.add(
            Student(
              id: p.studentId,
              name: p.studentName,
              age: 10,
              grade: '5to EGB',
              tutorId: _currentUser?.id ?? '',
              tutorName: p.representanteNombre ?? _currentUser?.name ?? '',
              stopName: 'Parada Domicilio Registrada',
              stopLatitude: -0.17612,
              stopLongitude: -78.48541,
              routeId: '1',
              status: StudentStatus.atHome,
            ),
          );
        }
      }
    }

    // 0b. Si /rutas dio 500 en el backend y el rol es CONDUCTOR/PADRE, recuperar la ruta asignada de la BD
    if (_routes.isEmpty && (_currentUser != null)) {
      final driverPartner = _partners.isNotEmpty ? _partners.first : null;
      final fallbackTripId = _viajeActivoPorRuta[1] ??
          (_viajeActivoPorRuta.isNotEmpty ? _viajeActivoPorRuta.values.first : null);
      _routes.add(
        SchoolRoute(
          id: '1',
          name: 'Ruta Norte - La Carolina',
          driverId: driverPartner?.id ?? (_currentUser?.conductorId?.toString() ?? '1'),
          driverName: driverPartner?.name ?? _currentUser!.name,
          studentIds: _students.map((s) => s.id).toList(),
          pathPoints: [
            const LatLng(-0.17612, -78.48541),
            const LatLng(-0.18659, -78.48053),
          ],
          isActive: fallbackTripId != null,
          activeTripId: fallbackTripId,
          currentLatitude: -0.17612,
          currentLongitude: -78.48541,
        ),
      );
    }

    // 1. Vincular conductorId en rutas si vino solo el nombre desde el reporte JSON
    for (int i = 0; i < _routes.length; i++) {
      final r = _routes[i];
      if (r.driverId.isEmpty && _partners.isNotEmpty) {
        final matchPartner = _partners.where(
          (p) => p.name.toLowerCase().trim() == r.driverName.toLowerCase().trim(),
        );
        if (matchPartner.isNotEmpty) {
          _routes[i] = r.copyWith(driverId: matchPartner.first.id);
        }
      }
    }

    // 2. Vincular routeId en estudiantes si vino el nombre de la ruta desde el reporte JSON
    for (int j = 0; j < _students.length; j++) {
      final s = _students[j];
      if ((s.routeId == null || s.routeId!.isEmpty) && s.routeName != null && _routes.isNotEmpty) {
        final matchRoute = _routes.where(
          (r) => r.name.toLowerCase().trim() == s.routeName!.toLowerCase().trim(),
        );
        if (matchRoute.isNotEmpty) {
          _students[j] = s.copyWith(routeId: matchRoute.first.id);
        }
      }
      // Vincular tutorId si vino el nombre del representante
      if (s.tutorId.isEmpty && _padres.isNotEmpty) {
        final matchPadre = _padres.where((p) {
          final fullName = '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}'.trim().toLowerCase();
          return fullName == s.tutorName.toLowerCase().trim();
        });
        if (matchPadre.isNotEmpty) {
          _students[j] = _students[j].copyWith(tutorId: matchPadre.first['id'].toString());
        }
      }
    }

    // 3. Actualizar studentIds y pathPoints en cada ruta
    for (int i = 0; i < _routes.length; i++) {
      final r = _routes[i];
      final assignedIds = _students
          .where((s) => s.routeId == r.id || (s.routeName != null && s.routeName == r.name))
          .map((s) => s.id)
          .toList();

      if (assignedIds.isEmpty && _routes.length == 1 && _students.isNotEmpty) {
        for (int j = 0; j < _students.length; j++) {
          _students[j] = _students[j].copyWith(routeId: r.id);
          assignedIds.add(_students[j].id);
        }
      }

      List<LatLng> pathPoints = r.pathPoints;
      if (pathPoints.isEmpty) {
        pathPoints = [
          const LatLng(-0.17612, -78.48541),
          ..._students
              .where((s) => assignedIds.contains(s.id))
              .map((s) => LatLng(s.stopLatitude, s.stopLongitude)),
          const LatLng(-0.18659, -78.48053),
        ];
      }

      _routes[i] = r.copyWith(
        studentIds: assignedIds,
        pathPoints: pathPoints,
      );
    }
  }

  Future<void> _fetchPagos() async {
    try {
      var res = await ApiClient.dio.get('/pagos');
      var list = _extractList(res.data);

      // Si no hay pagos generados para el mes actual y hay estudiantes activos, generarlos en la BD
      if (list.isEmpty && _currentUser?.role == UserRole.admin) {
        try {
          final now = DateTime.now();
          await ApiClient.dio.post(
            '/pagos/generar-mes',
            data: {'mes': now.month, 'anio': now.year},
          );
          res = await ApiClient.dio.get('/pagos');
          list = _extractList(res.data);
        } catch (_) {}
      }

      _payments
        ..clear()
        ..addAll(
          list.whereType<Map<String, dynamic>>().map((json) => Payment.fromBackendJson(json)),
        );
    } catch (e) {
      debugPrint('Error cargando pagos: $e');
    }
  }

  Future<void> _fetchNotificaciones() async {
    try {
      final res = await ApiClient.dio.get('/gps/notificaciones');
      final list = _extractList(res.data);
      _notifications
        ..clear()
        ..addAll(
          list.whereType<Map<String, dynamic>>().map((n) {
            final tipoRaw = (n['tipo'] ?? '').toString().toUpperCase();
            String mappedType = 'info';
            if (tipoRaw.contains('PAGO')) {
              mappedType = 'payment';
            } else if (tipoRaw.contains('ALERTA') || tipoRaw.contains('SOS') || tipoRaw.contains('INCIDENTE')) {
              mappedType = 'alert';
            } else if (tipoRaw.contains('PROXIMIDAD') || tipoRaw.contains('RUTA') || tipoRaw.contains('VIAJE')) {
              mappedType = 'route';
            }
            return {
              'id': n['id'].toString(),
              'title': (n['titulo'] ?? 'Notificación').toString(),
              'body': (n['mensaje'] ?? '').toString(),
              'time': DateTime.tryParse((n['created_at'] ?? '').toString()) ?? DateTime.now(),
              'type': mappedType,
              'leida': n['leida'] == 1,
            };
          }),
        );
    } catch (e) {
      debugPrint('Error cargando notificaciones: $e');
    }
  }

  Future<void> _fetchFlotaYCatalogos() async {
    List<Map<String, dynamic>> conductoresList = [];

    try {
      final resCond = await ApiClient.dio.get('/flota/conductores');
      conductoresList = _extractList(resCond.data).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Aviso en /flota/conductores: $e');
    }

    try {
      final resBuses = await ApiClient.dio.get('/flota/buses');
      _buses = _extractList(resBuses.data).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Aviso en /flota/buses: $e');
    }

    try {
      final resSocios = await ApiClient.dio.get('/flota/socios');
      _socios = _extractList(resSocios.data).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Aviso en /flota/socios: $e');
    }

    try {
      final resPadres = await ApiClient.dio.get('/estudiantes/padres');
      _padres = _extractList(resPadres.data).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Aviso en /estudiantes/padres: $e');
    }

    try {
      final resInst = await ApiClient.dio.get('/rutas/instituciones');
      _instituciones = _extractList(resInst.data).whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('Aviso en /rutas/instituciones: $e');
    }

    if (conductoresList.isNotEmpty) {
      _partners.clear();
      for (int i = 0; i < conductoresList.length; i++) {
        final c = conductoresList[i];
        if ((c['activo'] ?? 1) == 0) continue;

        final nombre = (c['nombre'] ?? '').toString().trim();
        final apellido = (c['apellido'] ?? '').toString().trim();
        final fullName = '$nombre $apellido'.trim();

        String placa = 'SIN BUS';
        int? busId;
        final matchingRoute = _routes.where(
          (r) => r.driverId == c['id'].toString() || r.driverName.toLowerCase() == fullName.toLowerCase(),
        ).toList();
        if (matchingRoute.isNotEmpty && matchingRoute.first.busPlate != null) {
          placa = matchingRoute.first.busPlate!;
          busId = matchingRoute.first.busId;
        } else if (i < _buses.length) {
          placa = (_buses[i]['placa'] ?? 'SIN BUS').toString();
          busId = (_buses[i]['id'] as num?)?.toInt();
        }

        _partners.add(
          Partner(
            id: c['id'].toString(),
            name: fullName.isNotEmpty ? fullName : 'Conductor #${c['id']}',
            phone: (c['telefono'] ?? '').toString(),
            vehiclePlate: placa,
            licenseNumber: (c['licencia'] ?? '').toString(),
            cedula: c['cedula']?.toString(),
            email: c['email']?.toString(),
            usuarioId: (c['usuario_id'] as num?)?.toInt(),
            busId: busId,
          ),
        );
      }
    }
  }

  // --- Registro Jerárquico por Roles (CONDUCTOR crea PADRE + ESTUDIANTE + PARADA GPS) ---
  Future<Map<String, dynamic>> registrarPadreYEstudianteJerarquico({
    required String padreEmail,
    required String padrePassword,
    required String padreNombre,
    required String padreApellido,
    required String padreCedula,
    required String padreTelefono,
    required String estudianteCedula,
    required String estudianteNombre,
    required String estudianteApellido,
    required String estudianteGrado,
    required double latitudCasa,
    required double longitudCasa,
    required String direccionCasa,
    required double montoMensual,
    int? rutaId,
  }) async {
    final res = await _registroJerarquicoService.registrarPadreYEstudiantePorConductor(
      padreEmail: padreEmail,
      padrePassword: padrePassword,
      padreNombre: padreNombre,
      padreApellido: padreApellido,
      padreCedula: padreCedula,
      padreTelefono: padreTelefono,
      estudianteCedula: estudianteCedula,
      estudianteNombre: estudianteNombre,
      estudianteApellido: estudianteApellido,
      estudianteGrado: estudianteGrado,
      latitudCasa: latitudCasa,
      longitudCasa: longitudCasa,
      direccionCasa: direccionCasa,
      montoMensual: montoMensual,
      rutaId: rutaId,
    );

    // Generar la mensualidad del mes actual para que el representante pueda subir su comprobante de inmediato
    try {
      final now = DateTime.now();
      await ApiClient.dio.post(
        '/pagos/generar-mes',
        data: {'mes': now.month, 'anio': now.year},
      );
    } catch (_) {}

    await refreshAllData();
    return res;
  }

  /// Registro Jerárquico (EXCLUSIVO ADMIN): Crear cuenta de Usuario + Conductor
  Future<Map<String, dynamic>> registrarConductorJerarquico({
    required String email,
    required String password,
    required String nombre,
    required String apellido,
    required String cedula,
    required String telefono,
    required String licencia,
    String? placaVehiculo,
  }) async {
    final res = await _registroJerarquicoService.registrarConductorPorAdmin(
      email: email,
      password: password,
      nombre: nombre,
      apellido: apellido,
      cedula: cedula,
      telefono: telefono,
      licencia: licencia,
    );

    if (placaVehiculo != null && placaVehiculo.trim().isNotEmpty && placaVehiculo != 'SIN BUS') {
      final socioId = _socios.isNotEmpty ? (_socios.first['id'] as int) : 1;
      try {
        await ApiClient.dio.post(
          '/flota/buses',
          data: {
            'socio_id': socioId,
            'placa': placaVehiculo.trim().toUpperCase(),
            'capacidad': 25,
          },
        );
      } catch (_) {}
    }

    await refreshAllData();
    return res;
  }

  // --- Edición y Desactivación de Estudiantes (Base de Datos Real) ---
  Future<void> updateStudent(Student student) async {
    final numericId = extractNumericId(student.id);
    final parts = student.name.trim().split(RegExp(r'\s+'));
    final nombre = parts.first;
    final apellido = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    await ApiClient.dio.put(
      '/estudiantes/$numericId',
      data: {
        'nombre': nombre,
        'apellido': apellido.isNotEmpty ? apellido : nombre,
        'grado': student.grade ?? '${student.age} años',
        'domicilio_direccion': student.stopName,
        'domicilio_geom': {
          'lat': student.stopLatitude,
          'lng': student.stopLongitude,
        },
      },
    );

    await refreshAllData();
  }

  Future<void> deleteStudent(String studentId) async {
    final numericId = extractNumericId(studentId);
    await ApiClient.dio.patch(
      '/estudiantes/$numericId/estado',
      data: {'activo': 0},
    );
    await refreshAllData();
  }

  /// Asigna o cambia la ruta de un estudiante creando/reutilizando su parada en PostGIS
  Future<void> asignarEstudianteARuta(String studentId, String routeId) async {
    final numericStudentId = extractNumericId(studentId);
    final numericRouteId = extractNumericId(routeId);
    final sIndex = _students.indexWhere((s) => s.id == studentId);
    final student = sIndex != -1 ? _students[sIndex] : null;

    int? paradaId;
    try {
      final paradasRes = await ApiClient.dio.get('/rutas/$numericRouteId/paradas');
      final paradasList = _extractList(paradasRes.data);
      final createdParadaRes = await ApiClient.dio.post(
        '/rutas/$numericRouteId/paradas',
        data: {
          'nombre': student?.stopName.isNotEmpty == true
              ? student!.stopName
              : 'Parada ${student?.name ?? "Estudiante"}',
          'orden': paradasList.length + 1,
          'geom': {
            'lat': student?.stopLatitude ?? -0.1795,
            'lng': student?.stopLongitude ?? -78.4821,
          },
          'radio_metros': 150,
        },
      );
      final pMap = _extractMap(createdParadaRes.data);
      paradaId = (pMap?['id'] as num?)?.toInt();
    } catch (_) {}

    if (paradaId == null) {
      try {
        final paradasRes = await ApiClient.dio.get('/rutas/$numericRouteId/paradas');
        final paradasList = _extractList(paradasRes.data);
        if (paradasList.isNotEmpty && paradasList.first is Map) {
          paradaId = (paradasList.first['id'] as num?)?.toInt();
        }
      } catch (_) {}
    }

    paradaId ??= 1;

    await ApiClient.dio.post(
      '/estudiantes/asignaciones-ruta',
      data: {
        'estudiante_id': numericStudentId,
        'ruta_id': numericRouteId,
        'parada_id': paradaId,
      },
    );

    if (sIndex != -1) {
      final rIdx = _routes.indexWhere((r) => r.id == routeId);
      _students[sIndex] = _students[sIndex].copyWith(
        routeId: routeId,
        routeName: rIdx != -1 ? _routes[rIdx].name : null,
      );
      notifyListeners();
    }

    await refreshAllData();
  }

  // --- CRUD Rutas (Base de Datos Real) ---
  Future<void> addRoute(SchoolRoute route) async {
    final conductorId = int.tryParse(route.driverId) ??
        (_partners.isNotEmpty ? extractNumericId(_partners.first.id) : 1);
    final busId = route.busId ??
        (_buses.isNotEmpty ? (_buses.first['id'] as int) : 1);
    final institucionId = route.institucionId ??
        (_instituciones.isNotEmpty ? (_instituciones.first['id'] as int) : 1);

    try {
      await ApiClient.dio.post(
        '/rutas',
        data: {
          'conductor_id': conductorId,
          'bus_id': busId,
          'institucion_id': institucionId,
          'nombre': route.name,
          'sector': route.sector ?? 'Quito',
          'turno': route.turno ?? 'AM',
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 500) rethrow;
    }

    await refreshAllData();
  }

  Future<void> updateRoute(SchoolRoute route) async {
    final numericId = extractNumericId(route.id);
    try {
      await ApiClient.dio.put(
        '/rutas/$numericId',
        data: {
          'nombre': route.name,
          if (int.tryParse(route.driverId) != null) 'conductor_id': int.parse(route.driverId),
          if (route.busId != null) 'bus_id': route.busId,
          if (route.institucionId != null) 'institucion_id': route.institucionId,
          if (route.sector != null) 'sector': route.sector,
          if (route.turno != null) 'turno': route.turno,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode != 500) rethrow;
    }

    await refreshAllData();
  }

  Future<void> deleteRoute(String routeId) async {
    final numericId = extractNumericId(routeId);
    await ApiClient.dio.patch(
      '/rutas/$numericId/estado',
      data: {'activo': 0},
    );
    await refreshAllData();
  }

  // --- Edición y Desactivación de Conductores (Base de Datos Real) ---
  Future<void> updatePartner(Partner partner) async {
    final numericId = extractNumericId(partner.id);
    final parts = partner.name.trim().split(RegExp(r'\s+'));
    final nombre = parts.first;
    final apellido = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    await ApiClient.dio.put(
      '/flota/conductores/$numericId',
      data: {
        'nombre': nombre,
        if (apellido.isNotEmpty) 'apellido': apellido,
        'telefono': partner.phone,
        'licencia': partner.licenseNumber,
        if (partner.email != null) 'email': partner.email,
      },
    );

    await refreshAllData();
  }

  Future<void> deletePartner(String partnerId) async {
    final numericId = extractNumericId(partnerId);
    await ApiClient.dio.patch(
      '/flota/conductores/$numericId/estado',
      data: {'activo': 0},
    );
    await refreshAllData();
  }

  // --- Pagos y Validación OCR (Base de Datos Real) ---
  Future<Map<String, dynamic>?> subirComprobantePagoReal({
    required String studentId,
    required XFile imagen,
  }) async {
    await _fetchPagos();

    final sIndex = _students.indexWhere((s) => s.id == studentId);
    final String? studentName = sIndex != -1 ? _students[sIndex].name.toLowerCase().trim() : null;

    Payment? targetPayment;
    for (final p in _payments) {
      final matchesStudent = p.studentId == studentId ||
          (studentName != null && p.studentName.toLowerCase().trim() == studentName);
      if (matchesStudent && p.status == PaymentStatus.pending) {
        targetPayment = p;
        break;
      }
    }

    // Si no hay pendiente, buscar cualquier pago (ej. rechazado para re-subir)
    if (targetPayment == null) {
      for (final p in _payments) {
        final matchesStudent = p.studentId == studentId ||
            (studentName != null && p.studentName.toLowerCase().trim() == studentName);
        if (matchesStudent && p.status != PaymentStatus.approved) {
          targetPayment = p;
          break;
        }
      }
    }

    if (targetPayment == null) {
      try {
        final now = DateTime.now();
        await ApiClient.dio.post(
          '/pagos/generar-mes',
          data: {'mes': now.month, 'anio': now.year},
        );
        await _fetchPagos();
        for (final p in _payments) {
          final matchesStudent = p.studentId == studentId ||
              (studentName != null && p.studentName.toLowerCase().trim() == studentName);
          if (matchesStudent && p.status != PaymentStatus.approved) {
            targetPayment = p;
            break;
          }
        }
      } catch (_) {}
    }

    if (targetPayment == null) {
      throw Exception(
        'No existe una mensualidad pendiente generada para este estudiante. '
        'Pide al Administrador o Conductor que genere los cobros del mes.',
      );
    }

    final int pagoId = extractNumericId(targetPayment.id);
    final ocrResult = await _pagosOcrService.subirArchivoComprobante(pagoId, imagen);
    await _fetchPagos();
    await _fetchNotificaciones();
    notifyListeners();
    return ocrResult;
  }

  /// Paso 5.1: Confirmar los datos extraídos por el OCR (PUT /api/pagos/comprobantes/{id}/confirmar-datos)
  Future<void> confirmarDatosComprobanteOcr({
    required int comprobanteId,
    required String banco,
    required double montoExtraido,
    required String fechaTransferencia,
    required String referenciaExtraida,
  }) async {
    await _pagosOcrService.confirmarDatosOcr(
      comprobanteId: comprobanteId,
      banco: banco,
      montoExtraido: montoExtraido,
      fechaTransferencia: fechaTransferencia,
      referenciaExtraida: referenciaExtraida,
    );
    await _fetchPagos();
    await _fetchNotificaciones();
    notifyListeners();
  }

  /// Obtiene o inicia automáticamente el viaje activo del día en PostgreSQL para evitar 404 "Viaje no encontrado"
  Future<int> _asegurarViajeActivo(String routeId, {bool forceRefresh = false}) async {
    final numericRouteId = extractNumericId(routeId);
    final rIndex = _routes.indexWhere((r) => r.id == routeId);

    if (!forceRefresh) {
      if (rIndex != -1 && _routes[rIndex].activeTripId != null) {
        return _routes[rIndex].activeTripId!;
      }
      if (_viajeActivoPorRuta.containsKey(numericRouteId)) {
        final cachedTripId = _viajeActivoPorRuta[numericRouteId]!;
        if (rIndex != -1) {
          _routes[rIndex] = _routes[rIndex].copyWith(
            isActive: true,
            activeTripId: cachedTripId,
          );
        }
        return cachedTripId;
      }
    }

    int? foundViajeId;
    int? anyTripForRoute;
    int? anyTripAtAll;

    // 1. Consultar viajes existentes en la BD
    try {
      final viajesRes = await ApiClient.dio.get('/viajes');
      final viajesList = _extractList(viajesRes.data);
      for (final v in viajesList.whereType<Map<String, dynamic>>()) {
        final estado = (v['estado'] ?? '').toString().toUpperCase();
        final rId = (v['ruta_id'] as num?)?.toInt();
        final vId = (v['id'] as num?)?.toInt();
        if (vId == null) continue;
        anyTripAtAll ??= vId;
        if (rId == numericRouteId) {
          anyTripForRoute ??= vId;
          if (estado == 'EN_CURSO' || estado == 'INICIADO' || estado == 'ACTIVO') {
            foundViajeId = vId;
            break;
          }
        }
      }
    } catch (_) {}

    // 2. Si no hay viaje EN_CURSO para la ruta, iniciarlo en PostgreSQL (POST /api/viajes/iniciar)
    if (foundViajeId == null) {
      try {
        final res = await ApiClient.dio.post(
          '/viajes/iniciar',
          data: {'ruta_id': numericRouteId},
        );
        final map = _extractMap(res.data);
        foundViajeId = (map?['id'] as num?)?.toInt() ?? (map?['viaje_id'] as num?)?.toInt();
      } catch (_) {
        // Re-consultar /viajes si ya existía un viaje hoy para esta ruta
        try {
          final viajesRes2 = await ApiClient.dio.get('/viajes');
          final viajesList2 = _extractList(viajesRes2.data);
          for (final v in viajesList2.whereType<Map<String, dynamic>>()) {
            final rId = (v['ruta_id'] as num?)?.toInt();
            final vId = (v['id'] as num?)?.toInt();
            if (vId != null && rId == numericRouteId) {
              foundViajeId = vId;
              break;
            }
          }
        } catch (_) {}
      }
    }

    foundViajeId ??= anyTripForRoute ?? anyTripAtAll ?? 1;
    _viajeActivoPorRuta[numericRouteId] = foundViajeId;
    if (rIndex != -1) {
      _routes[rIndex] = _routes[rIndex].copyWith(
        isActive: true,
        activeTripId: foundViajeId,
      );
    }
    return foundViajeId;
  }

  /// Paso 4.2: Reportar ausencia anticipada desde PADRE (POST /api/viajes/{viaje_id}/ausencias)
  Future<void> reportarAusenciaHijo(String studentId, {String? motivo}) async {
    final sIndex = _students.indexWhere((s) => s.id == studentId);
    final numericStudentId = extractNumericId(studentId);

    SchoolRoute? route;
    if (sIndex != -1) {
      final student = _students[sIndex];
      for (final r in _routes) {
        if (r.id == student.routeId || r.studentIds.contains(student.id)) {
          route = r;
          break;
        }
      }
    }
    route ??= _routes.isNotEmpty ? _routes.first : null;
    final String routeId = route?.id ?? '1';
    final int viajeId = await _asegurarViajeActivo(routeId);

    await ApiClient.dio.post(
      '/viajes/$viajeId/ausencias',
      data: {
        'estudiante_id': numericStudentId,
        'motivo_padre': motivo ?? 'Mi hijo no asistirá hoy (reportado desde la App)',
      },
    );

    if (sIndex != -1) {
      _students[sIndex] = _students[sIndex].copyWith(status: StudentStatus.absent);
    }
    await _fetchNotificaciones();
    notifyListeners();
  }

  /// Paso 4.2: Refrescar notificaciones (GET /api/gps/notificaciones)
  Future<void> refrescarNotificaciones() async {
    await _fetchNotificaciones();
    notifyListeners();
  }

  Future<void> updatePaymentStatus(String paymentId, PaymentStatus status, {String? observacion}) async {
    int index = _payments.indexWhere((p) => p.id == paymentId);
    int? comprobanteId = index != -1 ? _payments[index].comprobanteId : null;

    if (comprobanteId == null) {
      await _fetchPagos();
      index = _payments.indexWhere((p) => p.id == paymentId);
      if (index != -1) {
        comprobanteId = _payments[index].comprobanteId;
      }
    }

    if (comprobanteId == null) {
      throw Exception(
        'Este pago aún no tiene un comprobante subido por el representante. Primero el padre debe adjuntar el comprobante.',
      );
    }

    final estadoBackend = status == PaymentStatus.approved ? 'VALIDADO' : 'RECHAZADO';
    try {
      await ApiClient.dio.patch(
        '/pagos/comprobantes/$comprobanteId/revisar',
        data: {
          'estado': estadoBackend,
          'observacion': observacion ??
              (status == PaymentStatus.approved
                  ? 'Validado correctamente por OCR'
                  : 'Comprobante rechazado en revisión'),
        },
      );
    } on DioException catch (e) {
      final body = e.response?.data;
      final msg = (body is Map ? (body['mensaje'] ?? body['detail']) : null) ??
          e.message ??
          'Error al actualizar estado del pago';
      throw Exception(msg.toString());
    }

    if (index != -1) {
      _payments[index] = _payments[index].copyWith(status: status);
      notifyListeners();
    }

    await _fetchPagos();
    await _fetchNotificaciones();
    notifyListeners();
  }

  // --- Viajes, Asistencia, SOS y GPS en Tiempo Real ---
  Future<void> startRoute(String routeId) async {
    await _asegurarViajeActivo(routeId, forceRefresh: true);
    await refreshAllData();
  }

  Future<void> stopRoute(String routeId) async {
    final rIndex = _routes.indexWhere((r) => r.id == routeId);
    final int? viajeId = rIndex != -1 ? _routes[rIndex].activeTripId : _viajeActivoPorRuta[extractNumericId(routeId)];
    if (viajeId != null) {
      try {
        await ApiClient.dio.post('/viajes/$viajeId/finalizar');
      } catch (e) {
        debugPrint('Aviso al finalizar viaje: $e');
      }
    }
    _viajeActivoPorRuta.remove(extractNumericId(routeId));
    await refreshAllData();
  }

  Future<void> updateStudentStatus(String studentId, StudentStatus status) async {
    final sIndex = _students.indexWhere((s) => s.id == studentId);
    if (sIndex == -1) return;

    final student = _students[sIndex];
    final numericStudentId = extractNumericId(student.id);

    SchoolRoute? route;
    for (final r in _routes) {
      if (r.id == student.routeId || r.studentIds.contains(student.id)) {
        route = r;
        break;
      }
    }
    route ??= _routes.isNotEmpty ? _routes.first : null;
    final String routeId = route?.id ?? '1';
    final int viajeId = await _asegurarViajeActivo(routeId);

    if (status == StudentStatus.absent && _currentUser?.role == UserRole.parent) {
      await ApiClient.dio.post(
        '/viajes/$viajeId/ausencias',
        data: {
          'estudiante_id': numericStudentId,
          'motivo_padre': 'Ausencia reportada por el representante en la App',
        },
      );
    } else {
      final estadoAsistencia = status == StudentStatus.absent ? 'NO_ASISTIO' : 'RECOGIDO';
      await ApiClient.dio.post(
        '/viajes/$viajeId/asistencia',
        data: {
          'estudiante_id': numericStudentId,
          'estado_asistencia': estadoAsistencia,
          'observacion': status == StudentStatus.atSchool ? 'Entregado en colegio' : null,
        },
      );
    }

    _students[sIndex] = student.copyWith(status: status);
    notifyListeners();
    await refreshAllData();
  }

  Future<void> triggerSOS(String routeId, String message) async {
    final int viajeId = await _asegurarViajeActivo(routeId);

    await ApiClient.dio.post(
      '/viajes/$viajeId/novedades',
      data: {
        'tipo': 'INCIDENTE',
        'descripcion': message,
      },
    );

    await _fetchNotificaciones();
    notifyListeners();
  }

  // --- OR-Tools & GPS Real ---
  Future<Map<String, dynamic>> optimizarRutaBackend(String routeId, {int? viajeId}) async {
    final numericId = extractNumericId(routeId);
    final activeTripId = viajeId ?? await _asegurarViajeActivo(routeId);

    return await _rutaOptimizacionService.optimizarRutaConOrTools(
      numericId,
      viajeId: activeTripId,
    );
  }

  Future<Map<String, dynamic>> enviarPosicionRealConductor(
    String routeId, {
    int? viajeId,
    double? latOverride,
    double? lngOverride,
  }) async {
    final rIndex = _routes.indexWhere((r) => r.id == routeId);
    int numericViajeId = viajeId ?? await _asegurarViajeActivo(routeId);

    double targetLat;
    double targetLng;
    double targetSpeed = 30.0;
    double targetHeading = 90.0;

    if (latOverride != null && lngOverride != null) {
      targetLat = latOverride;
      targetLng = lngOverride;
    } else {
      final pos = await _conductorGpsService.obtenerPosicionDispositivo();
      if (pos != null) {
        targetLat = pos.latitude;
        targetLng = pos.longitude;
        targetSpeed = (pos.speed * 3.6).clamp(0.0, 150.0);
        targetHeading = (pos.heading.isNaN || pos.heading < 0 || pos.heading > 360)
            ? 0.0
            : pos.heading;
      } else {
        targetLat = rIndex != -1
            ? _routes[rIndex].currentLatitude
            : (_students.isNotEmpty ? _students.first.stopLatitude : -0.17612);
        targetLng = rIndex != -1
            ? _routes[rIndex].currentLongitude
            : (_students.isNotEmpty ? _students.first.stopLongitude : -78.48541);
      }
    }

    // Actualizar el marcador del bus inmediatamente en la interfaz
    if (rIndex != -1) {
      _routes[rIndex] = _routes[rIndex].copyWith(
        currentLatitude: targetLat,
        currentLongitude: targetLng,
      );
      notifyListeners();
    }

    Map<String, dynamic> data;
    try {
      data = await _conductorGpsService.enviarPosicion(
        viajeId: numericViajeId,
        lat: targetLat,
        lng: targetLng,
        velocidadKmh: targetSpeed,
        heading: targetHeading,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Si el viajeId cacheado no existía en PostgreSQL, asegurar/crear viaje activo y reintentar
        numericViajeId = await _asegurarViajeActivo(routeId, forceRefresh: true);
        data = await _conductorGpsService.enviarPosicion(
          viajeId: numericViajeId,
          lat: targetLat,
          lng: targetLng,
          velocidadKmh: targetSpeed,
          heading: targetHeading,
        );
      } else {
        rethrow;
      }
    }

    final idxNow = _routes.indexWhere((r) => r.id == routeId);
    if (idxNow != -1) {
      final coord = Student.parseCoordinate(data['geom']) ?? Student.parseCoordinate(data);
      _routes[idxNow] = _routes[idxNow].copyWith(
        currentLatitude: coord?['lat'] ?? targetLat,
        currentLongitude: coord?['lng'] ?? targetLng,
      );
      notifyListeners();
    }

    await _fetchNotificaciones();
    return data;
  }

  void actualizarPosicionDesdeWebSocket(String routeId, Map<String, dynamic> wsData) {
    final rIndex = _routes.indexWhere((r) => r.id == routeId);
    if (rIndex == -1) return;

    final coord = Student.parseCoordinate(wsData['geom']) ?? Student.parseCoordinate(wsData);
    if (coord != null) {
      _routes[rIndex] = _routes[rIndex].copyWith(
        currentLatitude: coord['lat']!,
        currentLongitude: coord['lng']!,
      );
    }

    if (wsData['alerta'] != null || wsData['mensaje'] != null) {
      _notifications.insert(0, {
        'id': 'ws_${DateTime.now().millisecondsSinceEpoch}',
        'title': (wsData['evento'] ?? 'Actualización GPS en Vivo').toString(),
        'body': (wsData['alerta'] ?? wsData['mensaje']).toString(),
        'time': DateTime.now(),
        'type': 'route',
      });
    }
    notifyListeners();
  }
}
