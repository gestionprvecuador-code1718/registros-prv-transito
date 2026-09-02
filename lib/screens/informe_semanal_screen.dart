// RUTA DE ARCHIVO: lib/screens/informe_semanal_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/storage_service.dart';
import '../services/docx_builder.dart';

class InformeSemanalScreen extends StatefulWidget {
  const InformeSemanalScreen({super.key});

  @override
  State<InformeSemanalScreen> createState() => _InformeSemanalScreenState();
}

class _InformeSemanalScreenState extends State<InformeSemanalScreen> {
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  final _jefaturaController = TextEditingController();
  final _patioController = TextEditingController();
  final _subzonaController = TextEditingController();
  final _subzonaAbrevController = TextEditingController();
  final _oficioNroController = TextEditingController();
  final _fechaOficioController = TextEditingController();
  final _asuntoOficioNroController = TextEditingController();
  final _asuntoOficioFechaController = TextEditingController();
  final _destinatarioNombreController = TextEditingController();
  final _destinatarioRangoController = TextEditingController();
  final _fechaLunesController = TextEditingController();
  final _fechaDomingoController = TextEditingController();
  final _vehiculosController = TextEditingController();
  final _motocicletasController = TextEditingController();
  final _observacionController = TextEditingController();
  final _firmanteNombreController = TextEditingController();
  final _firmanteRangoController = TextEditingController();

  bool _cargando = true;
  DateTime? _lunes;
  DateTime? _domingo;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  String _formatoFecha(DateTime d) => '${d.day.toString().padLeft(2, '0')} de ${_meses[d.month - 1]} de ${d.year}';

  /// La semana del informe SIEMPRE es lunes 00H00 a domingo 00H00 de la
  /// última semana completa (el informe se hace los lunes hasta el
  /// mediodía, reportando la semana que acaba de terminar).
  ({DateTime lunes, DateTime domingo}) _calcularUltimaSemana() {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final diasDesdeDomingo = hoySinHora.weekday % 7; // domingo=0, lunes=1, ... sábado=6
    final diff = diasDesdeDomingo == 0 ? 7 : diasDesdeDomingo;
    final domingo = hoySinHora.subtract(Duration(days: diff));
    final lunes = domingo.subtract(const Duration(days: 6));
    return (lunes: lunes, domingo: domingo);
  }

  Future<void> _inicializar() async {
    final semana = _calcularUltimaSemana();
    _lunes = semana.lunes;
    _domingo = semana.domingo;

    _jefaturaController.text = StorageService.ultimaSubzona.toUpperCase();
    _patioController.text = StorageService.ultimoCrv.toUpperCase();
    _subzonaController.text = StorageService.ultimaSubzona;
    _oficioNroController.text = StorageService.ultimoOficioInformeNro;
    _asuntoOficioNroController.text = StorageService.ultimoAsuntoOficioNro;
    _asuntoOficioFechaController.text = StorageService.ultimoAsuntoOficioFecha;
    _destinatarioNombreController.text = StorageService.ultimoDestinatarioNombre;
    _destinatarioRangoController.text = StorageService.ultimoDestinatarioRango;
    _firmanteNombreController.text = StorageService.ultimoFirmanteNombre.isNotEmpty
        ? StorageService.ultimoFirmanteNombre
        : StorageService.ultimoPoliciaNombre;
    _firmanteRangoController.text = StorageService.ultimoFirmanteRango;

    _fechaOficioController.text = _formatoFecha(DateTime.now());
    _fechaLunesController.text = _formatoFecha(_lunes!);
    _fechaDomingoController.text = _formatoFecha(_domingo!);

    final conteo = await StorageService.contarLibertadesEnRango(_lunes!, _domingo!);
    _vehiculosController.text = conteo.vehiculos.toString();
    _motocicletasController.text = conteo.motocicletas.toString();

    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    for (final c in [
      _jefaturaController, _patioController, _subzonaController, _subzonaAbrevController,
      _oficioNroController, _fechaOficioController, _asuntoOficioNroController,
      _asuntoOficioFechaController, _destinatarioNombreController, _destinatarioRangoController,
      _fechaLunesController, _fechaDomingoController, _vehiculosController,
      _motocicletasController, _observacionController, _firmanteNombreController,
      _firmanteRangoController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _generarYCompartir() async {
    // Recuerda los datos que rara vez cambian, para la próxima semana.
    StorageService.ultimoOficioInformeNro = _oficioNroController.text.trim();
    StorageService.ultimoAsuntoOficioNro = _asuntoOficioNroController.text.trim();
    StorageService.ultimoAsuntoOficioFecha = _asuntoOficioFechaController.text.trim();
    StorageService.ultimoDestinatarioNombre = _destinatarioNombreController.text.trim();
    StorageService.ultimoDestinatarioRango = _destinatarioRangoController.text.trim();
    StorageService.ultimoFirmanteNombre = _firmanteNombreController.text.trim();
    StorageService.ultimoFirmanteRango = _firmanteRangoController.text.trim();

    final bytes = DocxBuilder.buildInformeSemanal(
      jefaturaNombre: _jefaturaController.text.trim(),
      patio: _patioController.text.trim(),
      subzona: _subzonaController.text.trim(),
      subzonaAbrev: _subzonaAbrevController.text.trim(),
      oficioNro: _oficioNroController.text.trim(),
      fechaOficio: _fechaOficioController.text.trim(),
      asuntoOficioNro: _asuntoOficioNroController.text.trim(),
      asuntoOficioFecha: _asuntoOficioFechaController.text.trim(),
      destinatarioNombre: _destinatarioNombreController.text.trim(),
      destinatarioRango: _destinatarioRangoController.text.trim(),
      fechaLunes: _fechaLunesController.text.trim(),
      fechaDomingo: _fechaDomingoController.text.trim(),
      vehiculos: int.tryParse(_vehiculosController.text.trim()) ?? 0,
      motocicletas: int.tryParse(_motocicletasController.text.trim()) ?? 0,
      observacionAdicional: _observacionController.text,
      firmanteNombre: _firmanteNombreController.text.trim(),
      firmanteRango: _firmanteRangoController.text.trim(),
    );

    final nombreArchivo =
        'INFORME_SEMANAL_${_fechaLunesController.text.replaceAll(' ', '_')}_${_patioController.text.trim()}.docx';

    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombreArchivo,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Informe Semanal - ${_patioController.text.trim()}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informe Semanal')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Semana calculada automáticamente: lunes ${_fechaLunesController.text} '
                      '00H00 → domingo ${_fechaDomingoController.text} 00H00. '
                      'El conteo de vehículos/motos ya se tomó de tus Libertades guardadas '
                      'en ese rango — revisa y ajusta si hace falta.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _seccion('Encabezado (cambia poco — se recuerda)', [
                  _campo(_jefaturaController, 'Jefatura de Tránsito (Ej. SANTO DOMINGO)'),
                  _campo(_patioController, 'Patio / CRV (Ej. CONTROL 120)'),
                  _campo(_subzonaController, 'Subzona completa (Ej. Santo Domingo de los Tsáchilas)'),
                  _campo(_subzonaAbrevController, 'Abreviatura de Subzona (Ej. SDT)'),
                ]),
                _seccion('Oficio de este informe (cambia cada semana)', [
                  _campo(_oficioNroController, 'N° de Oficio de este informe'),
                  _campo(_fechaOficioController, 'Fecha del oficio'),
                ]),
                _seccion('Oficio de referencia (ASUNTO — rara vez cambia)', [
                  _campo(_asuntoOficioNroController, 'N° de Oficio de referencia'),
                  _campo(_asuntoOficioFechaController, 'Fecha del oficio de referencia'),
                ]),
                _seccion('Destinatario (cambia solo si hay nuevo jefe)', [
                  _campo(_destinatarioNombreController, 'Nombre completo del Director'),
                  _campo(_destinatarioRangoController, 'Rango (Ej. Coronel de E.M)'),
                ]),
                _seccion('Semana reportada', [
                  _campo(_fechaLunesController, 'Desde (lunes)'),
                  _campo(_fechaDomingoController, 'Hasta (domingo)'),
                ]),
                _seccion('Conteo de la semana (auto, editable)', [
                  Row(
                    children: [
                      Expanded(child: _campo(_vehiculosController, 'N° Vehículos', tipo: TextInputType.number)),
                      const SizedBox(width: 10),
                      Expanded(child: _campo(_motocicletasController, 'N° Motocicletas', tipo: TextInputType.number)),
                    ],
                  ),
                  _campo(_observacionController, 'Observación adicional (opcional, para casos especiales)', lineas: 3),
                ]),
                _seccion('Quién firma (cambia poco — se recuerda)', [
                  _campo(_firmanteNombreController, 'Nombre completo de quien firma'),
                  _campo(_firmanteRangoController, 'Rango de quien firma'),
                ]),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Generar y compartir Informe Semanal'),
                  onPressed: _generarYCompartir,
                ),
              ],
            ),
    );
  }

  Widget _seccion(String titulo, List<Widget> hijos) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...hijos.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
          ],
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {int lineas = 1, TextInputType? tipo}) {
    return TextFormField(
      controller: ctrl,
      maxLines: lineas,
      keyboardType: tipo,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }
}
