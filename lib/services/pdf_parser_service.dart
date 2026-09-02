import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/participante_vehiculo.dart';

/// Lee un PDF de "Parte Policial / Noticia del Incidente" (sistema Ecu911).
/// A diferencia de las fotos de la hoja física, este es texto digital
/// real: no hace falta OCR, solo extraer el texto y separarlo con
/// expresiones regulares.
///
/// NOTA WEB: extraerTextoBytes recibe directamente los bytes del PDF
/// (Uint8List) en vez de un File de dart:io, porque en el navegador
/// no existe un sistema de archivos real. Syncfusion's PdfDocument ya
/// aceptaba bytes (inputBytes) de todas formas, así que este cambio
/// solo mueve la lectura de bytes (antes con pdf.readAsBytesSync())
/// a captura_screen.dart, que ahora la obtiene de file_picker con
/// withData: true.
class PdfParserService {
  String? _buscar(String texto, RegExp regex, {int grupo = 1}) {
    final m = regex.firstMatch(texto);
    if (m == null) return null;
    final valor = m.group(grupo)?.trim();
    return (valor == null || valor.isEmpty) ? null : valor;
  }

  /// Extrae todo el texto del PDF, página por página, a partir de sus bytes.
  String extraerTextoBytes(Uint8List bytes) {
    final documento = PdfDocument(inputBytes: bytes);
    final texto = PdfTextExtractor(documento).extractText();
    documento.dispose();
    return texto;
  }

  /// Orden de antigüedad policial, de MAYOR a MENOR grado. Se usa para
  /// elegir, entre todo el personal policial que participó en el
  /// hecho (normalmente listado al final del PDF), a quien debe
  /// figurar como "quien elabora el parte".
  static const List<String> _jerarquiaPolicial = [
    'MAYR', 'CPTN', 'TNTE', 'SBTE', 'SBOP', 'SBOS', 'SGOP', 'SGOS', 'CBOP', 'CBOS', 'POLI',
  ];

  /// Busca todas las líneas con forma "GRADO NOMBRE APELLIDO ... C.C./C.I. NNNNNNNNNN"
  /// dentro del bloque de personal policial y devuelve el nombre y la
  /// cédula del de mayor antigüedad, según _jerarquiaPolicial.
  ///
  /// NOTA: el patrón exacto de esa sección puede variar entre
  /// plantillas de parte; si no detecta a nadie, conviene revisar con
  /// un PDF real cómo viene escrito ese bloque (igual que se hizo
  /// antes con el bloque de "Participante N.° N") y ajustar el regex.
  ({String nombre, String cedula})? _personalMasAntiguo(String texto) {
    final regexLinea = RegExp(
      r'\b(MAYR|CPTN|TNTE|SBTE|SBOP|SBOS|SGOP|SGOS|CBOP|CBOS|POLI)\.?\s+'
      r'([A-ZÁÉÍÓÚÑ][A-ZÁÉÍÓÚÑ .]+?)\s+'
      r'(?:C\.?C\.?|C\.?I\.?)\.?:?\s*(\d{9,10})',
    );

    final candidatosPorGrado = <String, ({String nombre, String cedula})>{};
    for (final m in regexLinea.allMatches(texto.toUpperCase())) {
      final grado = m.group(1)!;
      // Si el mismo grado aparece más de una vez, nos quedamos con el primero.
      candidatosPorGrado.putIfAbsent(
        grado,
        () => (nombre: m.group(2)!.trim(), cedula: m.group(3)!),
      );
    }

    for (final grado in _jerarquiaPolicial) {
      final candidato = candidatosPorGrado[grado];
      if (candidato != null) return candidato;
    }
    return null;
  }

  MetadatosParte extraerMetadatos(String texto) {
    final t = texto.replaceAll('\n', ' ');
    final personalMasAntiguo = _personalMasAntiguo(t);

    return MetadatosParte(
      // "Parte Policial No." es la etiqueta más común; si no aparece,
      // se intenta con "Parte No." (la que sale arriba del todo, junto
      // a la fecha de impresión).
      parteNo: _buscar(t, RegExp(r'Parte Policial No\.?\s*(\d+)')) ??
          _buscar(t, RegExp(r'Parte No\.?\s*(\d+)')) ??
          '',
      fechaHecho: _buscar(t, RegExp(r'Fecha del Hecho:\s*(\d{2}/\d{2}/\d{4})')) ?? '',
      horaHecho: _buscar(t, RegExp(r'Hora aproximada del\s*Hecho:\s*(\d{1,2}:\d{2})')) ?? '',
      direccion: _buscar(t, RegExp(r'Dirección:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ0-9 ]+?)(?:Intersección|Número de Casa)')) ?? '',
      // Distintas plantillas usan encabezados distintos para el relato
      // del hecho ("RESUMEN EJECUTIVO" en una plantilla más vieja,
      // "CIRCUNSTANCIAS DEL SINIESTRO DE TRÁNSITO" en el formato real
      // de Ecu911 "Noticia del Incidente"). Se intentan ambos.
      circunstancias: _buscar(
              t,
              RegExp(
                  r'(?:\*RESUMEN EJECUTIVO\*|CIRCUNSTANCIAS DEL SINIESTRO DE TR[ÁA]NSITO)\s*(.+?)'
                  r'(?:\*Participante 1|Vehículo 1|Fotograf[íi]a|PERSONAS HERIDAS|PERSONA FALLECIDA|PERSONAS APREHENDIDAS)',
                  dotAll: true)) ??
          '',
      // Preferimos al personal policial de mayor antigüedad detectado
      // en el bloque de participantes; si no se detecta a nadie (por
      // ejemplo, plantilla distinta), caemos al viejo "Realizado por:".
      elaboradoPor: personalMasAntiguo?.nombre ??
          _buscar(t, RegExp(r'Realizado por:\s*([A-ZÁÉÍÓÚñÑ.,]+(?:\s+[A-ZÁÉÍÓÚñÑ.,]+)*)')) ??
          '',
      elaboradoPorCedula: personalMasAntiguo?.cedula ?? '',
    );
  }

  /// Detecta cada bloque "Participante N.° N ... Vehículo participante
  /// N.° N ..." y arma un ParticipanteVehiculo por cada uno.
  ///
  /// El formato real de Ecu911 ("Noticia del Incidente") NO usa
  /// asteriscos ni las etiquetas "Propietario:"/"Conductor:" — trae un
  /// solo nombre + cédula por participante (el conductor), seguido de
  /// los datos del vehículo (Tipo/Marca/Placas/Color). Por eso acá
  /// "propietario" queda vacío: no viene en este documento, se
  /// completa a mano si hace falta.
  List<ParticipanteVehiculo> extraerParticipantes(String texto) {
    final porBloques = _extraerPorBloquesParticipante(texto);
    if (porBloques.isNotEmpty) return porBloques;

    // Respaldo: si el PDF no trae el encabezado "Participante N.° N"
    // (otra plantilla de parte, por ejemplo), buscamos directamente
    // cada "Placas:" en todo el documento y completamos los demás
    // datos mirando el texto alrededor de esa coincidencia.
    return _extraerFlexible(texto);
  }

  List<ParticipanteVehiculo> _extraerPorBloquesParticipante(String texto) {
    final resultado = <ParticipanteVehiculo>[];

    // Cada bloque empieza en "Participante N.° N" — el símbolo exacto
    // entre "Participante" y el número varía según la plantilla
    // ("N.°", "N°", "No.", o nada), por eso se acepta cualquier cosa
    // que no sea un dígito ahí en medio (hasta 15 caracteres).
    // OJO: se usa "Participante" con mayúscula inicial a propósito,
    // porque el encabezado de cada vehículo es "Vehículo participante
    // N.° N" (con minúscula) y así no se confunden entre sí.
    final bloques = texto.split(RegExp(r'Participante[^\d\n]{0,15}\d+'));

    for (final bloque in bloques.skip(1)) {
      final placa = _buscar(bloque, RegExp(r'Placas:\s*([A-Z0-9\-]+)'));
      if (placa == null) continue;

      final tipo = _buscar(bloque, RegExp(r'Tipo:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|Marca)'));
      final marca = _buscar(bloque, RegExp(r'Marca:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|Placas)'));
      final color = _buscar(bloque, RegExp(r'Color:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|$)'));
      final conductor = _buscar(bloque, RegExp(r'Nombres:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ .]+?)(?:\n|C\.C)'));
      final conductorCedula = _buscar(bloque, RegExp(r'C\.C\.?:?\s*(\d{9,10})'));

      resultado.add(ParticipanteVehiculo(
        placa: placa.replaceAll(RegExp(r'\s'), '').toUpperCase(),
        tipo: tipo ?? '',
        marca: marca ?? '',
        color: color ?? '',
        conductor: conductor ?? '',
        conductorCedula: conductorCedula ?? '',
        propietario: '',
        propietarioCedula: '',
      ));
    }

    return resultado;
  }

  /// Respaldo cuando la plantilla del PDF no trae "Participante N.° N":
  /// busca cada ocurrencia de "Placas:" en todo el documento y arma un
  /// ParticipanteVehiculo mirando ~300 caracteres alrededor de cada
  /// una (mismo criterio de campos que el método principal).
  ///
  /// NOTA: si esto tampoco detecta nada en un PDF real, lo más seguro
  /// es que ese PDF ni siquiera diga "Placas:" (por ejemplo si es una
  /// imagen escaneada sin texto seleccionable). En ese caso no hay
  /// texto que extraer y hay que usar las fotos, tal como ya sugiere
  /// el aviso en pantalla.
  List<ParticipanteVehiculo> _extraerFlexible(String texto) {
    final resultado = <ParticipanteVehiculo>[];
    final regexPlaca = RegExp(r'Placas?:\s*([A-Z0-9\-]{5,8})');

    for (final m in regexPlaca.allMatches(texto)) {
      final inicioVentana = (m.start - 300).clamp(0, texto.length);
      final finVentana = (m.end + 300).clamp(0, texto.length);
      final ventana = texto.substring(inicioVentana, finVentana);

      final placa = m.group(1)!;
      final tipo = _buscar(ventana, RegExp(r'Tipo:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|Marca)'));
      final marca = _buscar(ventana, RegExp(r'Marca:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|Placas)'));
      final color = _buscar(ventana, RegExp(r'Color:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ ]+?)(?:\n|$)'));
      final conductor = _buscar(ventana, RegExp(r'Nombres:\s*([A-Za-zÁÉÍÓÚáéíóúñÑ .]+?)(?:\n|C\.C)'));
      final conductorCedula = _buscar(ventana, RegExp(r'C\.C\.?:?\s*(\d{9,10})'));

      resultado.add(ParticipanteVehiculo(
        placa: placa.replaceAll(RegExp(r'\s'), '').toUpperCase(),
        tipo: tipo ?? '',
        marca: marca ?? '',
        color: color ?? '',
        conductor: conductor ?? '',
        conductorCedula: conductorCedula ?? '',
        propietario: '',
        propietarioCedula: '',
      ));
    }

    return resultado;
  }
}
