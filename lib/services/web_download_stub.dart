/// Versión "vacía" para Android/iOS nativo (APK). Ahí SÍ existe un
/// sistema de archivos real (se usa path_provider + dart:io File),
/// así que no hace falta disparar una descarga de navegador — por
/// eso esta función no hace nada en esta plataforma.
///
/// Este archivo y web_download_web.dart se seleccionan
/// automáticamente entre sí según la plataforma, mediante el import
/// condicional que hay en storage_service.dart. No hace falta
/// tocarlo ni importarlo manualmente en ningún otro lado.
void descargarBytesEnNavegador(String nombreArchivo, List<int> bytes) {
  // No-op: en Android/iOS nativo los archivos se guardan en disco
  // normalmente, ver storage_service.dart.
}
