import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/caso_ingreso.dart';
import '../services/storage_service.dart';
import '../widgets/campo_autocompletable.dart';

class FormularioScreen extends StatefulWidget {
  final CasoIngreso? casoExistente;

  const FormularioScreen({super.key, this.casoExistente});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controladores de Texto
  final _hojaIngresoController = TextEditingController();
  final _parteIngresoController = TextEditingController();
  final _fechaIngresoController = TextEditingController();
  final _horaRetencionController = TextEditingController();
  final _subzonaController = TextEditingController();
  final _crvController = TextEditingController();
  final _placaController = TextEditingController();
  final _marcaController = TextEditingController();
  final _modeloController = TextEditingController();
  final _anioController = TextEditingController();
  final _colorController = TextEditingController();
  final _cilindrajeController = TextEditingController();
  final _chasisController = TextEditingController();
  final _motorController = TextEditingController();
  final _tonelajeController = TextEditingController();
  final _numeroOperativoController = TextEditingController();
  final _resultadoAlcoholemiaController = TextEditingController();
  final _numeroPruebaAlcoholemiaController = TextEditingController();
  final _nombreSancionadoController = TextEditingController();
  final _cedulaSancionadoController = TextEditingController();
  final _propietarioController = TextEditingController();
  final _cedulaPropietarioController = TextEditingController();
  final _conductorController = TextEditingController();
  final _cedulaConductorController = TextEditingController();
  final _kmGruaController = TextEditingController();
  final _valorGruaController = TextEditingController();
  final _nombreGruaParticularController = TextEditingController();
  final _telefonoGruaParticularController = TextEditingController();
  final _custodioRecibeController = TextEditingController();
  final _policiaNombreController = TextEditingController();
  final _policiaCedulaController = TextEditingController();
  final _observacionesController = TextEditingController();

  // Valores heredados (31/ago): campos que Xavier pidió sacar del
  // formulario de Ingreso pero que, si se está EDITANDO un caso viejo
  // que ya los tenía llenos, no se deben borrar silenciosamente al
  // guardar. Se cargan en _cargarDatosExistentes y se devuelven tal
  // cual en _guardarFormulario, sin mostrarse en pantalla.
  String _legacyCausaPrincipal = '';
  String _legacySubmotivoFalta = '';
  String _legacyAutoridadRequirente = '';
  String _legacyLatitud = '';
  String _legacyLongitud = '';
  String _legacyDistrito = '';
  String _legacyPericiaRealizada = '';
  String _legacyPeritoNombre = '';
  bool _legacySeNegoPrueba = false;
  String _legacyRangoAlcoholemia = '';
  String _legacyOrdenPagoAlcohocheck = '';
  String _legacyValorAlcohocheck = '';

  // Variables de Estado para Desplegables y Switches
  String _tipoVehiculo = 'AUTOMÓVIL';
  String _estadoVehiculo = 'Bueno';
  bool _aplicaAlcohotest = false;

  // --- desplegables oficiales de SIIPNE 3W ---
  String _tipoCobroParqueo = 'LIVIANO';
  // 30/ago: renombrado de ['SUS PROPIOS MEDIOS', 'GRÚA'] a estas 2 opciones
  // reales; al elegir PARTICULAR se muestran los casilleros de la grúa.
  String _traslado = 'SUS PROPIOS MEDIOS';
  // 31/ago: Xavier pidió que "Tipo operativo" tenga SOLO 2 opciones; al
  // elegir "OPERATIVO N°" se muestra el casillero de número de operativo.
  String _tipoOperativo = 'SIN OPERATIVO';
  String _causaLegal = 'Contravenciones de Tránsito';
  String _detalleCausa = '';

  final List<String> _tiposCobroParqueo = ['LIVIANO', 'PESADO', 'MOTOCICLETA', 'EXTRAPESADO'];
  // 31/ago (ronda 2): Xavier pidió una 3ra opción "GRÚA POLICIAL" — el
  // campo "Km. Grúa Policial" (antes siempre visible fuera del
  // desplegable) ahora solo aparece cuando se elige esta opción.
  final List<String> _tiposTraslado = ['SUS PROPIOS MEDIOS', 'PARTICULAR', 'GRÚA POLICIAL'];
  final List<String> _tiposOperativo = ['SIN OPERATIVO', 'OPERATIVO N°'];

  // NOTA IMPORTANTE: esta lista de "Causa legal / Detalle causa" es una
  // transcripción de las capturas de pantalla del sistema SIIPNE 3W que
  // Xavier compartió — el texto de varios artículos aparecía CORTADO en
  // la imagen (la pantalla no alcanzaba a mostrarlo completo). Cada
  // entrada marcada "// TODO" tiene el texto tal como se alcanzó a leer;
  // hace falta que Xavier confirme o complete la redacción oficial
  // exacta antes de usar esto en un documento legal real.
  final Map<String, List<String>> _causasLegales = {
    'Acuerdo Ministerial 00004': [
      'Artículo 10 /Verificación del incumplimiento al toque de queda', // TODO: confirmar texto completo
      'Artículo 11 /Verificación de la violación a la restricción de circulación vehicular según el último dígito de placa', // TODO: confirmar texto completo
      'Artículo 12 /Verificación del mal uso o uso fraudulento del salvoconducto', // TODO: confirmar texto completo
    ],
    'Contravenciones de Tránsito': [
      'Artículo 383 /Conducción de vehículo con llantas en mal estado', // TODO: confirmar texto completo
      'Artículo 383.i2 /Conducción de vehículo con llantas en mal estado (transporte público)', // TODO
      'Artículo 384 /Conducción de vehículo bajo efecto de sustancias estupefacientes o psicotrópicas', // TODO
      'Artículo 385.1 /Nivel de alcohol de 0,3 a 0,8 gramos por litro de sangre', // TODO
      'Artículo 385.2 /Nivel de alcohol mayor de 0,8 hasta 1,2 gramos por litro de sangre', // TODO
      'Artículo 385.3 /Nivel de alcohol superior a 1,2 gramos por litro de sangre', // TODO
      'Artículo 385.4 /Conductores de transporte público liviano o pesado, comercial', // TODO
      'Artículo 386.1 /Conducir sin haber obtenido licencia', // TODO
      'Artículo 386.i2.1 /Transportar pasajeros o bienes sin título habilitante', // TODO
      'Artículo 386.i2.2 /Conducir con licencia de categoría diferente a la exigida', // TODO
      'Artículo 386.i2.3 /Participar con vehículos a motor en competencias en la vía pública', // TODO
      'Artículo 389.7 /Vehículo a motor que no cumpla las normas y condiciones', // TODO
      'Artículo 391.5 /Estacionar en sitios prohibidos por la ley o los reglamentos', // TODO
    ],
    'Reglamento a la LTTTSV': [
      'Artículo 160 /Ningún vehículo podrá circular sin poseer la matrícula vigente', // TODO
      'Artículo 177 /Título habilitante correspondiente para circular', // TODO
    ],
    'Accidente de Tránsito': [
      'Accidente de Tránsito /Accidente de Tránsito',
    ],
    'Orden Judicial': [
      'Orden Judicial /Orden Judicial',
    ],
  };

  // Listas para Desplegables
  final List<String> _tiposVehiculo = [
    'AUTOMÓVIL',
    'MOTOCICLETA',
    'CAMIONETA',
    'AUTOBÚS',
    'CAMIÓN',
    'TRAILER',
    'OTRO'
  ];

  final List<String> _estadosVehiculo = ['Excelente', 'Bueno', 'Regular', 'Averiado / Chocado'];

  @override
  void initState() {
    super.initState();
    if (widget.casoExistente != null) {
      _cargarDatosExistentes(widget.casoExistente!);
    } else {
      _fechaIngresoController.text = _fechaActual();
      // Valores en caché LOCAL del último ingreso llenado en este
      // teléfono — se usan como respaldo si Firestore no responde o no
      // tiene el dato (ver _prellenarDesdeFirestore).
      _subzonaController.text = StorageService.ultimaSubzona;
      _crvController.text = StorageService.ultimoCrv;
      _policiaNombreController.text = StorageService.ultimoPoliciaNombre;
      _policiaCedulaController.text = StorageService.ultimoPoliciaCedula;
      _prellenarDesdeFirestore();
    }
  }

  // NUEVO (31/ago, ronda 2): Xavier notó que, al volver a loguearse, la
  // hoja de Ingreso NO trae la Subzona ni el CRV/Patio que ya configuró
  // en identificacion_screen.dart durante el registro de la cuenta.
  // Esto NO es un bug de que "no vuelva a preguntar" — es correcto que
  // el registro inicial (zona/subzona/jefatura/patio) no se repita en
  // cada login, porque ya quedó guardado en Firestore. Lo que SÍ
  // faltaba es que el formulario de Ingreso LEA esos datos guardados.
  // Aquí se hace, para los 2 campos que sí existen en este formulario
  // (Subzona y CRV/Patio); si Firestore trae un valor, tiene prioridad
  // sobre el caché local del teléfono.
  //
  // SUPUESTO A CONFIRMAR: los nombres de campo en Firestore
  // ('subzona' y 'patio') se tomaron de lo que ya se ve en
  // home_screen.dart (que sí lee 'patio' con éxito). Si el campo real
  // de subzona en el documento de 'usuarios' se llama distinto, avísame
  // y lo ajusto — no tengo identificacion_screen.dart todavía para
  // confirmarlo con certeza.
  Future<void> _prellenarDesdeFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final datos = doc.data();
      if (datos == null || !mounted) return;

      final subzona = (datos['subzona'] as String?)?.trim();
      final patio = (datos['patio'] as String?)?.trim();

      setState(() {
        if (subzona != null && subzona.isNotEmpty) {
          _subzonaController.text = subzona;
        }
        if (patio != null && patio.isNotEmpty) {
          _crvController.text = patio;
        }
      });
    } catch (_) {
      // Sin conexión o sin permiso: se queda con el caché local, sin
      // interrumpir el llenado del formulario.
    }
  }

  // NUEVO (31/ago, ronda 2): autocompleta "Tipo cobro parqueo" según el
  // tonelaje ingresado, usando el tarifario que Xavier compartió.
  // OJO: los cortes de tonelaje (3.5 TN y 12 TN) son los rangos
  // estándar de la ANT para livianos/pesados/extrapesados — Xavier
  // debe CONFIRMAR que coinciden exactamente con su tarifario antes de
  // usar esto en un documento oficial.
  String? _tipoCobroSegunTonelaje(String valorStr) {
    final tonelaje = double.tryParse(valorStr.replaceAll(',', '.'));
    if (tonelaje == null) return null;
    if (tonelaje <= 3.5) return 'LIVIANO';
    if (tonelaje <= 12) return 'PESADO';
    return 'EXTRAPESADO';
  }

  void _calcularTipoCobroPorTonelaje(String valorStr) {
    if (_tipoVehiculo == 'MOTOCICLETA') {
      setState(() => _tipoCobroParqueo = 'MOTOCICLETA');
      return;
    }
    final calculado = _tipoCobroSegunTonelaje(valorStr);
    if (calculado != null) setState(() => _tipoCobroParqueo = calculado);
  }

  String _fechaActual() {
    final now = DateTime.now();
    return "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
  }

  void _cargarDatosExistentes(CasoIngreso c) {
    _hojaIngresoController.text = c.hojaIngresoNro;
    _parteIngresoController.text = c.parteIngresoNro;
    _fechaIngresoController.text = c.fechaIngreso;
    _horaRetencionController.text = c.horaRetencion;
    _subzonaController.text = c.subzona;
    _crvController.text = c.crv;
    _placaController.text = c.placa;
    _marcaController.text = c.marca;
    _modeloController.text = c.modelo;
    _anioController.text = c.anioFabricacion;
    _colorController.text = c.color;
    _cilindrajeController.text = c.cilindraje;
    _chasisController.text = c.chasis;
    _motorController.text = c.motor;
    _tonelajeController.text = c.tonelaje;
    _numeroOperativoController.text = c.numeroOperativo;
    _resultadoAlcoholemiaController.text = c.resultadoAlcoholemia;
    _numeroPruebaAlcoholemiaController.text = c.numeroPruebaAlcoholemia;
    _nombreSancionadoController.text = c.nombreSancionado;
    _cedulaSancionadoController.text = c.cedulaSancionado;
    _propietarioController.text = c.propietario;
    _cedulaPropietarioController.text = c.cedulaPropietario;
    _conductorController.text = c.conductor;
    _cedulaConductorController.text = c.cedulaConductor;
    _kmGruaController.text = c.kmGrua;
    _valorGruaController.text = c.valorGrua;
    _nombreGruaParticularController.text = c.nombreGruaParticular;
    _telefonoGruaParticularController.text = c.telefonoGruaParticular;
    _custodioRecibeController.text = c.custodioRecibeNombre;
    _policiaNombreController.text = c.policiaNombre;
    _policiaCedulaController.text = c.policiaCedula;
    _observacionesController.text = c.observaciones;

    // Valores heredados que ya no se muestran en el formulario, pero se
    // conservan tal cual para no perder datos de casos antiguos al editar.
    _legacyCausaPrincipal = c.causaPrincipal;
    _legacySubmotivoFalta = c.submotivoFalta;
    _legacyAutoridadRequirente = c.autoridadRequirente;
    _legacyLatitud = c.latitud;
    _legacyLongitud = c.longitud;
    _legacyDistrito = c.distritoCircuitoSubcircuito;
    _legacyPericiaRealizada = c.periciaRealizada;
    _legacyPeritoNombre = c.peritoNombre;
    _legacySeNegoPrueba = c.seNegoPrueba;
    _legacyRangoAlcoholemia = c.rangoAlcoholemia;
    _legacyOrdenPagoAlcohocheck = c.ordenPagoAlcohocheckNro;
    _legacyValorAlcohocheck = c.valorAlcohocheck;

    setState(() {
      _tipoVehiculo = _tiposVehiculo.contains(c.tipoVehiculo) ? c.tipoVehiculo : 'AUTOMÓVIL';
      _estadoVehiculo = _estadosVehiculo.contains(c.estadoVehiculo) ? c.estadoVehiculo : 'Bueno';
      _aplicaAlcohotest = c.aplicaAlcohotest;
      _tipoCobroParqueo = _tiposCobroParqueo.contains(c.tipoCobroParqueo) ? c.tipoCobroParqueo : 'LIVIANO';
      _traslado = _tiposTraslado.contains(c.traslado) ? c.traslado : 'SUS PROPIOS MEDIOS';
      _tipoOperativo = _tiposOperativo.contains(c.tipoOperativo) ? c.tipoOperativo : 'SIN OPERATIVO';
      _causaLegal = _causasLegales.containsKey(c.causaLegal) ? c.causaLegal : 'Contravenciones de Tránsito';
      _detalleCausa = c.detalleCausa;
    });
  }

  bool _guardando = false;

  CasoIngreso? _construirCasoDesdeFormulario() {
    if (!_formKey.currentState!.validate()) return null;

    StorageService.ultimaSubzona = _subzonaController.text.trim();
    StorageService.ultimoCrv = _crvController.text.trim();
    StorageService.ultimoPoliciaNombre = _policiaNombreController.text.trim();
    StorageService.ultimoPoliciaCedula = _policiaCedulaController.text.trim();

    final esParticular = _traslado == 'PARTICULAR';

    return CasoIngreso(
      id: widget.casoExistente?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      hojaIngresoNro: _hojaIngresoController.text.trim(),
      parteIngresoNro: _parteIngresoController.text.trim(),
      fechaIngreso: _fechaIngresoController.text.trim(),
      horaRetencion: _horaRetencionController.text.trim(),
      subzona: _subzonaController.text.trim(),
      crv: _crvController.text.trim(),
      placa: _placaController.text.trim().toUpperCase(),
      marca: _marcaController.text.trim(),
      modelo: _modeloController.text.trim(),
      anioFabricacion: _anioController.text.trim(),
      color: _colorController.text.trim(),
      tipoVehiculo: _tipoVehiculo,
      cilindraje: _tipoVehiculo == 'MOTOCICLETA' ? _cilindrajeController.text.trim() : '',
      chasis: _chasisController.text.trim(),
      motor: _motorController.text.trim(),
      tonelaje: _tipoVehiculo == 'MOTOCICLETA' ? '' : _tonelajeController.text.trim(),
      numeroOperativo: _tipoOperativo == 'OPERATIVO N°' ? _numeroOperativoController.text.trim() : '',
      aplicaAlcohotest: _aplicaAlcohotest,
      numeroPruebaAlcoholemia: _aplicaAlcohotest ? _numeroPruebaAlcoholemiaController.text.trim() : '',
      nombreSancionado: _aplicaAlcohotest ? _nombreSancionadoController.text.trim() : '',
      cedulaSancionado: _aplicaAlcohotest ? _cedulaSancionadoController.text.trim() : '',
      resultadoAlcoholemia: _aplicaAlcohotest ? _resultadoAlcoholemiaController.text.trim() : '',
      propietario: _propietarioController.text.trim(),
      cedulaPropietario: _cedulaPropietarioController.text.trim(),
      conductor: _conductorController.text.trim(),
      cedulaConductor: _cedulaConductorController.text.trim(),
      // Km. Grúa Policial: solo aplica cuando el traslado fue con la
      // grúa de la propia Policía (31/ago, ronda 2)
      kmGrua: _traslado == 'GRÚA POLICIAL' ? _kmGruaController.text.trim() : '',
      // Valor / nombre / teléfono de la grúa PARTICULAR: solo si aplica
      valorGrua: esParticular ? _valorGruaController.text.trim() : '',
      nombreGruaParticular: esParticular ? _nombreGruaParticularController.text.trim() : '',
      telefonoGruaParticular: esParticular ? _telefonoGruaParticularController.text.trim() : '',
      traslado: _traslado,
      tipoCobroParqueo: _tipoCobroParqueo,
      tipoOperativo: _tipoOperativo,
      causaLegal: _causaLegal,
      detalleCausa: _detalleCausa,
      custodioRecibeNombre: _custodioRecibeController.text.trim(),
      policiaNombre: _policiaNombreController.text.trim(),
      policiaCedula: _policiaCedulaController.text.trim(),
      estadoVehiculo: _estadoVehiculo,
      observaciones: _observacionesController.text.trim(),
      // --- Campos heredados (31/ago): ya no se muestran en el
      // formulario; se devuelven tal cual para no perder datos al
      // editar un caso guardado antes de este cambio.
      causaPrincipal: _legacyCausaPrincipal,
      submotivoFalta: _legacySubmotivoFalta,
      autoridadRequirente: _legacyAutoridadRequirente,
      latitud: _legacyLatitud,
      longitud: _legacyLongitud,
      distritoCircuitoSubcircuito: _legacyDistrito,
      periciaRealizada: _legacyPericiaRealizada,
      peritoNombre: _legacyPeritoNombre,
      seNegoPrueba: _legacySeNegoPrueba,
      rangoAlcoholemia: _legacyRangoAlcoholemia,
      ordenPagoAlcohocheckNro: _legacyOrdenPagoAlcohocheck,
      valorAlcohocheck: _legacyValorAlcohocheck,
    );
  }

  Future<void> _guardarFormulario() async {
    final nuevoCaso = _construirCasoDesdeFormulario();
    if (nuevoCaso == null) return;

    setState(() => _guardando = true);
    await StorageService.guardarCasoIngreso(nuevoCaso);
    if (!mounted) return;
    setState(() => _guardando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Registro de Ingreso guardado con éxito')),
    );
    Navigator.pop(context, true);
  }

  // NUEVO (31/ago, ronda 2): Xavier pidió recuperar el flujo Vista
  // previa → Descargar / Enviar por WhatsApp también en Ingresos (antes
  // solo se había hecho en Libertad por error de interpretación).
  // MISMA ACLARACIÓN TÉCNICA que en Libertad: la app no guarda archivos
  // directo al almacenamiento del teléfono, así que "Descargar" y
  // "WhatsApp" abren la misma bandeja nativa de compartir.
  //
  // SUPUESTO A CONFIRMAR: se asume que storage_service.dart ya tiene
  // (o se le puede agregar) un método `generarWordIngreso(caso)` con la
  // MISMA firma que `generarWordLibertad` (ya usado en el formulario de
  // Libertad) y que `obtenerNombreArchivoWord` acepta `esIngreso: true`
  // como contraparte de `esIngreso: false`. Si el nombre real del
  // método es distinto, Xavier debe avisarme para ajustarlo.
  Future<void> _verVistaPrevia() async {
    final nuevoCaso = _construirCasoDesdeFormulario();
    if (nuevoCaso == null) return;

    final accion = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => _VistaPreviaIngresoScreen(caso: nuevoCaso)),
    );
    if (accion == null || !mounted) return;

    setState(() => _guardando = true);
    await StorageService.guardarCasoIngreso(nuevoCaso);
    if (!mounted) return;
    setState(() => _guardando = false);

    if (accion == 'whatsapp') {
      await _compartir(nuevoCaso, mensajeWhatsapp: true);
    } else if (accion == 'descargar') {
      await _compartir(nuevoCaso);
    }
  }

  Future<void> _compartir(CasoIngreso caso, {bool mensajeWhatsapp = false}) async {
    final bytes = StorageService.generarWordIngreso(caso);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: caso.placa, esIngreso: true);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles(
      [xFile],
      text: mensajeWhatsapp
          ? 'Ingreso ${caso.placa} - REGISTROS PRV TRANSITO (elige WhatsApp en la bandeja para enviarlo)'
          : 'Ingreso ${caso.placa} - REGISTROS PRV TRANSITO',
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.casoExistente == null ? 'Nuevo Ingreso a Patio' : 'Editar Ingreso'),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSeccionHeader('📄 Datos del Documento y Retención', Icons.assignment),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hojaIngresoController,
                    decoration: const InputDecoration(labelText: 'N° Hoja de Ingreso'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _parteIngresoController,
                    decoration: const InputDecoration(labelText: 'N° Parte Policial'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _fechaIngresoController,
                    decoration: const InputDecoration(labelText: 'Fecha (DD/MM/AAAA)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _horaRetencionController,
                    decoration: const InputDecoration(labelText: 'Hora Retención (HH:MM)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _subzonaController,
                    decoration: const InputDecoration(labelText: 'Subzona (Ej. SANTO DOMINGO)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _crvController,
                    decoration: const InputDecoration(labelText: 'CRV / Patio (Ej. CONTROL 120)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _tipoOperativo,
              decoration: const InputDecoration(labelText: 'Tipo operativo'),
              items: _tiposOperativo.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _tipoOperativo = v!),
            ),
            if (_tipoOperativo == 'OPERATIVO N°') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _numeroOperativoController,
                decoration: const InputDecoration(labelText: 'N° de Operativo'),
              ),
            ],
            const SizedBox(height: 10),
            if (_tipoVehiculo != 'MOTOCICLETA') ...[
              TextFormField(
                controller: _tonelajeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tonelaje (TN)',
                  helperText: 'Autocompleta el tipo de cobro según el tarifario',
                ),
                onChanged: _calcularTipoCobroPorTonelaje,
              ),
              const SizedBox(height: 10),
            ],
            DropdownButtonFormField<String>(
              value: _tipoCobroParqueo,
              decoration: const InputDecoration(labelText: 'Tipo cobro parqueo'),
              items: _tiposCobroParqueo.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() {
                _tipoCobroParqueo = v!;
                // Si eligen MOTOCICLETA aquí, sincroniza también
                // el tipo de vehículo para que coincida en toda
                // la app (matriz Excel, Word, etc.)
                if (v == 'MOTOCICLETA') _tipoVehiculo = 'MOTOCICLETA';
              }),
            ),
            const SizedBox(height: 20),
            _buildSeccionHeader('🚗 Datos del Vehículo', Icons.directions_car),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _placaController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Placa'),
                    validator: (v) => v!.isEmpty ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _tipoVehiculo,
                    decoration: const InputDecoration(labelText: 'Tipo de Vehículo'),
                    items: _tiposVehiculo
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _tipoVehiculo = val;
                          if (val == 'MOTOCICLETA') {
                            _tipoCobroParqueo = 'MOTOCICLETA';
                          } else if (_tipoCobroParqueo == 'MOTOCICLETA') {
                            // Ya no es moto: recalcula con el tonelaje si hay uno cargado
                            _tipoCobroParqueo =
                                _tipoCobroSegunTonelaje(_tonelajeController.text) ?? 'LIVIANO';
                          }
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CampoAutocompletable(
                    etiqueta: 'Marca',
                    claveAlmacenamiento: 'marca_vehiculo',
                    controller: _marcaController,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _modeloController,
                    decoration: const InputDecoration(labelText: 'Modelo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _anioController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Año Fabricación'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CampoAutocompletable(
                    etiqueta: 'Color',
                    claveAlmacenamiento: 'color_vehiculo',
                    controller: _colorController,
                  ),
                ),
              ],
            ),
            // Ya existía: al elegir MOTOCICLETA se pide cilindraje en vez
            // de chasis/motor. No se tocó — ya funcionaba correctamente.
            if (_tipoVehiculo == 'MOTOCICLETA') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _cilindrajeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cilindraje (cc)',
                  hintText: 'Ej. 150cc, 250cc',
                  prefixIcon: Icon(Icons.two_wheeler),
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _chasisController,
                      decoration: const InputDecoration(labelText: 'N° Chasis / VIN'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motorController,
                      decoration: const InputDecoration(labelText: 'N° Motor'),
                    ),
                  ),
                ],
              ),
            ],
            // 31/ago: Propietario/Conductor se movieron aquí, dentro de
            // Datos del Vehículo (antes estaban en su propia sección al
            // final, junto con el Agente — Xavier pidió este orden
            // porque el conductor es un dato del vehículo, no del
            // procedimiento).
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _propietarioController,
                    decoration: const InputDecoration(labelText: 'Propietario'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cedulaPropietarioController,
                    decoration: const InputDecoration(labelText: 'Cédula Propietario'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _conductorController,
                    decoration: const InputDecoration(labelText: 'Conductor'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _cedulaConductorController,
                    decoration: const InputDecoration(labelText: 'Cédula Conductor'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // 31/ago: Xavier pidió eliminar "Causa Principal", "Falta /
            // Detalle Específico" y "Autoridad Requirente" — quedaban
            // repetidos con "Causa legal oficial" de abajo.
            _buildSeccionHeader('⚖️ Motivo de Ingreso y Faltas', Icons.gavel),
            const Text(
              'Causa legal oficial (para subir a SIIPNE 3W)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _causaLegal,
              decoration: const InputDecoration(labelText: 'Causa legal'),
              items: _causasLegales.keys
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _causaLegal = val;
                    _detalleCausa = _causasLegales[val]!.first;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: (_causasLegales[_causaLegal] ?? const ['']).contains(_detalleCausa)
                  ? _detalleCausa
                  : (_causasLegales[_causaLegal]?.first ?? ''),
              decoration: const InputDecoration(labelText: 'Detalle causa'),
              items: (_causasLegales[_causaLegal] ?? const [''])
                  .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) => setState(() => _detalleCausa = val ?? ''),
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠️ Algunos detalles de causa están con el texto legal incompleto '
              '(la captura de pantalla los mostraba cortados). Revisar contra SIIPNE 3W antes de imprimir un documento oficial.',
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
            const SizedBox(height: 20),
            _buildSeccionHeader('🍺 Módulo de Alcoholemia / Alcohotest', Icons.local_bar),
            SwitchListTile(
              title: const Text('¿Aplica Prueba de Alcoholemia?'),
              value: _aplicaAlcohotest,
              onChanged: (val) => setState(() => _aplicaAlcohotest = val),
            ),
            if (_aplicaAlcohotest) ...[
              Card(
                color: Colors.amber[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _numeroPruebaAlcoholemiaController,
                        decoration: const InputDecoration(labelText: 'N° de Prueba'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _resultadoAlcoholemiaController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Resultado (g/L)',
                          hintText: 'Ej. 0.8',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nombreSancionadoController,
                        decoration: const InputDecoration(labelText: 'Nombre del Sancionado'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _cedulaSancionadoController,
                        decoration: const InputDecoration(labelText: 'Cédula'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // 31/ago: los datos de pago del Alcohocheck (orden/comprobante)
            // se registrarán en la hoja de Libertad junto a los demás
            // comprobantes de pago — pendiente de agregar ahí cuando se
            // comparta formulario_libertad_screen.dart.
            const SizedBox(height: 20),
            _buildSeccionHeader('🚚 Grúa y Custodia', Icons.local_shipping),
            DropdownButtonFormField<String>(
              value: _traslado,
              decoration: const InputDecoration(labelText: 'Traslado'),
              items: _tiposTraslado.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _traslado = v!),
            ),
            // 30/ago: solo si el traslado fue con grúa PARTICULAR se piden
            // estos 3 datos. Ya no se piden placa ni nombre del conductor
            // de la grúa (Xavier confirmó que no son relevantes).
            if (_traslado == 'PARTICULAR') ...[
              const SizedBox(height: 10),
              CampoAutocompletable(
                etiqueta: 'Nombre de la grúa',
                claveAlmacenamiento: 'nombre_grua_particular',
                controller: _nombreGruaParticularController,
                hintText: 'Ej. Grúa El Gato, Grúa Tello, Unitaxis',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valorGruaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Valor (\$)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _telefonoGruaParticularController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                    ),
                  ),
                ],
              ),
            ],
            // 31/ago (ronda 2): "Km. Grúa Policial" ya no es un campo
            // fijo — ahora solo aparece cuando el traslado fue con la
            // GRÚA de la propia Policía (3ra opción del desplegable).
            if (_traslado == 'GRÚA POLICIAL') ...[
              const SizedBox(height: 10),
              TextFormField(
                controller: _kmGruaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Km. Grúa Policial',
                  helperText: 'Se llena a mano — no se extrae de ningún lado',
                ),
              ),
            ],
            const SizedBox(height: 10),
            CampoAutocompletable(
              etiqueta: 'Servidor policial que RECIBE la custodia del vehículo',
              claveAlmacenamiento: 'servidor_recibe_custodia',
              controller: _custodioRecibeController,
            ),
            // 31/ago: "Investigación / Pericias" se quitó de Ingresos —
            // Xavier pidió que vaya en la hoja de Salida (Libertad).
            // Pendiente agregarla ahí cuando se comparta ese formulario.
            const SizedBox(height: 20),
            _buildSeccionHeader('📋 Estado del Vehículo u Observaciones', Icons.build),
            DropdownButtonFormField<String>(
              value: _estadoVehiculo,
              decoration: const InputDecoration(labelText: 'Estado Físico'),
              items: _estadosVehiculo.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _estadoVehiculo = val);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _observacionesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones / Inventario'),
            ),
            const SizedBox(height: 20),
            // 31/ago: "Persona y Agente que Toma Procedimiento" pasó a
            // ser la ÚLTIMA sección del formulario (antes estaba en medio,
            // antes de Grúa/Custodia) — Propietario/Conductor ya se
            // registran en Datos del Vehículo, así que aquí solo queda
            // quien elabora el parte.
            // 31/ago (ronda 2): Xavier pidió quitar la palabra "Agente"
            // de toda la app — son Policía Nacional, no "agentes".
            _buildSeccionHeader('👤 Personal que Toma Procedimiento', Icons.person),
            CampoAutocompletable(
              etiqueta: 'Grado / Nombre',
              claveAlmacenamiento: 'agente_a_cargo',
              controller: _policiaNombreController,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _policiaCedulaController,
              decoration: const InputDecoration(labelText: 'Cédula'),
            ),
            const SizedBox(height: 30),
            FilledButton.icon(
              icon: _guardando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.visibility_outlined),
              label: Text(_guardando ? 'Procesando...' : 'Vista previa'),
              onPressed: _guardando ? null : _verVistaPrevia,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _guardando ? null : _guardarFormulario,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar sin vista previa'),
            ),
          ],
        ),
      ),
    );
  }

  // 31/ago (ronda 2): esta era la causa REAL de la "cinta amarilla y
  // negra" que Xavier seguía viendo en varias secciones — el Text no
  // tenía Expanded, así que en pantallas angostas o títulos largos
  // (con emoji + texto) el Row se desbordaba (RenderFlex overflow).
  // Con Expanded, el texto simplemente pasa a una segunda línea.
  Widget _buildSeccionHeader(String titulo, IconData icono) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: Colors.blueGrey[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

/// NUEVO (31/ago, ronda 2): pantalla de Vista Previa para Ingreso —
/// mismo patrón que la de Libertad. Muestra un resumen de solo lectura
/// antes de guardar y compartir.
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
          _tarjeta('Documento y Retención', [
            _fila('N° Hoja de Ingreso', caso.hojaIngresoNro),
            _fila('N° Parte Policial', caso.parteIngresoNro),
            _fila('Fecha', caso.fechaIngreso),
            _fila('Hora Retención', caso.horaRetencion),
            _fila('Subzona', caso.subzona),
            _fila('CRV / Patio', caso.crv),
            _fila('Tipo operativo', caso.tipoOperativo),
            _fila('N° de Operativo', caso.numeroOperativo),
            _fila('Tonelaje', caso.tonelaje),
            _fila('Tipo cobro parqueo', caso.tipoCobroParqueo),
          ]),
          _tarjeta('Datos del Vehículo', [
            _fila('Tipo', caso.tipoVehiculo),
            _fila('Marca', caso.marca),
            _fila('Modelo', caso.modelo),
            _fila('Año', caso.anioFabricacion),
            _fila('Color', caso.color),
            _fila('Cilindraje', caso.cilindraje),
            _fila('Chasis', caso.chasis),
            _fila('Motor', caso.motor),
            _fila('Propietario', caso.propietario),
            _fila('Cédula Propietario', caso.cedulaPropietario),
            _fila('Conductor', caso.conductor),
            _fila('Cédula Conductor', caso.cedulaConductor),
          ]),
          _tarjeta('Motivo de Ingreso', [
            _fila('Causa legal', caso.causaLegal),
            _fila('Detalle causa', caso.detalleCausa),
          ]),
          if (caso.aplicaAlcohotest)
            _tarjeta('Alcoholemia', [
              _fila('N° de prueba', caso.numeroPruebaAlcoholemia),
              _fila('Resultado', '${caso.resultadoAlcoholemia} g/L'),
              _fila('Nombre del sancionado', caso.nombreSancionado),
              _fila('Cédula', caso.cedulaSancionado),
            ]),
          _tarjeta('Grúa y Custodia', [
            _fila('Traslado', caso.traslado),
            _fila('Nombre de la grúa', caso.nombreGruaParticular),
            _fila('Teléfono grúa', caso.telefonoGruaParticular),
            _fila('Valor grúa', caso.valorGrua),
            _fila('Km. Grúa Policial', caso.kmGrua),
            _fila('Servidor que recibe custodia', caso.custodioRecibeNombre),
          ]),
          _tarjeta('Estado del Vehículo', [
            _fila('Estado físico', caso.estadoVehiculo),
            _fila('Observaciones', caso.observaciones),
          ]),
          _tarjeta('Personal que Toma Procedimiento', [
            _fila('Grado / Nombre', caso.policiaNombre),
            _fila('Cédula', caso.policiaCedula),
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
