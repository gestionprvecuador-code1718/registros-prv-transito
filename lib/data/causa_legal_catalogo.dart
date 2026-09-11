// RUTA DE ARCHIVO: lib/data/causa_legal_catalogo.dart

/// Catálogo real de "Causa legal" -> "Detalle causa" tal como aparece
/// en SIIPNE 3W (capturas que compartió Xavier el 09/sep).
///
/// OJO: las descripciones de cada artículo son un RESUMEN de lo que
/// se alcanzaba a leer en las capturas — el texto completo salía
/// cortado por el borde de la pantalla en varias de ellas (sobre todo
/// los artículos 383 a 391 del bloque "Contravenciones de Tránsito").
/// El número de artículo SÍ está completo y es confiable; la
/// descripción es orientativa. Antes de usarlo en un documento
/// oficial, conviene que Xavier confirme el texto exacto (una captura
/// más ancha, o copiando el texto directo de SIIPNE).
///
/// - "Accidente de Tránsito" no tiene sub-lista: su "Detalle causa" es
///   la misma causa, sin desplegable (así lo pidió Xavier).
/// - "Orden Judicial" tampoco tiene sub-lista: su "Detalle causa" es
///   un casillero libre para escribir el N° de Orden.
class CausaLegalCatalogo {
  static const causaAccidenteTransito = 'Accidente de Tránsito /Por accidente de Tránsito';
  static const causaOrdenJudicial = 'Orden Judicial /Orden Judicial';

  static const List<String> causas = [
    'Acuerdo Ministerial 00004 /ACUERDO MINISTERIAL 10',
    'Contravenciones de Tránsito /Artículos que permiten en el COIP la retención de los vehículos',
    'Reglamento a la LTTTSV /Artículos del Reglamento de Tránsito que estipulan la retención del vehículo.',
    causaAccidenteTransito,
    causaOrdenJudicial,
  ];

  static const Map<String, List<String>> detalles = {
    'Acuerdo Ministerial 00004 /ACUERDO MINISTERIAL 10': [
      'Artículo 10 /Verificación del incumplimiento al toque de queda.',
      'Artículo 11 /Verificación de la violación a la restricción de circulación vehicular según el último dígito de la placa.',
      'Artículo 12 /Verificación del mal uso o uso fraudulento del salvoconducto.',
    ],
    'Contravenciones de Tránsito /Artículos que permiten en el COIP la retención de los vehículos': [
      'Artículo 383 /Conducción de vehículo con llantas en mal estado.',
      'Artículo 383.i2 /Conducción de vehículo con llantas en mal estado (transporte público).',
      'Artículo 384 /Conducción bajo efecto de sustancias estupefacientes, psicotrópicas o preparados que las contengan.',
      'Artículo 385.1 /Nivel de alcohol de 0,3 a 0,8 gramos por litro de sangre.',
      'Artículo 385.2 /Nivel de alcohol mayor de 0,8 hasta 1,2 gramos por litro de sangre.',
      'Artículo 385.3 /Nivel de alcohol superior a 1,2 gramos por litro de sangre.',
      'Artículo 385.4 /Conductores de transporte público, comercial o de carga bajo efectos del alcohol.',
      'Artículo 386.1 /Conducir sin haber obtenido licencia.',
      'Artículo 386.i2.1 /Transportar pasajeros o bienes sin el título habilitante correspondiente.',
      'Artículo 386.i2.2 /Conducir con una licencia de categoría diferente a la exigida.',
      'Artículo 386.i2.3 /Participar con vehículos a motor en competencias en la vía pública.',
      'Artículo 389.7 /Conducir un vehículo que no cumpla las normas y condiciones técnico-mecánicas.',
      'Artículo 391.5 /Estacionar un vehículo en sitios prohibidos por la ley o los reglamentos.',
    ],
    'Reglamento a la LTTTSV /Artículos del Reglamento de Tránsito que estipulan la retención del vehículo.': [
      'Artículo 160 /Circular sin poseer la matrícula vigente.',
      'Artículo 177 /Circular sin los títulos habilitantes correspondientes.',
    ],
    // Sin sub-lista a propósito — ver comportamiento especial en
    // formulario_screen.dart.
    causaAccidenteTransito: [],
    causaOrdenJudicial: [],
  };

  static bool tieneDesplegable(String causa) => (detalles[causa] ?? []).isNotEmpty;
}
