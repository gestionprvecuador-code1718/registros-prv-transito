import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import 'docx_builder.dart';
import 'pdf_builder.dart';
import 'firestore_sync_service.dart';

/// Fuente de verdad de los datos: dos archivos JSON (ingresos.json,
/// libertades.json) que viven en el almacenamiento propio de la app.
///
/// Cada vez que se agrega un caso nuevo:
///  1. se guarda en el JSON correspondiente (el "banco de datos"), y
///  2. se regenera por completo el .docx acumulado a partir de TODOS
///     los casos guardados de ese tipo.
///
/// Regenerar el Word completo (en vez de tratar de "insertar" en un
/// .docx ya comprimido) es más simple y evita corromper el archivo.
/// El JSON es además lo que después alimentará la plantilla de Excel.
class StorageService {
  static const _jsonIngresos = 'ingresos.json';
  static const _jsonLibertades = 'libertades.json';
  static const _jsonBorradoresLibertad = 'borradores_libertad.json'; // NUEVO
  static const _docxIngresos = 'Ingresos.docx';
  static const _docxLibertades = 'Libertades.docx';

  Future<Directory> _dir() async => getApplicationDocumentsDirectory();

  // ---------- Ingresos ----------

  Future<List<CasoIngreso>> cargarIngresos() async {
    final dir = await _dir();
    final file = File('${dir.path}/$_jsonIngresos');
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List;
    return data.map((e) => CasoIngreso.fromJson(e)).toList();
  }

  Future<File> agregarIngreso(CasoIngreso caso, {String patio = ''}) async {
    final dir = await _dir();
    final lista = await cargarIngresos();
    lista.add(caso);

    final jsonFile = File('${dir.path}/$_jsonIngresos');
    await jsonFile.writeAsString(jsonEncode(lista.map((e) => e.toJson()).toList()));

    unawaited(FirestoreSyncService().subirIngreso(caso, patio: patio));

    // NUEVO: en paralelo, se prepara automáticamente un borrador de
    // Libertad con los datos ya heredados del Ingreso, listo para
    // completarse después desde "Buscar por placa" → "Liberar
    // vehículo". Este borrador NO entra al Word oficial de Libertades
    // (eso solo pasa cuando el vehículo realmente sale y se guarda el
    // caso completo) — solo queda disponible para prellenar el
    // formulario más rápido.
    unawaited(guardarBorradorLibertad(CasoLibertad(
      id: caso.id,
      crv: caso.crv,
      dirigidoA: caso.dirigidoA,
      causa: caso.causa,
      marca: caso.marca,
      color: caso.color,
      placa: caso.placa,
      tipoVehiculo: caso.tipoVehiculo,
      retiradoPor: caso.propietario,
      cedulaRetira: caso.cedulaPropietario,
      hojaIngresoNro: caso.hojaIngresoNro,
      parteIngresoNro: caso.parteIngresoNro,
      fechaIngreso: caso.fechaIngreso,
    )));

    return _regenerarIngresosDocx(lista);
  }

  /// Reemplaza un caso ya guardado (por id) con los datos editados, sin
  /// crear un registro nuevo. Usado por la pantalla de "Buscar por placa".
  Future<File> actualizarIngreso(CasoIngreso casoEditado, {String patio = ''}) async {
    final dir = await _dir();
    final lista = await cargarIngresos();
    final indice = lista.indexWhere((c) => c.id == casoEditado.id);
    if (indice == -1) {
      // por seguridad, si no se encuentra, se agrega en vez de perder el dato
      lista.add(casoEditado);
    } else {
      lista[indice] = casoEditado;
    }

    final jsonFile = File('${dir.path}/$_jsonIngresos');
    await jsonFile.writeAsString(jsonEncode(lista.map((e) => e.toJson()).toList()));

    unawaited(FirestoreSyncService().subirIngreso(casoEditado, patio: patio));
    return _regenerarIngresosDocx(lista);
  }

  /// Busca todos los ingresos guardados cuya placa coincida (parcial,
  /// sin distinguir mayúsculas/minúsculas ni guiones).
  Future<List<CasoIngreso>> buscarIngresosPorPlaca(String placa) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final lista = await cargarIngresos();
    return lista
        .where((c) => c.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase().contains(normalizada))
        .toList();
  }

  List<String> _bloqueIngreso(CasoIngreso c) {
    final tipo = c.tipoVehiculo.isEmpty ? '' : 'Tipo ${c.tipoVehiculo} ';
    final causa = c.causa.isEmpty ? 'motivo por determinar' : c.causa;
    final trasladado = c.trasladadoComoTexto();
    final novedad = c.novedades.isEmpty ? 'Sin mayor novedad' : c.novedades;
    final dirigidoA = c.dirigidoA.isEmpty ? 'Mi Mayor' : c.dirigidoA;

    return [
      'HOJA N° ${c.hojaIngresoNro}',
      '',
      'Por medio del presente me permito poner en su conocimiento $dirigidoA, que encontrándome de servicio '
          'como custodio del CRV "${c.crv}" en el lugar y hora antes indicada se procedió al ingreso del vehículo '
          '${tipo}Marca ${c.marca}, color ${c.color} de placas ${c.placa} de propiedad del señor ${c.propietario}, '
          'por $causa, con hoja de ingreso N° ${c.hojaIngresoNro}'
          '${c.parteIngresoNro.isEmpty ? '' : ' y parte N° ${c.parteIngresoNro}'}; '
          'quien es trasladado en $trasladado; toma procedimiento el señor ${c.tomaProcedimiento}',
      '',
      novedad,
      '',
      'Particular que me permito poner en su conocimiento $dirigidoA para los fines pertinentes.',
    ];
  }

  Future<File> _regenerarIngresosDocx(List<CasoIngreso> lista) async {
    final dir = await _dir();
    final bloques = lista.map(_bloqueIngreso).toList();

    final bytes = DocxBuilder.build(titulo: 'REGISTRO DE INGRESOS - CRV', bloques: bloques);
    final file = File('${dir.path}/$_docxIngresos');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ---------- Libertades ----------

  Future<List<CasoLibertad>> cargarLibertades() async {
    final dir = await _dir();
    final file = File('${dir.path}/$_jsonLibertades');
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List;
    return data.map((e) => CasoLibertad.fromJson(e)).toList();
  }

  Future<File> agregarLibertad(CasoLibertad caso, {String patio = ''}) async {
    final dir = await _dir();
    final lista = await cargarLibertades();
    lista.add(caso);

    final jsonFile = File('${dir.path}/$_jsonLibertades');
    await jsonFile.writeAsString(jsonEncode(lista.map((e) => e.toJson()).toList()));

    unawaited(FirestoreSyncService().subirLibertad(caso, patio: patio));
    // Ya se completó de verdad: el borrador automático ya no hace falta.
    unawaited(borrarBorradorLibertad(caso.hojaIngresoNro));
    return _regenerarLibertadesDocx(lista);
  }

  Future<File> actualizarLibertad(CasoLibertad casoEditado, {String patio = ''}) async {
    final dir = await _dir();
    final lista = await cargarLibertades();
    final indice = lista.indexWhere((c) => c.id == casoEditado.id);
    if (indice == -1) {
      lista.add(casoEditado);
    } else {
      lista[indice] = casoEditado;
    }

    final jsonFile = File('${dir.path}/$_jsonLibertades');
    await jsonFile.writeAsString(jsonEncode(lista.map((e) => e.toJson()).toList()));

    unawaited(FirestoreSyncService().subirLibertad(casoEditado, patio: patio));
    return _regenerarLibertadesDocx(lista);
  }

  Future<List<CasoLibertad>> buscarLibertadesPorPlaca(String placa) async {
    final normalizada = placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase();
    final lista = await cargarLibertades();
    return lista
        .where((c) => c.placa.replaceAll('-', '').replaceAll(' ', '').toUpperCase().contains(normalizada))
        .toList();
  }

  List<String> _bloqueLibertad(CasoLibertad c) {
    final dirigidoA = c.dirigidoA.isEmpty ? 'Mi Mayor' : c.dirigidoA;
    final crv = c.crv.isEmpty ? 'Control 120' : c.crv;
    final causa = c.causa.isEmpty ? 'motivo por determinar' : c.causa;

    return [
      'HOJA N° ${c.hojaIngresoNro}',
      '',
      'Por medio del presente me permito poner en su conocimiento $dirigidoA, que encontrándome como '
          'custodio del CRV "$crv", se dio cumplimiento al Memorando Nro. ${c.memorandoNro} de fecha '
          '${c.memorandoFecha}, el mismo que tiene referencia al Oficio de DEVOLUCIÓN DE VEHÍCULO Nro. '
          '${c.oficioDevolucionNro} de fecha ${c.oficioDevolucionFecha}, firmado por ${c.firmadoPor}; por lo '
          'que se procede a dar la libertad del vehículo, Marca ${c.marca}, color ${c.color}, de placas '
          '${c.placa}, siendo retirado por su propietario el señor ${c.retiradoPor}, con C.C. ${c.cedulaRetira}.',
      '',
      'Hoja de Ingreso Nro.: ${c.hojaIngresoNro}   Parte de ingreso Nro.: ${c.parteIngresoNro}',
      'Fecha de ingreso: ${c.fechaIngreso}   Causa: $causa',
      'Días de permanencia en el CRV: ${c.diasPermanencia}   Vehículo tipo: ${c.tipoVehiculo}',
      '',
      c.pagosComoTexto(),
      if (c.observaciones.trim().isNotEmpty) ...['', 'Observaciones: ${c.observaciones}'],
      '',
      'Particular que me permito poner en su conocimiento $dirigidoA para los fines pertinentes.',
    ];
  }

  Future<File> _regenerarLibertadesDocx(List<CasoLibertad> lista) async {
    final dir = await _dir();
    final bloques = lista.map(_bloqueLibertad).toList();

    final bytes = DocxBuilder.build(titulo: 'REGISTRO DE LIBERTADES - CRV', bloques: bloques);
    final file = File('${dir.path}/$_docxLibertades');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ---------- Último caso (para compartir por WhatsApp) ----------

  /// Busca el caso más reciente entre TODOS los ingresos y libertades
  /// guardados, y genera un .docx aparte solo con ese caso (no el
  /// documento acumulado completo), listo para compartir.
  Future<File?> archivoUltimoCaso() async {
    final ingresos = await cargarIngresos();
    final libertades = await cargarLibertades();

    CasoIngreso? ultimoIngreso = ingresos.isEmpty ? null : ingresos.last;
    CasoLibertad? ultimaLibertad = libertades.isEmpty ? null : libertades.last;

    if (ultimoIngreso == null && ultimaLibertad == null) return null;

    final esIngreso = ultimaLibertad == null ||
        (ultimoIngreso != null && ultimoIngreso.creado.isAfter(ultimaLibertad.creado));

    final dir = await _dir();
    final file = File('${dir.path}/ultimo_caso.docx');

    if (esIngreso) {
      final bytes = DocxBuilder.build(
        titulo: 'PARTE DE INGRESO - CRV',
        bloques: [_bloqueIngreso(ultimoIngreso!)],
      );
      await file.writeAsBytes(bytes);
    } else {
      final bytes = DocxBuilder.build(
        titulo: 'PARTE DE LIBERTAD - CRV',
        bloques: [_bloqueLibertad(ultimaLibertad!)],
      );
      await file.writeAsBytes(bytes);
    }
    return file;
  }

  // ---------- Acceso directo a los archivos generados ----------

  Future<File?> archivoIngresos() async {
    final dir = await _dir();
    final f = File('${dir.path}/$_docxIngresos');
    return await f.exists() ? f : null;
  }

  Future<File?> archivoLibertades() async {
    final dir = await _dir();
    final f = File('${dir.path}/$_docxLibertades');
    return await f.exists() ? f : null;
  }

  // ---------- Borradores automáticos de Libertad ----------
  // Se crean en paralelo al guardar un Ingreso (ver agregarIngreso), y
  // se usan para prellenar "Liberar vehículo" sin tener que reconstruir
  // los datos heredados desde cero. NO forman parte del Word oficial
  // acumulado (Libertades.docx) — eso solo ocurre cuando el caso se
  // completa y se guarda de verdad con agregarLibertad().

  Future<List<CasoLibertad>> _cargarBorradoresLibertad() async {
    final dir = await _dir();
    final file = File('${dir.path}/$_jsonBorradoresLibertad');
    if (!await file.exists()) return [];
    final data = jsonDecode(await file.readAsString()) as List;
    return data.map((e) => CasoLibertad.fromJson(e)).toList();
  }

  Future<void> _guardarListaBorradores(List<CasoLibertad> lista) async {
    final dir = await _dir();
    final file = File('${dir.path}/$_jsonBorradoresLibertad');
    await file.writeAsString(jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  /// Crea o actualiza (por hojaIngresoNro) el borrador automático de
  /// Libertad para un Ingreso.
  Future<void> guardarBorradorLibertad(CasoLibertad borrador) async {
    final lista = await _cargarBorradoresLibertad();
    final indice = lista.indexWhere((b) => b.hojaIngresoNro == borrador.hojaIngresoNro);
    if (indice == -1) {
      lista.add(borrador);
    } else {
      lista[indice] = borrador;
    }
    await _guardarListaBorradores(lista);
  }

  /// Busca el borrador automático de Libertad para una hoja de ingreso
  /// específica (null si no existe, por ejemplo si el Ingreso es muy
  /// viejo y se creó antes de tener esta función).
  Future<CasoLibertad?> buscarBorradorLibertadPorHoja(String hojaIngresoNro) async {
    final lista = await _cargarBorradoresLibertad();
    for (final b in lista) {
      if (b.hojaIngresoNro == hojaIngresoNro) return b;
    }
    return null;
  }

  /// Elimina el borrador una vez que la Libertad ya se completó de
  /// verdad y se guardó con agregarLibertad().
  Future<void> borrarBorradorLibertad(String hojaIngresoNro) async {
    final lista = await _cargarBorradoresLibertad();
    lista.removeWhere((b) => b.hojaIngresoNro == hojaIngresoNro);
    await _guardarListaBorradores(lista);
  }

  // ---------- Último caso en PDF (para descargar/imprimir directo) ----------
  Future<File?> archivoUltimoCasoPdf() async {
    final ingresos = await cargarIngresos();
    final libertades = await cargarLibertades();

    CasoIngreso? ultimoIngreso = ingresos.isEmpty ? null : ingresos.last;
    CasoLibertad? ultimaLibertad = libertades.isEmpty ? null : libertades.last;

    if (ultimoIngreso == null && ultimaLibertad == null) return null;

    final esIngreso = ultimaLibertad == null ||
        (ultimoIngreso != null && ultimoIngreso.creado.isAfter(ultimaLibertad.creado));

    final dir = await _dir();
    final file = File('${dir.path}/ultimo_caso.pdf');

    if (esIngreso) {
      final bytes = PdfBuilder.build(
        titulo: 'PARTE DE INGRESO - CRV',
        bloques: [_bloqueIngreso(ultimoIngreso!)],
      );
      await file.writeAsBytes(bytes);
    } else {
      final bytes = PdfBuilder.build(
        titulo: 'PARTE DE LIBERTAD - CRV',
        bloques: [_bloqueLibertad(ultimaLibertad!)],
      );
      await file.writeAsBytes(bytes);
    }
    return file;
  }
}
