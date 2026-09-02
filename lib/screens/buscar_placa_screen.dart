// RUTA DE ARCHIVO: lib/screens/buscar_placa_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/storage_service.dart';
import 'formulario_screen.dart';
import 'formulario_libertad_screen.dart';

class BuscarPlacaScreen extends StatefulWidget {
  const BuscarPlacaScreen({super.key});

  @override
  State<BuscarPlacaScreen> createState() => _BuscarPlacaScreenState();
}

/// Ícono vectorizado (vehículo + moto, Material Icons son vectores) que
/// indica de un vistazo el estado del vehículo: ROJO = todavía
/// ingresado en el patio, VERDE = ya fue liberado. El mismo widget se
/// puede reutilizar tal cual en cualquier otra pantalla que liste
/// vehículos (ej. un futuro panel nacional).
class EstadoVehiculoIcon extends StatelessWidget {
  final bool liberado;
  final double size;
  const EstadoVehiculoIcon({super.key, required this.liberado, this.size = 22});

  @override
  Widget build(BuildContext context) {
    final color = liberado ? Colors.green.shade600 : Colors.red.shade600;
    return Tooltip(
      message: liberado ? 'Vehículo liberado' : 'Vehículo ingresado (en el patio)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car, color: color, size: size),
            const SizedBox(width: 2),
            Icon(Icons.two_wheeler, color: color, size: size),
          ],
        ),
      ),
    );
  }
}

class _BuscarPlacaScreenState extends State<BuscarPlacaScreen> {
  final _controller = TextEditingController();
  List<CasoIngreso> _ingresos = [];
  List<CasoLibertad> _libertades = [];
  bool _buscando = false;
  bool _yaSeBusco = false;

  Future<void> _buscar() async {
    final placa = _controller.text.trim();
    if (placa.isEmpty) return;
    setState(() => _buscando = true);

    final ingresos = await StorageService.buscarIngresosPorPlaca(placa);
    final libertades = await StorageService.buscarLibertadesPorPlaca(placa);

    if (mounted) {
      setState(() {
        _ingresos = ingresos;
        _libertades = libertades;
        _buscando = false;
        _yaSeBusco = true;
      });
    }
  }

  /// True si ya existe un caso de Libertad para la misma hoja de ingreso.
  bool _yaTieneLibertad(CasoIngreso ingreso) {
    return _libertades.any((l) => l.hojaIngresoNro == ingreso.hojaIngresoNro);
  }

  void _editarIngreso(CasoIngreso c) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormularioScreen(casoExistente: c)),
    ).then((_) => _buscar()); // refresca por si guardó cambios
  }

  void _liberarVehiculo(CasoIngreso ingreso) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormularioLibertadScreen(ingreso: ingreso)),
    ).then((_) => _buscar()); // refresca para que el ícono pase a verde
  }

  void _editarLibertad(CasoLibertad libertad) {
    // Busca el ingreso original de esta libertad (por hoja de ingreso)
    // para poder mostrar los datos heredados de solo lectura al editar.
    CasoIngreso? ingresoBase;
    try {
      ingresoBase = _ingresos.firstWhere((i) => i.hojaIngresoNro == libertad.hojaIngresoNro);
    } catch (_) {
      ingresoBase = null;
    }
    if (ingresoBase == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioLibertadScreen(ingreso: ingresoBase!, existente: libertad),
      ),
    ).then((_) => _buscar());
  }

  Future<void> _compartirIngreso(CasoIngreso c) async {
    final bytes = StorageService.generarWordIngreso(c);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: c.placa, esIngreso: true);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Ingreso ${c.placa} - REGISTROS PRV TRANSITO');
  }

  Future<void> _compartirLibertad(CasoLibertad c) async {
    final bytes = StorageService.generarWordLibertad(c);
    final nombre = StorageService.obtenerNombreArchivoWord(placa: c.placa, esIngreso: false);
    final xFile = XFile.fromData(
      Uint8List.fromList(bytes),
      name: nombre,
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );
    await Share.shareXFiles([xFile], text: 'Libertad ${c.placa} - REGISTROS PRV TRANSITO');
  }

  @override
  Widget build(BuildContext context) {
    final sinResultados = _yaSeBusco && _ingresos.isEmpty && _libertades.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar por placa')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa',
                      hintText: 'Ej. PAD1978',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _buscando ? null : _buscar,
                  child: _buscando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (sinResultados)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No se encontró ningún caso con esa placa.', textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView(
              children: [
                ..._ingresos.map((c) {
                  final tieneLibertad = _yaTieneLibertad(c);
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: EstadoVehiculoIcon(liberado: tieneLibertad),
                          title: Text('INGRESO — ${c.placa}'),
                          subtitle: Text('${c.marca} ${c.color} — Hoja ${c.hojaIngresoNro}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share_outlined),
                                tooltip: 'Compartir / Descargar',
                                onPressed: () => _compartirIngreso(c),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Editar',
                                onPressed: () => _editarIngreso(c),
                              ),
                            ],
                          ),
                        ),
                        if (!tieneLibertad)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.tonalIcon(
                                icon: const Icon(Icons.logout),
                                label: const Text('Liberar vehículo'),
                                onPressed: () => _liberarVehiculo(c),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                ..._libertades.map((c) => Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const EstadoVehiculoIcon(liberado: true),
                        title: Text('LIBERTAD — ${c.placa}'),
                        subtitle: Text('${c.marca} ${c.color} — Hoja ${c.hojaIngresoNro}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_outlined),
                              tooltip: 'Compartir / Descargar',
                              onPressed: () => _compartirLibertad(c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Editar',
                              onPressed: () => _editarLibertad(c),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
