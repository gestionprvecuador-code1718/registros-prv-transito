// RUTA DE ARCHIVO: lib/screens/formulario_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/caso_ingreso.dart';
import '../services/storage_service.dart';
import '../widgets/campo_autocompletable.dart';
import 'documento_screen.dart';
import 'home_screen.dart';

void _verTextoOcr(BuildContext context, String? texto) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Texto que reconoció la cámara'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Text(
            (texto == null || texto.trim().isEmpty) ? '(no se reconoció ningún texto)' : texto,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    ),
  );
}

// ============================================================
// FORMULARIO: INGRESO
// ============================================================
//
// ORDEN DE SECCIONES (09/sep): replica el orden en que SIIPNE 3W pide
// los datos, tal como indicó Xavier, para evitar tener que saltar de
// un lado a otro y reescribir datos repetidos:
//   1. Tipo operativo
//   2. Fecha de retención
//   3. Hora de retención
//   4. Personal que toma procedimiento (nombre + cédula)
//   5. Propietario (nombre + cédula)
//   6. Conductor (nombre + cédula)
//   7. Causa legal -> Detalle de la causa
//   8. Datos del vehículo (placa, tipo, color, motor, chasis, marca,
//      modelo, año, cilindraje/estado)
//   9. Formulario N° (antes "Hoja de ingreso Nro.")
//  10. N° de Parte Web (Ingreso) (antes "Parte de ingreso Nro.")
//  11. Trasladado por... (sus propios medios / particular / policial)
//  12. Tipo de cobro (tonelaje -> autocompleta liviano/pesado/extrapesado)
//  13. Alcoholemia: Nombres del conductor (auto) / Cédula (auto) /
//      Prueba N° / Resultado / Citación N°
//  14. Personal Policial que Recibe la Custodia (al final)

class FormularioIngresoScreen extends StatefulWidget {
  final CasoIngreso caso;
  final String? textoOcr;
  final bool esEdicion;
  const FormularioIngresoScreen({super.key, required this.caso, this.textoOcr, this.esEdicion = false});

  @override
  State<FormularioIngresoScreen> createState() => _FormularioIngresoScreenState();
}

const _tiposVehiculo = ['AUTOMÓVIL', 'CAMIONETA', 'CAMIÓN', 'BUS', 'MOTOCICLETA', 'PLATAFORMA', 'OTRO'];

// NOTA: catálogo genérico de causas legales — Xavier pidió reemplazar
// esto por el listado real de artículos (383/384/385.1-4/386.1/
// 386.i2.1/386.i2.2 + 160/177 del reglamento) en una ronda anterior;
// falta que comparta el texto exacto de cada artículo para
// completarlo (ver notas del proyecto). Mientras tanto, "Detalle
// causa" queda libre para escribir el artículo exacto a mano.
const _causasLegales = [
  'Accidente de tránsito',
  'Infracción de tránsito',
  'Orden judicial',
  'Requerimiento fiscal',
  'Operativo de control',
  'Otro',
];

const _tiposCobroParqueo = ['LIVIANO', 'PESADO', 'MOTOCICLETA', 'EXTRAPESADO'];

const _tiposTraslado = ['SUS PROPIOS MEDIOS', 'PARTICULAR', 'GRÚA POLICIAL'];

class _FormularioIngresoScreenState extends State<FormularioIngresoScreen> {
  final _formKey = GlobalKey<FormState>();
  late CasoIngreso _caso;

  final _tipoOperativoNroCtrl = TextEditingController();
  final _fechaCtrl = TextEditingController();
  final _horaCtrl = TextEditingController();
  final _policiaNombreCtrl = TextEditingController();
  final _policiaCedulaCtrl = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _cedulaPropietarioCtrl = TextEditingController();
  final _conductorCtrl = TextEditingController();
  final _cedulaConductorCtrl = TextEditingController();
  final _detalleCausaCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _motorCtrl = TextEditingController();
  final _chasisCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();
  final _cilindrajeCtrl = TextEditingController();
  final _estadoVehiculoCtrl = TextEditingController();
  final _hojaCtrl = TextEditingController(); // "Formulario N°"
  final _parteCtrl = TextEditingController(); // "N° de Parte Web (Ingreso)"
  final _kmGruaCtrl = TextEditingController();
  final _valorGruaCtrl = TextEditingController();
  final _nombreGruaParticularCtrl = TextEditingController();
  final _telefonoGruaParticularCtrl = TextEditingController();
  final _tonelajeCtrl = TextEditingController();
  final _nombreSancionadoCtrl = TextEditingController();
  final _cedulaSancionadoCtrl = TextEditingController();
  final _numeroPruebaCtrl = TextEditingController();
  final _resultadoAlcoholemiaCtrl = TextEditingController();
  final _citacionCtrl = TextEditingController();
  final _custodioRecibeCtrl = TextEditingController();
  final _subzonaCtrl = TextEditingController();
  final _crvCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String _tipoVehiculo = 'AUTOMÓVIL';
  String _tipoOperativo = 'SIN OPERATIVO';
  String _causaLegal = 'Accidente de tránsito';
  String? _tipoCobroParqueo;
  String _traslado = 'SUS PROPIOS MEDIOS';
  bool _aplicaAlcohotest = false;

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _caso = widget.caso;

    _tipoOperativoNroCtrl.text = _caso.numeroOperativo;
    // Si es un caso nuevo (no edición) y no vino una fecha ya extraída
    // de fotos/PDF, se autocompleta con la fecha de hoy — el mismo
    // criterio que ya usa Libertad para "Fecha de Salida".
    _fechaCtrl.text = _caso.fechaIngreso.isEmpty && !widget.esEdicion
        ? DateFormat('dd/MM/yyyy').format(DateTime.now())
        : _caso.fechaIngreso;
    _horaCtrl.text = _caso.horaRetencion;
    _policiaNombreCtrl.text = _caso.policiaNombre;
    _policiaCedulaCtrl.text = _caso.policiaCedula;
    _propietarioCtrl.text = _caso.propietario;
    _cedulaPropietarioCtrl.text = _caso.cedulaPropietario;
    _conductorCtrl.text = _caso.conductor;
    _cedulaConductorCtrl.text = _caso.cedulaConductor;
    _detalleCausaCtrl.text = _caso.detalleCausa;
    _placaCtrl.text = _caso.placa;
    _colorCtrl.text = _caso.color;
    _motorCtrl.text = _caso.motor;
    _chasisCtrl.text = _caso.chasis;
    _marcaCtrl.text = _caso.marca;
    _modeloCtrl.text = _caso.modelo;
    _anioCtrl.text = _caso.anioFabricacion;
    _cilindrajeCtrl.text = _caso.cilindraje;
    _estadoVehiculoCtrl.text = _caso.estadoVehiculo;
    _hojaCtrl.text = _caso.hojaIngresoNro;
    _parteCtrl.text = _caso.parteIngresoNro;
    _kmGruaCtrl.text = _caso.kmGrua;
    _valorGruaCtrl.text = _caso.valorGrua;
    _nombreGruaParticularCtrl.text = _caso.nombreGruaParticular;
    _telefonoGruaParticularCtrl.text = _caso.telefonoGruaParticular;
    _tonelajeCtrl.text = _caso.tonelaje;
    // "Nombres del Conductor"/"Cédula" de Alcoholemia parten
    // precargados con los datos del conductor de arriba (editable, ver
    // _alTocarSwitchAlcoholemia), salvo que ya se hubiera guardado algo
    // distinto para el sancionado en una edición previa.
    _nombreSancionadoCtrl.text = _caso.nombreSancionado.isNotEmpty ? _caso.nombreSancionado : _caso.conductor;
    _cedulaSancionadoCtrl.text = _caso.cedulaSancionado.isNotEmpty ? _caso.cedulaSancionado : _caso.cedulaConductor;
    _numeroPruebaCtrl.text = _caso.numeroPruebaAlcoholemia;
    _resultadoAlcoholemiaCtrl.text = _caso.resultadoAlcoholemia;
    _citacionCtrl.text = _caso.citacionNro;
    _custodioRecibeCtrl.text = _caso.custodioRecibeNombre;
    _subzonaCtrl.text = _caso.subzona;
    _crvCtrl.text = _caso.crv.isEmpty ? 'Control 120' : _caso.crv;
    _observacionesCtrl.text = _caso.observaciones;

    _tipoVehiculo = _tiposVehiculo.contains(_caso.tipoVehiculo) ? _caso.tipoVehiculo : 'AUTOMÓVIL';
    _tipoOperativo = _caso.tipoOperativo.isEmpty ? 'SIN OPERATIVO' : _caso.tipoOperativo;
    _causaLegal = _causasLegales.contains(_caso.causaLegal) ? _caso.causaLegal : 'Accidente de tránsito';
    _tipoCobroParqueo = _tiposCobroParqueo.contains(_caso.tipoCobroParqueo) ? _caso.tipoCobroParqueo : null;
    _traslado = _tiposTraslado.contains(_caso.traslado) ? _caso.traslado : 'SUS PROPIOS MEDIOS';
    _aplicaAlcohotest = _caso.aplicaAlcohotest;

    _tonelajeCtrl.addListener(_autocompletarTipoCobro);
  }

  @override
  void dispose() {
    for (final c in [
      _tipoOperativoNroCtrl, _fechaCtrl, _horaCtrl, _policiaNombreCtrl, _policiaCedulaCtrl,
      _propietarioCtrl, _cedulaPropietarioCtrl, _conductorCtrl, _cedulaConductorCtrl, _detalleCausaCtrl,
      _placaCtrl, _colorCtrl, _motorCtrl, _chasisCtrl, _marcaCtrl, _modeloCtrl, _anioCtrl,
      _cilindrajeCtrl, _estadoVehiculoCtrl, _hojaCtrl, _parteCtrl, _kmGruaCtrl, _valorGruaCtrl,
      _nombreGruaParticularCtrl, _telefonoGruaParticularCtrl, _tonelajeCtrl, _nombreSancionadoCtrl,
      _cedulaSancionadoCtrl, _numeroPruebaCtrl, _resultadoAlcoholemiaCtrl, _citacionCtrl,
      _custodioRecibeCtrl, _subzonaCtrl, _crvCtrl, _observacionesCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Tarifario oficial (vigente 2021-2025): Livianos ≤3,5TN, Pesados
  /// 3,51-12TN, Extrapesados >12TN. Motocicletas siempre van aparte,
  /// sin importar el tonelaje.
  void _autocompletarTipoCobro() {
    if (_tipoVehiculo == 'MOTOCICLETA') {
      setState(() => _tipoCobroParqueo = 'MOTOCICLETA');
      return;
    }
    final tonelaje = double.tryParse(_tonelajeCtrl.text.replaceAll(',', '.'));
    if (tonelaje == null) return;
    String nuevo;
    if (tonelaje <= 3.5) {
      nuevo = 'LIVIANO';
    } else if (tonelaje <= 12) {
      nuevo = 'PESADO';
    } else {
      nuevo = 'EXTRAPESADO';
    }
    if (nuevo != _tipoCobroParqueo) setState(() => _tipoCobroParqueo = nuevo);
  }

  /// Al activar el switch de Alcoholemia, se precargan "Nombres del
  /// Conductor"/"Cédula" con lo ya escrito arriba en Conductor — sigue
  /// siendo editable por si la prueba se le hizo a otra persona.
  void _alActivarAlcoholemia(bool activo) {
    setState(() {
      _aplicaAlcohotest = activo;
      if (activo) {
        if (_nombreSancionadoCtrl.text.trim().isEmpty) _nombreSancionadoCtrl.text = _conductorCtrl.text;
        if (_cedulaSancionadoCtrl.text.trim().isEmpty) _cedulaSancionadoCtrl.text = _cedulaConductorCtrl.text;
      }
    });
  }

  void _aplicarCambiosACaso() {
    _caso
      ..hojaIngresoNro = _hojaCtrl.text.trim()
      ..parteIngresoNro = _parteCtrl.text.trim()
      ..fechaIngreso = _fechaCtrl.text.trim()
      ..horaRetencion = _horaCtrl.text.trim()
      ..subzona = _subzonaCtrl.text.trim()
      ..crv = _crvCtrl.text.trim()
      ..placa = _placaCtrl.text.trim()
      ..marca = _marcaCtrl.text.trim()
      ..modelo = _modeloCtrl.text.trim()
      ..anioFabricacion = _anioCtrl.text.trim()
      ..color = _colorCtrl.text.trim()
      ..tipoVehiculo = _tipoVehiculo
      ..cilindraje = _tipoVehiculo == 'MOTOCICLETA' ? _cilindrajeCtrl.text.trim() : ''
      ..chasis = _tipoVehiculo == 'MOTOCICLETA' ? '' : _chasisCtrl.text.trim()
      ..motor = _tipoVehiculo == 'MOTOCICLETA' ? '' : _motorCtrl.text.trim()
      ..numeroOperativo = _tipoOperativo == 'OPERATIVO N°' ? _tipoOperativoNroCtrl.text.trim() : ''
      ..tipoOperativo = _tipoOperativo
      ..aplicaAlcohotest = _aplicaAlcohotest
      ..numeroPruebaAlcoholemia = _aplicaAlcohotest ? _numeroPruebaCtrl.text.trim() : ''
      ..nombreSancionado = _aplicaAlcohotest ? _nombreSancionadoCtrl.text.trim() : ''
      ..cedulaSancionado = _aplicaAlcohotest ? _cedulaSancionadoCtrl.text.trim() : ''
      ..resultadoAlcoholemia = _aplicaAlcohotest ? _resultadoAlcoholemiaCtrl.text.trim() : ''
      ..citacionNro = _aplicaAlcohotest ? _citacionCtrl.text.trim() : ''
      ..propietario = _propietarioCtrl.text.trim()
      ..cedulaPropietario = _cedulaPropietarioCtrl.text.trim()
      ..conductor = _conductorCtrl.text.trim()
      ..cedulaConductor = _cedulaConductorCtrl.text.trim()
      ..traslado = _traslado
      ..kmGrua = _traslado == 'GRÚA POLICIAL' ? _kmGruaCtrl.text.trim() : ''
      ..valorGrua = _traslado == 'PARTICULAR' ? _valorGruaCtrl.text.trim() : ''
      ..nombreGruaParticular = _traslado == 'PARTICULAR' ? _nombreGruaParticularCtrl.text.trim() : ''
      ..telefonoGruaParticular = _traslado == 'PARTICULAR' ? _telefonoGruaParticularCtrl.text.trim() : ''
      ..tonelaje = _tipoVehiculo == 'MOTOCICLETA' ? '' : _tonelajeCtrl.text.trim()
      ..tipoCobroParqueo = _tipoCobroParqueo ?? ''
      ..causaLegal = _causaLegal
      ..detalleCausa = _detalleCausaCtrl.text.trim()
      ..custodioRecibeNombre = _custodioRecibeCtrl.text.trim()
      ..policiaNombre = _policiaNombreCtrl.text.trim()
      ..policiaCedula = _policiaCedulaCtrl.text.trim()
      ..estadoVehiculo = _estadoVehiculoCtrl.text.trim()
      ..observaciones = _observacionesCtrl.text.trim();
  }

  Future<void> _guardar({bool compartirDespues = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    _aplicarCambiosACaso();
    await StorageService.guardarCasoIngreso(_caso);

    if (!mounted) return;
    setState(() => _guardando = false);

    if (compartirDespues) {
      await _compartir();
      return;
    }

    if (widget.esEdicion) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caso actualizado')));
      Navigator.pop(context);
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso)),
      (route) => route.isFirst,
    );
  }

  Future<void> _verVistaPrevia() async {
    if (!_formKey.currentState!.validate()) return;
    _aplicarCambiosACaso();

    final accion = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => _VistaPreviaIngresoScreen(caso: _caso)),
    );
    if (accion == null || !mounted) return;

    setState(() => _guardando = true);
    await StorageService.guardarCasoIngreso(_caso);
    if (!mounted) return;
    setState(() => _guardando = false);

    if (accion == 'whatsapp') {
      await _compartir(mensajeWhatsapp: true);
    } else if (accion == 'descargar') {
      await _compartir();
    }
  }

  Future<void> _compartir({bool mensajeWhatsapp = false}) async {
    final bytes = StorageService.generarWordIngreso(_caso);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: _caso.placa, esIngreso: true);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles(
      [xFile],
      text: mensajeWhatsapp
          ? 'Ingreso ${_caso.placa} - REGISTROS PRV TRANSITO (elige WhatsApp en la bandeja para enviarlo)'
          : 'Ingreso ${_caso.placa} - REGISTROS PRV TRANSITO',
    );
    if (mounted) {
      if (widget.esEdicion) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso)),
          (route) => route.isFirst,
        );
      }
    }
  }

  Widget _seccion(String titulo, IconData icono, List<Widget> hijos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ...hijos.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {int lineas = 1, TextInputType? tipo, bool requerido = false}) {
    return TextFormField(
      controller: ctrl,
      maxLines: lineas,
      keyboardType: tipo,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      validator: requerido ? (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar Ingreso' : 'Confirmar datos de Ingreso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_snippet_outlined),
            tooltip: 'Ver texto reconocido',
            onPressed: () => _verTextoOcr(context, widget.textoOcr),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1-3: Tipo operativo / Fecha / Hora de retención (+
            // subzona/CRV, que no tienen un lugar fijo en el orden que
            // dio Xavier — quedan aquí por ser también "datos
            // generales" del ingreso).
            _seccion('Datos del ingreso', Icons.assignment_outlined, [
              DropdownButtonFormField<String>(
                initialValue: _tipoOperativo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo operativo', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'SIN OPERATIVO', child: Text('Sin operativo')),
                  DropdownMenuItem(value: 'OPERATIVO N°', child: Text('Operativo N°')),
                ],
                onChanged: (v) => setState(() => _tipoOperativo = v ?? 'SIN OPERATIVO'),
              ),
              if (_tipoOperativo == 'OPERATIVO N°') _campo(_tipoOperativoNroCtrl, 'Número de operativo'),
              _campo(_fechaCtrl, 'Fecha de retención (dd/mm/aaaa)', requerido: true),
              _campo(_horaCtrl, 'Hora de retención'),
              CampoAutocompletable(etiqueta: 'Subzona', claveAlmacenamiento: 'ingreso_subzona', controller: _subzonaCtrl),
              CampoAutocompletable(etiqueta: 'CRV / Control', claveAlmacenamiento: 'ingreso_crv', controller: _crvCtrl),
            ]),
            // 4: Personal que toma procedimiento
            _seccion('Personal que toma procedimiento', Icons.local_police_outlined, [
              CampoAutocompletable(
                etiqueta: 'Nombre del policía',
                claveAlmacenamiento: 'ingreso_policia_nombre',
                controller: _policiaNombreCtrl,
              ),
              CampoAutocompletable(
                etiqueta: 'Cédula del policía',
                claveAlmacenamiento: 'ingreso_policia_cedula',
                controller: _policiaCedulaCtrl,
              ),
            ]),
            // 5: Propietario
            _seccion('Propietario', Icons.person_outline, [
              CampoAutocompletable(
                etiqueta: 'Nombre del propietario',
                claveAlmacenamiento: 'ingreso_propietario',
                controller: _propietarioCtrl,
              ),
              CampoAutocompletable(
                etiqueta: 'Cédula del propietario',
                claveAlmacenamiento: 'ingreso_cedula_propietario',
                controller: _cedulaPropietarioCtrl,
              ),
            ]),
            // 6: Conductor
            _seccion('Conductor', Icons.badge_outlined, [
              CampoAutocompletable(
                etiqueta: 'Nombre del conductor',
                claveAlmacenamiento: 'ingreso_conductor',
                controller: _conductorCtrl,
              ),
              CampoAutocompletable(
                etiqueta: 'Cédula del conductor',
                claveAlmacenamiento: 'ingreso_cedula_conductor',
                controller: _cedulaConductorCtrl,
              ),
            ]),
            // 7: Causa legal -> Detalle de la causa
            _seccion('Causa legal', Icons.gavel_outlined, [
              DropdownButtonFormField<String>(
                initialValue: _causaLegal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Causa legal', border: OutlineInputBorder(), isDense: true),
                items: _causasLegales.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _causaLegal = v ?? 'Accidente de tránsito'),
              ),
              _campo(_detalleCausaCtrl, 'Detalle causa (artículo exacto)', lineas: 3),
            ]),
            // 8: Datos del vehículo
            _seccion('Datos del vehículo', Icons.directions_car_outlined, [
              _campo(_placaCtrl, 'Placa', requerido: true),
              DropdownButtonFormField<String>(
                initialValue: _tipoVehiculo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo de vehículo', border: OutlineInputBorder(), isDense: true),
                items: _tiposVehiculo
                    .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _tipoVehiculo = v ?? 'AUTOMÓVIL';
                  _autocompletarTipoCobro();
                }),
              ),
              CampoAutocompletable(etiqueta: 'Color', claveAlmacenamiento: 'ingreso_color', controller: _colorCtrl),
              if (_tipoVehiculo == 'MOTOCICLETA')
                CampoAutocompletable(
                  etiqueta: 'Cilindraje (ej. 150cc)',
                  claveAlmacenamiento: 'ingreso_cilindraje',
                  controller: _cilindrajeCtrl,
                )
              else ...[
                _campo(_motorCtrl, 'Motor'),
                _campo(_chasisCtrl, 'Chasis / VIN'),
              ],
              CampoAutocompletable(etiqueta: 'Marca', claveAlmacenamiento: 'ingreso_marca', controller: _marcaCtrl),
              CampoAutocompletable(etiqueta: 'Modelo', claveAlmacenamiento: 'ingreso_modelo', controller: _modeloCtrl),
              _campo(_anioCtrl, 'Año de fabricación'),
              _campo(_estadoVehiculoCtrl, 'Estado físico del vehículo', lineas: 2),
            ]),
            // 9-10: Formulario N° / N° de Parte Web (Ingreso)
            _seccion('Identificación del trámite', Icons.numbers_outlined, [
              _campo(_hojaCtrl, 'Formulario N°', requerido: true),
              _campo(_parteCtrl, 'N° de Parte Web (Ingreso)'),
            ]),
            // 11: Trasladado por...
            _seccion('Trasladado por', Icons.local_shipping_outlined, [
              DropdownButtonFormField<String>(
                initialValue: _traslado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Trasladado por', border: OutlineInputBorder(), isDense: true),
                items: _tiposTraslado.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _traslado = v ?? 'SUS PROPIOS MEDIOS'),
              ),
              if (_traslado == 'GRÚA POLICIAL') _campo(_kmGruaCtrl, 'Km. grúa policial'),
              if (_traslado == 'PARTICULAR') ...[
                CampoAutocompletable(
                  etiqueta: 'Nombre de la grúa particular',
                  claveAlmacenamiento: 'ingreso_grua_particular',
                  controller: _nombreGruaParticularCtrl,
                ),
                CampoAutocompletable(
                  etiqueta: 'Teléfono de la grúa',
                  claveAlmacenamiento: 'ingreso_grua_telefono',
                  controller: _telefonoGruaParticularCtrl,
                ),
                _campo(_valorGruaCtrl, 'Valor pagado', tipo: const TextInputType.numberWithOptions(decimal: true)),
              ],
            ]),
            // 12: Tipo de cobro (tonelaje -> autocompleta)
            _seccion('Tipo de cobro', Icons.paid_outlined, [
              if (_tipoVehiculo != 'MOTOCICLETA')
                _campo(_tonelajeCtrl, 'Tonelaje (TN)', tipo: const TextInputType.numberWithOptions(decimal: true)),
              DropdownButtonFormField<String>(
                initialValue: _tipoCobroParqueo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo cobro parqueo',
                  border: OutlineInputBorder(),
                  isDense: true,
                  helperText: 'Se sugiere solo según el tonelaje; puedes cambiarlo a mano',
                ),
                items: _tiposCobroParqueo.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _tipoCobroParqueo = v),
              ),
            ]),
            // 13: Alcoholemia (rediseñada)
            _seccion('Alcoholemia', Icons.local_bar_outlined, [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('¿Se realizó prueba de alcoholemia?'),
                value: _aplicaAlcohotest,
                onChanged: _alActivarAlcoholemia,
              ),
              if (_aplicaAlcohotest) ...[
                _campo(_nombreSancionadoCtrl, 'Nombres del conductor'),
                _campo(_cedulaSancionadoCtrl, 'Cédula de ciudadanía'),
                _campo(_numeroPruebaCtrl, 'Prueba N°'),
                _campo(_resultadoAlcoholemiaCtrl, 'Resultado (g/L)', tipo: const TextInputType.numberWithOptions(decimal: true)),
                _campo(_citacionCtrl, 'Citación N°'),
              ],
            ]),
            // 14: Personal Policial que Recibe la Custodia
            _seccion('Personal Policial que Recibe la Custodia', Icons.shield_outlined, [
              CampoAutocompletable(
                etiqueta: 'Recibe la custodia',
                claveAlmacenamiento: 'ingreso_custodio_recibe',
                controller: _custodioRecibeCtrl,
              ),
            ]),
            _seccion('Observaciones', Icons.notes_outlined, [
              _campo(_observacionesCtrl, 'Observaciones', lineas: 3),
            ]),
            const SizedBox(height: 8),
            FilledButton.icon(
              icon: _guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.visibility_outlined),
              label: Text(_guardando ? 'Procesando...' : 'Vista previa'),
              onPressed: _guardando ? null : _verVistaPrevia,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.save_outlined),
              label: Text(widget.esEdicion ? 'Guardar cambios' : 'Guardar sin vista previa'),
              onPressed: _guardando ? null : () => _guardar(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista Previa de solo lectura antes de guardar/compartir — mismo
/// patrón que _VistaPreviaLibertadScreen en formulario_libertad_screen.dart.
class _VistaPreviaIngresoScreen extends StatelessWidget {
  final CasoIngreso caso;
  const _VistaPreviaIngresoScreen({required this.caso});

  Widget _fila(String etiqueta, String valor) {
    if (valor.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 14),
          children: [
            TextSpan(text: '$etiqueta: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: valor),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(String titulo, List<Widget> filas) {
    final visibles = filas.where((w) => w is! SizedBox).toList();
    if (visibles.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            ...filas,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vista Previa — Ingreso')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${caso.placa.toUpperCase()} — ${caso.marca} ${caso.color}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          _tarjeta('Datos del ingreso', [
            _fila('Tipo operativo', caso.tipoOperativo),
            _fila('Fecha de retención', caso.fechaIngreso),
            _fila('Hora de retención', caso.horaRetencion),
            _fila('CRV', caso.crv),
          ]),
          _tarjeta('Personal que toma procedimiento', [
            _fila('Nombre', caso.policiaNombre),
            _fila('Cédula', caso.policiaCedula),
          ]),
          _tarjeta('Propietario', [
            _fila('Nombre', caso.propietario),
            _fila('Cédula', caso.cedulaPropietario),
          ]),
          _tarjeta('Conductor', [
            _fila('Nombre', caso.conductor),
            _fila('Cédula', caso.cedulaConductor),
          ]),
          _tarjeta('Causa legal', [
            _fila('Causa', caso.causaLegal),
            _fila('Detalle', caso.detalleCausa),
          ]),
          _tarjeta('Vehículo', [
            _fila('Tipo', caso.tipoVehiculo),
            _fila('Modelo', caso.modelo),
            _fila('Año', caso.anioFabricacion),
            _fila('Chasis', caso.chasis),
            _fila('Motor', caso.motor),
          ]),
          _tarjeta('Identificación del trámite', [
            _fila('Formulario N°', caso.hojaIngresoNro),
            _fila('N° de Parte Web (Ingreso)', caso.parteIngresoNro),
          ]),
          _tarjeta('Trasladado por', [
            _fila('Traslado', caso.traslado),
            _fila('Grúa particular', caso.nombreGruaParticular),
          ]),
          _tarjeta('Tipo de cobro', [
            _fila('Tonelaje', caso.tonelaje),
            _fila('Tipo cobro parqueo', caso.tipoCobroParqueo),
          ]),
          if (caso.aplicaAlcohotest)
            _tarjeta('Alcoholemia', [
              _fila('Nombres del conductor', caso.nombreSancionado),
              _fila('Cédula', caso.cedulaSancionado),
              _fila('Prueba N°', caso.numeroPruebaAlcoholemia),
              _fila('Resultado', '${caso.resultadoAlcoholemia} g/L'),
              _fila('Citación N°', caso.citacionNro),
            ]),
          _tarjeta('Personal Policial que Recibe la Custodia', [
            _fila('Recibe la custodia', caso.custodioRecibeNombre),
          ]),
          _tarjeta('Observaciones', [
            _fila('Observaciones', caso.observaciones),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.download_outlined),
            label: const Text('Descargar'),
            onPressed: () => Navigator.pop(context, 'descargar'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined),
            label: const Text('Enviar por WhatsApp'),
            onPressed: () => Navigator.pop(context, 'whatsapp'),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Volver a editar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
