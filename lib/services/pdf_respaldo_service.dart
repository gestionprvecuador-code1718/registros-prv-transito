// RUTA DE ARCHIVO: lib/services/pdf_respaldo_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Ronda 21: guarda una copia local (dentro del propio celular) de cada
/// PDF de parte policial que se sube, como respaldo — sin depender de
/// la nube (subirlo a Firebase Storage requeriría cambiar el proyecto
/// al plan de pago "Blaze"). Xavier pidió esto explícitamente: mientras
/// sea el mismo celular y no se borren los datos de la app, el respaldo
/// se mantiene; si cambia de teléfono o de cuenta, se pierde — eso lo
/// tiene claro y le parece bien. Los datos del caso en sí (placa,
/// nombres, etc.) siguen guardándose en Firestore como siempre; esto
/// es solo el PDF original adjunto.
class PdfRespaldoService {
  static const _carpetaNombre = 'partes_pdf_respaldo';

  static Future<Directory> _carpeta() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_carpetaNombre');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Guarda [bytes] con un nombre legible y devuelve la ruta local
  /// final. Si ya existe un archivo con ese nombre, se agrega un
  /// sufijo numérico para no pisar el anterior.
  static Future<String> guardar(Uint8List bytes, {required String nombreSugerido}) async {
    final dir = await _carpeta();
    var ruta = '${dir.path}/$nombreSugerido.pdf';
    var intento = 1;
    while (await File(ruta).exists()) {
      ruta = '${dir.path}/${nombreSugerido}_$intento.pdf';
      intento++;
    }
    final archivo = File(ruta);
    await archivo.writeAsBytes(bytes);
    return ruta;
  }

  /// Lista los PDF guardados localmente, más recientes primero.
  static Future<List<File>> listar() async {
    final dir = await _carpeta();
    if (!await dir.exists()) return [];
    final archivos = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();
    archivos.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
    return archivos;
  }

  static Future<void> eliminar(File archivo) async {
    if (await archivo.exists()) await archivo.delete();
  }

  /// Tamaño total ocupado por los respaldos, en bytes (para mostrar en
  /// la pantalla "PDFs guardados" si hace falta más adelante).
  static Future<int> espacioUsadoBytes() async {
    final archivos = await listar();
    var total = 0;
    for (final a in archivos) {
      total += await a.length();
    }
    return total;
  }
}
