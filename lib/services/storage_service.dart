// RUTA DE ARCHIVO: lib/services/storage_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import 'auth_service.dart';
import 'docx_builder.dart';
import 'excel_matriz_builder.dart';
import 'firestore_sync_service.dart';

/// Fuente de verdad de los datos: todo se guarda como JSON en
/// SharedPreferences (NO se usa dart:io/path_provider — así "Descargar"
/// y "Enviar por WhatsApp" pueden compartir el mismo flujo de
/// Share.shareXFiles en cualquier plataforma, incluida la web).
///
/// Cada caso (Ingreso o Libertad) se guarda/actualiza por su "id"
/// (upsert). El Word de cada caso se genera al vuelo cuando se
/// necesita compartir/descargar (ya no existe un solo .docx
/// acumulado con "todos los casos juntos" como en versiones viejas).
class StorageService {
  static const _claveIngresos = 'ingresos_json_v1';
  static const _claveLibertades = 'libertades_json_v1';

  static List<CasoIngreso>? _cacheIngresos;
  static List<CasoLibertad>? _cacheLibertades;

  // ---------- "Recordados" en memoria para el Informe Semanal ----------
  // Campos que rara vez cambian entre semanas (jefatura, oficio de
  // referencia, destinatario, firmante...). Viven solo en memoria: si
  // se cierra la app del todo se pierden — Xavier no ha pedido
  // cambiar esto todavía (persistirlos sería agregar SharedPreferences
  // acá también, es un cambio pequeño si se pide más adelante).
  static String ultimaSubzona = '';
  static String ultimoCrv = '';
  static String ultimoPoliciaNombre = '';
  static String ultimoOficioInformeNro = '';
  static String ultimoAsuntoOficioNro = '';
  static String ultimoAsuntoOficioFecha = '';
  static String ultimoDestinatarioNombre = '';
  static String ultimoDestinatarioRango = '';
  static String ultimoFirmanteNombre = '';
  static String ultimoFirmanteRango = '';

  static Future<String> _patioDelUsuario() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return '';
    final perfil = await AuthService().obtenerPerfil(usuario.uid);
    return perfil?['patio'] ?? '';
  }

  static Future<void> _asegurarCargado() async {
    if (_cacheIngresos != null && _cacheLibertades != null) return;
    final prefs = await SharedPreferences.getInstance();

    final jsonIngresos = prefs.getString(_claveIngresos);
    _cacheIngresos = jsonIngresos == null
        ? <CasoIngreso>[]
        : (jsonDecode(jsonIngresos) as List).map((e) => CasoIngreso.fromJson(e)).toList();

    final jsonLibertades = prefs.getString(_claveLibertades);
    _cacheLibertades = jsonLibertades == null
        ? <CasoLibertad>[]
        : (jsonDecode(jsonLibertades) as List).map((e) => CasoLibertad.fromJson(e)).toList();
  }

  static Future<void> _guardarIngresosEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveIngresos, jsonEncode(_cacheIngresos!.map((e) => e.toJson()).toList()));
  }

  static Future<void> _guardarLibertadesEnDisco() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveLibertades, jsonEncode(_cacheLibertades!.map((e) => e.toJson()).toList()));
  }

  // ---------- Lectura ----------

  static Future<List<CasoIngreso>> obtenerIngresos() async {
    await _asegurarCargado();
    return List<CasoIngreso>.from(_cacheIngresos!);
  }

  static Future<List<CasoLibertad>> obtenerLibertades() async {
    await _asegurarCargado();
    return List<CasoLibertad>.from(_cacheLibertades!);
  }

  static Future<List<CasoIngreso>> buscarIngresosPorPlaca(String placa) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final lista = await obtenerIngresos();
    return lista
        .where((c) => c.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase().contains(normalizada))
        .toList();
  }

  static Future<List<CasoLibertad>> buscarLibertadesPorPlaca(String placa) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final lista = await obtenerLibertades();
    return lista
        .where((c) => c.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase().contains(normalizada))
        .toList();
  }

  /// True si ya existe una Libertad guardada para esa hoja de ingreso.
  static Future<bool> yaTieneLibertad(String hojaIngresoNro) async {
    final libertades = await obtenerLibertades();
    return libertades.any((l) => l.hojaIngresoNro == hojaIngresoNro);
  }

  // ---------- Guardado (upsert por id) ----------

  static Future<void> guardarCasoIngreso(CasoIngreso caso) async {
    await _asegurarCargado();
    final indice = _cacheIngresos!.indexWhere((c) => c.id == caso.id);
    if (indice == -1) {
      _cacheIngresos!.add(caso);
    } else {
      _cacheIngresos![indice] = caso;
    }
    await _guardarIngresosEnDisco();

    // Se "recuerdan" para prellenar el próximo Informe Semanal.
    if (caso.subzona.trim().isNotEmpty) ultimaSubzona = caso.subzona;
    if (caso.crv.trim().isNotEmpty) ultimoCrv = caso.crv;
    if (caso.policiaNombre.trim().isNotEmpty) ultimoPoliciaNombre = caso.policiaNombre;

    final patio = await _patioDelUsuario();
    unawaited(FirestoreSyncService().subirIngreso(caso, patio: patio));
  }

  static Future<void> guardarCasoLibertad(CasoLibertad caso) async {
    await _asegurarCargado();
    final indice = _cacheLibertades!.indexWhere((c) => c.id == caso.id);
    if (indice == -1) {
      _cacheLibertades!.add(caso);
    } else {
      _cacheLibertades![indice] = caso;
    }
    await _guardarLibertadesEnDisco();

    final patio = await _patioDelUsuario();
    unawaited(FirestoreSyncService().subirLibertad(caso, patio: patio));
  }

  // ---------- Generación de documentos ----------

  static List<int> generarWordIngreso(CasoIngreso c) => DocxBuilder.buildIngreso(c);

  static List<int> generarWordLibertad(CasoLibertad c) => DocxBuilder.buildLibertad(c);

  static String obtenerNombreArchivoWord({required String placa, required bool esIngreso}) {
    final placaLimpia = placa.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return '${esIngreso ? 'Ingreso' : 'Libertad'}_$placaLimpia.docx';
  }

  /// Genera el Excel consolidado (matriz VEHICULOS/MOTOCICLETAS) a
  /// partir de TODOS los ingresos/libertades guardados. Devuelve null
  /// si todavía no hay ningún Ingreso guardado.
  static Future<List<int>?> generarExcelConsolidado() async {
    final ingresos = await obtenerIngresos();
    if (ingresos.isEmpty) return null;
    final libertades = await obtenerLibertades();
    return ExcelMatrizBuilder.build(ingresos: ingresos, libertades: libertades);
  }

  // ---------- Conteo para el Informe Semanal ----------

  static DateTime? _parseFechaDdMmAaaa(String texto) {
    final partes = texto.trim().split('/');
    if (partes.length != 3) return null;
    final d = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final y = int.tryParse(partes[2]);
    if (d == null || m == null || y == null) return null;
    try {
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  /// Cuenta cuántas Libertades (por fecha de salida) caen dentro del
  /// rango [lunes, domingo] (ambos inclusive), separando vehículos de
  /// motocicletas según el campo tipoVehiculo.
  static Future<({int vehiculos, int motocicletas})> contarLibertadesEnRango(
    DateTime lunes,
    DateTime domingo,
  ) async {
    final lista = await obtenerLibertades();
    var vehiculos = 0;
    var motocicletas = 0;

    final desde = DateTime(lunes.year, lunes.month, lunes.day);
    final hasta = DateTime(domingo.year, domingo.month, domingo.day, 23, 59, 59);

    for (final c in lista) {
      final fecha = _parseFechaDdMmAaaa(c.fechaSalida);
      if (fecha == null) continue;
      if (fecha.isBefore(desde) || fecha.isAfter(hasta)) continue;

      if (c.tipoVehiculo.trim().toUpperCase() == 'MOTOCICLETA') {
        motocicletas++;
      } else {
        vehiculos++;
      }
    }

    return (vehiculos: vehiculos, motocicletas: motocicletas);
  }
}
