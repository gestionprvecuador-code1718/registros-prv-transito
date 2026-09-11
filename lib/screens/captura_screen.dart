// RUTA DE ARCHIVO: lib/screens/captura_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'home_screen.dart';
import 'formulario_screen.dart';
import 'formulario_libertad_screen.dart';
import 'seleccionar_vehiculo_screen.dart';
import 'ajustes_screen.dart';
import '../services/gemini_vision_service.dart';
import '../services/api_key_service.dart';
import '../services/pdf_parser_service.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';

class CapturaScreen extends StatefulWidget {
  final TipoParte tipo;

  /// Ingreso del que nace la Libertad (viene de "Liberar vehículo" en
  /// Buscar por placa / Ver ingresos). Solo se usa cuando tipo ==
  /// TipoParte.libertad — permite heredar placa/marca/color/hoja/
  /// causa y combinar esos datos con lo que Gemini extraiga de las
  /// fotos nuevas (memorando, oficio, orden de pago, comprobante).
  final CasoIngreso? ingresoBase;

  const CapturaScreen({super.key, required this.tipo, this.ingresoBase});

  @override
  State<CapturaScreen> createState() => _CapturaScreenState();
}

class _CapturaScreenState extends State<CapturaScreen> {
  final List<File> _imagenes = [];
  final ImagePicker _picker = ImagePicker();
  bool _procesando = false;

  String get _titulo => widget.tipo == TipoParte.ingreso
      ? 'Nuevo Ingreso'
      : (widget.ingresoBase != null ? 'Liberar vehículo — ${widget.ingresoBase!.placa}' : 'Nueva Libertad');

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
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (resultado == null || resultado.files.single.bytes == null) return;

    setState(() => _procesando = true);
    try {
      final bytes = resultado.files.single.bytes!;
      final parser = PdfParserService();
      final texto = parser.extraerTextoBytes(bytes);
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
          builder: (_) => SeleccionarVehiculoScreen(participantes: participantes, metadatos: metadatos, textoCompleto: texto),
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
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      if (widget.tipo == TipoParte.ingreso) {
        final datos = await gemini.extraerIngreso(_imagenes, apiKey);
        final caso = CasoIngreso(
          id: id,
          hojaIngresoNro: datos['hojaIngresoNro'] ?? '',
          parteIngresoNro: datos['parteIngresoNro'] ?? '',
          crv: datos['crv'] ?? '',
          subzona: datos['subzona'] ?? '',
          fechaIngreso: datos['fechaIngreso'] ?? '',
          horaRetencion: datos['horaRetencion'] ?? '',
          tipoVehiculo: datos['tipoVehiculo'] ?? '',
          marca: datos['marca'] ?? '',
          modelo: datos['modelo'] ?? '',
          anioFabricacion: datos['anioFabricacion'] ?? '',
          color: datos['color'] ?? '',
          cilindraje: datos['cilindraje'] ?? '',
          chasis: datos['chasis'] ?? '',
          motor: datos['motor'] ?? '',
          placa: datos['placa'] ?? '',
          propietario: datos['propietario'] ?? '',
          cedulaPropietario: datos['cedulaPropietario'] ?? '',
          conductor: datos['conductor'] ?? '',
          cedulaConductor: datos['cedulaConductor'] ?? '',
          causaLegal: datos['causaLegal'] ?? '',
          detalleCausa: datos['detalleCausa'] ?? '',
          traslado: datos['traslado'] ?? '',
          custodioRecibeNombre: datos['custodioRecibeNombre'] ?? '',
          policiaNombre: datos['policiaNombre'] ?? '',
          policiaCedula: datos['policiaCedula'] ?? '',
        );
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: caso)));
      } else {
        final ingreso = widget.ingresoBase;
        // datos = lo que Gemini logre leer de las fotos nuevas
        // (memorando, oficio, juez que firma, orden de pago, comprobante...)
        final datos = await gemini.extraerLibertad(_imagenes, apiKey);

        final huboDatosDePago = (datos['ordenPagoNro'] ?? datos['comprobantePagoNro'] ?? datos['valor']) != null &&
            ((datos['ordenPagoNro'] ?? '').isNotEmpty ||
                (datos['comprobantePagoNro'] ?? '').isNotEmpty ||
                (datos['valor'] ?? '').isNotEmpty);

        final pagos = huboDatosDePago
            ? [
                PagoGaraje(
                  ordenPagoNro: datos['ordenPagoNro'] ?? '',
                  comprobantePagoNro: datos['comprobantePagoNro'] ?? '',
                  diasPagados: datos['diasPagados'] ?? '',
                  precioUnitario: datos['precioUnitario'] ?? '',
                  valor: datos['valor'] ?? '',
                  horaFechaPago: datos['horaFechaPago'] ?? '',
                  entidadFinanciera: datos['entidadFinanciera'] ?? '',
                ),
              ]
            : [PagoGaraje()];

        final observacionComision = (datos['valorTransaccionOComision'] ?? '').trim();

        final caso = CasoLibertad(
          id: id,
          // Heredado del Ingreso, con la extracción de Gemini como
          // respaldo si por algún motivo no viniera el ingreso base.
          hojaIngresoNro: ingreso?.hojaIngresoNro ?? datos['hojaIngresoNro'] ?? '',
          parteIngresoNro: ingreso?.parteIngresoNro ?? '',
          marca: ingreso?.marca ?? datos['marca'] ?? '',
          color: ingreso?.color ?? datos['color'] ?? '',
          placa: ingreso?.placa ?? datos['placa'] ?? '',
          tipoVehiculo: ingreso?.tipoVehiculo ?? '',
          crv: ingreso?.crv ?? '',
          causa: ingreso != null
              ? [ingreso.causaLegal, ingreso.detalleCausa].where((s) => s.trim().isNotEmpty).join(' - ')
              : '',
          fechaIngreso: ingreso?.fechaIngreso ?? datos['fechaIngreso'] ?? '',
          tipoServicioGaraje: datos['tipoServicioGaraje'] ?? '',
          // Genuinamente nuevo de Libertad: siempre viene de esta extracción.
          memorandoNro: datos['memorandoNro'] ?? '',
          memorandoFecha: datos['memorandoFecha'] ?? '',
          oficioDevolucionNro: datos['oficioDevolucionNro'] ?? '',
          oficioDevolucionFecha: datos['oficioDevolucionFecha'] ?? '',
          firmadoPor: datos['firmadoPor'] ?? '',
          retiradoPor: datos['retiradoPor'] ?? '',
          cedulaRetira: datos['cedulaRetira'] ?? '',
          fechaSalida: datos['fechaSalida'] ?? '',
          observaciones: observacionComision.isNotEmpty
              ? 'El comprobante muestra un valor de transacción/comisión de $observacionComision aparte del valor base.'
              : '',
          pagos: pagos,
        );
        if (!mounted) return;
        if (ingreso != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => FormularioLibertadScreen(ingreso: ingreso, existente: caso)),
          );
        } else {
          // No debería pasar en el flujo normal (siempre se viene de
          // un Ingreso ya guardado), pero se maneja por seguridad.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se encontró el Ingreso base para esta Libertad.')),
            );
          }
        }
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
    if (widget.tipo == TipoParte.ingreso) {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: CasoIngreso(id: id))),
      );
    } else {
      final ingreso = widget.ingresoBase;
      if (ingreso == null) {
        Navigator.pop(context);
        return;
      }
      // FormularioLibertadScreen ya sabe construir un CasoLibertad
      // nuevo a partir del ingreso cuando no se le pasa "existente".
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FormularioLibertadScreen(ingreso: ingreso)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titulo)),
      body: Column(
        children: [
          if (widget.ingresoBase != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Ya se heredaron los datos del Ingreso (Hoja ${widget.ingresoBase!.hojaIngresoNro}). '
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
                  if (widget.tipo == TipoParte.ingreso) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Subir documento PDF (parte policial)'),
                        onPressed: _procesando ? null : _elegirPdf,
                      ),
                    ),
                  ],
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
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _procesando ? null : _abrirFormularioVacio,
                    child: const Text('Omitir fotos y llenar el resto a mano'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
