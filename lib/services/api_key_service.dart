import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Guarda la API key de Gemini en un archivo de texto simple dentro del
/// almacenamiento propio de la app (no requiere paquetes extra).
///
/// La API key es GRATUITA: se obtiene en https://aistudio.google.com/apikey
/// con cualquier cuenta de Google, sin tarjeta de crédito, para el nivel
/// gratuito de Gemini.
class ApiKeyService {
  static const _archivo = 'gemini_api_key.txt';

  Future<String?> obtenerApiKey() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_archivo');
    if (!await file.exists()) return null;
    final contenido = (await file.readAsString()).trim();
    return contenido.isEmpty ? null : contenido;
  }

  Future<void> guardarApiKey(String apiKey) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_archivo');
    await file.writeAsString(apiKey.trim());
  }
}
