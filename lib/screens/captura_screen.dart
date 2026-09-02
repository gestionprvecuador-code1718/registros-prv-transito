// RUTA DE ARCHIVO: lib/screens/captura_screen.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../models/caso_ingreso.dart';
import '../services/api_key_service.dart';
import 'formulario_screen.dart';

class CapturaScreen extends StatefulWidget {
  const CapturaScreen({super.key});

  @override
  State<CapturaScreen> createState() => _CapturaScreenState();
}

class _CapturaScreenState extends State<CapturaScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _estaProcesando = false;
  String _estadoProcesamiento = '';
  String? _error;

  // 30/ago: se conservan los últimos bytes capturados (foto, galería o
  // PDF) para poder REINTENTAR sin pedirle al oficial que vuelva a
  // tomar la foto o elegir el archivo — antes se perdía al fallar.
  Uint8List? _ultimosBytes;
  String? _ultimoMimeType;

  // 31/ago: esta pantalla leía la API Key directo de SharedPreferences
  // con una clave escrita a mano ('gemini_api_key'), que NO es
  // necesariamente la misma que usa ApiKeyService (la clase real que
  // usa ajustes_screen.dart para GUARDAR la clave). Si los nombres no
  // coincidían, Ajustes mostraba "ya tienes una API key configurada"
  // pero esta pantalla seguía sin encontrarla — eso explica el error
  // "No hay una API Key de Gemini configurada" que Xavier reportó
  // incluso después de guardarla. Ahora se usa el mismo servicio.
  final _apiKeyService = ApiKeyService();

  Future<String?> _obtenerApiKey() => _apiKeyService.obtenerApiKey();

  Future<void> _elegirImagen(ImageSource origen) async {
    final XFile? imagen = await _picker.pickImage(source: origen, imageQuality: 85);
    if (imagen == null) return;
    final bytes = await imagen.readAsBytes();
    setState(() {
      _ultimosBytes = bytes;
      _ultimoMimeType = 'image/jpeg';
      _error = null;
    });
    await _procesarConIA();
  }

  Future<void> _elegirPdf() async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    final archivo = resultado?.files.single;
    if (archivo?.bytes == null) return;
    setState(() {
      _ultimosBytes = archivo!.bytes;
      _ultimoMimeType = 'application/pdf';
      _error = null;
    });
    await _procesarConIA();
  }

  static final _prompt = TextPart('''
Analiza el siguiente documento oficial de tránsito/policial (Parte Policial, Hoja de Ingreso, Alcoholemia o Memorando) y extrae los datos en formato JSON estricto.

Reglas de Normalización y Sinónimos:
- tipoVehiculo: Normalizar a uno de estos: AUTOMÓVIL, MOTOCICLETA, CAMIONETA, AUTOBÚS, CAMIÓN, TRAILER. (Ejemplo: "moto", "pasola", "moped" -> "MOTOCICLETA").
- tipoOperativo: "SIN OPERATIVO" si no se menciona un operativo específico; "OPERATIVO N°" (y extraer el número en numeroOperativo) si el documento menciona un operativo con número.
- Alcoholemia: Si ves valores en g/L o texto de prueba de alcohol, extrae numeroPruebaAlcoholemia, resultadoAlcoholemia, nombreSancionado y cedulaSancionado, y marca aplicaAlcohotest en true.
- Motocicleta: Si es motocicleta, intenta extraer el cilindraje en cc.
- traslado: "SUS PROPIOS MEDIOS" si el vehículo llegó por su cuenta, "PARTICULAR" si lo trajo una grúa/wincha particular.

Responde ÚNICAMENTE con el siguiente JSON:
{
  "hojaIngresoNro": "", "parteIngresoNro": "", "fechaIngreso": "", "horaRetencion": "",
  "subzona": "", "crv": "", "tipoOperativo": "", "numeroOperativo": "",
  "placa": "", "marca": "", "modelo": "", "anioFabricacion": "",
  "color": "", "tipoVehiculo": "", "cilindraje": "", "chasis": "", "motor": "",
  "causaLegal": "", "detalleCausa": "",
  "aplicaAlcohotest": false, "numeroPruebaAlcoholemia": "", "resultadoAlcoholemia": "",
  "nombreSancionado": "", "cedulaSancionado": "",
  "propietario": "", "cedulaPropietario": "", "conductor": "", "cedulaConductor": "",
  "traslado": "", "nombreGruaParticular": "", "telefonoGruaParticular": "", "valorGrua": "", "kmGrua": "",
  "custodioRecibeNombre": "", "policiaNombre": "", "policiaCedula": ""
}
''');

  Future<void> _procesarConIA() async {
    if (_ultimosBytes == null || _ultimoMimeType == null) return;

    final apiKey = await _obtenerApiKey();
    if (apiKey == null) {
      setState(() => _error =
          'No hay una API Key de Gemini configurada. Ve a "Ajustes de IA" (⚙️ en la pantalla principal) y agrégala, o usa "Llenar a mano" por ahora.');
      return;
    }

    setState(() {
      _estaProcesando = true;
      _estadoProcesamiento = 'Analizando documento con Inteligencia Artificial...';
      _error = null;
    });

    const intentosMax = 3;
    for (var intento = 1; intento <= intentosMax; intento++) {
      try {
        // 01/sep: 'gemini-1.5-flash' fue DADO DE BAJA por Google (error real:
        // "models/gemini-1.5-flash is not found for API version v1beta").
        // Esto — y NO tu internet — era lo que impedía subir cualquier
        // parte hasta ahora. Se usa el alias 'gemini-flash-latest', que
        // Google mantiene apuntando siempre a un modelo Flash vigente, para
        // que la app no se vuelva a romper la próxima vez que retiren una
        // versión.
        final model = GenerativeModel(model: 'gemini-flash-latest', apiKey: apiKey);
        final content = [
          Content.multi([_prompt, DataPart(_ultimoMimeType!, _ultimosBytes!)])
        ];
        final response = await model.generateContent(content).timeout(const Duration(seconds: 45));

        if (response.text == null) {
          throw Exception('La IA no devolvió texto.');
        }
        _irAlFormulario(response.text!);
        return;
      } catch (e) {
        final texto = e.toString();
        final esErrorDeRed = texto.contains('SocketException') ||
            texto.contains('ClientException') ||
            texto.contains('Failed host lookup') ||
            texto.contains('TimeoutException') ||
            texto.contains('connection abort');
        // 01/sep: si Google vuelve a retirar el modelo en el futuro, este
        // mensaje evita que se muestre el error crudo de la API.
        final esModeloNoDisponible =
            texto.contains('is not found for API version') || texto.contains('not supported for generateContent');
        // 02/sep: error real reportado por Xavier — servidor de Google
        // saturado temporalmente ("Server Error [503]... currently
        // experiencing high demand... status: UNAVAILABLE"). Antes NO se
        // reintentaba (solo se reintentaban errores de red), así que se
        // mostraba de una sola vez en lugar de insistir como con la
        // conexión. Ahora también se reintenta.
        final esServidorSaturado =
            texto.contains('UNAVAILABLE') || texto.contains('503') || texto.contains('high demand');

        if ((esErrorDeRed || esServidorSaturado) && intento < intentosMax) {
          if (mounted) {
            setState(() => _estadoProcesamiento = esServidorSaturado
                ? 'El servicio de IA está saturado, reintentando (${intento + 1}/$intentosMax)...'
                : 'Problema de conexión, reintentando (${intento + 1}/$intentosMax)...');
          }
          await Future.delayed(Duration(seconds: 2 * intento)); // 2s, luego 4s
          continue;
        }

        if (mounted) {
          setState(() {
            _estaProcesando = false;
            // 31/ago (ronda 2): las 2 capturas que compartió Xavier son
            // errores de RED/DNS (ClientException / "Failed host
            // lookup"), no del código ni de la API Key — ya se reintentó
            // 3 veces automáticamente y las 3 fallaron por conexión.
            // Mensaje más claro para que sepa que es su wifi/datos, no
            // un bug de la app.
            _error = esErrorDeRed
                ? 'No se pudo conectar a internet para analizar el documento (se reintentó $intentosMax veces). '
                    'Revisa tu wifi o datos móviles e inténtalo de nuevo, o usa "Llenar a mano" mientras tanto.'
                : esServidorSaturado
                    ? 'El servicio de IA de Google está saturado en este momento (se reintentó $intentosMax veces). '
                        'No es un problema de tu conexión ni de la app — espera unos minutos y toca "Reintentar", '
                        'o usa "Llenar a mano" mientras tanto.'
                    : esModeloNoDisponible
                        ? 'El servicio de IA no está disponible en este momento (no es un problema de tu conexión). '
                            'Usa "Llenar a mano" mientras se soluciona, o avísale a Xavier.'
                        : 'Error al procesar el documento: $e';
          });
        }
        return;
      }
    }
  }

  void _irAlFormulario(String jsonResponseText) {
    final cleanJson = jsonResponseText.replaceAll('```json', '').replaceAll('```', '').trim();
    CasoIngreso? caso;
    try {
      final data = jsonDecode(cleanJson) as Map<String, dynamic>;
      data['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      caso = CasoIngreso.fromJson(data);
    } catch (_) {
      caso = null; // si el JSON viene mal formado, el formulario se abre vacío (llenar a mano)
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => FormularioScreen(casoExistente: caso)),
    );
  }

  void _llenarAMano() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const FormularioScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear Documento / Parte'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Center(
        child: _estaProcesando
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(_estadoProcesamiento, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.document_scanner, size: 80, color: Colors.blueGrey),
                    const SizedBox(height: 20),
                    const Text(
                      'OCR Progresivo Inteligente',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Toma una foto, selecciona una imagen o sube el PDF del parte policial u hoja de ingreso. '
                      'La IA extraerá los datos y autocompletará solo los casilleros vacíos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  if (_ultimosBytes != null)
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Reintentar'),
                                      onPressed: _procesarConIA,
                                    ),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined),
                                    label: const Text('Llenar a mano'),
                                    onPressed: _llenarAMano,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _elegirImagen(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('TOMAR FOTO CON LA CÁMARA'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.blueGrey[900],
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _elegirImagen(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('SELECCIONAR DE LA GALERÍA'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _elegirPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('SUBIR PARTE POLICIAL (PDF)'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _llenarAMano,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Prefiero llenar el formulario a mano'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
