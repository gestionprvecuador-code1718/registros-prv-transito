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
    if (_esIngreso) {
      final lista = await StorageService.obtenerIngresos();
      lista.sort((a, b) => b.creado.compareTo(a.creado)); // más reciente primero
      if (mounted) setState(() { _ingresos = lista; _cargando = false; });
    } else {
      final lista = await StorageService.obtenerLibertades();
      lista.sort((a, b) => b.creado.compareTo(a.creado));
      if (mounted) setState(() { _libertades = lista; _cargando = false; });
    }
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
                          .map((c) => Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: const EstadoVehiculoIcon(liberado: false),
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
                                          MaterialPageRoute(builder: (_) => FormularioScreen(casoExistente: c)),
                                        ).then((_) => _cargar()),
                                      ),
                                    ],
                                  ),
                                ),
                              ))
                          .toList()
                      : _libertades
                          .map((c) => Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: const EstadoVehiculoIcon(liberado: true),
                                  title: Text('${c.placa} — ${c.marca} ${c.color}'),
                                  subtitle: Text('Hoja ${c.hojaIngresoNro} — Salida ${c.fechaSalida}'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.share_outlined),
                                    tooltip: 'Compartir / Descargar',
                                    onPressed: () => _compartirLibertad(c),
                                  ),
                                ),
                              ))
                          .toList(),
                ),
    );
  }
}
