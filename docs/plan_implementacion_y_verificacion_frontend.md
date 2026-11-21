# Plan Paso a Paso: Cómo Implementar y Verificar Todo el Backend en tu Frontend (Flutter)

Esta guía te sirve como hoja de ruta y **checklist de verificación** para asegurarte de que tu aplicación en **Flutter** consuma el **100% de los módulos del Backend (`RF-01` a `RF-15`)**.

---

## 1. Orden Exacto para Implementarlo en Flutter (De Menor a Mayor Complejidad)

### Fase 1: Conexión Base y Login por Rol (`RF-01`, `RF-15`)
- [x] **Paso 1.1:** Copiar `ApiClient` de [guia_conexion_flutter.md](file:///c:/Users/jair/Videos/Tesis/guia_conexion_flutter.md#L48-L106) en `lib/core/api_client.dart`.
- [x] **Paso 1.2:** Configurar `baseUrl`:
  - `http://10.0.2.2:8000` si usas Emulador Android.
  - `http://127.0.0.1:8000` si corres Flutter en Windows/Web.
  - `http://TU_IP_WIFI:8000` si pruebas en tu celular físico.
- [x] **Paso 1.3:** Crear `LoginScreen` consumiendo `POST /api/auth/login`.
- [x] **Paso 1.4:** Leer `data['usuario']['roles']` y redirigir:
  - Si es `ADMIN` $\rightarrow$ `AdminHomeScreen`
  - Si es `CONDUCTOR` $\rightarrow$ `ConductorHomeScreen`
  - Si es `PADRE` $\rightarrow$ `PadreHomeScreen`

---

### Fase 2: Flujo de Registro Jerárquico (`RF-02`, `RF-04`)
- [x] **Paso 2.1 (En `ADMIN`):** Crear el formulario **"Registrar Conductor"** que llame a `POST /api/flota/conductores` ([guia_registro_jerarquico_frontend.md](file:///c:/Users/jair/Videos/Tesis/guia_registro_jerarquico_frontend.md#L56-L93)).
- [x] **Paso 2.2 (En `CONDUCTOR`):** Crear el formulario **"Registrar Padre y Estudiante"** que llame a `POST /api/estudiantes/registrar-padre-y-estudiante` ([guia_registro_jerarquico_frontend.md](file:///c:/Users/jair/Videos/Tesis/guia_registro_jerarquico_frontend.md#L97-L195)), capturando la ubicación GPS de la casa del estudiante con un pin en el mapa o con `Geolocator.getCurrentPosition()`.

---

### Fase 3: Mapa y Optimización de Rutas con Google OR-Tools (`RF-03`, `RF-08`)
- [x] **Paso 3.1 (En `CONDUCTOR` y `ADMIN`):** Agregar un widget `FlutterMap` (de `flutter_map`).
- [x] **Paso 3.2:** Poner un botón **"Optimizar Ruta Hoy (OR-Tools)"** que llame a `POST /api/rutas/{ruta_id}/optimizar`.
- [x] **Paso 3.3:** Dibujar los puntos de `data['polilinea_coordenadas']` en un `PolylineLayer` azul y las paradas de `data['paradas_activas_optimizadas']` en un `MarkerLayer` numerado (`1, 2, 3...`).

---

### Fase 4: Viaje Diario, Asistencia y Monitoreo GPS en Tiempo Real (`RF-07`, `RF-09`, `RF-10`, `RF-11`)
- [x] **Paso 4.1 (En `CONDUCTOR`):**
  - Botón **"Iniciar Recorrido"** $\rightarrow$ `POST /api/viajes/iniciar`.
  - Timer cada 5 segundos enviando `Geolocator.getCurrentPosition()` $\rightarrow$ `POST /api/gps/viajes/{viaje_id}/posicion`.
  - Lista de estudiantes (`GET /api/viajes/conductor/mi-ruta/estudiantes`) con dos botones por niño:
    - **"Subió al Bus"** $\rightarrow$ `POST /api/viajes/{viaje_id}/asistencia` con `{"estudiante_id": id, "estado_asistencia": "RECOGIDO"}`.
    - **"No Salió"** $\rightarrow$ `POST /api/viajes/{viaje_id}/asistencia` con `{"estudiante_id": id, "estado_asistencia": "NO_ASISTIO"}`.
  - Botón **"Finalizar Recorrido"** $\rightarrow$ `POST /api/viajes/{viaje_id}/finalizar`.
- [x] **Paso 4.2 (En `PADRE`):**
  - Conectar el mapa al WebSocket `ws://.../api/gps/ws/rutas/{ruta_id}?token=$token` para mover el ícono del bus en vivo cuando el conductor se mueve.
  - Botón **"Mi hijo no asistirá hoy"** $\rightarrow$ `POST /api/viajes/{viaje_id}/ausencias`.
  - Pantalla de campanita de notificaciones $\rightarrow$ `GET /api/gps/notificaciones`.

---

### Fase 5: Pagos con OCR y Reportes (`RF-06`, `RF-12`, `RF-13`, `RF-14`)
- [x] **Paso 5.1 (En `PADRE`):**
  - Listar sus pagos (`GET /api/pagos`).
  - Botón **"Subir Comprobante"** usando `ImagePicker` $\rightarrow$ `POST /api/pagos/{pago_id}/comprobante`.
  - Mostrar en un diálogo los datos que el **OCR** leyó automáticamente (`banco`, `monto_extraido`, `fecha_transferencia`, `referencia_extraida`, `ocr_confianza`) y botón **"Confirmar Datos"** (`PUT /api/pagos/comprobantes/{id}/confirmar-datos`).
- [x] **Paso 5.2 (En `ADMIN`):**
  - Ver comprobantes `EN_REVISION` (`GET /api/pagos?estado=EN_REVISION`), ver la imagen subida (`http://.../uploads/comprobantes/...`) y botón **"Aprobar Pago"** (`PATCH /api/pagos/comprobantes/{id}/revisar` con `{"estado": "VALIDADO"}`).
  - Botones para descargar **Reporte PDF** y **Reporte Excel** (`/api/reportes/rutas`, `/api/reportes/estudiantes`, `/api/reportes/pagos`).

---

## 3. ¿Cómo Verificar que el Frontend Realmente Está Ejecutando Todo en el Backend?

Cuando estés probando desde tu App Flutter, tienes **3 formas simultáneas** de comprobar que todo se está ejecutando de verdad:

### Verificación 1: En la consola donde corre FastAPI (`uvicorn`)
Cada vez que toques un botón en Flutter, verás en tiempo real en la terminal de PowerShell:
```text
INFO:     127.0.0.1:54120 - "POST /api/auth/login HTTP/1.1" 200 OK
INFO:     127.0.0.1:54121 - "POST /api/estudiantes/registrar-padre-y-estudiante HTTP/1.1" 201 Created
INFO:     127.0.0.1:54125 - "POST /api/rutas/1/optimizar HTTP/1.1" 200 OK
INFO:     127.0.0.1:54130 - "POST /api/gps/viajes/1/posicion HTTP/1.1" 201 Created
INFO:     127.0.0.1:54135 - "POST /api/pagos/1/comprobante HTTP/1.1" 201 Created
```

### Verificación 2: Prueba del Ciclo Completo de 5 Minutos desde Flutter
Sigue este guion desde la App móvil para validar los 3 roles:
1. **Entra como `ADMIN` (`admin@cooperativa.ec` / `admin123`):**
   - Registra un Conductor nuevo $\rightarrow$ verifica que te responda `"COD": "COD_OK"`.
2. **Cierra sesión y entra como `CONDUCTOR` (`conductor@cooperativa.ec` / `conductor123`):**
   - Registra un Padre y su Hijo en la pantalla **"Registrar Padre y Estudiante"**.
   - Presiona **"Optimizar Ruta"** y verifica que el mapa dibuje la polilínea incluyendo la nueva parada del niño.
   - Inicia el viaje y emite una ubicación GPS cercana a la parada $\rightarrow$ verifica que devuelva `alertas_geocerca_generadas: 1`.
3. **Cierra sesión y entra con la cuenta del `PADRE` que acabas de crear:**
   - Entra a **Notificaciones** y verifica que aparezca la alerta *"Unidad próxima a Parada..."*.
   - Sube una foto de comprobante de pago y verifica que la pantalla muestre el Banco, Monto y Referencia extraídos por el OCR.

### Verificación 3: En DBeaver (Base de Datos PostgreSQL + PostGIS, puerto `5435`)
Refresca las tablas en DBeaver mientras usas la App Flutter y verás cómo se insertan las filas reales en:
- `usuarios`, `conductores`, `estudiantes`, `paradas`, `asignaciones_estudiante_ruta`
- `viajes`, `posiciones_gps`, `notificaciones`
- `pagos`, `comprobantes`

