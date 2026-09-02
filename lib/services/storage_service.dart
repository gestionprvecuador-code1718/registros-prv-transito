import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import 'docx_builder.dart';
import 'excel_matriz_builder.dart';

class StorageService {
  static const String _keyIngresos = 'casos_ingreso_list';
  static const String _keyLibertades = 'casos_libertad_list';

  // Persistencia de Agente / Policía que toma el procedimiento
  static String ultimoPoliciaNombre = '';
  static String ultimoPoliciaCedula = '';
  // Persistencia de Subzona / CRV (normalmente no cambian entre casos
  // del mismo oficial, así que se recuerdan igual que el policía)
  static String ultimaSubzona = '';
  static String ultimoCrv = '';

  // --- NUEVO (30/ago): recordados para el Informe Semanal — mismo
  // patrón que los de arriba (en memoria mientras la app sigue abierta,
  // no persisten al cerrar la app; si se quiere persistencia real entre
  // sesiones, guardarlos también en SharedPreferences o en el perfil de
  // Firestore, a decidir). Todos son editables cada vez en la pantalla,
  // esto solo evita reescribirlos cada semana.
  static String ultimoOficioInformeNro = '';
  static String ultimoAsuntoOficioNro = '';
  static String ultimoAsuntoOficioFecha = '';
  static String ultimoDestinatarioNombre = '';
  static String ultimoDestinatarioRango = '';
  static String ultimoFirmanteNombre = '';
  static String ultimoFirmanteRango = '';

  // --- MÓDULO CASOS DE INGRESO ---

  static Future<List<CasoIngreso>> obtenerIngresos() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyIngresos);
    if (data == null || data.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => CasoIngreso.fromJson(e)).toList();
  }

  static Future<void> guardarCasoIngreso(CasoIngreso nuevoCaso) async {
    final prefs = await SharedPreferences.getInstance();
    List<CasoIngreso> lista = await obtenerIngresos();

    int index = lista.indexWhere((element) => element.id == nuevoCaso.id);
    if (index >= 0) {
      lista[index] = nuevoCaso;
    } else {
      lista.add(nuevoCaso);
    }

    final String data = jsonEncode(lista.map((e) => e.toJson()).toList());
    await prefs.setString(_keyIngresos, data);
  }

  static Future<CasoIngreso?> buscarIngresoPorPlaca(String placa) async {
    List<CasoIngreso> lista = await obtenerIngresos();
    final placaClean = placa.trim().toUpperCase();
    try {
      return lista.firstWhere((element) => element.placa.toUpperCase() == placaClean);
    } catch (_) {
      return null;
    }
  }

  /// Igual que buscarIngresoPorPlaca, pero devuelve TODOS los que
  /// coincidan (permite buscar por coincidencia parcial, y ver el
  /// historial completo de una placa si ingresó más de una vez).
  static Future<List<CasoIngreso>> buscarIngresosPorPlaca(String placa) async {
    final normalizada = placa.trim().toUpperCase();
    if (normalizada.isEmpty) return [];
    final lista = await obtenerIngresos();
    return lista.where((c) => c.placa.toUpperCase().contains(normalizada)).toList();
  }

  // --- MÓDULO CASOS DE LIBERTAD / DEVOLUCIÓN ---

  static Future<List<CasoLibertad>> obtenerLibertades() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyLibertades);
    if (data == null || data.isEmpty) return [];

    final List<dynamic> jsonList = jsonDecode(data);
    return jsonList.map((e) => CasoLibertad.fromJson(e)).toList();
  }

  static Future<void> guardarCasoLibertad(CasoLibertad nuevoCaso) async {
    final prefs = await SharedPreferences.getInstance();
    List<CasoLibertad> lista = await obtenerLibertades();

    int index = lista.indexWhere((element) => element.id == nuevoCaso.id);
    if (index >= 0) {
      lista[index] = nuevoCaso;
    } else {
      lista.add(nuevoCaso);
    }

    final String data = jsonEncode(lista.map((e) => e.toJson()).toList());
    await prefs.setString(_keyLibertades, data);
  }

  /// Todas las libertades guardadas cuya placa coincida (coincidencia
  /// parcial, igual que buscarIngresosPorPlaca).
  static Future<List<CasoLibertad>> buscarLibertadesPorPlaca(String placa) async {
    final normalizada = placa.trim().toUpperCase();
    if (normalizada.isEmpty) return [];
    final lista = await obtenerLibertades();
    return lista.where((c) => c.placa.toUpperCase().contains(normalizada)).toList();
  }

  /// NUEVO (30/ago): cuenta cuántas libertades (vehículos vs
  /// motocicletas) caen dentro de [inicio, finInclusive] comparando
  /// `fechaSalida` (formato DD/MM/AAAA). Usado por el Informe Semanal
  /// para prellenar el conteo automático — el resultado sigue siendo
  /// editable en la pantalla antes de generar el Word.
  static Future<({int vehiculos, int motocicletas})> contarLibertadesEnRango(
    DateTime inicio,
    DateTime finInclusive,
  ) async {
    final lista = await obtenerLibertades();
    int vehiculos = 0;
    int motos = 0;

    DateTime? parseFecha(String s) {
      final p = s.trim().split('/');
      if (p.length != 3) return null;
      final d = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final y = int.tryParse(p[2]);
      if (d == null || m == null || y == null) return null;
      try {
        return DateTime(y, m, d);
      } catch (_) {
        return null;
      }
    }

    for (final l in lista) {
      final fecha = parseFecha(l.fechaSalida);
      if (fecha == null) continue;
      final dentroDelRango = !fecha.isBefore(inicio) && !fecha.isAfter(finInclusive);
      if (!dentroDelRango) continue;
      if (l.tipoVehiculo.toUpperCase() == 'MOTOCICLETA') {
        motos++;
      } else {
        vehiculos++;
      }
    }

    return (vehiculos: vehiculos, motocicletas: motos);
  }

  // --- GENERACIÓN DE NOMBRES DINÁMICOS PARA DOCUMENTOS ---

  static String obtenerNombreArchivoWord({required String placa, required bool esIngreso}) {
    final String placaLimpia = placa.trim().toUpperCase().replaceAll(' ', '_');
    final String prefijo = esIngreso ? 'Ingreso' : 'Libertad';
    return '${prefijo}_$placaLimpia.docx';
  }

  // --- GENERACIÓN DE WORD POR CASO PUNTUAL ---

  static List<int> generarWordIngreso(CasoIngreso c) => DocxBuilder.buildIngreso(c);

  static List<int> generarWordLibertad(CasoLibertad l) => DocxBuilder.buildLibertad(l);

  // --- EXPORTACIÓN CONSOLIDADA A EXCEL (.XLSX) ---

  static Future<List<int>?> generarExcelConsolidado() async {
    final ingresos = await obtenerIngresos();
    final libertades = await obtenerLibertades();
    if (ingresos.isEmpty) return null;

    return ExcelMatrizBuilder.build(ingresos: ingresos, libertades: libertades);
  }
}
