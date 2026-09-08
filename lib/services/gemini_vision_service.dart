import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Envía una o varias fotos a Google Gemini (modelo con visión) y le pide
/// que devuelva directamente los datos del formulario en JSON.
///
/// A diferencia del OCR local (que falla mucho con letra manuscrita),
/// un modelo de IA con visión "entiende" la imagen completa como lo
/// haría una persona, así que interpreta bastante mejor la letra a
/// mano — a costa de necesitar internet y una API key.
///
/// La API key es gratuita: se obtiene en https://aistudio.google.com/apikey
class GeminiVisionService {
  static const _modelo = 'gemini-3.6-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelo:generateContent';

  static const _camposIngreso = [
    'hojaIngresoNro',
    'crv',
    'fechaIngreso',
    'tipoVehiculo',
    'marca',
    'color',
    'placa',
    'propietario',
    'cedulaPropietario',
    'causa',
    'comoLlego',
    'tomaProcedimiento',
  ];

  /// Campos de Libertad — ahora cubren TODOS los documentos posibles:
  /// hoja física de salida, oficio judicial de devolución/memorando,
  /// y orden de pago + comprobante bancario/Datafast.
  static const _camposLibertad = [
    // De la hoja física de salida (si se fotografía también):
    'hojaIngresoNro',
    'marca',
    'color',
    'placa',
    'fechaIngreso',
    'fechaSalida',
    'retiradoPor',
    'cedulaRetira',
    // Del oficio judicial de devolución / memorando:
    'memorandoNro',
    'memorandoFecha',
    'oficioDevolucionNro',
    'oficioDevolucionFecha',
    'firmadoPor',
    // De la Orden de Pago (Agencia Nacional de Tránsito):
    'ordenPagoNro',
    'diasPagados',
    'precioUnitario',
    'tipoServicioGaraje',
    // Del comprobante bancario / Datafast:
    'comprobantePagoNro',
    'valor',
    'valorTransaccionOComision',
    'horaFechaPago',
    'entidadFinanciera',
  ];

  Future<Map<String, String>> extraerIngreso(List<File> imagenes, String apiKey) =>
      _extraer(imagenes, apiKey, _camposIngreso, _promptIngreso);

  Future<Map<String, String>> extraerLibertad(List<File> imagenes, String apiKey) =>
      _extraer(imagenes, apiKey, _camposLibertad, _promptLibertad);

  static const _promptIngreso = '''
Eres un asistente que digitaliza hojas de "RECEPCIÓN DEL VEHÍCULO EN EL PATIO DE RETENCIÓN VEHICULAR DE TRÁNSITO" de la Policía Nacional del Ecuador.
La hoja tiene texto impreso (etiquetas) y datos llenados a mano (a veces con letra cursiva difícil).
Extrae SOLO los siguientes datos de la parte SUPERIOR de la hoja (ingreso), en JSON, sin explicaciones, sin markdown:
- hojaIngresoNro: el número impreso en rojo en la esquina superior derecha (7 dígitos aprox., ej. "0002099")
- crv: el nombre del control/CRV (ej. "Control 120")
- fechaIngreso: fecha de ingreso en formato dd/mm/aaaa
- tipoVehiculo: tipo de vehículo si se menciona (ej. "Plataforma"), si no aparece deja ""
- marca: marca del vehículo (ej. "SINOTRUCK")
- color: color del vehículo
- placa: placas del vehículo (formato ecuatoriano, 3 letras + números, ej. "PAD-1978")
- propietario: nombre completo del propietario
- cedulaPropietario: número de cédula del propietario. Búscalo primero junto al nombre del propietario en la parte superior; si no aparece ahí, búscalo en la sección inferior "RECIBE CONFORME" o junto a la palabra "Yo" (quien retira el vehículo) — a veces solo está ahí. Si viene de un PDF con varios datos del propietario/conductor, tómalo de esa sección.
- causa: causa de la detención (ej. "Accidente de tránsito")
- comoLlego: quién entrega el vehículo / cómo llegó
- tomaProcedimiento: quién elabora el parte policial (grado y nombre)
Si un dato no aparece o no se puede leer con confianza, usa "" (cadena vacía). NUNCA inventes datos.
Responde ÚNICAMENTE el objeto JSON con esas claves.''';

  static const _promptLibertad = '''
Eres un asistente que digitaliza documentos para la LIBERTAD (devolución) de un vehículo retenido, de la Policía Nacional del Ecuador. Vas a recibir VARIAS fotos que pueden ser de HASTA TRES documentos distintos — no todas las fotos son del mismo documento, así que revisa cada una por separado antes de decidir de dónde sale cada dato:

DOCUMENTO A — Hoja física de control (sección inferior "SALIDA DEL VEHÍCULO DEL PATIO DE RETENCIÓN DE TRÁNSITO", llenada a mano/esfero):
- hojaIngresoNro: número impreso en rojo en la esquina superior derecha de la hoja
- marca, color, placa: datos del vehículo (arriba de la hoja)
- fechaIngreso: fecha de ingreso (arriba) en formato dd/mm/aaaa
- fechaSalida: fecha de salida (sección inferior) en formato dd/mm/aaaa
- retiradoPor: el nombre que sigue a la palabra "Yo" en la sección de salida
- cedulaRetira: número de cédula en la sección "RECIBE CONFORME" de abajo

DOCUMENTO B — Oficio/memorando judicial de devolución de vehículo (documento de un Juez o Fiscal, con membrete de una Unidad Judicial o Fiscalía):
- memorandoNro: número que aparece después de "Memorando Nro." o similar
- memorandoFecha: fecha de ese memorando, formato dd/mm/aaaa
- oficioDevolucionNro: número después de "Oficio de DEVOLUCIÓN DE VEHÍCULO Nro." o similar
- oficioDevolucionFecha: fecha de ese oficio, formato dd/mm/aaaa
- firmadoPor: nombre completo y cargo de quien firma el oficio (ej. "Dr. Fulano de Tal, Juez de la Unidad Judicial de Tránsito de...")

DOCUMENTO C1 — Orden de Pago (formato "SOLICITUD DE PAGO" / "ORDEN DE PAGO No." de la Agencia Nacional de Tránsito):
- ordenPagoNro: número después de "ORDEN DE PAGO No."
- diasPagados: el número de la columna "Cantidad" (cantidad de días)
- precioUnitario: el número de la columna "Precio Unitario", sin símbolo de dólar
- tipoServicioGaraje: el texto completo de la fila "Rubro"/"Servicio" tal como aparece impreso (ej. "SERVICIO DE GARAJE PESADOS (DE 3,51 TN HASTA 12 TN)") — transcríbelo literal, no lo resumas ni lo interpretes

DOCUMENTO C2 — Comprobante bancario o de Datafast (recibo de pago):
- comprobantePagoNro: número de comprobante/referencia/autorización del pago
- valor: el monto TOTAL realmente cobrado en el comprobante, sin símbolo de dólar (incluye cualquier comisión si aparece sumada)
- valorTransaccionOComision: si el comprobante muestra por separado un "valor de la transacción" o comisión, colócalo aquí; si no aparece, usa ""
- horaFechaPago: fecha y hora del pago tal como aparecen
- entidadFinanciera: nombre del banco o entidad

REGLAS IMPORTANTES:
- Si no ves el Documento A en las fotos, igual intenta llenar los campos de marca/color/placa si aparecen en cualquier otro documento (a veces el comprobante o el oficio también los mencionan); si no aparecen en ninguna foto, usa "".
- Si un dato no aparece en NINGUNA de las fotos o no se puede leer con confianza, usa "" (cadena vacía). NUNCA inventes ni calcules valores.
- No confundas el "valor" del comprobante bancario con el "precioUnitario" de la Orden de Pago: son documentos distintos.
Responde ÚNICAMENTE el objeto JSON con las claves: hojaIngresoNro, marca, color, placa, fechaIngreso, fechaSalida, retiradoPor, cedulaRetira, memorandoNro, memorandoFecha, oficioDevolucionNro, oficioDevolucionFecha, firmadoPor, ordenPagoNro, diasPagados, precioUnitario, tipoServicioGaraje, comprobantePagoNro, valor, valorTransaccionOComision, horaFechaPago, entidadFinanciera.''';

  Future<Map<String, String>> _extraer(
    List<File> imagenes,
    String apiKey,
    List<String> campos,
    String prompt,
  ) async {
    final parts = <Map<String, dynamic>>[
      {'text': prompt}
    ];

    for (final img in imagenes) {
      final bytes = await img.readAsBytes();
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': base64Encode(bytes),
        }
      });
    }

    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {'response_mime_type': 'application/json'},
    });

    final respuesta = await http
        .post(
          Uri.parse('$_endpoint?key=$apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    if (respuesta.statusCode != 200) {
      throw Exception('Gemini respondió ${respuesta.statusCode}: ${respuesta.body}');
    }

    final data = jsonDecode(respuesta.body);
    final texto = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (texto == null) {
      throw Exception('Respuesta inesperada de Gemini: ${respuesta.body}');
    }

    final json = jsonDecode(texto) as Map<String, dynamic>;
    return {for (final campo in campos) campo: (json[campo] ?? '').toString()};
  }
}
