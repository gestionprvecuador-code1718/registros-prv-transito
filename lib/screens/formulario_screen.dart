import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../utils/pago_validacion.dart';
import 'documento_screen.dart';
import 'home_screen.dart';

Future<String> _patioDelUsuario() async {
  final usuario = FirebaseAuth.instance.currentUser;
  if (usuario == null) return '';
  final perfil = await AuthService().obtenerPerfil(usuario.uid);
  return perfil?['patio'] ?? '';
}

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

/// Campo de texto reutilizable, ya conectado a un TextEditingController.
class _Campo extends StatelessWidget {
  final String etiqueta;
  final TextEditingController controller;
  final int lineas;

  const _Campo({required this.etiqueta, required this.controller, this.lineas = 1});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: lineas,
        decoration: InputDecoration(
          labelText: etiqueta,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

// ============================================================
// FORMULARIO: INGRESO   (sin cambios respecto a tu versión)
// ============================================================

class FormularioIngresoScreen extends StatefulWidget {
  final CasoIngreso caso;
  final String? textoOcr;
  final bool esEdicion;
  const FormularioIngresoScreen({super.key, required this.caso, this.textoOcr, this.esEdicion = false});

  @override
  State<FormularioIngresoScreen> createState() => _FormularioIngresoScreenState();
}

const _gradosDirigidoA = ['Mi Mayor', 'Mi Coronel', 'Mi Capitán', 'Mi Teniente', 'Mi General', 'Mi Subteniente'];

class _FormularioIngresoScreenState extends State<FormularioIngresoScreen> {
  late final Map<String, TextEditingController> c;
  bool _guardando = false;
  late String _dirigidoA;
  late String _trasladadoTipo;

  @override
  void initState() {
    super.initState();
    final caso = widget.caso;
    _dirigidoA = _gradosDirigidoA.contains(caso.dirigidoA) ? caso.dirigidoA : 'Mi Mayor';
    _trasladadoTipo = caso.comoLlego == 'huincha' ? 'huincha' : 'sus propios medios';
    c = {
      'crv': TextEditingController(text: caso.crv.isEmpty ? 'Control 120' : caso.crv),
      'tipoVehiculo': TextEditingController(text: caso.tipoVehiculo),
      'marca': TextEditingController(text: caso.marca),
      'color': TextEditingController(text: caso.color),
      'placa': TextEditingController(text: caso.placa),
      'propietario': TextEditingController(text: caso.propietario),
      'cedula': TextEditingController(text: caso.cedulaPropietario),
      'causa': TextEditingController(text: caso.causa),
      'kmVia': TextEditingController(text: caso.kmVia),
      'hoja': TextEditingController(text: caso.hojaIngresoNro),
      'parte': TextEditingController(text: caso.parteIngresoNro),
      'fecha': TextEditingController(text: caso.fechaIngreso),
      'huinchaNombre': TextEditingController(text: caso.huinchaNombre),
      'tomaProc': TextEditingController(text: caso.tomaProcedimiento),
      'novedades': TextEditingController(text: caso.novedades),
    };
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final caso = CasoIngreso(
      id: widget.caso.id,
      crv: c['crv']!.text,
      tipoVehiculo: c['tipoVehiculo']!.text,
      marca: c['marca']!.text,
      color: c['color']!.text,
      placa: c['placa']!.text,
      propietario: c['propietario']!.text,
      cedulaPropietario: c['cedula']!.text,
      causa: c['causa']!.text,
      kmVia: c['kmVia']!.text,
      hojaIngresoNro: c['hoja']!.text,
      parteIngresoNro: c['parte']!.text,
      fechaIngreso: c['fecha']!.text,
      comoLlego: _trasladadoTipo,
      huinchaNombre: c['huinchaNombre']!.text,
      tomaProcedimiento: c['tomaProc']!.text,
      dirigidoA: _dirigidoA,
      novedades: c['novedades']!.text,
      creado: widget.caso.creado,
    );

    final patio = await _patioDelUsuario();

    if (widget.esEdicion) {
      await StorageService().actualizarIngreso(caso, patio: patio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caso actualizado')));
      Navigator.pop(context);
      return;
    }

    await StorageService().agregarIngreso(caso, patio: patio);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.ingreso)),
      (route) => route.isFirst,
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _dirigidoA,
            decoration: const InputDecoration(labelText: 'Dirigido a', border: OutlineInputBorder(), isDense: true),
            items: _gradosDirigidoA.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _dirigidoA = v ?? _dirigidoA),
          ),
          const SizedBox(height: 12),
          _Campo(etiqueta: 'CRV / Control', controller: c['crv']!),
          _Campo(etiqueta: 'Tipo de vehículo', controller: c['tipoVehiculo']!),
          _Campo(etiqueta: 'Marca', controller: c['marca']!),
          _Campo(etiqueta: 'Color', controller: c['color']!),
          _Campo(etiqueta: 'Placa', controller: c['placa']!),
          _Campo(etiqueta: 'Propietario', controller: c['propietario']!),
          _Campo(etiqueta: 'Cédula del propietario', controller: c['cedula']!),
          _Campo(etiqueta: 'Causa', controller: c['causa']!),
          _Campo(etiqueta: 'Km / vía', controller: c['kmVia']!),
          _Campo(etiqueta: 'Hoja de ingreso Nro.', controller: c['hoja']!),
          _Campo(etiqueta: 'Parte de ingreso Nro.', controller: c['parte']!),
          _Campo(etiqueta: 'Fecha de ingreso (dd/mm/aaaa)', controller: c['fecha']!),
          DropdownButtonFormField<String>(
            initialValue: _trasladadoTipo,
            decoration:
                const InputDecoration(labelText: 'TRASLADADO EN', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'sus propios medios', child: Text('Sus propios medios')),
              DropdownMenuItem(value: 'huincha', child: Text('Huincha')),
            ],
            onChanged: (v) => setState(() => _trasladadoTipo = v ?? _trasladadoTipo),
          ),
          if (_trasladadoTipo == 'huincha') ...[
            const SizedBox(height: 12),
            _Campo(etiqueta: 'Nombre de la huincha', controller: c['huinchaNombre']!),
          ],
          const SizedBox(height: 12),
          _Campo(etiqueta: 'Toma procedimiento', controller: c['tomaProc']!),
          _Campo(etiqueta: 'Novedades', controller: c['novedades']!, lineas: 3),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: _guardando
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : (widget.esEdicion ? 'Guardar cambios' : 'Guardar en Ingresos.docx')),
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FORMULARIO: LIBERTAD   (actualizado: fecha de salida + cálculo
// automático de días, varios pagos, observaciones, y validación
// cruzada antes de guardar)
// ============================================================

class FormularioLibertadScreen extends StatefulWidget {
  final CasoLibertad caso;
  final String? textoOcr;
  final bool esEdicion;
  const FormularioLibertadScreen({super.key, required this.caso, this.textoOcr, this.esEdicion = false});

  @override
  State<FormularioLibertadScreen> createState() => _FormularioLibertadScreenState();
}

class _PagoControllers {
  final ordenPago = TextEditingController();
  final comprobante = TextEditingController();
  final diasPagados = TextEditingController();
  final precioUnitario = TextEditingController();
  final valor = TextEditingController();
  final horaFecha = TextEditingController();
  final entidad = TextEditingController();

  _PagoControllers.desde(PagoGaraje p) {
    ordenPago.text = p.ordenPagoNro;
    comprobante.text = p.comprobantePagoNro;
    diasPagados.text = p.diasPagados;
    precioUnitario.text = p.precioUnitario;
    valor.text = p.valor;
    horaFecha.text = p.horaFechaPago;
    entidad.text = p.entidadFinanciera;
  }

  PagoGaraje aPagoGaraje() => PagoGaraje(
        ordenPagoNro: ordenPago.text,
        comprobantePagoNro: comprobante.text,
        diasPagados: diasPagados.text,
        precioUnitario: precioUnitario.text,
        valor: valor.text,
        horaFechaPago: horaFecha.text,
        entidadFinanciera: entidad.text,
      );
}

class _FormularioLibertadScreenState extends State<FormularioLibertadScreen> {
  late final Map<String, TextEditingController> c;
  late List<_PagoControllers> _pagos;
  late String _dirigidoA;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final caso = widget.caso;
    _dirigidoA = _gradosDirigidoA.contains(caso.dirigidoA) ? caso.dirigidoA : 'Mi Mayor';
    c = {
      'crv': TextEditingController(text: caso.crv.isEmpty ? 'Control 120' : caso.crv),
      'causa': TextEditingController(text: caso.causa),
      'memorandoNro': TextEditingController(text: caso.memorandoNro),
      'memorandoFecha': TextEditingController(text: caso.memorandoFecha),
      'oficioNro': TextEditingController(text: caso.oficioDevolucionNro),
      'firmadoPor': TextEditingController(text: caso.firmadoPor),
      'marca': TextEditingController(text: caso.marca),
      'color': TextEditingController(text: caso.color),
      'placa': TextEditingController(text: caso.placa),
      'retiradoPor': TextEditingController(text: caso.retiradoPor),
      'cedula': TextEditingController(text: caso.cedulaRetira),
      'hoja': TextEditingController(text: caso.hojaIngresoNro),
      'parte': TextEditingController(text: caso.parteIngresoNro),
      'fechaIngreso': TextEditingController(text: caso.fechaIngreso),
      'fechaSalida': TextEditingController(text: caso.fechaSalida),
      'dias': TextEditingController(text: caso.diasPermanencia),
      'tipoVehiculo': TextEditingController(text: caso.tipoVehiculo),
      'observaciones': TextEditingController(text: caso.observaciones),
    };
    final listaPagos = caso.pagos.isEmpty ? [PagoGaraje()] : caso.pagos;
    _pagos = listaPagos.map((p) => _PagoControllers.desde(p)).toList();
  }

  void _agregarPago() {
    setState(() => _pagos.add(_PagoControllers.desde(PagoGaraje())));
  }

  void _quitarPago(int index) {
    if (_pagos.length <= 1) return; // siempre debe quedar al menos uno
    setState(() => _pagos.removeAt(index));
  }

  /// Calcula automáticamente los días de permanencia a partir de
  /// "Fecha de ingreso" y "Fecha de salida" (formato dd/mm/aaaa).
  void _calcularDias() {
    final ingreso = parseFechaDdMmAaaa(c['fechaIngreso']!.text);
    final salida = parseFechaDdMmAaaa(c['fechaSalida']!.text);
    if (ingreso == null || salida == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa el formato de las fechas (dd/mm/aaaa) para calcular los días.')),
      );
      return;
    }
    final dias = calcularDiasPermanencia(ingreso, salida);
    setState(() => c['dias']!.text = dias.toString());
  }

  /// Corre las dos validaciones cruzadas y muestra el resultado.
  /// Solo bloquea el guardado si hay un error real (diferencia grande
  /// de valores); una diferencia pequeña o de días es advertencia y
  /// deja seguir, precargando el campo Observaciones (editable).
  Future<bool> _validarAntesDeGuardar() async {
    final pagosGaraje = _pagos.map((p) => p.aPagoGaraje()).toList();
    final resultado = validarCasoLibertad(
      pagosGaraje,
      c['fechaIngreso']!.text,
      c['fechaSalida']!.text,
    );

    if (resultado.observacionCombinada.isNotEmpty && c['observaciones']!.text.trim().isEmpty) {
      c['observaciones']!.text = resultado.observacionCombinada;
    }

    if (!resultado.valores.esError) {
      // OK o advertencia: seguimos, pero si hay algo que avisar lo mostramos.
      if (!resultado.valores.ok || !resultado.dias.ok) {
        if (!mounted) return true;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Revisión de pagos'),
            content: Text('${resultado.valores.mensaje}\n\n${resultado.dias.mensaje}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido, continuar')),
            ],
          ),
        );
      }
      return true;
    }

    // Error real: bloquea el guardado.
    if (!mounted) return false;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Valores de garaje no coinciden'),
        content: Text(resultado.valores.mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Revisar datos')),
        ],
      ),
    );
    return false;
  }

  Future<void> _guardar() async {
    final puedeContinuar = await _validarAntesDeGuardar();
    if (!puedeContinuar) return;

    setState(() => _guardando = true);
    final caso = CasoLibertad(
      id: widget.caso.id,
      crv: c['crv']!.text,
      dirigidoA: _dirigidoA,
      causa: c['causa']!.text,
      memorandoNro: c['memorandoNro']!.text,
      memorandoFecha: c['memorandoFecha']!.text,
      oficioDevolucionNro: c['oficioNro']!.text,
      firmadoPor: c['firmadoPor']!.text,
      marca: c['marca']!.text,
      color: c['color']!.text,
      placa: c['placa']!.text,
      retiradoPor: c['retiradoPor']!.text,
      cedulaRetira: c['cedula']!.text,
      hojaIngresoNro: c['hoja']!.text,
      parteIngresoNro: c['parte']!.text,
      fechaIngreso: c['fechaIngreso']!.text,
      fechaSalida: c['fechaSalida']!.text,
      diasPermanencia: c['dias']!.text,
      tipoVehiculo: c['tipoVehiculo']!.text,
      observaciones: c['observaciones']!.text,
      pagos: _pagos.map((p) => p.aPagoGaraje()).toList(),
      creado: widget.caso.creado,
    );

    final patio = await _patioDelUsuario();

    if (widget.esEdicion) {
      await StorageService().actualizarLibertad(caso, patio: patio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caso actualizado')));
      Navigator.pop(context);
      return;
    }

    await StorageService().agregarLibertad(caso, patio: patio);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DocumentoScreen(tipo: TipoParte.libertad)),
      (route) => route.isFirst,
    );
  }

  Widget _tarjetaPago(int index) {
    final p = _pagos[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Pago #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_pagos.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Quitar este pago',
                    onPressed: () => _quitarPago(index),
                  ),
              ],
            ),
            _Campo(etiqueta: 'Orden de pago Garaje Nro.', controller: p.ordenPago),
            _Campo(etiqueta: 'Comprobante de pago Nro.', controller: p.comprobante),
            Row(
              children: [
                Expanded(child: _Campo(etiqueta: 'Días pagados', controller: p.diasPagados)),
                const SizedBox(width: 8),
                Expanded(child: _Campo(etiqueta: 'Precio unitario (USD/día)', controller: p.precioUnitario)),
              ],
            ),
            _Campo(etiqueta: 'Valor pagado según comprobante (USD)', controller: p.valor),
            _Campo(etiqueta: 'Hora y fecha de pago', controller: p.horaFecha),
            _Campo(etiqueta: 'Entidad financiera', controller: p.entidad),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.esEdicion ? 'Editar Libertad' : 'Confirmar datos de Libertad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_snippet_outlined),
            tooltip: 'Ver texto reconocido',
            onPressed: () => _verTextoOcr(context, widget.textoOcr),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _dirigidoA,
            decoration: const InputDecoration(labelText: 'Dirigido a', border: OutlineInputBorder(), isDense: true),
            items: _gradosDirigidoA.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (v) => setState(() => _dirigidoA = v ?? _dirigidoA),
          ),
          const SizedBox(height: 12),
          _Campo(etiqueta: 'CRV / Control', controller: c['crv']!),
          _Campo(etiqueta: 'Causa', controller: c['causa']!),
          _Campo(etiqueta: 'Memorando Nro.', controller: c['memorandoNro']!),
          _Campo(etiqueta: 'Fecha del memorando', controller: c['memorandoFecha']!),
          _Campo(etiqueta: 'Oficio de devolución Nro.', controller: c['oficioNro']!),
          _Campo(etiqueta: 'Firmado por', controller: c['firmadoPor']!),
          _Campo(etiqueta: 'Marca', controller: c['marca']!),
          _Campo(etiqueta: 'Color', controller: c['color']!),
          _Campo(etiqueta: 'Placa', controller: c['placa']!),
          _Campo(etiqueta: 'Retirado por', controller: c['retiradoPor']!),
          _Campo(etiqueta: 'C.C. / C.I. de quien retira', controller: c['cedula']!),
          _Campo(etiqueta: 'Hoja de ingreso Nro.', controller: c['hoja']!),
          _Campo(etiqueta: 'Parte de ingreso Nro.', controller: c['parte']!),
          _Campo(etiqueta: 'Fecha de ingreso (dd/mm/aaaa)', controller: c['fechaIngreso']!),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _Campo(etiqueta: 'Fecha de salida (dd/mm/aaaa)', controller: c['fechaSalida']!)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: OutlinedButton(
                  onPressed: _calcularDias,
                  child: const Text('Calcular días'),
                ),
              ),
            ],
          ),
          _Campo(etiqueta: 'Días de permanencia en el CRV', controller: c['dias']!),
          _Campo(etiqueta: 'Vehículo tipo', controller: c['tipoVehiculo']!),
          const Divider(height: 24),
          Row(
            children: [
              const Text('Pagos de garaje', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: _agregarPago,
                icon: const Icon(Icons.add),
                label: const Text('Agregar otro pago'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < _pagos.length; i++) _tarjetaPago(i),
          _Campo(etiqueta: 'Observaciones', controller: c['observaciones']!, lineas: 3),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: _guardando
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_guardando ? 'Guardando...' : (widget.esEdicion ? 'Guardar cambios' : 'Guardar en Libertades.docx')),
            onPressed: _guardando ? null : _guardar,
          ),
        ],
      ),
    );
  }
}
