import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'home_screen.dart';
import 'formulario_screen.dart';
import 'seleccionar_vehiculo_screen.dart';
import 'ajustes_screen.dart';
import '../services/gemini_vision_service.dart';
import '../services/api_key_service.dart';
import '../services/pdf_parser_service.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

class CapturaScreen extends StatefulWidget {
  final TipoParte tipo;

  /// Caso de Libertad ya prellenado (desde "Liberar vehículo" en
  /// Buscar por placa). Si viene, NO se crea un CasoLibertad en
  /// blanco: se combinan los datos ya heredados del Ingreso con lo
  /// que Gemini extraiga de las fotos nuevas (memorando, oficio,
  /// pagos, etc.).
  final CasoLibertad? casoLibertadBase;

  const CapturaScreen({super.key, required this.tipo, this.casoLibertadBase});

  @override
  State<CapturaScreen> createState() => _CapturaScreenState();
}

class _CapturaScreenState extends State<CapturaScreen> {
  final List<File> _imagenes = [];
  final ImagePicker _picker = ImagePicker();
  bool _procesando = false;

  String get _titulo => widget.tipo == TipoParte.ingreso
      ? 'Nuevo Ingreso'
      : (widget.casoLibertadBase != null ? 'Liberar vehículo — ${widget.casoLibertadBase!.placa}' : 'Nueva Libertad');

  Future<void> _tomarFoto() async {
    final foto = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (foto != null) setState(() => _imagenes.add(File(foto.path)));
  }

  Future<void> _elegirDeGaleria() async {
    final fotos = await _picker.pickMultiImage(imageQuality: 90);
    if (fotos.isNotEmpty) {
      setState(() => _imagenes.addAll(fotos.map((f) => File(f.path))));
    }
  }

  Future<void> _elegirPdf() async {
    final resultado = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (resultado == null || resultado.files.single.path == null) return;

    setState(() => _procesando = true);
    try {
      final pdfFile = File(resultado.files.single.path!);
      final parser = PdfParserService();
      final texto = parser.extraerTexto(pdfFile);
      final metadatos = parser.extraerMetadatos(texto);
      final participantes = parser.extraerParticipantes(texto);

      if (!mounted) return;

      if (participantes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se detectó ningún vehículo en este PDF. Prueba con las fotos.')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeleccionarVehiculoScreen(participantes: participantes, metadatos: metadatos),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo leer el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _procesar() async {
    if (_imagenes.isEmpty) return;

    final apiKey = await ApiKeyService().obtenerApiKey();
    if (apiKey == null) {
      if (!mounted) return;
      final configurar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Falta configurar la IA'),
          content: const Text(
              'Todavía no has guardado tu API key gratuita de Gemini. Puedes configurarla ahora, '
              'o llenar el formulario a mano sin usar IA.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Llenar a mano')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Configurar ahora')),
          ],
        ),
      );
      if (configurar == true) {
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const AjustesScreen()));
        return; // el usuario vuelve a tocar "Extraer datos" luego de configurar
      } else {
        _abrirFormularioVacio();
        return;
      }
    }

    setState(() => _procesando = true);
    final gemini = GeminiVisionService();
    final id = widget.casoLibertadBase?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    try {
      if (widget.tipo == TipoParte.ingreso) {
        final datos = await gemini.extraerIngreso(_imagenes, apiKey);
        final caso = CasoIngreso(
          id: id,
          hojaIngresoNro: datos['hojaIngresoNro'] ?? '',
          crv: datos['crv'] ?? '',
          fechaIngreso: datos['fechaIngreso'] ?? '',
          tipoVehiculo: datos['tipoVehiculo'] ?? '',
          marca: datos['marca'] ?? '',
          color: datos['color'] ?? '',
          placa: datos['placa'] ?? '',
          propietario: datos['propietario'] ?? '',
          cedulaPropietario: datos['cedulaPropietario'] ?? datos['cedula'] ?? '',
          causa: datos['causa'] ?? '',
          comoLlego: datos['comoLlego'] ?? '',
          tomaProcedimiento: datos['tomaProcedimiento'] ?? '',
        );
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: caso)));
      } else {
        // datos = lo que Gemini logre leer de las fotos nuevas
        // (memorando, oficio, juez que firma, orden de pago, comprobante...)
        final datos = await gemini.extraerLibertad(_imagenes, apiKey);
        final base = widget.casoLibertadBase;

        // Si viene un pago nuevo extraído (orden de pago / comprobante),
        // se arma como PagoGaraje; si no se extrajo nada de pago, se
        // conserva el/los pago(s) que ya traía el caso base (o uno vacío).
        List<PagoGaraje> pagos;
        final huboDatosDePago = (datos['ordenPagoNro'] ?? datos['comprobantePagoNro'] ?? datos['valor']) != null;
        if (huboDatosDePago) {
          pagos = [
            PagoGaraje(
              ordenPagoNro: datos['ordenPagoNro'] ?? '',
              comprobantePagoNro: datos['comprobantePagoNro'] ?? '',
              diasPagados: datos['diasPagados'] ?? datos['cantidadDias'] ?? '',
              precioUnitario: datos['precioUnitario'] ?? '',
              valor: datos['valor'] ?? datos['valorTotal'] ?? '',
              horaFechaPago: datos['horaFechaPago'] ?? '',
              entidadFinanciera: datos['entidadFinanciera'] ?? '',
            ),
          ];
        } else {
          pagos = base?.pagos ?? [PagoGaraje()];
        }

        final observacionComision = (datos['valorTransaccionOComision'] ?? '').trim();
        final caso = CasoLibertad(
          id: id,
          // Heredado del Ingreso (si venimos de "Liberar vehículo"),
          // con la extracción de Gemini como respaldo si algo faltara.
          hojaIngresoNro: base?.hojaIngresoNro ?? datos['hojaIngresoNro'] ?? '',
          parteIngresoNro: base?.parteIngresoNro ?? datos['parteIngresoNro'] ?? '',
          marca: base?.marca ?? datos['marca'] ?? '',
          color: base?.color ?? datos['color'] ?? '',
          placa: base?.placa ?? datos['placa'] ?? '',
          tipoVehiculo: base?.tipoVehiculo ?? datos['tipoVehiculo'] ?? '',
          crv: base?.crv ?? datos['crv'] ?? '',
          dirigidoA: base?.dirigidoA ?? datos['dirigidoA'] ?? 'Mi Mayor',
          causa: base?.causa ?? datos['causa'] ?? '',
          fechaIngreso: base?.fechaIngreso ?? datos['fechaIngreso'] ?? '',
          retiradoPor: base?.retiradoPor ?? datos['retiradoPor'] ?? '',
          cedulaRetira: base?.cedulaRetira ?? datos['cedulaRetira'] ?? '',
          // Genuinamente nuevo de Libertad: siempre viene de esta extracción.
          memorandoNro: datos['memorandoNro'] ?? '',
          memorandoFecha: datos['memorandoFecha'] ?? '',
          oficioDevolucionNro: datos['oficioDevolucionNro'] ?? '',
          oficioDevolucionFecha: datos['oficioDevolucionFecha'] ?? '',
          firmadoPor: datos['firmadoPor'] ?? '',
          fechaSalida: datos['fechaSalida'] ?? '',
          diasPermanencia: datos['diasPermanencia'] ?? '',
          observaciones: observacionComision.isNotEmpty
              ? 'El comprobante muestra un valor de transacción/comisión de $observacionComision aparte del valor base.'
              : (base?.observaciones ?? ''),
          pagos: pagos,
        );
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FormularioLibertadScreen(caso: caso)));
      }
    } catch (e) {
      if (!mounted) return;
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('No se pudo escanear'),
          content: Text('Puede ser que no haya internet en este momento, o la API key sea inválida.\n\nDetalle: $e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Reintentar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Llenar a mano')),
          ],
        ),
      );
      if (continuar == true) _abrirFormularioVacio();
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _abrirFormularioVacio() {
    final id = widget.casoLibertadBase?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    if (widget.tipo == TipoParte.ingreso) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: CasoIngreso(id: id))),
      );
    } else {
      // Si veníamos de "Liberar vehículo", igual conservamos lo
      // prellenado aunque el usuario decida llenar el resto a mano.
      final caso = widget.casoLibertadBase ?? CasoLibertad(id: id);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormularioLibertadScreen(caso: caso)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulo)),
      body: Column(
        children: [
          if (widget.casoLibertadBase != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ya se heredaron los datos del Ingreso (Hoja ${widget.casoLibertadBase!.hojaIngresoNro}). '
                'Toma fotos del oficio de devolución/memorando y de la orden de pago/comprobante para '
                'completar lo que falta.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: _imagenes.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Toma una o varias fotos de los documentos del caso\n'
                        '(parte policial, hoja de ingreso, memorando, etc.)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _imagenes.length,
                    itemBuilder: (context, i) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_imagenes[i],
                              fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() => _imagenes.removeAt(i)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(Icons.close, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Cámara'),
                          onPressed: _procesando ? null : _tomarFoto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                          onPressed: _procesando ? null : _elegirDeGaleria,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Subir documento PDF (parte policial)'),
                      onPressed: _procesando ? null : _elegirPdf,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _procesando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.document_scanner),
                      label: Text(_procesando ? 'Procesando...' : 'Extraer datos (OCR)'),
                      onPressed: (_imagenes.isEmpty || _procesando) ? null : _procesar,
                    ),
                  ),
                  if (widget.casoLibertadBase != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _procesando ? null : _abrirFormularioVacio,
                      child: const Text('Omitir fotos y llenar el resto a mano'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
