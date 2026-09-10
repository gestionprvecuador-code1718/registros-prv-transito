// RUTA DE ARCHIVO: lib/screens/documento_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'home_screen.dart';
import '../models/caso_ingreso.dart';
import '../models/caso_libertad.dart';
import '../services/storage_service.dart';
import 'buscar_placa_screen.dart' show EstadoVehiculoIcon;
import 'formulario_screen.dart';
import 'captura_screen.dart';

/// 02/sep: sello grande tipo "estampado" (rojo = todavía en el patio,
/// verde = ya liberado) — Xavier pidió aprovechar el espacio libre debajo
/// de cada caso encontrado para que el estado se note de un vistazo,
/// como un sello de goma. Reutilizable en cualquier pantalla que liste
/// ingresos/libertades.
class SelloEstadoGrande extends StatelessWidget {
  final bool liberado;
  const SelloEstadoGrande({super.key, required this.liberado});

  @override
  Widget build(BuildContext context) {
    final color = liberado ? Colors.green.shade700 : Colors.red.shade700;
    final texto = liberado ? 'LIBERADO' : 'EN EL PATIO';
    final icono = liberado ? Icons.check_circle_outline : Icons.lock_outline;
    return Center(
      child: Transform.rotate(
        angle: -0.08,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 3),
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: color, size: 26),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ya no existe un solo .docx con "todos los ingresos juntos" (eso era
/// de la arquitectura vieja). Ahora esta pantalla simplemente lista
/// todos los casos guardados de un tipo, y cada uno se comparte por
/// separado. El consolidado de TODOS los casos es el Excel (botón
/// "EXPORTAR MATRIZ COMPLETA" en la pantalla principal).
class DocumentoScreen extends StatefulWidget {
  final TipoParte tipo;
  const DocumentoScreen({super.key, required this.tipo});

  @override
  State<DocumentoScreen> createState() => _DocumentoScreenState();
}

class _DocumentoScreenState extends State<DocumentoScreen> {
  List<CasoIngreso> _ingresos = [];
  List<CasoLibertad> _libertades = [];
  bool _cargando = true;

  bool get _esIngreso => widget.tipo == TipoParte.ingreso;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    // 02/sep: ahora SIEMPRE se cargan ambas listas (antes solo se cargaba
    // una u otra según la pestaña) — se necesita cruzar ingresos con
    // libertades para saber el estado REAL de cada vehículo (antes el
    // ícono quedaba fijo en rojo aunque ya estuviera liberado).
    final ingresos = await StorageService.obtenerIngresos();
    ingresos.sort((a, b) => b.creado.compareTo(a.creado));
    final libertades = await StorageService.obtenerLibertades();
    libertades.sort((a, b) => b.creado.compareTo(a.creado));
    if (mounted) {
      setState(() {
        _ingresos = ingresos;
        _libertades = libertades;
        _cargando = false;
      });
    }
  }

  bool _yaTieneLibertad(CasoIngreso ingreso) {
    return _libertades.any((l) => l.hojaIngresoNro == ingreso.hojaIngresoNro);
  }

  void _liberarVehiculo(CasoIngreso ingreso) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CapturaScreen(tipo: TipoParte.libertad, ingresoBase: ingreso),
      ),
    ).then((_) => _cargar());
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
    final titulo = _esIngreso ? 'Ingresos guardados' : 'Libertades guardadas';
    final total = _esIngreso ? _ingresos.length : _libertades.length;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : total == 0
              ? const Center(child: Text('Todavía no hay registros guardados'))
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: _esIngreso
                      ? _ingresos
                          .map((c) {
                            final tieneLibertad = _yaTieneLibertad(c);
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ListTile(
                                    leading: EstadoVehiculoIcon(liberado: tieneLibertad),
                                    title: Text('${c.placa} — ${c.marca} ${c.color}'),
                                    subtitle: Text('Hoja ${c.hojaIngresoNro} — ${c.fechaIngreso}'),
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
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => FormularioIngresoScreen(caso: c, esEdicion: true),
                                            ),
                                          ).then((_) => _cargar()),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 02/sep: sello grande visible + botón "Liberar
                                  // vehículo" — Xavier pidió aprovechar el
                                  // espacio libre debajo de cada caso.
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                                    child: Column(
                                      children: [
                                        SelloEstadoGrande(liberado: tieneLibertad),
                                        if (!tieneLibertad) ...[
                                          const SizedBox(height: 12),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.tonalIcon(
                                              icon: const Icon(Icons.logout),
                                              label: const Text('Liberar vehículo'),
                                              onPressed: () => _liberarVehiculo(c),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList()
                      : _libertades
                          .map((c) => Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                      leading: const EstadoVehiculoIcon(liberado: true),
                                      title: Text('${c.placa} — ${c.marca} ${c.color}'),
                                      subtitle: Text('Hoja ${c.hojaIngresoNro} — Salida ${c.fechaSalida}'),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.share_outlined),
                                        tooltip: 'Compartir / Descargar',
                                        onPressed: () => _compartirLibertad(c),
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.fromLTRB(12, 4, 12, 14),
                                      child: SelloEstadoGrande(liberado: true),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                ),
    );
  }
}
