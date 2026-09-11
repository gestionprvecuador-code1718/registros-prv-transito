// RUTA DE ARCHIVO: lib/screens/seleccionar_vehiculo_screen.dart

import 'package:flutter/material.dart';
import '../models/participante_vehiculo.dart';
import '../models/caso_ingreso.dart';
import '../services/pdf_parser_service.dart';
import 'formulario_screen.dart';

class SeleccionarVehiculoScreen extends StatelessWidget {
  final List<ParticipanteVehiculo> participantes;
  final MetadatosParte metadatos;
  // Texto crudo que extrajo el PDF, tal cual — se reenvía al
  // formulario para poder revisarlo con "Ver texto reconocido" cuando
  // algo no se extrajo bien, en vez de adivinar a ciegas.
  final String? textoCompleto;

  const SeleccionarVehiculoScreen({
    super.key,
    required this.participantes,
    required this.metadatos,
    this.textoCompleto,
  });

  void _elegir(BuildContext context, ParticipanteVehiculo p) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final parser = PdfParserService();

    final observaciones = [
      if (metadatos.direccion.isNotEmpty) 'Lugar: ${metadatos.direccion}',
    ].join('\n');

    final causaLegal = parser.sugerirCausaLegal(metadatos.circunstancias);
    final detalleCausa = parser.sugerirDetalleCausa(causaLegal, metadatos.circunstancias) ?? '';

    final caso = CasoIngreso(
      id: id,
      marca: p.marca,
      modelo: p.modelo,
      color: p.color,
      placa: p.placa,
      tipoVehiculo: p.tipo,
      chasis: p.chasis,
      anioFabricacion: p.anio,
      // El parser ya deja "propietario" con el mismo dato de
      // "conductor" cuando el parte no distingue a uno del otro —
      // igual queda editable en el formulario.
      propietario: p.propietario,
      cedulaPropietario: p.propietarioCedula,
      conductor: p.conductor,
      cedulaConductor: p.conductorCedula,
      // "Fecha de retención"/"Hora de retención" en el formulario,
      // aunque el campo del modelo sigue llamándose fechaIngreso.
      fechaIngreso: metadatos.fechaHecho,
      horaRetencion: metadatos.horaHecho,
      parteIngresoNro: metadatos.parteNo,
      causaLegal: causaLegal,
      detalleCausa: detalleCausa,
      // Ya viene formateado como "Grado. NOMBRE COMPLETO" (ej. "Sgos.
      // PACA PILCO ANGEL HERIBERTO").
      policiaNombre: metadatos.elaboradoPor,
      policiaCedula: metadatos.elaboradoPorCedula,
      observaciones: observaciones,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FormularioIngresoScreen(caso: caso, textoOcr: textoCompleto)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona el vehículo')),
      body: Column(
        children: [
          if (metadatos.parteNo.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(
                'Parte Policial N°: ${metadatos.parteNo}\n'
                'Se detectaron ${participantes.length} vehículo(s). Toca el que te interesa registrar.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: participantes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final p = participantes[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text('${i + 1}')),
                    title: Text(p.placa, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(
                      '${p.marca} ${p.color} — ${p.tipo}\n'
                      'Propietario: ${p.propietario.isEmpty ? p.conductor : p.propietario}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _elegir(context, p),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
